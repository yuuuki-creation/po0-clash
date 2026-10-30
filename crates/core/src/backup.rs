use std::collections::{BTreeMap, BTreeSet};
use std::fs;
use std::io::{Cursor, Read, Write};
use std::path::Path;

use serde::de::DeserializeOwned;
use serde::{Deserialize, Serialize};
use zip::result::ZipError;
use zip::write::SimpleFileOptions;
use zip::{CompressionMethod, ZipArchive, ZipWriter};

use crate::app_settings::RestoreStrategy;
use crate::error::{CoreError, Result};
use crate::flutter_backup;
use crate::model::{ProfileKind, RestoreScope};
use crate::options::EngineOptions;
use crate::profiles::Content;
use crate::settings::Settings;
use crate::util;

const MANIFEST: &str = "po0-clash-backup.json";
const SETTINGS: &str = "settings.json";
const VERSION: u32 = 1;
const ENTRY_LIMIT: u64 = 64 << 20;

#[derive(Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
struct Manifest {
    version: u32,
    app_version: String,
    created_at: i64,
}

/// FlClash's backup: the settings and each profile's file, by profile id, in one zip.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct Backup {
    pub settings: Settings,
    pub files: BTreeMap<String, Content>,
    /// The Flutter app's settings do not map onto these, so only its profiles, scripts, rules and whitelist come back.
    pub flutter: bool,
}

impl Backup {
    pub fn to_zip(&self, app_version: &str) -> Result<Vec<u8>> {
        let manifest = Manifest {
            version: VERSION,
            app_version: app_version.to_owned(),
            created_at: util::now(),
        };
        let settings = Settings {
            connected: false,
            ..self.settings.clone()
        };
        let mut entries = vec![
            (
                MANIFEST.to_owned(),
                serde_json::to_vec_pretty(&manifest).expect("manifest serializes"),
            ),
            (
                SETTINGS.to_owned(),
                serde_json::to_vec_pretty(&settings).expect("settings serialize"),
            ),
        ];
        for (id, content) in &self.files {
            entries.push(match content {
                Content::Yaml(text) => (format!("profiles/{id}.yaml"), text.clone().into_bytes()),
                Content::Links(text) => (format!("profiles/{id}.txt"), text.clone().into_bytes()),
            });
        }
        let options = SimpleFileOptions::default().compression_method(CompressionMethod::Deflated);
        let mut zip = ZipWriter::new(Cursor::new(Vec::new()));
        for (name, bytes) in entries {
            zip.start_file(name, options).map_err(write_error)?;
            zip.write_all(&bytes)?;
        }
        Ok(zip.finish().map_err(write_error)?.into_inner())
    }

    /// Entries are only looked up by names built from ids that are safe as file names, so a crafted archive
    /// cannot write outside the profiles folder.
    pub fn from_zip(bytes: &[u8], scratch: &Path) -> Result<Self> {
        let mut zip = ZipArchive::new(Cursor::new(bytes)).map_err(|_| not_a_backup())?;
        if zip.index_for_name(MANIFEST).is_none()
            && let Some(config) = read_entry(&mut zip, flutter_backup::CONFIG)?
        {
            return Self::from_flutter(&mut zip, &config, scratch);
        }
        let manifest: Manifest = parse(read_entry(&mut zip, MANIFEST)?)?;
        if manifest.version > VERSION {
            return Err(CoreError::Invalid(
                "this backup was made by a newer po0-clash".into(),
            ));
        }
        let mut settings: Settings = parse(read_entry(&mut zip, SETTINGS)?)?;
        let mut seen = BTreeSet::new();
        settings
            .profiles
            .retain(|profile| safe_id(&profile.id) && seen.insert(profile.id.clone()));
        let mut files = BTreeMap::new();
        for profile in &settings.profiles {
            let yaml = read_text(&mut zip, &format!("profiles/{}.yaml", profile.id))?;
            let content = match yaml {
                Some(text) => Some(Content::Yaml(text)),
                None => read_text(&mut zip, &format!("profiles/{}.txt", profile.id))?
                    .map(Content::Links),
            };
            if let Some(content) = content {
                files.insert(profile.id.clone(), content);
            }
        }
        settings.profiles.retain(|profile| {
            files.contains_key(&profile.id)
                || profile.kind == ProfileKind::Subscription && profile.url.is_some()
        });
        Ok(Self {
            settings,
            files,
            flutter: false,
        })
    }

