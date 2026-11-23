//! Installation values the expert page shows and changes (#138).
//!
//! These are values set once per car: where the reverse gear comes from,
//! which output the speakers are wired to, whether a power supply is there.
//! Driver settings stay in the database, lists such as `[[controls]]` stay
//! in the files. A new value for the page is one entry in [`SCHEMA`]; the
//! page builds its fields from the schema, it knows no key itself.
//!
//! The page writes only `config.d/99-ui.toml` ([`config::UI_DROP_IN`]),
//! which is laid over every other file. A change is checked together with
//! the main file and all drop-ins, exactly as at start, before anything is
//! written; the file it replaces is kept as `99-ui.toml.bak`. Values take
//! effect when the backend starts again.

use std::ffi::OsString;
use std::fs;
use std::io::Write;
use std::os::unix::fs::OpenOptionsExt;
use std::path::{Path, PathBuf};

use anyhow::{Context, Result};

use crate::audio_output::SoundCard;
use crate::config::{self, Config};

/// How a value is entered and written to the file.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum Kind {
    Bool,
    /// A whole number in `min..=max`, in `unit` (may be empty).
    Integer {
        min: i64,
        max: i64,
        unit: &'static str,
    },
    /// One of `choices` (value, German label). `numeric` writes the value
    /// as a number instead of a string.
    Choice {
        choices: &'static [(&'static str, &'static str)],
        numeric: bool,
    },
    /// An ALSA card id; the choices are the cards of this machine
    /// (`/proc/asound/cards`), but a card that is not plugged in right now
    /// can still be kept.
    SoundCard,
    /// Free text up to `max_len` characters; the configuration's own
    /// checks decide the rest.
    Text {
        max_len: usize,
    },
}

/// One value of the page.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub struct Setting {
    /// Dotted key as in the file, e.g. `reverse_gear.gpio_line`.
    pub key: &'static str,
    /// Heading the page groups the value under.
    pub group: &'static str,
    pub label: &'static str,
    pub help: &'static str,
    pub kind: Kind,
    /// What applies when no file sets the key, as text; empty when it is
    /// unset (e.g. no GPIO line, the system's default output).
    pub default: &'static str,
    /// The value may be absent: resetting it leaves it unset.
    pub optional: bool,
}

const GROUP_REVERSE: &str = "Rückwärtsgang";
const GROUP_AUDIO: &str = "Tonausgabe";
const GROUP_POWER: &str = "Netzteil";

