use std::time::Duration;

use base64::Engine as _;
use base64::engine::general_purpose::{STANDARD, STANDARD_NO_PAD, URL_SAFE, URL_SAFE_NO_PAD};
use serde_yaml::Value;
use ureq::{Agent, Proxy};

use crate::error::{CoreError, Result};
use crate::model::Usage;

const BODY_LIMIT: u64 = 32 << 20;
const TIMEOUT: Duration = Duration::from_secs(30);

#[derive(Debug, Clone, PartialEq, Eq)]
pub enum Content {
    Yaml(String),
    /// One share link per line.
    Links(String),
}

#[derive(Debug)]
pub struct Fetched {
    pub content: Content,
    pub name: Option<String>,
    pub usage: Option<Usage>,
    pub update_hours: Option<u32>,
}

/// Airports pick the format from the user agent; these tokens get a mihomo YAML from the common panels.
fn user_agent(app_version: &str) -> String {
    format!("clash-verge/v2 mihomo/1.19 po0-clash/{app_version}")
}

pub fn fetch(
    url: &str,
    proxy: Option<&str>,
    app_version: &str,
    custom_agent: Option<&str>,
) -> Result<Fetched> {
    let parsed = url.parse::<ureq::http::Uri>().ok();
    let scheme_ok = parsed
        .as_ref()
        .and_then(|uri| uri.scheme_str())
        .is_some_and(|scheme| scheme == "http" || scheme == "https");
    if !scheme_ok {
        return Err(CoreError::Invalid("not an http(s) link".into()));
    }
    let proxy = proxy
        .map(Proxy::new)
        .transpose()
        .map_err(|error| CoreError::Network(error.to_string()))?;
    let agent = Agent::new_with_config(
        Agent::config_builder()
            .proxy(proxy)
            .timeout_global(Some(TIMEOUT))
            .http_status_as_error(false)
            .user_agent(custom_agent.map_or_else(|| user_agent(app_version), str::to_owned))
            .build(),
    );
    let mut response = agent
        .get(url)
        .call()
        .map_err(|error| CoreError::Network(error.to_string().replace(url, "<url>")))?;
    let status = response.status().as_u16();
    if !(200..300).contains(&status) {
        return Err(CoreError::Network(format!("HTTP {status}")));
    }
    let header = |name: &str| {
        response
            .headers()
            .get(name)
            .and_then(|value| value.to_str().ok())
            .map(str::to_owned)
    };
    let usage = header("subscription-userinfo").map(|value| parse_userinfo(&value));
    let name = header("profile-title")
        .and_then(|value| decode_title(&value))
        .or_else(|| header("content-disposition").and_then(|value| disposition_name(&value)))
        .or_else(|| parsed.and_then(|uri| uri.host().map(str::to_owned)));
    let update_hours =
        header("profile-update-interval").and_then(|value| value.trim().parse().ok());
    let body = response
        .body_mut()
        .with_config()
        .limit(BODY_LIMIT)
        .read_to_string()
        .map_err(|error| CoreError::Network(error.to_string()))?;
    Ok(Fetched {
        content: classify(&body)?,
        name,
        usage,
        update_hours,
    })
}

pub fn classify(body: &str) -> Result<Content> {
    if let Ok(Value::Mapping(map)) = serde_yaml::from_str::<Value>(body) {
        let has = |key: &str| map.get(key).is_some_and(|value| !value.is_null());
        if has("proxies") || has("proxy-providers") {
            return Ok(Content::Yaml(body.to_owned()));
        }
    }
    let links = extract_links(body);
    if !links.is_empty() {
        return Ok(Content::Links(links.join("\n")));
    }
    Err(CoreError::Invalid(
        "not a Clash/mihomo config or a share-link list".into(),
    ))
}

/// Share links one per line, or the same list base64-encoded as V2RayN subscriptions serve it.
pub fn extract_links(text: &str) -> Vec<String> {
    let direct = links_in(text);
    if !direct.is_empty() {
        return direct;
    }
    let compact: String = text.chars().filter(|c| !c.is_whitespace()).collect();
    [STANDARD, STANDARD_NO_PAD, URL_SAFE, URL_SAFE_NO_PAD]
        .iter()
        .find_map(|engine| engine.decode(&compact).ok())
        .and_then(|bytes| String::from_utf8(bytes).ok())
        .map(|decoded| links_in(&decoded))
        .unwrap_or_default()
}

fn links_in(text: &str) -> Vec<String> {
    let mut links: Vec<String> = Vec::new();
    for line in text.lines().map(str::trim) {
        let Some((scheme, rest)) = line.split_once("://") else {
            continue;
        };
        let valid = !rest.is_empty()
            && !scheme.is_empty()
            && scheme
                .chars()
                .all(|c| c.is_ascii_alphanumeric() || c == '+' || c == '-');
        if valid && !links.iter().any(|existing| existing == line) {
            links.push(line.to_owned());
        }
    }
    links
}

