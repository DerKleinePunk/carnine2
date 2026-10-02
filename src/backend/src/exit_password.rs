//! The password that "Beenden" in the options asks for (#51). The backend
//! keeps only an Argon2id hash of it: the factory default comes from the
//! configuration (`[exit_password] hash`), a password changed over gRPC goes
//! into a drop-in of its own, which survives a deployment.

use std::fs;
use std::io::Write;
use std::os::unix::fs::OpenOptionsExt;
use std::path::{Path, PathBuf};
use std::sync::Mutex;

use anyhow::{Context, Result};
use argon2::password_hash::rand_core::OsRng;
use argon2::password_hash::{PasswordHash, PasswordHasher, PasswordVerifier, SaltString};
use argon2::Argon2;
use tracing::warn;

/// Hash of the factory default password, used when the configuration names
/// none. The image's configuration carries the same hash (#51).
pub const DEFAULT_HASH: &str =
    "$argon2id$v=19$m=19456,t=2,p=1$Y2FybmluZS1leGl0LXB3$O+DjYmFGfVSWu+fkiM29V8Fv5Dy6eIQzW2q1WDqQXk0";

/// Name of the drop-in a changed password is written to. It sorts after the
/// drop-ins the image and the map setup bring, so it wins over them.
pub const DROP_IN_NAME: &str = "30-exit-password.toml";

pub const MIN_LENGTH: usize = 4;
pub const MAX_LENGTH: usize = 64;

/// Why a new password was not accepted.
#[derive(Debug, PartialEq, Eq)]
pub enum Rejection {
    TooShort,
    TooLong,
    /// Line breaks and other control characters cannot be typed on the
    /// on-screen keyboard and would only lock the user out.
    ControlCharacter,
}

impl Rejection {
    pub fn message(&self) -> String {
        match self {
            Self::TooShort => format!("the new password needs at least {MIN_LENGTH} characters"),
            Self::TooLong => format!("the new password may have at most {MAX_LENGTH} characters"),
            Self::ControlCharacter => "the new password contains a control character".to_owned(),
        }
    }
}

pub fn check_new(password: &str) -> Result<(), Rejection> {
    let length = password.chars().count();
    if length < MIN_LENGTH {
        return Err(Rejection::TooShort);
    }
    if length > MAX_LENGTH {
        return Err(Rejection::TooLong);
    }
    if password.chars().any(char::is_control) {
        return Err(Rejection::ControlCharacter);
    }
    Ok(())
}

pub fn hash(password: &str) -> Result<String> {
    let salt = SaltString::generate(&mut OsRng);
    Argon2::default()
        .hash_password(password.as_bytes(), &salt)
        .map(|hash| hash.to_string())
        .map_err(|error| anyhow::anyhow!("failed to hash the exit password: {error}"))
}

/// Whether `password` matches `hash`. A hash that cannot be parsed matches
/// nothing.
pub fn verify(hash: &str, password: &str) -> bool {
    PasswordHash::new(hash).is_ok_and(|parsed| {
        Argon2::default()
            .verify_password(password.as_bytes(), &parsed)
            .is_ok()
    })
}

/// Whether `hash` is a hash [`verify`] can check against.
pub fn is_valid_hash(hash: &str) -> bool {
    PasswordHash::new(hash).is_ok()
}

/// Writes `hash` as the `[exit_password]` drop-in into `directory`. The file
/// is replaced in one step, so a power cut leaves the old or the new
/// password, never half a file.
pub fn write_drop_in(directory: &Path, hash: &str) -> Result<PathBuf> {
    let path = directory.join(DROP_IN_NAME);
    let temporary = directory.join(format!(".{DROP_IN_NAME}.tmp"));
    let content = format!(
        "# Written by carnine-backend when the exit password was changed (#51).\n\
         # Only the Argon2id hash is kept; delete this file for the factory default.\n\
         [exit_password]\n\
         hash = \"{hash}\"\n"
    );
    let write = || -> std::io::Result<()> {
        // Readable for the backend's group only, like the other drop-ins.
        let mut file = fs::OpenOptions::new()
            .write(true)
            .create(true)
            .truncate(true)
            .mode(0o640)
            .open(&temporary)?;
        file.write_all(content.as_bytes())?;
        file.sync_all()?;
        fs::rename(&temporary, &path)
    };
    write().with_context(|| format!("failed to write {}", path.display()))?;
    Ok(path)
}

/// Why [`Store::change`] did not change the password.
#[derive(Debug)]
pub enum ChangeError {
    WrongPassword,
    Rejected(Rejection),
    Storage(anyhow::Error),
}

/// The hash in force, and where a changed one is written to.
pub struct Store {
    hash: Mutex<String>,
    drop_in_directory: Option<PathBuf>,
}

impl Default for Store {
    fn default() -> Self {
        Self::new(None, None)
    }
}

/// Leaves the hash out of logs.
impl std::fmt::Debug for Store {
    fn fmt(&self, formatter: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        formatter
            .debug_struct("Store")
            .field("drop_in_directory", &self.drop_in_directory)
            .finish_non_exhaustive()
    }
}

impl Store {
    /// `hash` from the configuration; `None` or a hash that cannot be read
    /// falls back to the factory default, so a broken entry never locks the
    /// user out. Without `drop_in_directory` the password cannot be changed.
    pub fn new(hash: Option<&str>, drop_in_directory: Option<PathBuf>) -> Self {
        let hash = match hash {
            Some(hash) if is_valid_hash(hash) => hash.to_owned(),
            Some(_) => {
                warn!("exit_password.hash is not an Argon2 hash; using the factory default");
                DEFAULT_HASH.to_owned()
            }
            None => DEFAULT_HASH.to_owned(),
        };
        Self {
            hash: Mutex::new(hash),
            drop_in_directory,
        }
    }