/// Every value of the page, in the order it shows them.
pub const SCHEMA: &[Setting] = &[
    Setting {
        key: "reverse_gear.source",
        group: GROUP_REVERSE,
        label: "Quelle",
        help: "Woher das Backend den Rückwärtsgang liest.",
        kind: Kind::Choice {
            choices: &[
                ("none", "keine"),
                ("gpio", "GPIO-Eingang"),
                ("demo", "Vorführung (über gRPC)"),
            ],
            numeric: false,
        },
        default: "none",
        optional: false,
    },
    Setting {
        key: "reverse_gear.gpio_chip",
        group: GROUP_REVERSE,
        label: "GPIO-Chip",
        help: "Gerätedatei des GPIO-Chips, beim Raspberry Pi /dev/gpiochip0.",
        kind: Kind::Text { max_len: 64 },
        default: "/dev/gpiochip0",
        optional: false,
    },
    Setting {
        key: "reverse_gear.gpio_line",
        group: GROUP_REVERSE,
        label: "GPIO-Leitung",
        help: "Nummer der Leitung auf dem Chip, z. B. 26 für GPIO 26. Nötig bei Quelle GPIO.",
        kind: Kind::Integer {
            min: 0,
            max: 511,
            unit: "",
        },
        default: "",
        optional: true,
    },
    Setting {
        key: "reverse_gear.active_low",
        group: GROUP_REVERSE,
        label: "Aktiv bei Masse",
        help: "Der Gang ist drin, wenn die Leitung auf Masse liegt (Optokoppler).",
        kind: Kind::Bool,
        default: "true",
        optional: false,
    },
    Setting {
        key: "reverse_gear.bias",
        group: GROUP_REVERSE,
        label: "Widerstand",
        help: "Pull-Widerstand am Eingang.",
        kind: Kind::Choice {
            choices: &[
                ("pull_up", "Pull-up (nach 3,3 V)"),
                ("pull_down", "Pull-down (nach Masse)"),
                ("none", "keiner"),
            ],
            numeric: false,
        },
        default: "pull_up",
        optional: false,
    },
    Setting {
        key: "reverse_gear.debounce_ms",
        group: GROUP_REVERSE,
        label: "Entprellen",
        help: "Kürzere Wechsel werden nicht beachtet. 0 schaltet es aus.",
        kind: Kind::Integer {
            min: 0,
            max: config::MAX_REVERSE_GEAR_DEBOUNCE_MS as i64,
            unit: "ms",
        },
        default: "50",
        optional: false,
    },
    Setting {
        key: "audio.output_card",
        group: GROUP_AUDIO,
        label: "Ausgang",
        help: "Soundkarte, an der die Lautsprecher hängen. Leer: Vorgabe des Systems. \
               Beim Image mit AC-3-Encoder leer lassen.",
        kind: Kind::SoundCard,
        default: "",
        optional: true,
    },
    Setting {
        key: "audio.mixer_control",
        group: GROUP_AUDIO,
        label: "Lautstärkeregler",
        help: "Mixer-Regler der Karte, an dem die Lautstärke gestellt wird.",
        kind: Kind::Text { max_len: 64 },
        default: crate::audio_output::DEFAULT_MIXER_CONTROL,
        optional: true,
    },
    Setting {
        key: "audio.channels",
        group: GROUP_AUDIO,
        label: "Kanäle",
        help: "4 oder 6 speisen Lautsprecher hinten. Leer: Vorgabe des Geräts (Stereo).",
        kind: Kind::Choice {
            choices: &[("2", "2 (Stereo)"), ("4", "4"), ("6", "6 (5.1)")],
            numeric: true,
        },
        default: "",
        optional: true,
    },
    Setting {
        key: "audio.rear_percent",
        group: GROUP_AUDIO,
        label: "Pegel hinten",
        help: "Lautstärke der hinteren Lautsprecher im Verhältnis zu vorn.",
        kind: Kind::Integer {
            min: 0,
            max: 100,
            unit: "%",
        },
        default: "100",
        optional: true,
    },
    Setting {
        key: "power_supply.enabled",
        group: GROUP_POWER,
        label: "Netzteil angeschlossen",
        help: "Das Backend spricht mit dem Kfz-Netzteil an der seriellen Schnittstelle.",
        kind: Kind::Bool,
        default: "false",
        optional: false,
    },
    Setting {
        key: "power_supply.amplifier_relay",
        group: GROUP_POWER,
        label: "Endstufe über Relais 3",
        help: "Relais 3 schaltet den Fernstart (REM) der Endstufe.",
        kind: Kind::Bool,
        default: "true",
        optional: false,
    },
    Setting {
        key: "power_supply.shutdown_on_poweroff",
        group: GROUP_POWER,
        label: "Mit der Zündung herunterfahren",
        help: "Aus, wenn der Pi am Tisch bei Zündung aus anbleiben soll.",
        kind: Kind::Bool,
        default: "true",
        optional: false,
    },
];

/// The page's texts in the language of the interface (#217).
///
/// German is the source and stays in [`SCHEMA`]; the other languages the
/// frontend offers come from `install_settings_texts.toml`, keyed by the
/// setting's key and, for headings, the first part of the key. Anything
/// missing falls back to German, so a gap never shows an empty field.
#[derive(Debug, Clone, Copy)]
pub struct Texts {
    table: Option<&'static toml::Table>,
}

/// Languages of the interface besides German, as in `install_settings_texts.toml`.
#[cfg(test)]
const TEXT_LANGUAGES: &[&str] = &[
    "en", "fr", "es", "it", "zh", "ja", "nl", "pl", "hu", "tr", "pt", "cs", "sv", "da",
];

fn text_tables() -> &'static toml::Table {
    static TABLES: std::sync::OnceLock<toml::Table> = std::sync::OnceLock::new();
    TABLES.get_or_init(|| {
        include_str!("install_settings_texts.toml")
            .parse()
            .expect("install_settings_texts.toml is valid TOML (checked by a test)")
    })
}