pub fn parse_userinfo(value: &str) -> Usage {
    let mut usage = Usage::default();
    for part in value.split(';') {
        let Some((key, number)) = part.split_once('=') else {
            continue;
        };
        let number = number.trim().parse::<f64>().unwrap_or(0.0).max(0.0) as u64;
        match key.trim() {
            "upload" => usage.upload = number,
            "download" => usage.download = number,
            "total" => usage.total = number,
            "expire" if number > 0 => usage.expire = Some(number as i64),
            _ => {}
        }
    }
    usage
}

fn decode_title(value: &str) -> Option<String> {
    let value = value.trim();
    let title = match value.strip_prefix("base64:") {
        Some(encoded) => String::from_utf8(STANDARD.decode(encoded.trim()).ok()?).ok()?,
        None => value.to_owned(),
    };
    (!title.trim().is_empty()).then(|| title.trim().to_owned())
}

fn disposition_name(value: &str) -> Option<String> {
    let mut plain = None;
    for part in value.split(';').map(str::trim) {
        if let Some(encoded) = part.strip_prefix("filename*=") {
            let encoded = encoded.trim_matches('"');
            let encoded = encoded.split_once("''").map_or(encoded, |(_, rest)| rest);
            if let Some(name) = percent_decode(encoded) {
                return strip_extension(name);
            }
        } else if let Some(name) = part.strip_prefix("filename=") {
            plain = Some(name.trim_matches('"').to_owned());
        }
    }
    plain.and_then(strip_extension)
}

fn strip_extension(name: String) -> Option<String> {
    let name = name
        .strip_suffix(".yaml")
        .or_else(|| name.strip_suffix(".yml"))
        .unwrap_or(&name)
        .trim()
        .to_owned();
    (!name.is_empty()).then_some(name)
}

fn percent_decode(text: &str) -> Option<String> {
    let bytes = text.as_bytes();
    let mut out = Vec::with_capacity(bytes.len());
    let mut i = 0;
    while i < bytes.len() {
        if bytes[i] == b'%' && i + 2 < bytes.len() {
            let hex = std::str::from_utf8(&bytes[i + 1..i + 3]).ok()?;
            out.push(u8::from_str_radix(hex, 16).ok()?);
            i += 3;
        } else {
            out.push(bytes[i]);
            i += 1;
        }
    }
    String::from_utf8(out).ok()
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn keeps_mihomo_yaml_as_is() {
        let yaml = "proxies:\n  - {name: a, type: ss, server: 1.1.1.1, port: 1, cipher: aes-128-gcm, password: p}\n";
        assert_eq!(classify(yaml), Ok(Content::Yaml(yaml.into())));
        let providers = "proxy-providers:\n  p: {type: http, url: 'https://x'}\n";
        assert!(matches!(classify(providers), Ok(Content::Yaml(_))));
    }

    #[test]
    fn reads_plain_and_base64_link_lists() {
        let list =
            "vless://id@h:443?x=1#a\n\n ss://abc@h:1#b \nnot a link\nvless://id@h:443?x=1#a\n";
        let expected = Content::Links("vless://id@h:443?x=1#a\nss://abc@h:1#b".into());
        assert_eq!(classify(list), Ok(expected.clone()));
        let encoded = STANDARD.encode(list);
        let wrapped = format!("{}\n{}", &encoded[..20], &encoded[20..]);
        assert_eq!(classify(&wrapped), Ok(expected));
    }

    #[test]
    fn rejects_anything_else() {
        assert!(classify("<html>login</html>").is_err());
        assert!(classify("mode: rule\n").is_err());
        assert!(classify("").is_err());
    }

    #[test]
    fn parses_subscription_userinfo() {
        let usage = parse_userinfo("upload=1024; download=2048;total=1e10; expire=1767225600");
        assert_eq!(
            usage,
            Usage {
                upload: 1024,
                download: 2048,
                total: 10_000_000_000,
                expire: Some(1_767_225_600),
            }
        );
        assert_eq!(parse_userinfo("expire=0").expire, None);
    }

    #[test]
    fn names_profiles_from_headers() {
        assert_eq!(decode_title("base64:5py65Zy6"), Some("机场".into()));
        assert_eq!(decode_title(" Plain "), Some("Plain".into()));
        assert_eq!(
            disposition_name("attachment; filename*=UTF-8''%E6%9C%BA%E5%9C%BA.yaml"),
            Some("机场".into())
        );
        assert_eq!(
            disposition_name("attachment; filename=\"sub.yml\""),
            Some("sub".into())
        );
    }

    #[test]
    fn refuses_non_http_links() {
        assert!(matches!(
            fetch("file:///etc/passwd", None, "0", None),
            Err(CoreError::Invalid(_))
        ));
    }
}
