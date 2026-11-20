//! Which sound card the backend plays on and sets the volume of (#48).
//!
//! The output is a value of the installation: the speakers are wired to one
//! output of the car, so it is set once, in `[audio] output_card`, and takes
//! effect when the backend starts. Without it the backend plays on the
//! system's default device as before, which the image makes ALSA card 0
//! (`carnine-audio-output.sh`). With it, it opens `default:CARD=<id>` and
//! sets the volume on that card's mixer control. Nothing here knows about a
//! particular board: the cards come from `/proc/asound/cards`.

use std::fs;
use std::path::Path;

/// Where Linux lists its sound cards.
pub const PROC_CARDS: &str = "/proc/asound/cards";

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

    /// The cpal (ALSA) device to open, `None` for the default device. The
    /// `default:` device of a card goes through its own configuration (on
    /// the Pi's HDMI the softvol with the `PCM` control), like the system
    /// default does today.
    pub fn device_name(&self) -> Option<String> {
        self.card
            .as_ref()
            .map(|card| format!("default:CARD={card}"))
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
        assert_eq!(default.device_name(), None);
        assert_eq!(default.mixer_card(), "0");
        assert_eq!(default.mixer_control(), "PCM");

        let jack = OutputChoice {
            card: Some("Headphones".to_string()),
            mixer_control: None,
        };
        assert_eq!(
            jack.device_name().as_deref(),
            Some("default:CARD=Headphones")
        );
        assert_eq!(jack.mixer_card(), "Headphones");

        let usb = OutputChoice {
            card: Some("Device".to_string()),
            mixer_control: Some("Speaker".to_string()),
        };
        assert_eq!(usb.mixer_control(), "Speaker");
    }
}