impl Texts {
    /// Texts for a language code as the interface names it (`"en"`,
    /// `"en-US"`, `"pt_PT"`); German for `"de"`, an empty or unknown code.
    pub fn for_language(language: &str) -> Self {
        let primary = language
            .split(['-', '_'])
            .next()
            .unwrap_or_default()
            .trim()
            .to_ascii_lowercase();
        let table = text_tables().get(&primary).and_then(toml::Value::as_table);
        Texts { table }
    }

    /// Whether these are the German texts of the schema.
    #[cfg(test)]
    pub fn is_german(&self) -> bool {
        self.table.is_none()
    }

    fn entry(&self, key: &str) -> Option<&'static toml::Table> {
        self.table?.get(key)?.as_table()
    }

    fn text(&self, key: &str, field: &str) -> Option<&'static str> {
        self.entry(key)?
            .get(field)?
            .as_str()
            .filter(|text| !text.is_empty())
    }

    pub fn group(&self, setting: &Setting) -> &'static str {
        let section = setting.key.split('.').next().unwrap_or_default();
        self.text("groups", section).unwrap_or(setting.group)
    }

    pub fn label(&self, setting: &Setting) -> &'static str {
        self.text(setting.key, "label").unwrap_or(setting.label)
    }

    pub fn help(&self, setting: &Setting) -> &'static str {
        self.text(setting.key, "help").unwrap_or(setting.help)
    }

    /// Label of one of the setting's choices; `german` is its label in [`SCHEMA`].
    pub fn choice(&self, setting: &Setting, value: &str, german: &'static str) -> &'static str {
        self.entry(setting.key)
            .and_then(|entry| entry.get("choices")?.as_table())
            .and_then(|choices| choices.get(value)?.as_str())
            .filter(|text| !text.is_empty())
            .unwrap_or(german)
    }
}

pub fn find(key: &str) -> Option<&'static Setting> {
    SCHEMA.iter().find(|setting| setting.key == key)
}

/// A setting as the page shows it.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct Shown {
    pub setting: &'static Setting,
    /// What the files say, or the default when none sets it.
    pub value: String,
    /// The file that sets it; `None` for the default.
    pub origin: Option<PathBuf>,
    /// What the running backend uses; differs from `value` until it starts
    /// again.
    pub active: String,
    /// Choices for [`Kind::SoundCard`]: the cards of this machine.
    pub cards: Vec<(String, String)>,
}

impl Shown {
    pub fn restart_pending(&self) -> bool {
        self.value != self.active
    }
}

/// Every setting with its value, where it comes from and what is active.
pub fn show(config_path: &Path, running: &Config, cards: &[SoundCard]) -> Result<Vec<Shown>> {
    let layers = Config::layers(config_path)?;
    let running = toml::Value::try_from(running)
        .context("failed to read the running configuration")?
        .as_table()
        .cloned()
        .unwrap_or_default();
    let cards: Vec<(String, String)> = cards
        .iter()
        .map(|card| (card.id.clone(), format!("{} – {}", card.id, card.name)))
        .collect();
    Ok(SCHEMA
        .iter()
        .map(|setting| {
            let found = layers.iter().rev().find_map(|(path, table)| {
                lookup(table, setting.key).map(|value| (path.clone(), text_of(value)))
            });
            let (value, origin) = match found {
                Some((path, value)) => (value, Some(path)),
                None => (setting.default.to_string(), None),
            };
            let active = lookup(&running, setting.key)
                .map(text_of)
                .unwrap_or_else(|| setting.default.to_string());
            Shown {
                setting,
                value,
                origin,
                active,
                cards: if setting.kind == Kind::SoundCard {
                    cards.clone()
                } else {
                    Vec::new()
                },
            }
        })
        .collect())
}

/// Why [`save`] wrote nothing.
#[derive(Debug)]
pub enum SaveError {
    /// Not a key of the page (also every secret, which never is one).
    UnknownKey(String),
    /// The value does not fit the key's type.
    InvalidValue { key: String, reason: String },
    /// The configuration would not start with the change.
    Rejected(String),
    /// Reading or writing the file failed.
    Storage(anyhow::Error),
}

