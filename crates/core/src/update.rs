use std::cmp::Ordering;

use serde_json::Value;

use crate::error::{CoreError, Result};
use crate::model::Release;
use crate::profiles;

const RELEASES: &str =
    "https://api.github.com/repos/yuuuki-creation/po0-clash/releases?per_page=30";
/// The Flutter app's releases share the repository under plain `v` tags.
const TAG_PREFIX: &str = "native-v";

pub fn check(app_version: &str, proxy: Option<&str>) -> Result<Option<Release>> {
    let body = profiles::download(RELEASES, proxy)?;
    let releases: Value =
        serde_json::from_slice(&body).map_err(|error| CoreError::Network(error.to_string()))?;
    Ok(newest_above(app_version, &releases))
}

/// Pre-releases count only for a build that is itself one, so a stable install is never offered a beta.
fn newest_above(app_version: &str, releases: &Value) -> Option<Release> {
    let current = Version::parse(app_version)?;
    releases
        .as_array()?
        .iter()
        .filter(|release| release.get("draft").and_then(Value::as_bool) != Some(true))
        .filter_map(|release| {
            let tag = release.get("tag_name")?.as_str()?;
            let version = Version::parse(tag.strip_prefix(TAG_PREFIX)?)?;
            (current.pre.is_some() || version.pre.is_none()).then_some((version, release))
        })
        .filter(|(version, _)| *version > current)
        .max_by(|(a, _), (b, _)| a.cmp(b))
        .map(|(version, release)| {
            let field = |name: &str| {
                release
                    .get(name)
                    .and_then(Value::as_str)
                    .unwrap_or_default()
                    .to_owned()
            };
            Release {
                version: version.text,
                url: field("html_url"),
                notes: field("body"),
            }
        })
}

#[derive(Debug)]
struct Version {
    core: [u64; 3],
    pre: Option<String>,
    text: String,
}

impl Version {
    fn parse(text: &str) -> Option<Self> {
        let text = text.trim().trim_start_matches('v');
        let text = text.split_once('+').map_or(text, |(version, _)| version);
        let (core, pre) = match text.split_once('-') {
            Some((core, pre)) => (core, Some(pre.to_owned())),
            None => (text, None),
        };
        let mut parts = core.split('.').map(|part| part.parse().ok());
        let core = [parts.next()??, parts.next()??, parts.next()??];
        parts.next().is_none().then(|| Self {
            core,
            pre,
            text: text.to_owned(),
        })
    }
}

impl Ord for Version {
    /// Semver precedence: a pre-release sorts before its release, and numeric identifiers compare as numbers.
    fn cmp(&self, other: &Self) -> Ordering {
        self.core
            .cmp(&other.core)
            .then_with(|| match (&self.pre, &other.pre) {
                (None, None) => Ordering::Equal,
                (None, Some(_)) => Ordering::Greater,
                (Some(_), None) => Ordering::Less,
                (Some(a), Some(b)) => {
                    let identifiers = |pre: &str| {
                        pre.split('.')
                            .map(|part| part.parse::<u64>().map_err(|_| part.to_owned()))
                            .collect::<Vec<_>>()
                    };
                    identifiers(a).cmp(&identifiers(b))
                }
            })
    }
}

impl PartialEq for Version {
    fn eq(&self, other: &Self) -> bool {
        self.cmp(other) == Ordering::Equal
    }
}

impl Eq for Version {}

impl PartialOrd for Version {
    fn partial_cmp(&self, other: &Self) -> Option<Ordering> {
        Some(self.cmp(other))
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use serde_json::json;

    fn releases() -> Value {
        json!([
            {"tag_name": "native-v7.1.0-beta.1", "html_url": "https://example.com/7.1b1", "body": "", "draft": false},
            {"tag_name": "native-v7.0.0", "html_url": "https://example.com/7.0", "body": "Notes", "draft": false},
            {"tag_name": "native-v7.0.0-beta.10", "html_url": "https://example.com/7.0b10", "body": "", "draft": false},
            {"tag_name": "native-v9.0.0", "html_url": "https://example.com/9", "body": "", "draft": true},
            {"tag_name": "v8.0.0", "html_url": "https://example.com/flutter", "body": "", "draft": false}
        ])
    }

    #[test]
    fn offers_the_newest_native_release() {
        let stable = newest_above("6.9.0", &releases()).unwrap();
        assert_eq!(
            (stable.version.as_str(), stable.notes.as_str()),
            ("7.0.0", "Notes")
        );
        let beta = newest_above("7.0.0-beta.2", &releases()).unwrap();
        assert_eq!(beta.version, "7.1.0-beta.1");
        assert_eq!(newest_above("7.0.0", &releases()), None);
        assert_eq!(newest_above("7.1.0-beta.1", &releases()), None);
    }

    #[test]
    fn orders_pre_releases_by_semver() {
        let version = |text| Version::parse(text).unwrap();
        assert!(version("7.0.0-beta.10") > version("7.0.0-beta.2"));
        assert!(version("7.0.0") > version("7.0.0-rc.1"));
        assert!(version("7.0.0-rc.1") > version("7.0.0-beta.9"));
        assert_eq!(Version::parse("7.0"), None);
    }
}
