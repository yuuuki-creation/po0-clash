use std::fs;
use std::path::Path;
use std::time::UNIX_EPOCH;

use serde_json::Value;

use crate::model::{GeoFile, Provider, ProviderKind, Rule, Usage};
use crate::options::GeoxUrl;
use crate::util;

/// The names mihomo looks for in its home, matched without regard to case.
const GEOIP: &str = "GeoIP.dat";
const GEOSITE: &str = "GeoSite.dat";
const MMDB: &[&str] = &["geoip.metadb", "Country.mmdb", "geoip.db"];
const ASN: &str = "ASN.mmdb";

pub fn provider_path(kind: ProviderKind, name: Option<&str>) -> String {
    let base = match kind {
        ProviderKind::Proxy => "/providers/proxies",
        ProviderKind::Rule => "/providers/rules",
    };
    name.map_or_else(
        || base.to_owned(),
        |name| format!("{base}/{}", util::encode_component(name)),
    )
}

pub fn parse_providers(kind: ProviderKind, value: &Value) -> Vec<Provider> {
    value
        .get("providers")
        .and_then(Value::as_object)
        .into_iter()
        .flatten()
        .filter_map(|(name, provider)| parse_provider(kind, name, provider))
        .collect()
}

/// Groups own an implicit `Compatible` provider each; those are not something a person can update.
fn parse_provider(kind: ProviderKind, name: &str, value: &Value) -> Option<Provider> {
    let vehicle = value.get("vehicleType")?.as_str()?;
    if vehicle == "Compatible" {
        return None;
    }
    let count = match kind {
        ProviderKind::Proxy => value
            .get("proxies")
            .and_then(Value::as_array)
            .map_or(0, Vec::len) as u64,
        ProviderKind::Rule => value.get("ruleCount").and_then(Value::as_u64).unwrap_or(0),
    };
    let usage = value
        .get("subscriptionInfo")
        .filter(|info| info.is_object())
        .map(|info| {
            let read = |name: &str| info.get(name).and_then(Value::as_i64).unwrap_or(0);
            Usage {
                upload: read("Upload").max(0) as u64,
                download: read("Download").max(0) as u64,
                total: read("Total").max(0) as u64,
                expire: Some(read("Expire")).filter(|expire| *expire > 0),
            }
        });
    Some(Provider {
        name: name.to_owned(),
        kind,
        vehicle: vehicle.to_owned(),
        behavior: value
            .get("behavior")
            .and_then(Value::as_str)
            .map(str::to_owned),
        count: u32::try_from(count).unwrap_or(u32::MAX),
        updated_at: value
            .get("updatedAt")
            .and_then(Value::as_str)
            .and_then(util::parse_time),
        usage,
    })
}

/// mihomo's `/proxies/{name}` only knows proxies written in the config, so single-node tests go through a provider
/// holding the node; every config proxy is also in the implicit `default` one.
pub fn provider_of(value: &Value, node: &str) -> Option<String> {
    value
        .get("providers")?
        .as_object()?
        .iter()
        .find(|(_, provider)| {
            provider
                .get("proxies")
                .and_then(Value::as_array)
                .is_some_and(|proxies| {
                    proxies
                        .iter()
                        .any(|proxy| proxy.get("name").and_then(Value::as_str) == Some(node))
                })
        })
        .map(|(name, _)| name.clone())
}

pub fn parse_rules(value: &Value) -> Vec<Rule> {
    let text = |rule: &Value, name: &str| {
        rule.get(name)
            .and_then(Value::as_str)
            .unwrap_or_default()
            .to_owned()
    };
    value
        .get("rules")
        .and_then(Value::as_array)
        .into_iter()
        .flatten()
        .map(|rule| Rule {
            kind: text(rule, "type"),
            payload: text(rule, "payload"),
            proxy: text(rule, "proxy"),
        })
        .collect()
}

fn existing(home: &Path, names: &[&str]) -> Option<String> {
    let entries = fs::read_dir(home).ok()?;
    let found: Vec<String> = entries
        .flatten()
        .filter_map(|entry| entry.file_name().into_string().ok())
        .collect();
    names.iter().find_map(|name| {
        found
            .iter()
            .find(|file| file.eq_ignore_ascii_case(name))
            .cloned()
    })
}

/// Each database's file name in `home` and where it is downloaded from.
pub fn geo_targets(home: &Path, urls: &GeoxUrl) -> Vec<(String, String)> {
    let name = |names: &[&str]| existing(home, names).unwrap_or_else(|| names[0].to_owned());
    vec![
        (name(&[GEOIP]), urls.geoip.clone()),
        (name(&[GEOSITE]), urls.geosite.clone()),
        (name(MMDB), urls.mmdb.clone()),
        (name(&[ASN]), urls.asn.clone()),
    ]
}

pub fn geo_files(home: &Path) -> Vec<GeoFile> {
    geo_targets(home, &GeoxUrl::default())
        .into_iter()
        .map(|(name, _)| {
            let meta = fs::metadata(home.join(&name)).ok();
            GeoFile {
                size: meta.as_ref().map(fs::Metadata::len),
                modified: meta
                    .and_then(|meta| meta.modified().ok())
                    .and_then(|time| time.duration_since(UNIX_EPOCH).ok())
                    .map(|elapsed| elapsed.as_secs() as i64),
                name,
            }
        })
        .collect()
}

#[cfg(test)]
mod tests {
    use super::*;
    use serde_json::json;

    #[test]
    fn reads_providers_but_not_the_ones_groups_own() {
        let proxies = json!({ "providers": {
            "default": { "vehicleType": "Compatible", "proxies": [] },
            "links": {
                "vehicleType": "File", "proxies": [{}, {}], "updatedAt": "2024-03-01T00:00:00Z",
                "subscriptionInfo": { "Upload": 1, "Download": 2, "Total": 10, "Expire": 0 }
            }
        }});
        let providers = parse_providers(ProviderKind::Proxy, &proxies);
        assert_eq!(providers.len(), 1);
        assert_eq!(providers[0].name, "links");
        assert_eq!(providers[0].count, 2);
        assert_eq!(providers[0].updated_at, Some(1_709_251_200));
        assert_eq!(
            providers[0].usage.as_ref().map(|usage| usage.expire),
            Some(None)
        );

        let rules = json!({ "providers": {
            "ads": { "vehicleType": "HTTP", "behavior": "Domain", "ruleCount": 42, "updatedAt": "0001-01-01T00:00:00Z" }
        }});
        let rules = parse_providers(ProviderKind::Rule, &rules);
        assert_eq!(rules[0].count, 42);
        assert_eq!(rules[0].behavior.as_deref(), Some("Domain"));
        assert_eq!(rules[0].updated_at, None);
        assert_eq!(rules[0].usage, None);
        assert_eq!(
            provider_path(ProviderKind::Rule, Some("a b")),
            "/providers/rules/a%20b"
        );
    }

    #[test]
    fn finds_geo_files_mihomo_would_use() {
        let home = std::env::temp_dir().join(format!("po0-geo-{}", util::random_id()));
        fs::create_dir_all(&home).unwrap();
        fs::write(home.join("country.MMDB"), b"1234").unwrap();
        let files = geo_files(&home);
        let names: Vec<&str> = files.iter().map(|file| file.name.as_str()).collect();
        assert_eq!(
            names,
            ["GeoIP.dat", "GeoSite.dat", "country.MMDB", "ASN.mmdb"]
        );
        assert_eq!(files[2].size, Some(4));
        assert_eq!(files[0].size, None);
        let _ = fs::remove_dir_all(home);
    }
}
