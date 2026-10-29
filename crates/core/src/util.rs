use std::fs;
use std::io::{self, Write};
use std::path::Path;
use std::time::{SystemTime, UNIX_EPOCH};

pub fn now() -> i64 {
    SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .map_or(0, |elapsed| elapsed.as_secs() as i64)
}

fn random_bytes<const N: usize>() -> [u8; N] {
    let mut bytes = [0u8; N];
    getrandom::fill(&mut bytes).expect("the OS random source is available");
    bytes
}

pub fn random_id() -> String {
    random_bytes::<6>()
        .iter()
        .map(|b| format!("{b:02x}"))
        .collect()
}

pub fn random_secret(len: usize) -> String {
    const ALPHABET: &[u8] = b"abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789";
    random_bytes::<64>()
        .iter()
        .take(len)
        .map(|b| char::from(ALPHABET[usize::from(*b) % ALPHABET.len()]))
        .collect()
}

pub fn write_atomic(path: &Path, bytes: &[u8]) -> io::Result<()> {
    if let Some(parent) = path.parent() {
        fs::create_dir_all(parent)?;
    }
    let tmp = path.with_extension("tmp");
    {
        let mut file = fs::File::create(&tmp)?;
        file.write_all(bytes)?;
        file.sync_all()?;
    }
    fs::rename(tmp, path)
}

/// `encodeURIComponent`: everything but the unreserved set and `!~*'()` is escaped.
pub fn encode_component(value: &str) -> String {
    value
        .bytes()
        .map(|byte| {
            if byte.is_ascii_alphanumeric() || b"-_.!~*'()".contains(&byte) {
                char::from(byte).to_string()
            } else {
                format!("%{byte:02X}")
            }
        })
        .collect()
}

pub fn snippet(text: &str) -> String {
    let text = text.trim();
    match text.char_indices().nth(80) {
        Some((end, _)) => format!("{}…", &text[..end]),
        None => text.to_owned(),
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn encodes_like_encode_uri_component() {
        assert_eq!(encode_component("pgnfw_a b/ü"), "pgnfw_a%20b%2F%C3%BC");
        assert_eq!(encode_component("a-_.!~*'()"), "a-_.!~*'()");
    }

    #[test]
    fn secrets_are_alphanumeric() {
        let secret = random_secret(24);
        assert_eq!(secret.len(), 24);
        assert!(secret.chars().all(|c| c.is_ascii_alphanumeric()));
        assert_ne!(random_id(), random_id());
    }

    #[test]
    fn snippets_cut_at_a_char_boundary() {
        assert_eq!(snippet(" short "), "short");
        let long = "节".repeat(100);
        assert_eq!(snippet(&long).chars().count(), 81);
    }
}