    /// SQLite reads the drift database from a file, so it is unpacked into `scratch` for the moment.
    fn from_flutter(
        zip: &mut ZipArchive<Cursor<&[u8]>>,
        config: &[u8],
        scratch: &Path,
    ) -> Result<Self> {
        let config: serde_json::Value =
            serde_json::from_slice(config).map_err(|_| not_a_backup())?;
        let database = read_entry(zip, flutter_backup::DATABASE)?;
        let path = scratch.join(format!("flutter-backup-{}.sqlite", util::random_id()));
        if let Some(bytes) = &database {
            fs::create_dir_all(scratch)?;
            fs::write(&path, bytes)?;
        }
        let restored =
            flutter_backup::read(&config, database.as_ref().map(|_| path.as_path()), |name| {
                read_text(zip, name).ok().flatten()
            });
        let _ = fs::remove_file(&path);
        let restored = restored.map_err(|_| not_a_backup())?;
        Ok(Self {
            settings: Settings {
                profiles: restored.profiles,
                scripts: restored.scripts,
                current_profile: restored.current,
                whitelist: restored.whitelist,
                options: EngineOptions {
                    added_rules: restored.global_rules,
                    ..EngineOptions::default()
                },
                ..Settings::default()
            },
            files: restored.files,
            flutter: true,
        })
    }

    /// The settings after restoring into `current`, and the profiles whose files are no longer needed.
    pub fn restore_into(
        self,
        current: &Settings,
        scope: RestoreScope,
        strategy: RestoreStrategy,
    ) -> (Settings, Vec<String>) {
        let flutter = self.flutter;
        let saved = self.settings;
        let mut next = current.clone();
        let dropped = match strategy {
            RestoreStrategy::Override => {
                next.profiles = saved.profiles.clone();
                next.scripts = saved.scripts.clone();
                current
                    .profiles
                    .iter()
                    .filter(|profile| saved.profile(&profile.id).is_none())
                    .map(|profile| profile.id.clone())
                    .collect()
            }
            RestoreStrategy::Compatible => {
                for profile in &saved.profiles {
                    match next.profile_mut(&profile.id) {
                        Some(existing) => *existing = profile.clone(),
                        None => next.profiles.push(profile.clone()),
                    }
                }
                for script in &saved.scripts {
                    match next
                        .scripts
                        .iter_mut()
                        .find(|existing| existing.id == script.id)
                    {
                        Some(existing) => *existing = script.clone(),
                        None => next.scripts.push(script.clone()),
                    }
                }
                Vec::new()
            }
        };
        if scope == RestoreScope::All && flutter {
            next.whitelist = saved.whitelist;
            next.options.added_rules = saved.options.added_rules;
            if let Some(id) = saved
                .current_profile
                .filter(|id| next.profile(id).is_some())
            {
                next.current_profile = Some(id);
            }
        } else if scope == RestoreScope::All {
            next.mode = saved.mode;
            next.route_mode = saved.route_mode;
            next.options = saved.options;
            next.whitelist = saved.whitelist;
            let mut app = saved.app;
            app.webdav = app.webdav.or_else(|| current.app.webdav.clone());
            next.app = app.validated().unwrap_or_else(|_| current.app.clone());
            if let Some(id) = saved
                .current_profile
                .filter(|id| next.profile(id).is_some())
            {
                next.current_profile = Some(id);
            }
        }
        if next.current().is_none() {
            next.current_profile = next.profiles.first().map(|profile| profile.id.clone());
        }
        (next, dropped)
    }
}

fn safe_id(id: &str) -> bool {
    !id.is_empty()
        && id.len() <= 64
        && id
            .bytes()
            .all(|byte| byte.is_ascii_alphanumeric() || byte == b'-' || byte == b'_')
}

fn not_a_backup() -> CoreError {
    CoreError::Invalid("not a po0-clash backup".into())
}

fn write_error(error: ZipError) -> CoreError {
    CoreError::Io(error.to_string())
}

fn parse<T: DeserializeOwned>(bytes: Option<Vec<u8>>) -> Result<T> {
    let bytes = bytes.ok_or_else(not_a_backup)?;
    serde_json::from_slice(&bytes).map_err(|_| not_a_backup())
}

fn read_entry(zip: &mut ZipArchive<Cursor<&[u8]>>, name: &str) -> Result<Option<Vec<u8>>> {
    let file = match zip.by_name(name) {
        Ok(file) => file,
        Err(ZipError::FileNotFound) => return Ok(None),
        Err(_) => return Err(not_a_backup()),
    };
    let mut bytes = Vec::new();
    file.take(ENTRY_LIMIT + 1)
        .read_to_end(&mut bytes)
        .map_err(|_| not_a_backup())?;
    if bytes.len() as u64 > ENTRY_LIMIT {
        return Err(CoreError::Invalid(
            "the backup holds a file too large to restore".into(),
        ));
    }
    Ok(Some(bytes))
}

