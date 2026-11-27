//! The licence texts of what an image ships (#123), for the UI's page
//! "Lizenzen". The packages install them under `/usr/share/doc`; the backend
//! only reads and hands them out, so the UI need not know where they live.
//! Dart and engine licences the UI has itself (`NOTICES.Z`).

use std::path::Path;

use tracing::{debug, warn};

/// Where the packages put their documentation.
pub const DOC_DIR: &str = "/usr/share/doc";

/// The documents, in the order the UI lists them: package, title, path
/// below [`DOC_DIR`].
const DOCUMENTS: &[(&str, &str, &str)] = &[
    (
        "carnine",
        "Quellcode-Angebot (GPL/LGPL)",
        "carnine/SOURCE-OFFER.txt",
    ),
    (
        "carnine-backend",
        "CarNine Backend",
        "carnine-backend/copyright",
    ),
    (
        "carnine-backend",
        "Rust-Bibliotheken im Backend",
        "carnine-backend/third-party-licenses.txt",
    ),
    (
        "carnine-frontend",
        "CarNine Oberfläche",
        "carnine-frontend/copyright",
    ),
    (
        "carnine-frontend",
        "ivi-homescreen (Flutter-Embedder)",
        "carnine-frontend/ivi-homescreen-licenses.txt",
    ),
    (
        "carnine-valhalla",
        "Valhalla (Routing)",
        "carnine-valhalla/copyright",
    ),
    (
        "carnine-voice",
        "Stimme (Ansagen)",
        "carnine-voice/copyright",
    ),
];

/// A document no larger than this is handed out; the largest today, the
/// backend's Rust crates, is about 350 KB.
const MAX_DOCUMENT_BYTES: u64 = 4 * 1024 * 1024;

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct LicenseDocument {
    pub package: String,
    pub title: String,
    pub text: String,
}

/// Reads every document present below `doc_dir`. A missing one (another
/// package set, WSL) is left out; an unreadable or oversized one is left out
/// with a warning.
pub fn load(doc_dir: &Path) -> Vec<LicenseDocument> {
    DOCUMENTS
        .iter()
        .filter_map(|&(package, title, relative)| {
            let path = doc_dir.join(relative);
            match std::fs::metadata(&path) {
                Err(error) if error.kind() == std::io::ErrorKind::NotFound => {
                    debug!(path = %path.display(), "licence document not installed");
                    return None;
                }
                Err(error) => {
                    warn!(%error, path = %path.display(), "licence document unreadable");
                    return None;
                }
                Ok(metadata) if metadata.len() > MAX_DOCUMENT_BYTES => {
                    warn!(path = %path.display(), bytes = metadata.len(), "licence document too large, left out");
                    return None;
                }
                Ok(_) => {}
            }
            match std::fs::read(&path) {
                Ok(bytes) => Some(LicenseDocument {
                    package: package.to_string(),
                    title: title.to_string(),
                    text: String::from_utf8_lossy(&bytes).into_owned(),
                }),
                Err(error) => {
                    warn!(%error, path = %path.display(), "licence document unreadable");
                    None
                }
            }
        })
        .collect()
}

#[cfg(test)]
mod tests {
    use super::*;

    fn temp_dir(name: &str) -> std::path::PathBuf {
        let dir = std::env::temp_dir().join(format!(
            "carnine-licenses-{name}-{}-{:?}",
            std::process::id(),
            std::thread::current().id()
        ));
        let _ = std::fs::remove_dir_all(&dir);
        std::fs::create_dir_all(&dir).unwrap();
        dir
    }

    fn put(dir: &Path, relative: &str, text: &[u8]) {
        let path = dir.join(relative);
        std::fs::create_dir_all(path.parent().unwrap()).unwrap();
        std::fs::write(path, text).unwrap();
    }

    #[test]
    fn nothing_installed_gives_an_empty_list() {
        let dir = temp_dir("empty");
        assert!(load(&dir).is_empty());
        std::fs::remove_dir_all(dir).unwrap();
    }

    #[test]
    fn the_documents_present_come_in_their_fixed_order() {
        let dir = temp_dir("order");
        put(&dir, "carnine-voice/copyright", b"voice");
        put(&dir, "carnine/SOURCE-OFFER.txt", b"offer");
        put(&dir, "carnine-backend/copyright", b"GPL-3.0-only");
        // Not ours: never handed out.
        put(&dir, "libc6/copyright", b"glibc");

        let documents = load(&dir);
        let summary: Vec<(&str, &str)> = documents
            .iter()
            .map(|document| (document.package.as_str(), document.text.as_str()))
            .collect();
        assert_eq!(
            summary,
            [
                ("carnine", "offer"),
                ("carnine-backend", "GPL-3.0-only"),
                ("carnine-voice", "voice"),
            ]
        );
        assert_eq!(documents[0].title, "Quellcode-Angebot (GPL/LGPL)");
        std::fs::remove_dir_all(dir).unwrap();
    }

    #[test]
    fn a_text_that_is_not_utf8_is_still_handed_out() {
        let dir = temp_dir("latin1");
        // "Müller" in Latin-1.
        put(&dir, "carnine-valhalla/copyright", b"M\xfcller");
        let documents = load(&dir);
        assert_eq!(documents.len(), 1);
        assert_eq!(documents[0].text, "M\u{fffd}ller");
        std::fs::remove_dir_all(dir).unwrap();
    }

    #[test]
    fn an_oversized_document_is_left_out() {
        let dir = temp_dir("large");
        put(&dir, "carnine-backend/copyright", b"small");
        let large = dir.join("carnine-backend/third-party-licenses.txt");
        let file = std::fs::File::create(&large).unwrap();
        file.set_len(MAX_DOCUMENT_BYTES + 1).unwrap();
        let documents = load(&dir);
        assert_eq!(documents.len(), 1);
        assert_eq!(documents[0].text, "small");
        std::fs::remove_dir_all(dir).unwrap();
    }

    #[test]
    fn every_listed_path_is_below_the_doc_dir() {
        for &(package, _, relative) in DOCUMENTS {
            assert!(
                relative.starts_with(&format!("{package}/")),
                "{relative} not in {package}'s folder"
            );
            assert!(!relative.contains(".."));
        }
    }
}