    fn current(&self) -> String {
        self.hash
            .lock()
            .unwrap_or_else(|poisoned| poisoned.into_inner())
            .clone()
    }

    pub fn verify(&self, password: &str) -> bool {
        verify(&self.current(), password)
    }

    pub fn change(&self, current: &str, new: &str) -> Result<(), ChangeError> {
        if !self.verify(current) {
            return Err(ChangeError::WrongPassword);
        }
        check_new(new).map_err(ChangeError::Rejected)?;
        let directory = self.drop_in_directory.as_deref().ok_or_else(|| {
            ChangeError::Storage(anyhow::anyhow!(
                "no configuration drop-in directory to store the password in"
            ))
        })?;
        let hash = hash(new).map_err(ChangeError::Storage)?;
        write_drop_in(directory, &hash).map_err(ChangeError::Storage)?;
        *self
            .hash
            .lock()
            .unwrap_or_else(|poisoned| poisoned.into_inner()) = hash;
        Ok(())
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    fn temporary_directory(name: &str) -> PathBuf {
        let directory = std::env::temp_dir().join(format!(
            "carnine-exit-password-{name}-{}",
            std::process::id()
        ));
        let _ = fs::remove_dir_all(&directory);
        fs::create_dir_all(&directory).unwrap();
        directory
    }

    #[test]
    fn a_store_without_a_configured_hash_takes_the_factory_password() {
        assert!(Store::new(None, None).verify("4321"));
        assert!(Store::new(Some("kaputt"), None).verify("4321"));
    }

    #[test]
    fn changing_needs_the_current_password_and_valid_rules() {
        let directory = temporary_directory("rules");
        let store = Store::new(None, Some(directory.clone()));

        assert!(matches!(
            store.change("falsch", "neues-pw"),
            Err(ChangeError::WrongPassword)
        ));
        assert!(matches!(
            store.change("4321", "12"),
            Err(ChangeError::Rejected(Rejection::TooShort))
        ));
        assert!(!directory.join(DROP_IN_NAME).exists());
        assert!(store.verify("4321"));
        fs::remove_dir_all(&directory).unwrap();
    }

    #[test]
    fn a_changed_password_counts_at_once_and_is_stored() {
        let directory = temporary_directory("change");
        let store = Store::new(None, Some(directory.clone()));

        store
            .change("4321", "neues-pw")
            .expect("change should work");

        assert!(store.verify("neues-pw"));
        assert!(!store.verify("4321"));
        let table: toml::Table =
            toml::from_str(&fs::read_to_string(directory.join(DROP_IN_NAME)).unwrap()).unwrap();
        let stored = table["exit_password"]["hash"].as_str().unwrap();
        assert!(Store::new(Some(stored), None).verify("neues-pw"));
        fs::remove_dir_all(&directory).unwrap();
    }

    #[test]
    fn without_a_drop_in_directory_the_password_stays() {
        let store = Store::new(None, None);
        assert!(matches!(
            store.change("4321", "neues-pw"),
            Err(ChangeError::Storage(_))
        ));
        assert!(store.verify("4321"));
    }

    #[test]
    fn the_default_hash_is_the_factory_password() {
        assert!(is_valid_hash(DEFAULT_HASH));
        assert!(verify(DEFAULT_HASH, "4321"));
        assert!(!verify(DEFAULT_HASH, "1234"));
        assert!(!verify(DEFAULT_HASH, ""));
    }

    #[test]
    fn a_new_hash_verifies_its_password_only() {
        let hash = hash("geheim").expect("hashing should work");
        assert!(hash.starts_with("$argon2id$"));
        assert!(!hash.contains("geheim"));
        assert!(verify(&hash, "geheim"));
        assert!(!verify(&hash, "Geheim"));
    }

    #[test]
    fn the_same_password_gets_a_new_salt_each_time() {
        assert_ne!(hash("geheim").unwrap(), hash("geheim").unwrap());
    }

    #[test]
    fn a_broken_hash_matches_nothing() {
        assert!(!is_valid_hash("4321"));
        assert!(!verify("4321", "4321"));
        assert!(!verify("", ""));
    }

    #[test]
    fn new_passwords_follow_the_rules() {
        assert_eq!(check_new("123"), Err(Rejection::TooShort));
        assert_eq!(check_new("1234"), Ok(()));
        assert_eq!(check_new("äöüß"), Ok(()));
        assert_eq!(check_new(&"x".repeat(MAX_LENGTH)), Ok(()));
        assert_eq!(
            check_new(&"x".repeat(MAX_LENGTH + 1)),
            Err(Rejection::TooLong)
        );
        assert_eq!(check_new("12\n34"), Err(Rejection::ControlCharacter));
    }

    #[test]
    fn the_drop_in_replaces_the_previous_one() {
        let directory = temporary_directory("drop-in");

        let first = hash("erstes").unwrap();
        let path = write_drop_in(&directory, &first).unwrap();
        let second = hash("zweites").unwrap();
        write_drop_in(&directory, &second).unwrap();

        let table: toml::Table = toml::from_str(&fs::read_to_string(&path).unwrap()).unwrap();
        let written = table["exit_password"]["hash"].as_str().unwrap();
        assert_eq!(written, second);
        assert!(verify(written, "zweites"));
        use std::os::unix::fs::PermissionsExt;
        let mode = fs::metadata(&path).unwrap().permissions().mode() & 0o777;
        assert_eq!(mode & 0o007, 0, "others must not read the hash");
        assert_eq!(fs::read_dir(&directory).unwrap().count(), 1);
        fs::remove_dir_all(&directory).unwrap();
    }
}
