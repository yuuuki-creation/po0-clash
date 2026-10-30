//! What the About page lists as open-source licenses: the engine, the upstream client and every crate the core
//! ships, from `licenses.tsv`, which `tool/native_licenses.py` writes.

use crate::model::License;

const CRATES: &str = include_str!("../licenses.tsv");

pub fn all() -> Vec<License> {
    let upstream = [
        ("mihomo", "GPL-3.0", "https://github.com/MetaCubeX/mihomo"),
        ("FlClash", "GPL-3.0", "https://github.com/chen08209/FlClash"),
    ]
    .map(|(name, license, url)| License {
        name: name.into(),
        version: String::new(),
        license: license.into(),
        url: url.into(),
    });
    let crates = CRATES.lines().filter_map(|line| {
        let mut fields = line.split('\t');
        Some(License {
            name: fields.next()?.into(),
            version: fields.next()?.into(),
            license: fields.next()?.into(),
            url: fields.next().unwrap_or_default().into(),
        })
    });
    upstream.into_iter().chain(crates).collect()
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn lists_the_engine_and_the_shipped_crates() {
        let licenses = all();
        assert_eq!(licenses[0].name, "mihomo");
        for name in ["rquickjs", "rusqlite", "ureq", "uniffi"] {
            assert!(
                licenses
                    .iter()
                    .any(|license| license.name == name && !license.license.is_empty()),
                "{name}"
            );
        }
    }
}
