//! Which sound card the backend plays on and sets the volume of (#48).
//!
//! The output is a value of the installation: the speakers are wired to one
//! output of the car, so it is set once, in `[audio] output_card`, and takes
//! effect when the backend starts. Without it the backend plays on the
//! system's default device as before, which the image makes ALSA card 0
//! (`carnine-audio-output.sh`). With it, the backend sets [`ALSA_PCM_CARD`]
//! before any thread runs, so ALSA's `default` device is that card's own
//! default (`default:CARD=<id>`, with the card's configuration: the softvol
//! `PCM` and IEC958 on the Pi's HDMI), and sets the volume on that card's
//! mixer control. cpal cannot open such a name itself: under ALSA it only
//! lists `default` and `plughw:<n>` named after the card (jeep-pi
//! 20.11.2026), and `plughw` would skip the card's configuration. A card that
//! is not there leaves everything on card 0. Nothing here knows about a
//! particular board: the cards come from `/proc/asound/cards`.

use std::fs;
use std::path::Path;

/// Where Linux lists its sound cards.
pub const PROC_CARDS: &str = "/proc/asound/cards";

/// The variable alsa-lib's `pcm.default` takes the card from
/// (`/usr/share/alsa/pcm/default.conf`, before `ALSA_CARD`).
pub const ALSA_PCM_CARD: &str = "ALSA_PCM_CARD";

/// Mixer card of the system default: card 0, where the image puts the
/// chosen output.
const DEFAULT_MIXER_CARD: &str = "0";

/// Mixer control without `[audio] mixer_control`: `PCM` is the softvol of
/// the Pi's HDMI outputs and the hardware control of its jack.
pub const DEFAULT_MIXER_CONTROL: &str = "PCM";

/// One line pair of `/proc/asound/cards`.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct SoundCard {
    pub index: u32,
    /// The card's id, e.g. `Headphones` or `vc4hdmi0`; stable across boots,
    /// unlike the index.
    pub id: String,
    /// The long name on the second line, e.g. `bcm2835 Headphones`.
    pub name: String,
}

/// Reads `/proc/asound/cards`:
///
/// ```text
///  2 [Headphones     ]: bcm2835_headpho - bcm2835 Headphones
///                       bcm2835 Headphones
/// ```
pub fn parse_cards(text: &str) -> Vec<SoundCard> {
    let mut cards: Vec<SoundCard> = Vec::new();
    for line in text.lines() {
        let trimmed = line.trim_start();
        let Some((index, rest)) = trimmed.split_once(' ') else {
            // A line of its own name only: the long name of the last card.
            if let Some(last) = cards.last_mut() {
                if !trimmed.is_empty() {
                    last.name = trimmed.trim().to_string();
                }
            }
            continue;
        };
        match (index.parse::<u32>(), rest.trim_start().strip_prefix('[')) {
            (Ok(index), Some(rest)) => {
                let Some((id, _)) = rest.split_once(']') else {
                    continue;
                };
                let short = rest
                    .split_once("]:")
                    .map(|(_, tail)| tail.trim().to_string())
                    .unwrap_or_default();
                cards.push(SoundCard {
                    index,
                    id: id.trim().to_string(),
                    name: short,
                });
            }
            _ => {
                if let Some(last) = cards.last_mut() {
                    last.name = trimmed.trim().to_string();
                }
            }
        }
    }
    cards
}

/// The cards of this machine; none where there is no ALSA (WSL).
pub fn read_cards(path: &Path) -> Vec<SoundCard> {
    fs::read_to_string(path)
        .map(|text| parse_cards(&text))
        .unwrap_or_default()
}

/// The output and mixer `[audio]` asks for.
#[derive(Debug, Clone, PartialEq, Eq, Default)]
pub struct OutputChoice {
    /// ALSA card id; `None` plays on the system default.
    pub card: Option<String>,
    /// Mixer control on that card; `None` is [`DEFAULT_MIXER_CONTROL`].
    pub mixer_control: Option<String>,
}

impl OutputChoice {
    pub fn from_config(audio: &crate::config::AudioConfig) -> Self {
        Self {
            card: audio.output_card.clone(),
            mixer_control: audio.mixer_control.clone(),
        }
    }

    /// What applies on this machine: the configured output when `cards`
    /// lists its card, else the system default (card 0, `PCM`) together
    /// with the card that is missing. Playback and volume both follow it,
    /// so they never part (#48: the volume once went to the jack while the
    /// sound stayed on HDMI).
    pub fn resolve(&self, cards: &[SoundCard]) -> (OutputChoice, Option<String>) {
        match &self.card {
            Some(card) if !cards.iter().any(|listed| &listed.id == card) => {
                (OutputChoice::default(), Some(card.clone()))
            }
            _ => (self.clone(), None),
        }
    }

