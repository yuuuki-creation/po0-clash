use std::collections::BTreeMap;
use std::fs;
use std::path::PathBuf;
use std::sync::{Mutex, MutexGuard, PoisonError};

use serde::{Deserialize, Serialize};

use crate::app_settings::{self, AppSettings};
use crate::error::Result;
use crate::model::{Mode, ProfileKind, RouteMode, Usage};
use crate::options::EngineOptions;
use crate::util;

#[derive(Debug, Clone, Default, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase", default)]
pub struct Settings {
    pub mode: Mode,
    pub route_mode: RouteMode,
    pub current_profile: Option<String>,
    pub profiles: Vec<ProfileRecord>,
    pub whitelist: WhitelistSettings,
    pub connected: bool,
    pub options: EngineOptions,
    #[serde(deserialize_with = "app_settings::lenient")]
    pub app: AppSettings,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct ProfileRecord {
    pub id: String,
    pub name: String,
    pub kind: ProfileKind,
    #[serde(default)]
    pub url: Option<String>,
    #[serde(default)]
    pub updated_at: Option<i64>,
    #[serde(default)]
    pub usage: Option<Usage>,
    #[serde(default)]
    pub update_hours: Option<u32>,
    #[serde(default)]
    pub manual_update: bool,
    #[serde(default)]
    pub selections: BTreeMap<String, String>,
}

impl ProfileRecord {
    pub fn new(id: String, name: String, kind: ProfileKind) -> Self {
        Self {
            id,
            name,
            kind,
            url: None,
            updated_at: Some(util::now()),
            usage: None,
            update_hours: None,
            manual_update: false,
            selections: BTreeMap::new(),
        }
    }
}

#[derive(Debug, Clone, Default, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase", default)]
pub struct WhitelistSettings {
    pub enabled: bool,
    pub entries: Vec<EntryRecord>,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct EntryRecord {
    pub id: String,
    pub name: String,
    pub value: String,
}

impl Settings {
    pub fn profile(&self, id: &str) -> Option<&ProfileRecord> {
        self.profiles.iter().find(|profile| profile.id == id)
    }

    pub fn profile_mut(&mut self, id: &str) -> Option<&mut ProfileRecord> {
        self.profiles.iter_mut().find(|profile| profile.id == id)
    }

    pub fn profile_index(&self, id: &str) -> Option<usize> {
        self.profiles.iter().position(|profile| profile.id == id)
    }

    pub fn current(&self) -> Option<&ProfileRecord> {
        self.current_profile
            .as_deref()
            .and_then(|id| self.profile(id))
    }
}

/// The only reader and writer of `settings.json`; every change is saved before it returns.
pub struct Store {
    path: PathBuf,
    data: Mutex<Settings>,
}

impl Store {
    pub fn open(path: PathBuf) -> (Self, bool) {
        let loaded = fs::read(&path)
            .ok()
            .and_then(|bytes| serde_json::from_slice::<Settings>(&bytes).ok());
        let existed = loaded.is_some();
        let store = Self {
            path,
            data: Mutex::new(loaded.unwrap_or_default()),
        };
        (store, existed)
    }

    pub fn get(&self) -> Settings {
        self.lock().clone()
    }

    pub fn read<T>(&self, f: impl FnOnce(&Settings) -> T) -> T {
        f(&self.lock())
    }

    pub fn save(&self) -> Result<()> {
        let json = serde_json::to_vec_pretty(&*self.lock()).expect("settings serialize");
        Ok(util::write_atomic(&self.path, &json)?)
    }

    pub fn update<T>(&self, f: impl FnOnce(&mut Settings) -> Result<T>) -> Result<T> {
        let mut data = self.lock();
        let mut next = data.clone();
        let value = f(&mut next)?;
        if next != *data {
            let json = serde_json::to_vec_pretty(&next).expect("settings serialize");
            util::write_atomic(&self.path, &json)?;
            *data = next;
        }
        Ok(value)
    }

    fn lock(&self) -> MutexGuard<'_, Settings> {
        self.data.lock().unwrap_or_else(PoisonError::into_inner)
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn saves_and_reloads_changes() {
        let dir = std::env::temp_dir().join(format!("po0-settings-{}", util::random_id()));
        let path = dir.join("settings.json");
        let (store, existed) = Store::open(path.clone());
        assert!(!existed);
        store
            .update(|s| {
                s.mode = Mode::Global;
                s.whitelist.entries.push(EntryRecord {
                    id: "a".into(),
                    name: "n".into(),
                    value: "pgnfw_x".into(),
                });
                Ok(())
            })
            .unwrap();
        let (reopened, existed) = Store::open(path);
        assert!(existed);
        assert_eq!(reopened.get(), store.get());
        fs::remove_dir_all(dir).unwrap();
    }

    #[test]
    fn a_failed_update_changes_nothing() {
        let dir = std::env::temp_dir().join(format!("po0-settings-{}", util::random_id()));
        let (store, _) = Store::open(dir.join("settings.json"));
        let result: Result<()> = store.update(|s| {
            s.mode = Mode::Direct;
            Err(crate::CoreError::Invalid("no".into()))
        });
        assert!(result.is_err());
        assert_eq!(store.get().mode, Mode::Rule);
        assert!(!dir.exists());
    }
}