fn read_text(zip: &mut ZipArchive<Cursor<&[u8]>>, name: &str) -> Result<Option<String>> {
    read_entry(zip, name)?
        .map(|bytes| String::from_utf8(bytes).map_err(|_| not_a_backup()))
        .transpose()
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::WebDav;
    use crate::model::Mode;
    use crate::settings::ProfileRecord;

    fn record(id: &str, kind: ProfileKind) -> ProfileRecord {
        ProfileRecord::new(id.into(), id.into(), kind)
    }

    fn backup() -> Backup {
        let mut settings = Settings {
            mode: Mode::Global,
            current_profile: Some("b".into()),
            profiles: vec![
                record("a", ProfileKind::File),
                record("b", ProfileKind::Links),
            ],
            ..Settings::default()
        };
        settings.app.pure_black = true;
        Backup {
            settings,
            files: BTreeMap::from([
                ("a".into(), Content::Yaml("proxies: []\n".into())),
                ("b".into(), Content::Links("vless://u@h:1#b".into())),
            ]),
            flutter: false,
        }
    }

    #[test]
    fn a_backup_survives_the_zip() {
        let backup = backup();
        let bytes = backup.to_zip("test").unwrap();
        assert_eq!(
            Backup::from_zip(&bytes, &std::env::temp_dir()).unwrap(),
            backup
        );
        assert!(Backup::from_zip(b"not a zip", &std::env::temp_dir()).is_err());
    }

    #[test]
    fn unsafe_ids_and_newer_backups_are_refused() {
        let mut backup = backup();
        backup
            .settings
            .profiles
            .push(record("../evil", ProfileKind::File));
        backup
            .settings
            .profiles
            .push(record("lost", ProfileKind::File));
        let restored =
            Backup::from_zip(&backup.to_zip("test").unwrap(), &std::env::temp_dir()).unwrap();
        let ids: Vec<_> = restored
            .settings
            .profiles
            .iter()
            .map(|p| p.id.as_str())
            .collect();
        assert_eq!(
            ids,
            ["a", "b"],
            "unsafe ids and files missing from the archive are dropped"
        );

        let mut zip = ZipWriter::new(Cursor::new(Vec::new()));
        zip.start_file(MANIFEST, SimpleFileOptions::default())
            .unwrap();
        zip.write_all(br#"{"version":2,"appVersion":"9","createdAt":0}"#)
            .unwrap();
        let newer = zip.finish().unwrap().into_inner();
        let error = Backup::from_zip(&newer, &std::env::temp_dir()).unwrap_err();
        assert!(error.to_string().contains("newer"));
    }

    #[test]
    fn strategies_merge_or_replace_the_profiles() {
        let mut current = Settings {
            current_profile: Some("local".into()),
            profiles: vec![
                record("local", ProfileKind::File),
                record("a", ProfileKind::Links),
            ],
            connected: true,
            ..Settings::default()
        };
        current.app.webdav = Some(WebDav {
            url: "https://dav.example.com/".into(),
            user: "u".into(),
            password: "p".into(),
            file_name: String::new(),
        });

        let (merged, dropped) = backup().restore_into(
            &current,
            RestoreScope::Profiles,
            RestoreStrategy::Compatible,
        );
        let ids: Vec<_> = merged.profiles.iter().map(|p| p.id.as_str()).collect();
        assert_eq!(ids, ["local", "a", "b"]);
        assert_eq!(
            merged.profiles[1].kind,
            ProfileKind::File,
            "the backup's copy replaces one with its id"
        );
        assert_eq!(merged.current_profile.as_deref(), Some("local"));
        assert_eq!(merged.mode, Mode::Rule, "only the profiles were asked for");
        assert!(dropped.is_empty());

        let (replaced, dropped) =
            backup().restore_into(&current, RestoreScope::All, RestoreStrategy::Override);
        let ids: Vec<_> = replaced.profiles.iter().map(|p| p.id.as_str()).collect();
        assert_eq!(ids, ["a", "b"]);
        assert_eq!(dropped, ["local"]);
        assert_eq!(replaced.current_profile.as_deref(), Some("b"));
        assert_eq!(replaced.mode, Mode::Global);
        assert!(replaced.app.pure_black);
        assert_eq!(
            replaced.app.webdav, current.app.webdav,
            "a backup without WebDAV keeps the account"
        );
        assert!(
            replaced.connected,
            "whether the engine runs is not part of a backup"
        );
    }

    #[test]
    fn a_flutter_backup_brings_back_its_whitelist_but_not_its_settings() {
        let mut zip = ZipWriter::new(Cursor::new(Vec::new()));
        zip.start_file(flutter_backup::CONFIG, SimpleFileOptions::default())
            .unwrap();
        zip.write_all(br#"{"version":1,"po0FirewallProps":{"enable":true,"tokenEntries":[{"token":"pgnfw_a","name":""}]}}"#)
            .unwrap();
        let bytes = zip.finish().unwrap().into_inner();
        let backup = Backup::from_zip(&bytes, &std::env::temp_dir()).unwrap();
        assert!(backup.flutter && backup.settings.profiles.is_empty());
        let current = Settings {
            mode: Mode::Global,
            ..Settings::default()
        };
        let (next, _) =
            backup.restore_into(&current, RestoreScope::All, RestoreStrategy::Compatible);
        assert_eq!(next.mode, Mode::Global);
        assert_eq!(next.whitelist.entries.len(), 1);
    }
}