impl SaveError {
    pub fn message(&self) -> String {
        match self {
            Self::UnknownKey(key) => format!("{key} kann hier nicht eingestellt werden"),
            Self::InvalidValue { key, reason } => format!("{key}: {reason}"),
            Self::Rejected(reason) => format!("Konfiguration wäre ungültig: {reason}"),
            Self::Storage(error) => format!("Speichern fehlgeschlagen: {error:#}"),
        }
    }
}

/// One change: a new value as text, or `None` to remove the key from the
/// page's file, so the other files or the default apply again.
pub type Change = (String, Option<String>);

/// Applies `changes` to `config.d/99-ui.toml` beside `config_path`, after
/// checking the whole configuration with them. Returns the file written.
pub fn save(
    config_path: &Path,
    changes: &[Change],
    environment: impl Fn(&str) -> Option<OsString>,
) -> Result<PathBuf, SaveError> {
    let directory = config_path.with_extension("d");
    let path = directory.join(config::UI_DROP_IN);
    // A file that cannot be read as TOML is replaced; it is kept as .bak.
    let mut table = fs::read_to_string(&path)
        .ok()
        .and_then(|text| toml::from_str::<toml::Table>(&text).ok())
        .unwrap_or_default();
    for (key, value) in changes {
        let setting = find(key).ok_or_else(|| SaveError::UnknownKey(key.clone()))?;
        match value {
            Some(text) => {
                let value = parse(setting, text).map_err(|reason| SaveError::InvalidValue {
                    key: key.clone(),
                    reason,
                })?;
                insert(&mut table, setting.key, value);
            }
            None => remove(&mut table, setting.key),
        }
    }
    Config::with_ui_drop_in(config_path, &table, environment)
        .map_err(|error| SaveError::Rejected(format!("{error:#}")))?;
    write(&directory, &path, &table).map_err(SaveError::Storage)?;
    Ok(path)
}

/// The text of the page as the value written to the file.
pub fn parse(setting: &Setting, text: &str) -> Result<toml::Value, String> {
    let text = text.trim();
    match setting.kind {
        Kind::Bool => match text {
            "true" => Ok(toml::Value::Boolean(true)),
            "false" => Ok(toml::Value::Boolean(false)),
            _ => Err(format!("„{text}“ ist weder true noch false")),
        },
        Kind::Integer { min, max, unit } => {
            let number: i64 = text
                .parse()
                .map_err(|_| format!("„{text}“ ist keine ganze Zahl"))?;
            if !(min..=max).contains(&number) {
                return Err(
                    format!("{number} liegt nicht zwischen {min} und {max} {unit}")
                        .trim_end()
                        .to_string(),
                );
            }
            Ok(toml::Value::Integer(number))
        }
        Kind::Choice { choices, numeric } => {
            if !choices.iter().any(|(value, _)| *value == text) {
                let allowed: Vec<&str> = choices.iter().map(|(value, _)| *value).collect();
                return Err(format!("„{text}“ ist keine der Möglichkeiten {allowed:?}"));
            }
            if numeric {
                text.parse()
                    .map(toml::Value::Integer)
                    .map_err(|_| format!("„{text}“ ist keine Zahl"))
            } else {
                Ok(toml::Value::String(text.to_string()))
            }
        }
        Kind::SoundCard => {
            if config::is_alsa_card_id(text) {
                Ok(toml::Value::String(text.to_string()))
            } else {
                Err(format!("„{text}“ ist keine Kennung einer Soundkarte"))
            }
        }
        Kind::Text { max_len } => {
            if text.is_empty() || text.chars().count() > max_len {
                Err(format!("Text muss 1 bis {max_len} Zeichen lang sein"))
            } else {
                Ok(toml::Value::String(text.to_string()))
            }
        }
    }
}

fn text_of(value: &toml::Value) -> String {
    match value {
        toml::Value::String(text) => text.clone(),
        other => other.to_string(),
    }
}

fn lookup<'a>(table: &'a toml::Table, key: &str) -> Option<&'a toml::Value> {
    let (section, name) = key.split_once('.')?;
    table.get(section)?.as_table()?.get(name)
}