    /// The value for [`ALSA_PCM_CARD`]; `None` keeps the system default.
    pub fn alsa_pcm_card(&self) -> Option<&str> {
        self.card.as_deref()
    }

    /// The `-c` of amixer: the card's id, or card 0 for the default.
    pub fn mixer_card(&self) -> &str {
        self.card.as_deref().unwrap_or(DEFAULT_MIXER_CARD)
    }

    pub fn mixer_control(&self) -> &str {
        self.mixer_control
            .as_deref()
            .unwrap_or(DEFAULT_MIXER_CONTROL)
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    /// As read on carnine-pc (Pi 4, 2026-11-20).
    const CARNINE_PC: &str = " 0 [vc4hdmi0       ]: vc4-hdmi - vc4-hdmi-0
                      vc4-hdmi-0
 1 [vc4hdmi1       ]: vc4-hdmi - vc4-hdmi-1
                      vc4-hdmi-1
 2 [Headphones     ]: bcm2835_headpho - bcm2835 Headphones
                      bcm2835 Headphones
";

    #[test]
    fn reads_the_cards_of_a_pi() {
        let cards = parse_cards(CARNINE_PC);
        let ids: Vec<(u32, &str, &str)> = cards
            .iter()
            .map(|card| (card.index, card.id.as_str(), card.name.as_str()))
            .collect();
        assert_eq!(
            ids,
            [
                (0, "vc4hdmi0", "vc4-hdmi-0"),
                (1, "vc4hdmi1", "vc4-hdmi-1"),
                (2, "Headphones", "bcm2835 Headphones"),
            ]
        );
        assert!(parse_cards("").is_empty());
        assert!(parse_cards("--- no soundcards ---\n").is_empty());
    }

    #[test]
    fn no_cards_file_is_no_cards() {
        assert!(read_cards(Path::new("/nonexistent/asound/cards")).is_empty());
    }

    #[test]
    fn card_ids_are_plain_names() {
        use crate::config::is_alsa_card_id;
        for good in ["Headphones", "vc4hdmi0", "USB_Audio", "Device-1"] {
            assert!(is_alsa_card_id(good), "{good}");
        }
        for bad in ["", "hw:0", "a b", "x,y", "../x", &"x".repeat(33)] {
            assert!(!is_alsa_card_id(bad), "{bad}");
        }
    }

    impl OutputChoice {
        pub fn card(card: &str) -> Self {
            Self {
                card: Some(card.to_string()),
                mixer_control: None,
            }
        }
    }

    #[test]
    fn the_default_plays_and_mixes_where_it_did() {
        let default = OutputChoice::default();
        assert_eq!(default.alsa_pcm_card(), None);
        assert_eq!(default.mixer_card(), "0");
        assert_eq!(default.mixer_control(), "PCM");

        let jack = OutputChoice {
            card: Some("Headphones".to_string()),
            mixer_control: None,
        };
        assert_eq!(jack.alsa_pcm_card(), Some("Headphones"));
        assert_eq!(jack.mixer_card(), "Headphones");

        let usb = OutputChoice {
            card: Some("Device".to_string()),
            mixer_control: Some("Speaker".to_string()),
        };
        assert_eq!(usb.mixer_control(), "Speaker");
    }

    #[test]
    fn a_card_that_is_not_there_leaves_playback_and_volume_on_card_0() {
        let cards = parse_cards(CARNINE_PC);
        let jack = OutputChoice {
            card: Some("Headphones".to_string()),
            mixer_control: Some("Speaker".to_string()),
        };
        assert_eq!(jack.resolve(&cards), (jack.clone(), None));

        let usb = OutputChoice {
            card: Some("USB".to_string()),
            mixer_control: Some("Speaker".to_string()),
        };
        let (effective, missing) = usb.resolve(&cards);
        assert_eq!(missing.as_deref(), Some("USB"));
        assert_eq!(effective.alsa_pcm_card(), None);
        assert_eq!(
            (effective.mixer_card(), effective.mixer_control()),
            ("0", "PCM")
        );

        // No ALSA at all (WSL): the same.
        assert_eq!(usb.resolve(&[]).0, OutputChoice::default());
        assert_eq!(
            OutputChoice::default().resolve(&[]),
            (OutputChoice::default(), None)
        );
    }
}
