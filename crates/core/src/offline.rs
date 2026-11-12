use std::collections::BTreeMap;

use serde_json::Value;

use crate::{CoreError, Node, ProxyGroup, Result, SELECTABLE_TYPES};

pub fn groups(
    yaml: &str,
    links: &[Node],
    selections: &BTreeMap<String, String>,
    cached: impl Fn(&str) -> Option<String>,
) -> Result<Vec<ProxyGroup>> {
    let root: Value = serde_yaml::from_str(yaml)
        .map_err(|_| CoreError::Invalid("the saved profile is not valid YAML".into()))?;
    let list = |key: &str| {
        root.get(key)
            .and_then(Value::as_array)
            .cloned()
            .unwrap_or_default()
    };
    let group_data = list("proxy-groups");
    let inline = nodes(&list("proxies"));
    let mut providers = BTreeMap::new();
    for (name, definition) in root
        .get("proxy-providers")
        .and_then(Value::as_object)
        .into_iter()
        .flatten()
    {
        let mut available = if name == "links" && !links.is_empty() {
            links.to_vec()
        } else {
            let saved = definition
                .get("path")
                .filter(|_| definition.get("type").and_then(Value::as_str) != Some("inline"))
                .and_then(Value::as_str)
                .and_then(&cached)
                .map(|text| from_text(&text))
                .filter(|nodes| !nodes.is_empty());
            saved.unwrap_or_else(|| {
                definition
                    .get("payload")
                    .and_then(Value::as_array)
                    .map(|payload| nodes(payload))
                    .unwrap_or_default()
            })
        };
        filter(&mut available, definition, true)?;
        providers.insert(name.clone(), available);
    }
    let types: BTreeMap<String, String> = list("proxies")
        .iter()
        .chain(&group_data)
        .filter_map(|item| {
            Some((
                item.get("name")?.as_str()?.to_owned(),
                kind(item.get("type")?.as_str()?),
            ))
        })
        .chain([
            ("DIRECT".into(), "Direct".into()),
            ("REJECT".into(), "Reject".into()),
        ])
        .collect();
    let mut groups = Vec::new();
    for data in group_data {
        let Some(name) = data.get("name").and_then(Value::as_str) else {
            continue;
        };
        let kind = kind(data.get("type").and_then(Value::as_str).unwrap_or_default());
        let mut nodes: Vec<Node> = data
            .get("proxies")
            .and_then(Value::as_array)
            .into_iter()
            .flatten()
            .filter_map(Value::as_str)
            .map(|name| Node {
                name: name.into(),
                kind: types.get(name).cloned().unwrap_or_default(),
                delay: None,
            })
            .collect();
        let all = data.get("include-all").and_then(Value::as_bool) == Some(true);
        let mut included = Vec::new();
        if all || data.get("include-all-proxies").and_then(Value::as_bool) == Some(true) {
            let mut sorted = inline.clone();
            sorted.sort_by(|a, b| a.name.cmp(&b.name));
            included.extend(sorted);
        }
        let provider_names: Vec<&str> =
            if all || data.get("include-all-providers").and_then(Value::as_bool) == Some(true) {
                providers.keys().map(String::as_str).collect()
            } else {
                data.get("use")
                    .and_then(Value::as_array)
                    .into_iter()
                    .flatten()
                    .filter_map(Value::as_str)
                    .collect()
            };
        for provider in provider_names {
            included.extend(providers.get(provider).into_iter().flatten().cloned());
        }
        filter(&mut included, &data, true)?;
        nodes.extend(included);
        filter(&mut nodes, &data, false)?;
        let mut seen = std::collections::BTreeSet::new();
        nodes.retain(|node| seen.insert(node.name.clone()));
        let default = data
            .get("default-selected")
            .and_then(Value::as_str)
            .filter(|name| nodes.iter().any(|node| node.name == *name));
        let now = selections
            .get(name)
            .filter(|selected| nodes.iter().any(|node| node.name == **selected))
            .cloned()
            .or_else(|| default.map(str::to_owned))
            .or_else(|| nodes.first().map(|node| node.name.clone()));
        groups.push(ProxyGroup {
            name: name.into(),
            selectable: SELECTABLE_TYPES.contains(&kind.as_str()),
            kind,
            now,
            nodes,
            icon: data.get("icon").and_then(Value::as_str).map(str::to_owned),
        });
    }
    Ok(groups)
}

fn nodes(values: &[Value]) -> Vec<Node> {
    values
        .iter()
        .filter_map(|node| {
            Some(Node {
                name: node.get("name")?.as_str()?.into(),
                kind: kind(node.get("type")?.as_str()?),
                delay: None,
            })
        })
        .collect()
}