fn insert(table: &mut toml::Table, key: &str, value: toml::Value) {
    let (section, name) = key.split_once('.').expect("schema keys are section.name");
    let entry = table
        .entry(section)
        .or_insert_with(|| toml::Value::Table(toml::Table::new()));
    if !entry.is_table() {
        *entry = toml::Value::Table(toml::Table::new());
    }
    if let toml::Value::Table(section) = entry {
        section.insert(name.to_string(), value);
    }
}

fn remove(table: &mut toml::Table, key: &str) {
    let (section, name) = key.split_once('.').expect("schema keys are section.name");
    if let Some(toml::Value::Table(inner)) = table.get_mut(section) {
        inner.remove(name);
        if inner.is_empty() {
            table.remove(section);
        }
    }
}

const HEADER: &str = "# Written by carnine-backend from the expert page (#138).\n\
# Laid over every other file; the previous version is 99-ui.toml.bak.\n\
# Delete this file to drop all values set on the page.\n\n";

/// Replaces `path` in one step, the old file kept as `.bak`, so a power cut
/// leaves the old or the new file, never half of one.
fn write(directory: &Path, path: &Path, table: &toml::Table) -> Result<()> {
    let content = format!(
        "{HEADER}{}",
        toml::to_string(table).context("failed to write the values as TOML")?
    );
    fs::create_dir_all(directory)
        .with_context(|| format!("failed to create {}", directory.display()))?;
    if path.exists() {
        let backup = path.with_extension("toml.bak");
        fs::copy(path, &backup).with_context(|| format!("failed to keep {}", backup.display()))?;
    }
    let temporary = directory.join(format!(".{}.tmp", config::UI_DROP_IN));
    let result = (|| -> std::io::Result<()> {
        let mut file = fs::OpenOptions::new()
            .write(true)
            .create(true)
            .truncate(true)
            .mode(0o640)
            .open(&temporary)?;
        file.write_all(content.as_bytes())?;
        file.sync_all()?;
        fs::rename(&temporary, path)
    })();
    result.with_context(|| format!("failed to write {}", path.display()))
}

#[cfg(test)]
mod tests {
    use super::*;

    /// The repository's configuration, as the device starts from it.
    const BASE: &str = include_str!("../../../resources/config/carnine.toml");

    fn directory(name: &str) -> PathBuf {
        let directory = std::env::temp_dir().join(format!(
            "carnine-install-settings-{name}-{}",
            std::process::id()
        ));
        let _ = fs::remove_dir_all(&directory);
        fs::create_dir_all(directory.join("config.d")).unwrap();
        fs::write(directory.join("config.toml"), BASE).unwrap();
        directory
    }

    fn no_env(_: &str) -> Option<OsString> {
        None
    }

    fn change(key: &str, value: &str) -> Change {
        (key.to_string(), Some(value.to_string()))
    }

    fn running(config_path: &Path) -> Config {
        Config::with_ui_drop_in(config_path, &toml::Table::new(), no_env).unwrap()
    }

