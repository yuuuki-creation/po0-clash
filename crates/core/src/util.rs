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

/// Unix seconds of an RFC 3339 time as mihomo writes it; `None` for Go's zero time.
pub fn parse_time(text: &str) -> Option<i64> {
    let (date, rest) = text.split_once('T')?;
    let mut date = date.splitn(3, '-').map(str::parse::<i64>);
    let (year, month, day) = (date.next()?.ok()?, date.next()?.ok()?, date.next()?.ok()?);
    let zone_at = rest.find(['Z', 'z', '+', '-']).unwrap_or(rest.len());
    let (clock, zone) = rest.split_at(zone_at);
    let mut clock = clock
        .split('.')
        .next()?
        .splitn(3, ':')
        .map(str::parse::<i64>);
    let (hour, minute, second) = (
        clock.next()?.ok()?,
        clock.next()?.ok()?,
        clock.next()?.ok()?,
    );
    let offset = match zone.chars().next() {
        Some(sign @ ('+' | '-')) => {
            let (hours, minutes) = zone[1..].split_once(':')?;
            let offset = hours.parse::<i64>().ok()? * 3600 + minutes.parse::<i64>().ok()? * 60;
            if sign == '-' { -offset } else { offset }
        }
        _ => 0,
    };
    let seconds =
        days_from_civil(year, month, day) * 86_400 + hour * 3600 + minute * 60 + second - offset;
    (seconds > 0).then_some(seconds)
}

fn days_from_civil(year: i64, month: i64, day: i64) -> i64 {
    let year = if month <= 2 { year - 1 } else { year };
    let era = year.div_euclid(400);
    let year_of_era = year - era * 400;
    let day_of_year = (153 * ((month + 9) % 12) + 2) / 5 + day - 1;
    let day_of_era = year_of_era * 365 + year_of_era / 4 - year_of_era / 100 + day_of_year;
    era * 146_097 + day_of_era - 719_468
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

    #[test]
    fn parses_mihomo_times() {
        assert_eq!(parse_time("1970-01-01T00:00:00Z"), None);
        assert_eq!(parse_time("2024-03-01T08:00:00+08:00"), Some(1_709_251_200));
        assert_eq!(
            parse_time("2024-03-01T00:00:00.123456789Z"),
            Some(1_709_251_200)
        );
        assert_eq!(parse_time("2024-02-29T23:30:00-00:30"), Some(1_709_251_200));
        assert_eq!(parse_time("0001-01-01T00:00:00Z"), None);
        assert_eq!(parse_time("yesterday"), None);
    }
}
