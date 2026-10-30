//! A backup the Flutter app made: `config.json`, its drift `database.sqlite`, and `profiles/` and `scripts/` files.

use std::collections::BTreeMap;
use std::path::Path;

use rusqlite::types::Value as Sql;
use rusqlite::{Connection, OpenFlags};
use serde_json::Value;

use crate::legacy;
use crate::model::{OverrideMode, ProfileKind, ProfileOverride, Script};
use crate::profiles::{self, Content};
use crate::settings::{EntryRecord, ProfileRecord, WhitelistSettings};
use crate::util;
use crate::whitelist;

pub const CONFIG: &str = "config.json";
pub const DATABASE: &str = "database.sqlite";

#[derive(Debug, Default, PartialEq, Eq)]
pub struct Restored {
    pub profiles: Vec<ProfileRecord>,
    pub files: BTreeMap<String, Content>,
    pub scripts: Vec<Script>,
    pub global_rules: Vec<String>,
    pub current: Option<String>,
    pub whitelist: WhitelistSettings,
}

type Row = BTreeMap<String, Sql>;

/// `file` reads an archive entry by name, such as `profiles/1.yaml`.
pub fn read(
    config: &Value,
    database: Option<&Path>,
    mut file: impl FnMut(&str) -> Option<String>,
) -> rusqlite::Result<Restored> {
    let mut saved = legacy::Legacy::default();
    legacy::read_config(config, &mut saved);
    let mut restored = Restored {
        current: saved.current,
        whitelist: whitelist_of(saved.whitelist_enabled, &saved.entries),
        ..Restored::default()
    };
    let Some(database) = database else {
        return Ok(restored);
    };
    let connection = Connection::open_with_flags(
        database,
        OpenFlags::SQLITE_OPEN_READ_ONLY | OpenFlags::SQLITE_OPEN_NO_MUTEX,
    )?;
    let rules: BTreeMap<i64, String> = rows(&connection, "rules")?
        .iter()
        .filter_map(|row| Some((int(row, "id")?, rule_text(row)?)))
        .collect();
    let mut links = rows(&connection, "profile_rule_mapping")?;
    links.sort_by_key(|link| text(link, "order"));
    let linked = |profile: Option<i64>, scene: Option<&str>| -> Vec<String> {
        links
            .iter()
            .filter(|link| {
                int(link, "profile_id") == profile && text(link, "scene").as_deref() == scene
            })
            .filter_map(|link| rules.get(&int(link, "rule_id")?).cloned())
            .collect()
    };
    restored.global_rules = linked(None, None);
    for row in rows(&connection, "scripts")? {
        let (Some(id), Some(name)) = (int(&row, "id"), text(&row, "label")) else {
            continue;
        };
        if let Some(content) = file(&format!("scripts/{id}.js")) {
            restored.scripts.push(Script {
                id: id.to_string(),
                name,
                content,
            });
        }
    }
    let mut groups = rows(&connection, "proxy_groups")?;
    groups.sort_by_key(|group| text(group, "order"));
    let mut profiles = rows(&connection, "profiles")?;
    profiles.sort_by_key(|row| {
        (
            int(row, "order").is_none(),
            int(row, "order"),
            int(row, "id"),
        )
    });
    for row in profiles {
        let (Some(id), Some(name)) = (int(&row, "id"), text(&row, "label")) else {
            continue;
        };
        let url = text(&row, "url")
            .filter(|url| url.starts_with("http://") || url.starts_with("https://"));
        let content =
            file(&format!("profiles/{id}.yaml")).and_then(|text| profiles::classify(&text).ok());
        let kind = match (&url, &content) {
            (Some(_), _) => ProfileKind::Subscription,
            (None, Some(Content::Links(_))) => ProfileKind::Links,
            (None, Some(Content::Yaml(_))) => ProfileKind::File,
            (None, None) => continue,
        };
        let id_text = id.to_string();
        if let Some(content) = content {
            restored.files.insert(id_text.clone(), content);
        }
        let custom_groups: Vec<serde_yaml::Value> = groups
            .iter()
            .filter(|group| int(group, "profile_id") == Some(id))
            .filter_map(group_yaml)
            .collect();
        let auto_update = int(&row, "auto_update").is_none_or(|value| value != 0);
        let hours = int(&row, "auto_update_duration_millis")
            .map(|millis| (millis / 3_600_000).max(1) as u32);
        restored.profiles.push(ProfileRecord {
            url,
            updated_at: int(&row, "last_update_date"),
            update_hours: hours,
            manual_update: !auto_update,
            selections: text(&row, "selected_map")
                .and_then(|map| serde_json::from_str(&map).ok())
                .unwrap_or_default(),
            overrides: ProfileOverride {
                mode: match text(&row, "overwrite_type").as_deref() {
                    Some("script") => OverrideMode::Script,
                    Some("custom") => OverrideMode::Custom,
                    _ => OverrideMode::Standard,
                },
                added_rules: linked(Some(id), Some("added")),
                disabled_global_rules: linked(Some(id), Some("disabled")),
                match_target: text(&row, "match_target").filter(|target| !target.trim().is_empty()),
                script_id: int(&row, "script_id")
                    .map(|script| script.to_string())
                    .filter(|script| restored.scripts.iter().any(|saved| saved.id == *script)),
                custom_groups: if custom_groups.is_empty() {
                    String::new()
                } else {
                    serde_yaml::to_string(&custom_groups).unwrap_or_default()
                },
                custom_rules: linked(Some(id), Some("custom")),
            },
            ..ProfileRecord::new(id_text, name, kind)
        });
    }
    Ok(restored)
}

