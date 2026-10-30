//! Node names of share links as mihomo's `ConvertsV2Ray` gives them, and renaming a node inside its link.

use std::collections::HashMap;

use base64::Engine;
use base64::engine::general_purpose::{STANDARD, STANDARD_NO_PAD, URL_SAFE, URL_SAFE_NO_PAD};

use crate::util;

/// Each link's node name in order, with mihomo's `-01` suffixes for repeats; `None` for links mihomo skips.
pub fn names(links: &[String]) -> Vec<Option<String>> {
    let mut seen: HashMap<String, u32> = HashMap::new();
    links
        .iter()
        .map(|link| {
            let name = base_name(link)?;
            Some(match seen.get_mut(&name) {
                Some(index) => {
                    *index += 1;
                    format!("{name}-{:02}", *index)
                }
                None => {
                    seen.insert(name.clone(), 0);
                    name
                }
            })
        })
        .collect()
}

pub fn scheme(link: &str) -> String {
    link.split_once("://")
        .map_or_else(String::new, |(scheme, _)| scheme.to_ascii_lowercase())
}

fn base_name(link: &str) -> Option<String> {
    let (_, body) = link.split_once("://")?;
    match scheme(link).as_str() {
        "vmess" => match decode(body) {
            Some(json) => serde_json::from_slice::<serde_json::Value>(&json)
                .ok()?
                .get("ps")?
                .as_str()
                .map(str::to_owned),
            None => Some(fragment(link)),
        },
        "ssr" => {
            let text = String::from_utf8(decode(body)?).ok()?;
            let (_, query) = text.split_once("/?")?;
            let remarks = query
                .split('&')
                .find_map(|pair| pair.strip_prefix("remarks="))
                .unwrap_or_default();
            Some(
                URL_SAFE_NO_PAD
                    .decode(remarks.replace('+', "-").replace('/', "_"))
                    .ok()
                    .and_then(|bytes| String::from_utf8(bytes).ok())
                    .unwrap_or_default(),
            )
        }
        "socks" | "socks5" | "socks5h" | "http" | "https" | "anytls" => {
            let (host, port) = host_port(body)?;
            let name = fragment(link);
            Some(if name.is_empty() {
                format!("{host}:{port}")
            } else {
                name
            })
        }
        "vless" | "trojan" | "ss" | "tuic" | "hysteria" | "hysteria2" | "hy2"
        | "hysteria2+realm" | "hy2+realm" => Some(fragment(link)),
        _ => None,
    }
}

/// The link naming its node `name`; `None` for kinds whose name this cannot rewrite.
pub fn renamed(link: &str, name: &str) -> Option<String> {
    let (scheme_text, body) = link.split_once("://")?;
    match scheme(link).as_str() {
        "vmess" if decode(body).is_some() => {
            let mut value: serde_json::Value = serde_json::from_slice(&decode(body)?).ok()?;
            value.as_object_mut()?.insert("ps".into(), name.into());
            Some(format!(
                "{scheme_text}://{}",
                STANDARD.encode(value.to_string())
            ))
        }
        "ssr" => {
            let text = String::from_utf8(decode(body)?).ok()?;
            let (head, query) = text.split_once("/?")?;
            let mut params: Vec<String> = query
                .split('&')
                .filter(|pair| !pair.is_empty() && !pair.starts_with("remarks="))
                .map(str::to_owned)
                .collect();
            params.push(format!("remarks={}", URL_SAFE_NO_PAD.encode(name)));
            let text = format!("{head}/?{}", params.join("&"));
            Some(format!("{scheme_text}://{}", URL_SAFE_NO_PAD.encode(text)))
        }
        _ if base_name(link).is_some() => {
            let base = link.split_once('#').map_or(link, |(base, _)| base);
            Some(format!("{base}#{}", util::encode_component(name)))
        }
        _ => None,
    }
}

fn decode(body: &str) -> Option<Vec<u8>> {
    let engines = if body.len().is_multiple_of(4) {
        [STANDARD, URL_SAFE]
    } else {
        [STANDARD_NO_PAD, URL_SAFE_NO_PAD]
    };
    engines.iter().find_map(|engine| engine.decode(body).ok())
}

fn fragment(link: &str) -> String {
    let Some((_, raw)) = link.split_once('#') else {
        return String::new();
    };
    percent_decode(raw).unwrap_or_else(|| raw.to_owned())
}

fn percent_decode(text: &str) -> Option<String> {
    let bytes = text.as_bytes();
    let mut out = Vec::with_capacity(bytes.len());
    let mut index = 0;
    while index < bytes.len() {
        if bytes[index] == b'%' {
            let hex = text.get(index + 1..index + 3)?;
            out.push(u8::from_str_radix(hex, 16).ok()?);
            index += 3;
        } else {
            out.push(bytes[index]);
            index += 1;
        }
    }
    String::from_utf8(out).ok()
}

fn host_port(body: &str) -> Option<(String, String)> {
    let authority = body.split(['/', '?', '#']).next()?;
    let address = authority
        .rsplit_once('@')
        .map_or(authority, |(_, address)| address);
    let (host, port) = match address.strip_prefix('[') {
        Some(rest) => {
            let (host, port) = rest.split_once("]:")?;
            (host, port)
        }
        None => address.rsplit_once(':')?,
    };
    (!host.is_empty() && !port.is_empty()).then(|| (host.to_owned(), port.to_owned()))
}

#[cfg(test)]
mod tests {
    use super::*;

    fn vmess(name: &str) -> String {
        let json =
            serde_json::json!({ "v": "2", "ps": name, "add": "1.2.3.4", "port": "443", "id": "u" });
        format!("vmess://{}", STANDARD.encode(json.to_string()))
    }

    #[test]
    fn names_follow_mihomo() {
        let ssr_text = format!(
            "1.2.3.4:443:origin:aes-256-cfb:plain:{}/?remarks={}",
            URL_SAFE_NO_PAD.encode("p"),
            URL_SAFE_NO_PAD.encode("东京")
        );
        let links: Vec<String> = vec![
            "ss://YWVzLTEyOC1nY206cA@1.2.3.4:1#Tokyo%2001".into(),
            "trojan://p@1.2.3.4:443#Tokyo%2001".into(),
            vmess("Tokyo 01"),
            "vless://u@host:443?security=tls#".into(),
            "socks5://user:pass@[::1]:1080".into(),
            format!("ssr://{}", URL_SAFE_NO_PAD.encode(ssr_text)),
            "wireguard://whatever#w".into(),
        ];
        assert_eq!(
            names(&links),
            [
                Some("Tokyo 01".into()),
                Some("Tokyo 01-01".into()),
                Some("Tokyo 01-02".into()),
                Some(String::new()),
                Some("::1:1080".into()),
                Some("东京".into()),
                None,
            ]
        );
    }

    #[test]
    fn renaming_rewrites_the_name_where_each_kind_keeps_it() {
        for link in [
            "ss://YWVzLTEyOC1nY206cA@1.2.3.4:1#old".to_owned(),
            "hysteria2://p@1.2.3.4:443?sni=a".to_owned(),
            vmess("old"),
            format!(
                "ssr://{}",
                URL_SAFE_NO_PAD.encode(format!(
                    "h:1:o:m:p:{}/?remarks=b2xk&group=Zw",
                    URL_SAFE_NO_PAD.encode("x")
                ))
            ),
        ] {
            let renamed = renamed(&link, "新 #1").unwrap();
            assert_eq!(names(&[renamed]), [Some("新 #1".to_owned())], "{link}");
        }
        assert_eq!(renamed("wireguard://x#w", "n"), None);
    }
}
