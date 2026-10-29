use std::fs;
use std::path::Path;

use serde_json::Value;

/// What the Flutter app (6.x) leaves that the native app takes over: subscriptions and
/// whitelist entries only (native-rewrite.md).
#[derive(Debug, Default, PartialEq, Eq)]
pub struct Legacy {
    pub profiles: Vec<LegacyProfile>,
    pub current: Option<String>,
    pub whitelist_enabled: bool,
    pub entries: Vec<(String, String)>,
}

#[derive(Debug, PartialEq, Eq)]
pub struct LegacyProfile {
    pub id: String,
    pub name: String,
    pub url: String,
    pub yaml: Option<String>,
}

pub fn read(prefs: Option<&Path>, database: Option<&Path>) -> Legacy {
    let mut legacy = Legacy::default();
    if let Some(config) = prefs.and_then(config_json) {
        read_config(&config, &mut legacy);
    }
    if let Some(database) = database.filter(|path| path.exists()) {
        legacy.profiles = read_profiles(database).unwrap_or_default();
    }
    legacy
}

/// `shared_preferences` keeps the app's `config` JSON under `flutter.config`: in a JSON map on
/// desktop and in `FlutterSharedPreferences.xml` on Android.
fn config_json(path: &Path) -> Option<Value> {
    let text = fs::read_to_string(path).ok()?;
    let raw = if path.extension().is_some_and(|ext| ext == "xml") {
        let start = text.find(r#"<string name="flutter.config">"#)?;
        let rest = &text[start + r#"<string name="flutter.config">"#.len()..];
        unescape_xml(&rest[..rest.find("</string>")?])
    } else {
        serde_json::from_str::<Value>(&text)
            .ok()?
            .get("flutter.config")?
            .as_str()?
            .to_owned()
    };
    serde_json::from_str(&raw).ok()
}

fn unescape_xml(text: &str) -> String {
    let mut out = String::with_capacity(text.len());
    let mut rest = text;
    while let Some(at) = rest.find('&') {
        out.push_str(&rest[..at]);
        rest = &rest[at..];
        let Some(end) = rest.find(';') else {
            break;
        };
        let entity = &rest[1..end];
        let decoded = match entity {
            "quot" => Some('"'),
            "amp" => Some('&'),
            "lt" => Some('<'),
            "gt" => Some('>'),
            "apos" => Some('\''),
            _ => entity
                .strip_prefix("#x")
                .and_then(|hex| u32::from_str_radix(hex, 16).ok())
                .or_else(|| entity.strip_prefix('#').and_then(|dec| dec.parse().ok()))
                .and_then(char::from_u32),
        };
        match decoded {
            Some(c) => {
                out.push(c);
                rest = &rest[end + 1..];
            }
            None => {
                out.push('&');
                rest = &rest[1..];
            }
        }
    }
    out.push_str(rest);
    out
}

fn read_config(config: &Value, legacy: &mut Legacy) {
    legacy.current = config.get("currentProfileId").map(|id| match id {
        Value::String(id) => id.clone(),
        other => other.to_string(),
    });
    let Some(props) = config.get("po0FirewallProps") else {
        return;
    };
    legacy.whitelist_enabled = props
        .get("enable")
        .and_then(Value::as_bool)
        .unwrap_or(false);
    for list in ["tokenEntries", "ggyEntries"] {
        for entry in props
            .get(list)
            .and_then(Value::as_array)
            .into_iter()
            .flatten()
        {
            let token = entry
                .get("token")
                .and_then(Value::as_str)
                .unwrap_or_default();
            let name = entry
                .get("name")
                .and_then(Value::as_str)
                .unwrap_or_default();
            if !token.is_empty() {
                legacy.entries.push((name.to_owned(), token.to_owned()));
            }
        }
    }
    if let Some(tokens) = props.get("tokens").and_then(Value::as_str) {
        legacy.entries.push((String::new(), tokens.to_owned()));
    }
}

fn read_profiles(database: &Path) -> rusqlite::Result<Vec<LegacyProfile>> {
    let connection = rusqlite::Connection::open_with_flags(
        database,
        rusqlite::OpenFlags::SQLITE_OPEN_READ_ONLY | rusqlite::OpenFlags::SQLITE_OPEN_NO_MUTEX,
    )?;
    let mut statement = connection
        .prepare(r#"SELECT id, label, url FROM profiles ORDER BY "order" IS NULL, "order", id"#)?;
    let profiles_dir = database.with_file_name("profiles");
    let rows = statement.query_map([], |row| {
        let id: i64 = row.get(0)?;
        Ok((
            id.to_string(),
            row.get::<_, String>(1)?,
            row.get::<_, String>(2)?,
        ))
    })?;
    Ok(rows
        .filter_map(std::result::Result::ok)
        .filter(|(_, _, url)| url.starts_with("http://") || url.starts_with("https://"))
        .map(|(id, name, url)| LegacyProfile {
            yaml: fs::read_to_string(profiles_dir.join(format!("{id}.yaml"))).ok(),
            id,
            name,
            url,
        })
        .collect())
}

#[cfg(test)]
mod tests {
    use super::*;

    fn temp_dir() -> std::path::PathBuf {
        let dir = std::env::temp_dir().join(format!("po0-legacy-{}", crate::util::random_id()));
        fs::create_dir_all(&dir).unwrap();
        dir
    }

    const CONFIG: &str = r#"{"currentProfileId":2,"po0FirewallProps":{"enable":true,"tokenEntries":[{"token":"pgnfw_a","name":"home"}],"ggyEntries":[{"token":"https://guguyun.com/w?token=g","name":""}],"pollSeconds":5}}"#;

    #[test]
    fn reads_desktop_preferences() {
        let dir = temp_dir();
        let prefs = dir.join("shared_preferences.json");
        let json = serde_json::json!({ "flutter.config": CONFIG, "flutter.other": 1 });
        fs::write(&prefs, json.to_string()).unwrap();
        let legacy = read(Some(&prefs), None);
        assert_eq!(legacy.current.as_deref(), Some("2"));
        assert!(legacy.whitelist_enabled);
        assert_eq!(
            legacy.entries,
            [
                ("home".to_owned(), "pgnfw_a".to_owned()),
                (String::new(), "https://guguyun.com/w?token=g".to_owned())
            ]
        );
        fs::remove_dir_all(dir).unwrap();
    }

    #[test]
    fn reads_android_preferences() {
        let dir = temp_dir();
        let prefs = dir.join("FlutterSharedPreferences.xml");
        let escaped = CONFIG.replace('&', "&amp;").replace('"', "&quot;");
        let xml = format!(
            "<?xml version='1.0' encoding='utf-8' standalone='yes' ?>\n<map>\n    <string name=\"flutter.config\">{escaped}</string>\n</map>\n"
        );
        fs::write(&prefs, xml).unwrap();
        let legacy = read(Some(&prefs), None);
        assert_eq!(legacy.entries.len(), 2);
        assert_eq!(unescape_xml("a&#x4e2d;&#25991;&bogus"), "a中文&bogus");
        fs::remove_dir_all(dir).unwrap();
    }

    #[test]
    fn reads_subscriptions_from_the_drift_database() {
        let dir = temp_dir();
        let database = dir.join("database.sqlite");
        let connection = rusqlite::Connection::open(&database).unwrap();
        connection
            .execute_batch(
                r#"CREATE TABLE profiles (id INTEGER PRIMARY KEY, label TEXT NOT NULL, url TEXT NOT NULL, "order" INTEGER);
                INSERT INTO profiles VALUES (1, 'local', '', 0), (2, 'b', 'https://b/sub', 2), (3, 'a', 'https://a/sub', 1);"#,
            )
            .unwrap();
        drop(connection);
        fs::create_dir_all(dir.join("profiles")).unwrap();
        fs::write(dir.join("profiles/2.yaml"), "proxies: []\n").unwrap();
        let profiles = read(None, Some(&database)).profiles;
        let names: Vec<_> = profiles.iter().map(|p| p.name.as_str()).collect();
        assert_eq!(names, ["a", "b"]);
        assert_eq!(profiles[1].yaml.as_deref(), Some("proxies: []\n"));
        assert_eq!(profiles[0].yaml, None);
        fs::remove_dir_all(dir).unwrap();
    }

    #[test]
    fn missing_files_import_nothing() {
        let dir = temp_dir();
        assert_eq!(
            read(Some(&dir.join("nope.json")), Some(&dir.join("nope.sqlite"))),
            Legacy::default()
        );
        fs::remove_dir_all(dir).unwrap();
    }
}