fn whitelist_of(enabled: bool, tokens: &[(String, String)]) -> WhitelistSettings {
    let mut entries: Vec<EntryRecord> = Vec::new();
    for (name, text) in tokens {
        for secret in whitelist::parse_secrets(text) {
            if !entries.iter().any(|entry| entry.value == secret.value) {
                entries.push(EntryRecord {
                    id: util::random_id(),
                    name: name.clone(),
                    value: secret.value,
                });
            }
        }
    }
    WhitelistSettings {
        enabled: enabled && !entries.is_empty(),
        entries,
    }
}

fn rows(connection: &Connection, table: &str) -> rusqlite::Result<Vec<Row>> {
    let mut statement = match connection.prepare(&format!(r#"SELECT * FROM "{table}""#)) {
        Ok(statement) => statement,
        Err(_) => return Ok(Vec::new()),
    };
    let names: Vec<String> = statement
        .column_names()
        .into_iter()
        .map(str::to_owned)
        .collect();
    let rows = statement.query_map([], |row| {
        names
            .iter()
            .enumerate()
            .map(|(index, name)| Ok((name.clone(), row.get::<_, Sql>(index)?)))
            .collect()
    })?;
    rows.collect()
}

fn int(row: &Row, column: &str) -> Option<i64> {
    match row.get(column)? {
        Sql::Integer(value) => Some(*value),
        Sql::Text(value) => value.parse().ok(),
        _ => None,
    }
}

fn text(row: &Row, column: &str) -> Option<String> {
    match row.get(column)? {
        Sql::Text(value) => Some(value.clone()),
        Sql::Integer(value) => Some(value.to_string()),
        _ => None,
    }
}

/// The Flutter app stores rules parsed, with the action under its Dart enum name, such as `DOMAIN_SUFFIX`.
fn rule_text(row: &Row) -> Option<String> {
    let action = text(row, "rule_action")?.replace('_', "-");
    let payload = match action.as_str() {
        "MATCH" => None,
        "RULE-SET" => text(row, "rule_provider"),
        _ => text(row, "content"),
    };
    let target = match action.as_str() {
        "SUB-RULE" => text(row, "sub_rule"),
        _ => text(row, "rule_target"),
    };
    let mut fields = vec![action];
    fields.extend(
        payload
            .into_iter()
            .chain(target)
            .filter(|field| !field.is_empty()),
    );
    if int(row, "src") == Some(1) {
        fields.push("src".into());
    }
    if int(row, "no_resolve") == Some(1) {
        fields.push("no-resolve".into());
    }
    Some(fields.join(","))
}

fn group_yaml(row: &Row) -> Option<serde_yaml::Value> {
    let mut group = serde_yaml::Mapping::new();
    let mut put = |key: &str, value: serde_yaml::Value| {
        group.insert(key.into(), value);
    };
    put("name", text(row, "name")?.into());
    put("type", text(row, "type")?.into());
    for (column, key) in [("proxies", "proxies"), ("use", "use")] {
        if let Some(list) =
            text(row, column).and_then(|list| serde_json::from_str::<Vec<String>>(&list).ok())
        {
            put(
                key,
                serde_yaml::Value::Sequence(
                    list.into_iter().map(serde_yaml::Value::from).collect(),
                ),
            );
        }
    }
    for (column, key) in [
        ("url", "url"),
        ("filter", "filter"),
        ("exclude_filter", "exclude-filter"),
        ("exclude_type", "exclude-type"),
        ("expected_status", "expected-status"),
        ("icon", "icon"),
    ] {
        if let Some(value) = text(row, column) {
            put(key, value.into());
        }
    }
    for (column, key) in [
        ("interval", "interval"),
        ("timeout", "timeout"),
        ("max_failed_times", "max-failed-times"),
    ] {
        if let Some(value) = int(row, column) {
            put(key, value.into());
        }
    }
    for (column, key) in [
        ("lazy", "lazy"),
        ("disable_u_d_p", "disable-udp"),
        ("include_all", "include-all"),
        ("include_all_proxies", "include-all-proxies"),
        ("include_all_providers", "include-all-providers"),
        ("hidden", "hidden"),
    ] {
        if let Some(value) = int(row, column) {
            put(key, (value != 0).into());
        }
    }
    Some(serde_yaml::Value::Mapping(group))
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn reads_profiles_overrides_scripts_and_rules() {
        let dir = std::env::temp_dir().join(format!("po0-flutter-{}", util::random_id()));
        std::fs::create_dir_all(&dir).unwrap();
        let database = dir.join(DATABASE);
        let connection = Connection::open(&database).unwrap();
        connection
            .execute_batch(
                r#"CREATE TABLE profiles (id INTEGER PRIMARY KEY, label TEXT NOT NULL, url TEXT NOT NULL,
                    last_update_date INTEGER, overwrite_type TEXT NOT NULL, script_id INTEGER, match_target TEXT,
                    auto_update_duration_millis INTEGER NOT NULL, auto_update INTEGER NOT NULL,
                    selected_map TEXT NOT NULL, "order" INTEGER);
                CREATE TABLE rules (id INTEGER PRIMARY KEY, rule_action TEXT NOT NULL, content TEXT, rule_target TEXT,
                    rule_provider TEXT, sub_rule TEXT, no_resolve INTEGER NOT NULL DEFAULT 0, src INTEGER NOT NULL DEFAULT 0);
                CREATE TABLE profile_rule_mapping (id TEXT, profile_id INTEGER, rule_id INTEGER, scene TEXT, "order" TEXT);
                CREATE TABLE scripts (id INTEGER PRIMARY KEY, label TEXT NOT NULL, last_update_time INTEGER NOT NULL);
                CREATE TABLE proxy_groups (id INTEGER PRIMARY KEY, profile_id INTEGER, name TEXT NOT NULL,
                    type TEXT NOT NULL, proxies TEXT, disable_u_d_p INTEGER, "order" TEXT);
                INSERT INTO profiles VALUES
                    (7, 'sub', 'https://a/sub', 1700000000, 'standard', NULL, 'PROXY', 7200000, 1, '{"PROXY":"a"}', 1),
                    (8, 'local', '', NULL, 'custom', NULL, NULL, 86400000, 0, '{}', 0),
                    (9, 'gone', '', NULL, 'script', 5, NULL, 86400000, 1, '{}', 2);
                INSERT INTO rules VALUES
                    (1, 'DOMAIN_SUFFIX', 'g.example', 'DIRECT', NULL, NULL, 0, 0),
                    (2, 'IP_CIDR', '10.0.0.0/8', 'MATCH', NULL, NULL, 1, 0),
                    (3, 'RULE_SET', NULL, 'PROXY', 'ads', NULL, 0, 0),
                    (4, 'MATCH', NULL, 'G', NULL, NULL, 0, 0);
                INSERT INTO profile_rule_mapping VALUES
                    ('a', NULL, 1, NULL, 'a0'), ('b', NULL, 3, NULL, 'a1'),
                    ('c', 7, 2, 'added', 'a0'), ('d', 7, 3, 'disabled', NULL), ('e', 8, 4, 'custom', 'a0');
                INSERT INTO scripts VALUES (5, 'tag', 0);
                INSERT INTO proxy_groups VALUES (1, 8, 'G', 'select', '["DIRECT"]', 1, 'a0');"#,
            )
            .unwrap();
        drop(connection);
        let config = serde_json::json!({
            "currentProfileId": 8,
            "po0FirewallProps": { "enable": true, "tokenEntries": [{ "token": "pgnfw_a", "name": "home" }] },
        });
        let files = BTreeMap::from([
            ("profiles/7.yaml", "proxies: []\n"),
            ("profiles/8.yaml", "proxies: []\n"),
            ("scripts/5.js", "function main(c) { return c; }"),
        ]);
        let restored = read(&config, Some(&database), |name| {
            files.get(name).map(|text| text.to_string())
        })
        .unwrap();
        let ids: Vec<_> = restored
            .profiles
            .iter()
            .map(|profile| profile.id.as_str())
            .collect();
        assert_eq!(
            ids,
            ["8", "7"],
            "a profile without a URL or a file is left out"
        );
        assert_eq!(restored.current.as_deref(), Some("8"));
        assert_eq!(
            restored.global_rules,
            ["DOMAIN-SUFFIX,g.example,DIRECT", "RULE-SET,ads,PROXY"]
        );
        assert_eq!(restored.scripts[0].name, "tag");
        let sub = &restored.profiles[1];
        assert_eq!(
            (sub.kind, sub.update_hours, sub.manual_update),
            (ProfileKind::Subscription, Some(2), false)
        );
        assert_eq!(sub.selections["PROXY"], "a");
        assert_eq!(
            sub.overrides.added_rules,
            ["IP-CIDR,10.0.0.0/8,MATCH,no-resolve"]
        );
        assert_eq!(sub.overrides.disabled_global_rules, ["RULE-SET,ads,PROXY"]);
        assert_eq!(sub.overrides.match_target.as_deref(), Some("PROXY"));
        let local = &restored.profiles[0];
        assert_eq!((local.kind, local.manual_update), (ProfileKind::File, true));
        assert_eq!(local.overrides.mode, OverrideMode::Custom);
        assert_eq!(local.overrides.custom_rules, ["MATCH,G"]);
        assert!(local.overrides.custom_groups.contains("disable-udp: true"));
        assert!(restored.whitelist.enabled && restored.whitelist.entries.len() == 1);
        std::fs::remove_dir_all(dir).unwrap();
    }
}