    /// A value of `setting` other than its default that the configuration
    /// accepts on its own.
    fn sample(setting: &Setting) -> &'static str {
        match setting.key {
            "reverse_gear.source" => "demo",
            "reverse_gear.gpio_chip" => "/dev/gpiochip4",
            "reverse_gear.gpio_line" => "26",
            "reverse_gear.active_low" => "false",
            "reverse_gear.bias" => "pull_down",
            "reverse_gear.debounce_ms" => "20",
            "audio.output_card" => "Headphones",
            "audio.mixer_control" => "Speaker",
            "audio.channels" => "6",
            "audio.rear_percent" => "40",
            "power_supply.enabled" => "true",
            "power_supply.amplifier_relay" => "false",
            "power_supply.shutdown_on_poweroff" => "false",
            other => panic!("no sample for {other}; add one with the schema entry"),
        }
    }

    #[test]
    fn every_key_exists_in_the_configuration_and_takes_its_sample() {
        let directory = directory("every-key");
        let config_path = directory.join("config.toml");
        for setting in SCHEMA {
            let value = sample(setting);
            assert_ne!(value, setting.default, "{}", setting.key);
            save(&config_path, &[change(setting.key, value)], no_env)
                .unwrap_or_else(|error| panic!("{}: {}", setting.key, error.message()));
            let config = Config::with_ui_drop_in(
                &config_path,
                &toml::from_str(
                    &fs::read_to_string(directory.join("config.d/99-ui.toml")).unwrap(),
                )
                .unwrap(),
                no_env,
            )
            .unwrap();
            // The key reaches the parsed configuration: serialized back, it
            // carries the sample.
            let table = toml::Value::try_from(&config).unwrap();
            let read = lookup(table.as_table().unwrap(), setting.key)
                .map(text_of)
                .unwrap_or_default();
            assert_eq!(read, value, "{}", setting.key);
            save(&config_path, &[(setting.key.to_string(), None)], no_env).unwrap();
        }
        assert_eq!(SCHEMA.len(), {
            let mut keys: Vec<_> = SCHEMA.iter().map(|setting| setting.key).collect();
            keys.sort_unstable();
            keys.dedup();
            keys.len()
        });
    }

    #[test]
    fn defaults_are_what_the_configuration_uses_without_the_key() {
        let directory = directory("defaults");
        let config_path = directory.join("config.toml");
        // The repository's file sets some of the keys; without them the
        // backend's own default has to be the schema's.
        let mut bare: toml::Table = toml::from_str(BASE).unwrap();
        for setting in SCHEMA {
            remove(&mut bare, setting.key);
        }
        fs::write(&config_path, toml::to_string(&bare).unwrap()).unwrap();
        let config = running(&config_path);
        for shown in show(&config_path, &config, &[]).unwrap() {
            assert_eq!(shown.origin, None, "{}", shown.setting.key);
            assert_eq!(shown.value, shown.setting.default, "{}", shown.setting.key);
            assert_eq!(shown.active, shown.setting.default, "{}", shown.setting.key);
            assert!(!shown.restart_pending(), "{}", shown.setting.key);
        }
    }

    #[test]
    fn origin_is_the_last_file_that_sets_the_key() {
        let directory = directory("origin");
        let config_path = directory.join("config.toml");
        fs::write(
            directory.join("config.d/50-car.toml"),
            "[audio]\nrear_percent = 60\n[reverse_gear]\ndebounce_ms = 30\n",
        )
        .unwrap();
        save(&config_path, &[change("audio.rear_percent", "40")], no_env).unwrap();
        let config = running(&config_path);
        let shown = show(&config_path, &config, &[]).unwrap();
        let get = |key: &str| shown.iter().find(|s| s.setting.key == key).unwrap();

        let rear = get("audio.rear_percent");
        assert_eq!(rear.value, "40");
        assert_eq!(rear.origin, Some(directory.join("config.d/99-ui.toml")));
        // The running configuration here is the one without the page's file.
        assert_eq!(rear.active, "60");
        assert!(rear.restart_pending());

        let debounce = get("reverse_gear.debounce_ms");
        assert_eq!(debounce.value, "30");
        assert_eq!(
            debounce.origin,
            Some(directory.join("config.d/50-car.toml"))
        );

        // Reset: the drop-in below applies again.
        save(&config_path, &[("audio.rear_percent".into(), None)], no_env).unwrap();
        let shown = show(&config_path, &config, &[]).unwrap();
        let rear = shown
            .iter()
            .find(|s| s.setting.key == "audio.rear_percent")
            .unwrap();
        assert_eq!(rear.value, "60");
        assert_eq!(rear.origin, Some(directory.join("config.d/50-car.toml")));
        assert!(!rear.restart_pending());
    }

    #[test]
    fn saving_keeps_the_previous_file_and_other_keys() {
        let directory = directory("backup");
        let config_path = directory.join("config.toml");
        let ui = directory.join("config.d/99-ui.toml");
        save(&config_path, &[change("audio.channels", "4")], no_env).unwrap();
        assert!(!ui.with_extension("toml.bak").exists());
        let first = fs::read_to_string(&ui).unwrap();
        assert!(first.starts_with("# Written by carnine-backend"), "{first}");
        assert!(first.contains("channels = 4"), "{first}");

        save(
            &config_path,
            &[
                change("reverse_gear.source", "gpio"),
                change("reverse_gear.gpio_line", "26"),
            ],
            no_env,
        )
        .unwrap();
        assert_eq!(
            fs::read_to_string(ui.with_extension("toml.bak")).unwrap(),
            first
        );
        let second: toml::Table = toml::from_str(&fs::read_to_string(&ui).unwrap()).unwrap();
        assert_eq!(
            lookup(&second, "audio.channels"),
            Some(&toml::Value::Integer(4))
        );
        assert_eq!(
            lookup(&second, "reverse_gear.gpio_line"),
            Some(&toml::Value::Integer(26))
        );
        assert!(!directory.join("config.d/.99-ui.toml.tmp").exists());

        // Resetting the last key of a section drops the section.
        save(&config_path, &[("audio.channels".into(), None)], no_env).unwrap();
        let third: toml::Table = toml::from_str(&fs::read_to_string(&ui).unwrap()).unwrap();
        assert!(!third.contains_key("audio"), "{third:?}");
    }

    #[test]
    fn an_invalid_configuration_writes_nothing() {
        let directory = directory("invalid");
        let config_path = directory.join("config.toml");
        let ui = directory.join("config.d/99-ui.toml");
        save(&config_path, &[change("audio.rear_percent", "50")], no_env).unwrap();
        let before = fs::read_to_string(&ui).unwrap();

        // Each value fits its type, together they do not: GPIO needs a line.
        let error = save(
            &config_path,
            &[change("reverse_gear.source", "gpio")],
            no_env,
        )
        .unwrap_err();
        assert!(matches!(error, SaveError::Rejected(_)), "{error:?}");
        assert!(error.message().contains("gpio_line"), "{}", error.message());
        assert_eq!(fs::read_to_string(&ui).unwrap(), before);
        assert!(!ui.with_extension("toml.bak").exists());
    }

    #[test]
    fn values_that_do_not_fit_their_type_are_refused() {
        let directory = directory("types");
        let config_path = directory.join("config.toml");
        for (key, value) in [
            ("power_supply.enabled", "ja"),
            ("reverse_gear.debounce_ms", "1001"),
            ("reverse_gear.debounce_ms", "-1"),
            ("reverse_gear.debounce_ms", "zwanzig"),
            ("reverse_gear.source", "can"),
            ("audio.channels", "5"),
            ("audio.output_card", "hw:0"),
            ("audio.mixer_control", ""),
        ] {
            let error = save(&config_path, &[change(key, value)], no_env).unwrap_err();
            assert!(
                matches!(&error, SaveError::InvalidValue { key: k, .. } if k == key),
                "{key}={value}: {error:?}"
            );
        }
        assert!(!directory.join("config.d/99-ui.toml").exists());
    }

    #[test]
    fn keys_outside_the_schema_and_secrets_are_refused() {
        let directory = directory("unknown");
        let config_path = directory.join("config.toml");
        for key in [
            "exit_password.hash",
            "server.socket_path",
            "audio",
            "audio.volume_state_path",
            "nonsense",
        ] {
            let error = save(&config_path, &[change(key, "x")], no_env).unwrap_err();
            assert!(
                matches!(error, SaveError::UnknownKey(_)),
                "{key}: {error:?}"
            );
        }
        assert!(!directory.join("config.d/99-ui.toml").exists());
    }

    #[test]
    fn a_broken_page_file_is_replaced_and_kept() {
        let directory = directory("broken");
        let config_path = directory.join("config.toml");
        let ui = directory.join("config.d/99-ui.toml");
        fs::write(&ui, "this is not toml [").unwrap();
        save(&config_path, &[change("audio.rear_percent", "70")], no_env).unwrap();
        assert_eq!(
            fs::read_to_string(ui.with_extension("toml.bak")).unwrap(),
            "this is not toml ["
        );
        assert!(fs::read_to_string(&ui)
            .unwrap()
            .contains("rear_percent = 70"));
    }

    #[test]
    fn sound_cards_are_the_choices_of_the_output() {
        let directory = directory("cards");
        let config_path = directory.join("config.toml");
        let cards = crate::audio_output::parse_cards(
            " 2 [Headphones     ]: bcm2835_headpho - bcm2835 Headphones\n                      bcm2835 Headphones\n",
        );
        let config = running(&config_path);
        let shown = show(&config_path, &config, &cards).unwrap();
        for entry in &shown {
            if entry.setting.key == "audio.output_card" {
                assert_eq!(
                    entry.cards,
                    [(
                        "Headphones".to_string(),
                        "Headphones – bcm2835 Headphones".to_string()
                    )]
                );
            } else {
                assert!(entry.cards.is_empty(), "{}", entry.setting.key);
            }
        }
    }

    #[test]
    fn every_language_has_every_text_of_the_page() {
        let tables = text_tables();
        let mut languages: Vec<&str> = tables.keys().map(String::as_str).collect();
        languages.sort_unstable();
        let mut expected = TEXT_LANGUAGES.to_vec();
        expected.sort_unstable();
        assert_eq!(
            languages, expected,
            "languages in install_settings_texts.toml"
        );
        for &language in TEXT_LANGUAGES {
            let texts = Texts::for_language(language);
            assert!(!texts.is_german(), "{language}");
            for setting in SCHEMA {
                let section = setting.key.split('.').next().unwrap();
                assert!(
                    texts.text("groups", section).is_some(),
                    "{language}: group {section}"
                );
                assert!(
                    texts.text(setting.key, "label").is_some(),
                    "{language}: {} label",
                    setting.key
                );
                assert!(
                    texts.text(setting.key, "help").is_some(),
                    "{language}: {} help",
                    setting.key
                );
                if let Kind::Choice { choices, .. } = setting.kind {
                    for (value, german) in choices {
                        let shown = texts.choice(setting, value, "");
                        assert!(
                            !shown.is_empty(),
                            "{language}: {} choice {value} ({german})",
                            setting.key
                        );
                    }
                }
            }
        }
    }

    #[test]
    fn the_texts_file_names_nothing_outside_the_schema() {
        for (language, table) in text_tables() {
            let table = table.as_table().unwrap();
            for (key, entry) in table {
                let entry = entry
                    .as_table()
                    .unwrap_or_else(|| panic!("{language}.{key}"));
                if key == "groups" {
                    for section in entry.keys() {
                        assert!(
                            SCHEMA
                                .iter()
                                .any(|setting| setting.key.starts_with(&format!("{section}."))),
                            "{language}: group {section} is not in the schema"
                        );
                    }
                    continue;
                }
                let setting =
                    find(key).unwrap_or_else(|| panic!("{language}: {key} is not in the schema"));
                for (field, value) in entry {
                    match field.as_str() {
                        "label" | "help" => assert!(value.is_str(), "{language}: {key}.{field}"),
                        "choices" => {
                            let Kind::Choice { choices, .. } = setting.kind else {
                                panic!("{language}: {key} has no choices");
                            };
                            for value in value.as_table().unwrap().keys() {
                                assert!(
                                    choices.iter().any(|(known, _)| known == value),
                                    "{language}: {key} has no choice {value}"
                                );
                            }
                        }
                        other => panic!("{language}: {key}.{other} is not a text of the page"),
                    }
                }
            }
        }
    }

    #[test]
    fn unknown_or_empty_languages_get_german() {
        for language in ["", "de", "de-DE", "DE_at", "xx", "klingon", "-"] {
            let texts = Texts::for_language(language);
            assert!(texts.is_german(), "{language:?}");
            let source = find("reverse_gear.source").unwrap();
            assert_eq!(texts.label(source), "Quelle");
            assert_eq!(texts.group(source), "Rückwärtsgang");
            assert_eq!(texts.choice(source, "gpio", "GPIO-Eingang"), "GPIO-Eingang");
        }
    }

    #[test]
    fn region_and_case_of_the_language_do_not_matter() {
        let source = find("reverse_gear.source").unwrap();
        for language in ["en", "en-US", "EN_gb", " en"] {
            let texts = Texts::for_language(language);
            assert_eq!(texts.group(source), "Reverse gear", "{language:?}");
            assert_eq!(texts.label(source), "Source", "{language:?}");
            assert_eq!(texts.choice(source, "gpio", "GPIO-Eingang"), "GPIO input");
        }
        let channels = find("audio.channels").unwrap();
        assert_eq!(Texts::for_language("pt_PT").label(channels), "Canais");
    }
}