fn from_text(text: &str) -> Vec<Node> {
    if let Ok(root) = serde_yaml::from_str::<Value>(text)
        && let Some(proxies) = root.get("proxies").and_then(Value::as_array)
    {
        return nodes(proxies);
    }
    let links = crate::profiles::extract_links(text);
    crate::links::names(&links)
        .into_iter()
        .zip(&links)
        .filter_map(|(name, link)| {
            Some(Node {
                name: name?,
                kind: kind(&crate::links::scheme(link)),
                delay: None,
            })
        })
        .collect()
}

fn filter(nodes: &mut Vec<Node>, definition: &Value, include: bool) -> Result<()> {
    let patterns = |key: &str| -> Result<Vec<fancy_regex::Regex>> {
        definition
            .get(key)
            .and_then(Value::as_str)
            .unwrap_or_default()
            .split("```")
            .filter(|pattern| !pattern.is_empty())
            .map(|pattern| {
                fancy_regex::RegexBuilder::new(pattern)
                    .backtrack_limit(100_000)
                    .build()
                    .map_err(|_| CoreError::Invalid("invalid proxy group filter".into()))
            })
            .collect()
    };
    let included = if include {
        patterns("filter")?
    } else {
        Vec::new()
    };
    let excluded = patterns("exclude-filter")?;
    let types: Vec<_> = definition
        .get("exclude-type")
        .and_then(Value::as_str)
        .unwrap_or_default()
        .split('|')
        .filter(|kind| !kind.is_empty())
        .map(kind)
        .collect();
    let matches = |patterns: &[fancy_regex::Regex], name: &str| -> Result<bool> {
        for pattern in patterns {
            if pattern
                .is_match(name)
                .map_err(|_| CoreError::Invalid("proxy group filter exceeded its limit".into()))?
            {
                return Ok(true);
            }
        }
        Ok(false)
    };
    let mut kept = Vec::new();
    for node in nodes.drain(..) {
        if (included.is_empty() || matches(&included, &node.name)?)
            && !matches(&excluded, &node.name)?
            && !types
                .iter()
                .any(|kind| kind.eq_ignore_ascii_case(&node.kind))
        {
            kept.push(node);
        }
    }
    *nodes = kept;
    Ok(())
}

pub fn kind(value: &str) -> String {
    match value {
        "select" => "Selector",
        "url-test" => "URLTest",
        "fallback" => "Fallback",
        "load-balance" => "LoadBalance",
        "relay" => "Relay",
        "ss" => "Shadowsocks",
        "ssr" => "ShadowsocksR",
        "vmess" => "VMess",
        "vless" => "VLESS",
        "trojan" => "Trojan",
        "socks5" => "Socks5",
        other => other,
    }
    .into()
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn a_subscription_provider_named_links_uses_its_saved_nodes_before_fallback_payload() {
        let yaml = "proxy-providers: {links: {type: http, path: cached, payload: [{name: Fallback, type: ss}]}}\nproxy-groups: [{name: Proxy, type: select, use: [links]}]";
        let groups = groups(yaml, &[], &BTreeMap::new(), |_| {
            Some("proxies: [{name: Cached, type: ss}]".into())
        })
        .unwrap();
        assert_eq!(groups[0].nodes[0].name, "Cached");
    }

    #[test]
    fn cached_provider_nodes_follow_inclusion_and_name_filters() {
        let yaml = r#"
proxy-providers:
  airport: {type: http, path: ./providers/po0-example.cache}
proxy-groups:
  - name: Overseas
    type: select
    proxies: [DIRECT]
    use: [airport]
    filter: '(?i)^(?!.*UK).*'
    exclude-type: Trojan
    default-selected: HK
"#;
        let groups = groups(yaml, &[], &BTreeMap::new(), |_| {
            Some(
                "proxies: [{name: UK, type: ss}, {name: HK, type: ss}, {name: US, type: trojan}]"
                    .into(),
            )
        })
        .unwrap();
        assert_eq!(
            groups[0]
                .nodes
                .iter()
                .map(|n| n.name.as_str())
                .collect::<Vec<_>>(),
            ["DIRECT", "HK"]
        );
        assert_eq!(groups[0].now.as_deref(), Some("HK"));
    }

    #[test]
    fn include_all_keeps_configured_proxies_and_does_not_invent_uncached_nodes() {
        let yaml = "proxies: [{name: Local, type: socks5}]\nproxy-providers: {remote: {type: http, path: unavailable}}\nproxy-groups: [{name: All, type: select, include-all: true}, {name: Remote, type: url-test, use: [remote]}]";
        let groups = groups(yaml, &[], &BTreeMap::new(), |_| None).unwrap();
        assert_eq!(groups[0].nodes[0].name, "Local");
        assert!(groups[1].nodes.is_empty());
    }
}
