mod app_settings;
mod backup;
mod config;
mod engine;
mod error;
mod ip_quality;
mod legacy;
mod logfile;
mod model;
mod network;
mod options;
mod profiles;
mod resources;
mod script;
mod settings;
mod update;
mod util;
mod webdav;
mod whitelist;

use std::collections::BTreeMap;
use std::fs;
use std::path::{Path, PathBuf};
use std::sync::atomic::Ordering;
use std::sync::{Arc, Condvar, Mutex, MutexGuard, PoisonError, RwLock, Weak};
use std::thread;
use std::time::Duration;

use serde_json::{Value, json};

pub use app_settings::*;
pub use error::{CoreError, Result};
pub use ip_quality::{IpQuality, IpQualityLevel, IpQualitySource, IpType};
pub use model::*;
pub use options::*;

use backup::Backup;
use engine::{Engine, Runtime, Session, sysdns, sysproxy};
use logfile::LogFile;
use profiles::Content;
use settings::{EntryRecord, ProfileRecord, Settings, Store};
use whitelist::Whitelist;

const LINKS_PROFILE_NAME: &str = "Share links";
const DEFAULT_UPDATE_HOURS: u32 = 24;
const UPDATE_CHECK: Duration = Duration::from_secs(600);
const FIRST_UPDATE_CHECK: Duration = Duration::from_secs(20);
const DELAY_TIMEOUT_MS: u32 = 5000;
const DOWNLOAD_TIMEOUT: Duration = Duration::from_secs(180);
const EXIT_IP_URL: &str = "https://www.cloudflare.com/cdn-cgi/trace";
const GROUP_TYPES: &[&str] = &["Selector", "URLTest", "Fallback", "LoadBalance", "Relay"];

pub trait Listener: Send + Sync {
    fn on_change(&self, change: Change);
}

#[derive(Debug, Clone)]
pub struct CoreOptions {
    pub data_dir: PathBuf,
    pub platform: Platform,
    pub mihomo_path: Option<PathBuf>,
    pub legacy_prefs: Option<PathBuf>,
    pub legacy_database: Option<PathBuf>,
    pub app_version: String,
}

struct Paths {
    profiles: PathBuf,
    home: PathBuf,
    run: PathBuf,
}

impl Paths {
    fn new(data_dir: &Path) -> Self {
        Self {
            profiles: data_dir.join("profiles"),
            home: data_dir.join("mihomo"),
            run: data_dir.join("run"),
        }
    }

    fn yaml(&self, id: &str) -> PathBuf {
        self.profiles.join(format!("{id}.yaml"))
    }

    fn links(&self, id: &str) -> PathBuf {
        self.profiles.join(format!("{id}.txt"))
    }

    /// A setuid-root mihomo leaves root-owned files behind, which an unprivileged one could not
    /// write, so the two never share a home. Share-link files sit in the home's root because
    /// mihomo may create `providers/` as root.
    fn home_for(&self, binary: Option<&Path>) -> PathBuf {
        if binary.is_some_and(engine::is_privileged) {
            self.home.with_file_name("mihomo-root")
        } else {
            self.home.clone()
        }
    }
}

struct Updater {
    stopped: Mutex<bool>,
    signal: Condvar,
}

/// Owns every piece of state; the platform apps only call these methods (ADR 0018). Every
/// method blocks, so UI code calls them off its main thread.
pub struct Core {
    me: Weak<Core>,
    platform: Platform,
    app_version: String,
    paths: Paths,
    mihomo_path: Mutex<Option<PathBuf>>,
    store: Store,
    engine: Engine,
    whitelist: Whitelist,
    listener: RwLock<Option<Arc<dyn Listener>>>,
    updater: Updater,
    mihomo_log: Arc<LogFile>,
    ip_qualities: ip_quality::Cache,
}

fn lock<T>(mutex: &Mutex<T>) -> MutexGuard<'_, T> {
    mutex.lock().unwrap_or_else(PoisonError::into_inner)
}

fn engine_error(error: impl std::fmt::Display) -> CoreError {
    CoreError::Engine(error.to_string())
}

impl Core {
    pub fn new(options: CoreOptions) -> Result<Arc<Self>> {
        let data_dir = options.data_dir.clone();
        let paths = Paths::new(&data_dir);
        for dir in [&data_dir, &paths.profiles, &paths.home, &paths.run] {
            fs::create_dir_all(dir)?;
        }
        logfile::init(data_dir.join("logs").join("core.log"));
        logfile::info(format!(
            "core {} starting, app {} on {:?}",
            env!("CARGO_PKG_VERSION"),
            options.app_version,
            options.platform
        ));
        let cleared = clear_if_requested(&data_dir, &paths);
        let (store, existed) = Store::open(data_dir.join("settings.json"));
        if !existed {
            if !cleared {
                import_legacy(&store, &paths, &options);
            }
            store.save()?;
        }
        engine::recover(&paths.run);
        let whitelist_settings = store.read(|s| s.whitelist.clone());
        let core = Arc::new_cyclic(|me: &Weak<Core>| {
            let (route_core, notify_core) = (me.clone(), me.clone());
            Self {
                me: me.clone(),
                platform: options.platform,
                app_version: options.app_version.clone(),
                mihomo_path: Mutex::new(options.mihomo_path.clone()),
                store,
                engine: Engine::default(),
                whitelist: Whitelist::start(
                    whitelist_settings,
                    data_dir.join("whitelist-results.json"),
                    Box::new(move || {
                        route_core
                            .upgrade()
                            .and_then(|core| core.engine.session())
                            .map_or_else(
                                || "DIRECT".to_owned(),
                                |session| session.runtime.direct.route(),
                            )
                    }),
                    Box::new(move || {
                        if let Some(core) = notify_core.upgrade() {
                            core.emit(&[Change::Whitelist]);
                        }
                    }),
                ),
                listener: RwLock::new(None),
                updater: Updater {
                    stopped: Mutex::new(false),
                    signal: Condvar::new(),
                },
                mihomo_log: Arc::new(LogFile::new(data_dir.join("logs").join("mihomo.log"))),
                ip_qualities: ip_quality::Cache::default(),
                paths,
            }
        });
        let updater = Arc::downgrade(&core);
        thread::Builder::new()
            .name("profile-updater".into())
            .spawn(move || run_updater(&updater))
            .map_err(CoreError::from)?;
        Ok(core)
    }

    pub fn set_listener(&self, listener: Arc<dyn Listener>) {
        *self
            .listener
            .write()
            .unwrap_or_else(PoisonError::into_inner) = Some(listener);
    }

    pub fn set_mihomo_path(&self, path: PathBuf) {
        *lock(&self.mihomo_path) = Some(path);
    }

    /// Called without the settings or session locks held, so a listener may read the core
    /// from `on_change`; it must not start or stop the engine there.
    fn emit(&self, changes: &[Change]) {
        let listener = self
            .listener
            .read()
            .unwrap_or_else(PoisonError::into_inner)
            .clone();
        if let Some(listener) = listener {
            for change in changes {
                listener.on_change(*change);
            }
        }
    }

    pub fn status(&self) -> Status {
        let settings = self.store.get();
        Status {
            engine: self.engine.state(),
            mode: settings.mode,
            route_mode: settings.route_mode,
            profile_id: settings.current_profile,
            current_node: self
                .engine
                .session()
                .and_then(|session| session.current_node()),
        }
    }

    pub fn traffic(&self) -> Traffic {
        self.engine
            .session()
            .map(|_| self.engine.monitor.traffic())
            .unwrap_or_default()
    }

    fn proxy_url(&self) -> Option<String> {
        self.engine
            .session()
            .map(|session| session.runtime.proxy_url())
    }

    // Engine lifecycle.

    pub fn start(&self, tun_fd: Option<i32>) -> Result<()> {
        let result = {
            let _ops = lock(&self.engine.ops);
            if let Some(session) = self.engine.session() {
                if session.runtime.tun_fd == tun_fd {
                    return Ok(());
                }
                self.teardown(&session);
            }
            self.start_locked(tun_fd)
        };
        self.emit(&[Change::Status, Change::Groups]);
        result
    }

    fn start_locked(&self, tun_fd: Option<i32>) -> Result<()> {
        self.engine.set_state(EngineState::Starting);
        self.emit(&[Change::Status]);
        match self.launch(tun_fd) {
            Ok(()) => {
                self.engine.set_state(EngineState::Running);
                logfile::info("engine running");
                self.set_connected(true);
                Ok(())
            }
            Err(error) => {
                logfile::warn(format!("engine start failed: {error}"));
                self.engine
                    .set_state(EngineState::Failed(error.to_string()));
                Err(error)
            }
        }
    }

    fn launch(&self, tun_fd: Option<i32>) -> Result<()> {
        let settings = self.store.get();
        let profile = settings
            .current()
            .cloned()
            .ok_or_else(|| CoreError::Invalid("add a subscription first".into()))?;
        engine::recover(&self.paths.run);
        let binary = lock(&self.mihomo_path).clone();
        let home = self.paths.home_for(binary.as_deref());
        let runtime = Runtime::new(
            self.platform,
            &self.paths.run,
            home,
            tun_fd,
            settings.options.mixed_port,
        )?;
        let missing =
            !self.paths.yaml(&profile.id).exists() && !self.paths.links(&profile.id).exists();
        if missing && profile.url.is_some() {
            self.download(&profile.id)?;
            self.emit(&[Change::Profiles]);
        }
        let config = self.write_config(&profile, &settings, &runtime)?;
        let runner = engine::launch(binary.as_deref(), &runtime.home, &config, &self.mihomo_log)?;
        let session = Arc::new(Session::new(runtime, runner, self.engine.next_generation()));
        let ready = engine::wait_ready(session.controller(), &session.runner, &self.mihomo_log)
            .and_then(|()| {
                self.apply_selections(&session, &profile.selections);
                if self.platform != Platform::Android
                    && settings.route_mode == RouteMode::SystemProxy
                {
                    sysproxy::set(session.runtime.mixed_port, &settings.options.bypass_domains)
                        .map_err(|error| {
                            CoreError::Engine(format!("cannot set the system proxy: {error}"))
                        })?;
                    session.system_proxy.store(true, Ordering::SeqCst);
                }
                if self.patches_system_dns(&settings) {
                    *lock(&session.system_dns) = sysdns::apply();
                }
                Ok(())
            });
        if let Err(error) = ready {
            session.release(&self.paths.run);
            session.runner.stop();
            return Err(error);
        }
        engine::save_record(&self.paths.run, &session);
        self.engine
            .monitor
            .set_log_level(settings.options.log_level);
        self.engine
            .monitor
            .set_only_proxy(settings.app.only_proxy_traffic);
        session.watch(&self.engine.monitor);
        self.engine.install(session.clone());
        self.refresh_current_node(&session, settings.mode);
        self.watch_exit(session.generation);
        Ok(())
    }

    fn watch_exit(&self, generation: u64) {
        if self.platform == Platform::Android {
            return;
        }
        let me = self.me.clone();
        thread::spawn(move || {
            loop {
                thread::sleep(Duration::from_millis(500));
                let Some(core) = me.upgrade() else {
                    return;
                };
                let Some(session) = core.engine.session() else {
                    return;
                };
                if session.generation != generation {
                    return;
                }
                if let Some(status) = session.runner.exited() {
                    core.on_exit(generation, &status);
                    return;
                }
            }
        });
    }

    /// An engine that dies on its own is reported, never restarted (native-rewrite.md).
    fn on_exit(&self, generation: u64, status: &str) {
        {
            let _ops = lock(&self.engine.ops);
            let Some(session) = self.engine.session() else {
                return;
            };
            if session.generation != generation {
                return;
            }
            self.engine.take();
            session.release(&self.paths.run);
            let message = format!(
                "mihomo exited ({status}): {}",
                engine::last_lines(&self.mihomo_log, 3)
            );
            logfile::warn(&message);
            self.engine.set_state(EngineState::Failed(message));
        }
        self.emit(&[Change::Status, Change::Groups]);
    }

    /// The user's own stop; quitting the app goes through `shutdown`, which keeps the intent.
    pub fn stop(&self) {
        self.stop_engine();
        self.set_connected(false);
    }

    /// Whether the user left the proxy connected, so an app launched at login can reconnect.
    pub fn was_connected(&self) -> bool {
        self.store.read(|s| s.connected)
    }

    fn set_connected(&self, connected: bool) {
        let _ = self.store.update(|s| {
            s.connected = connected;
            Ok(())
        });
    }

    fn stop_engine(&self) {
        {
            let _ops = lock(&self.engine.ops);
            if let Some(session) = self.engine.take() {
                self.teardown(&session);
                logfile::info("engine stopped");
            }
            self.engine.set_state(EngineState::Stopped);
        }
        self.emit(&[Change::Status, Change::Groups]);
    }

    fn teardown(&self, session: &Session) {
        self.engine.take();
        session.release(&self.paths.run);
        session.runner.stop();
    }

    fn restart(&self) -> Result<()> {
        let result = {
            let _ops = lock(&self.engine.ops);
            match self.engine.session() {
                Some(session) => {
                    let tun_fd = session.runtime.tun_fd;
                    self.teardown(&session);
                    self.start_locked(tun_fd)
                }
                None => Ok(()),
            }
        };
        self.emit(&[Change::Status, Change::Groups]);
        result
    }

    /// Hot reload keeps TUN up; on Android a restart would close the VPN's descriptor.
    fn reload(&self) -> Result<()> {
        let result = {
            let _ops = lock(&self.engine.ops);
            let Some(session) = self.engine.session() else {
                return Ok(());
            };
            let settings = self.store.get();
            match settings.current().cloned() {
                None => {
                    self.teardown(&session);
                    self.engine.set_state(EngineState::Stopped);
                    Ok(())
                }
                Some(profile) => {
                    let config = self.write_config(&profile, &settings, &session.runtime)?;
                    let body = json!({ "path": config.to_string_lossy() });
                    session
                        .controller()
                        .json("PUT", "/configs?force=true", Some(&body))
                        .map(|_| {
                            self.apply_selections(&session, &profile.selections);
                            self.refresh_current_node(&session, settings.mode);
                        })
                }
            }
        };
        self.emit(&[Change::Status, Change::Groups]);
        result
    }

    /// The profile's config before po0's changes, and the share-link file it points at, if any.
    fn config_base(
        &self,
        profile: &ProfileRecord,
        settings: &Settings,
    ) -> Result<(String, Option<(String, String)>)> {
        if let Ok(yaml) = fs::read_to_string(self.paths.yaml(&profile.id)) {
            return Ok((yaml, None));
        }
        if let Ok(links) = fs::read_to_string(self.paths.links(&profile.id)) {
            let name = format!("po0-links-{}.txt", profile.id);
            let base = config::links_base(&format!("./{name}"), settings.options.delay_url());
            return Ok((base, Some((name, links))));
        }
        Err(CoreError::Invalid(format!(
            "{} has not been downloaded yet",
            profile.name
        )))
    }

    /// An override script runs on the profile's own config, before po0-clash's settings, as in FlClash.
    fn overridden_base(
        &self,
        profile: &ProfileRecord,
        settings: &Settings,
    ) -> Result<(String, Option<(String, String)>)> {
        let (base, links) = self.config_base(profile, settings)?;
        let overrides = &profile.overrides;
        let script = overrides
            .script_id
            .as_deref()
            .and_then(|id| settings.script(id))
            .filter(|_| overrides.mode == OverrideMode::Script);
        match script {
            Some(script) => Ok((config::run_script(&base, &script.content)?, links)),
            None => Ok((base, links)),
        }
    }

    fn write_config(
        &self,
        profile: &ProfileRecord,
        settings: &Settings,
        runtime: &Runtime,
    ) -> Result<PathBuf> {
        let (base, links) = self.overridden_base(profile, settings)?;
        if let Some((name, links)) = links {
            util::write_atomic(&runtime.home.join(name), links.as_bytes())?;
        }
        let rendered = config::render(
            &base,
            &config::Params {
                platform: self.platform,
                mode: settings.mode,
                route_mode: settings.route_mode,
                tun_fd: runtime.tun_fd,
                mixed_port: runtime.mixed_port,
                controller: runtime.controller.endpoint.config_entry(),
                secret: runtime.controller.secret(),
                direct: &runtime.direct,
                options: &settings.options,
                overrides: &profile.overrides,
            },
        )?;
        let path = runtime.home.join("config.yaml");
        util::write_atomic(&path, rendered.as_bytes())?;
        Ok(path)
    }

    fn apply_selections(&self, session: &Session, selections: &BTreeMap<String, String>) {
        for (group, node) in selections {
            let path = format!("/proxies/{}", util::encode_component(group));
            let _ = session
                .controller()
                .json("PUT", &path, Some(&json!({ "name": node })));
        }
    }

    // Mode and routing.

    pub fn app_settings(&self) -> AppSettings {
        self.store.read(|s| s.app.clone())
    }

    pub fn set_app_settings(&self, settings: AppSettings) -> Result<()> {
        let settings = settings.validated()?;
        self.engine
            .monitor
            .set_only_proxy(settings.only_proxy_traffic);
        self.store.update(|s| {
            s.app = settings;
            Ok(())
        })
    }

    pub fn engine_options(&self) -> EngineOptions {
        self.store.read(|s| s.options.clone())
    }

    /// A new mixed port moves the system proxy, so desktops restart for it; everything else hot-reloads.
    pub fn set_engine_options(&self, options: EngineOptions) -> Result<()> {
        self.engine.monitor.set_log_level(options.log_level);
        let proxy_changed = self.store.update(|s| {
            let changed = s.options.mixed_port != options.mixed_port
                || s.options.bypass_domains != options.bypass_domains
                || s.options.auto_set_system_dns != options.auto_set_system_dns;
            s.options = options;
            Ok(changed)
        })?;
        if proxy_changed && self.platform != Platform::Android {
            self.restart()
        } else {
            self.reload()
        }
    }

    pub fn set_mode(&self, mode: Mode) -> Result<()> {
        self.store.update(|s| {
            s.mode = mode;
            Ok(())
        })?;
        if let Some(session) = self.engine.session() {
            session.controller().json(
                "PATCH",
                "/configs",
                Some(&json!({ "mode": mode.as_str() })),
            )?;
            self.refresh_current_node(&session, mode);
        }
        self.emit(&[Change::Status, Change::Groups]);
        Ok(())
    }

    pub fn set_route_mode(&self, route_mode: RouteMode) -> Result<()> {
        let changed = self.store.update(|s| {
            let changed = s.route_mode != route_mode;
            s.route_mode = route_mode;
            Ok(changed)
        })?;
        if changed && self.platform != Platform::Android {
            self.restart()?;
        }
        self.emit(&[Change::Status]);
        Ok(())
    }

    // Profiles.

    pub fn profiles(&self) -> Vec<Profile> {
        self.store.read(|s| {
            s.profiles
                .iter()
                .map(|record| Profile {
                    id: record.id.clone(),
                    name: record.name.clone(),
                    kind: record.kind,
                    url: record.url.clone(),
                    updated_at: record.updated_at,
                    usage: record.usage.clone(),
                    selected: s.current_profile.as_deref() == Some(record.id.as_str()),
                    auto_update: !record.manual_update,
                    update_hours: record.update_hours.unwrap_or(DEFAULT_UPDATE_HOURS),
                })
                .collect()
        })
    }

    fn profile(&self, id: &str) -> Result<Profile> {
        self.profiles()
            .into_iter()
            .find(|profile| profile.id == id)
            .ok_or_else(|| CoreError::Invalid("no such profile".into()))
    }

    fn fetch(&self, url: &str) -> Result<profiles::Fetched> {
        let proxy = self.proxy_url();
        let (agent, verify) = self.store.read(|s| {
            (
                s.options.user_agent.trim().to_owned(),
                s.app.check_certificate,
            )
        });
        let agent = (!agent.is_empty()).then_some(agent.as_str());
        match profiles::fetch(url, proxy.as_deref(), &self.app_version, agent, verify) {
            Err(CoreError::Network(_)) if proxy.is_some() => {
                profiles::fetch(url, None, &self.app_version, agent, verify)
            }
            other => other,
        }
    }

    fn store_content(&self, id: &str, content: &Content) -> Result<()> {
        let (keep, drop, text) = match content {
            Content::Yaml(text) => (self.paths.yaml(id), self.paths.links(id), text),
            Content::Links(text) => (self.paths.links(id), self.paths.yaml(id), text),
        };
        util::write_atomic(&keep, text.as_bytes())?;
        let _ = fs::remove_file(drop);
        Ok(())
    }

    fn patches_system_dns(&self, settings: &Settings) -> bool {
        self.platform == Platform::MacOs
            && settings.route_mode == RouteMode::Tun
            && settings.options.auto_set_system_dns
    }

    fn reload_if_current(&self, id: &str) -> Result<()> {
        if self
            .store
            .read(|s| s.current_profile.as_deref() == Some(id))
        {
            self.reload()?;
        }
        Ok(())
    }

    pub fn add_subscription(&self, url: String) -> Result<Profile> {
        let url = url.trim().to_owned();
        let fetched = self.fetch(&url)?;
        let id = util::random_id();
        self.store_content(&id, &fetched.content)?;
        self.store.update(|s| {
            s.profiles.push(ProfileRecord {
                url: Some(url.clone()),
                usage: fetched.usage.clone(),
                update_hours: fetched.update_hours,
                ..ProfileRecord::new(
                    id.clone(),
                    fetched.name.clone().unwrap_or_else(|| url.clone()),
                    ProfileKind::Subscription,
                )
            });
            if s.current().is_none() {
                s.current_profile = Some(id.clone());
            }
            Ok(())
        })?;
        logfile::info(format!("subscription {id} added"));
        let reloaded = self.reload_if_current(&id);
        self.emit(&[Change::Profiles, Change::Status]);
        reloaded?;
        self.profile(&id)
    }

    /// Never reloads the engine, so `launch` can call it with the engine lock held.
    fn download(&self, id: &str) -> Result<()> {
        let url = self
            .store
            .read(|s| s.profile(id).and_then(|profile| profile.url.clone()))
            .ok_or_else(|| CoreError::Invalid("only subscriptions can be updated".into()))?;
        let fetched = self.fetch(&url).inspect_err(|error| {
            logfile::warn(format!("subscription {id} update failed: {error}"));
        })?;
        self.store_content(id, &fetched.content)?;
        self.store.update(|s| {
            let profile = s
                .profile_mut(id)
                .ok_or_else(|| CoreError::Invalid("no such profile".into()))?;
            profile.updated_at = Some(util::now());
            profile.usage = fetched.usage.clone().or(profile.usage.take());
            profile.update_hours = fetched.update_hours.or(profile.update_hours);
            Ok(())
        })?;
        logfile::info(format!("subscription {id} updated"));
        Ok(())
    }

    pub fn update_profile(&self, id: String) -> Result<Profile> {
        self.download(&id)?;
        let reloaded = self.reload_if_current(&id);
        self.emit(&[Change::Profiles]);
        reloaded?;
        self.profile(&id)
    }

    pub fn remove_profile(&self, id: String) -> Result<()> {
        let was_current = self.store.update(|s| {
            let before = s.profiles.len();
            s.profiles.retain(|profile| profile.id != id);
            if s.profiles.len() == before {
                return Err(CoreError::Invalid("no such profile".into()));
            }
            let was_current = s.current_profile.as_deref() == Some(id.as_str());
            if was_current {
                s.current_profile = s.profiles.first().map(|profile| profile.id.clone());
            }
            Ok(was_current)
        })?;
        let _ = fs::remove_file(self.paths.yaml(&id));
        let _ = fs::remove_file(self.paths.links(&id));
        let reloaded = if was_current { self.reload() } else { Ok(()) };
        self.emit(&[Change::Profiles, Change::Status]);
        reloaded
    }

    pub fn select_profile(&self, id: String) -> Result<()> {
        let changed = self.store.update(|s| {
            if s.profile(&id).is_none() {
                return Err(CoreError::Invalid("no such profile".into()));
            }
            let changed = s.current_profile.as_deref() != Some(id.as_str());
            s.current_profile = Some(id.clone());
            Ok(changed)
        })?;
        let reloaded = if changed { self.reload() } else { Ok(()) };
        self.emit(&[Change::Profiles, Change::Status]);
        reloaded
    }

    /// A config or a list of share links read from a file the user picked.
    pub fn import_file(&self, name: String, content: String) -> Result<Profile> {
        let content = profiles::classify(&content)?;
        let name = Path::new(name.trim())
            .file_stem()
            .and_then(|stem| stem.to_str())
            .filter(|stem| !stem.is_empty())
            .unwrap_or("Imported")
            .to_owned();
        let id = util::random_id();
        self.store_content(&id, &content)?;
        self.store.update(|s| {
            s.profiles
                .push(ProfileRecord::new(id.clone(), name, ProfileKind::File));
            if s.current().is_none() {
                s.current_profile = Some(id.clone());
            }
            Ok(())
        })?;
        logfile::info(format!("profile {id} imported from a file"));
        let reloaded = self.reload_if_current(&id);
        self.emit(&[Change::Profiles, Change::Status]);
        reloaded?;
        self.profile(&id)
    }

    pub fn edit_profile(&self, id: String, edit: ProfileEdit) -> Result<Profile> {
        let name = edit.name.trim().to_owned();
        if name.is_empty() {
            return Err(CoreError::Invalid("a profile needs a name".into()));
        }
        let url = edit.url.map(|url| url.trim().to_owned());
        self.store.update(|s| {
            let profile = s
                .profile_mut(&id)
                .ok_or_else(|| CoreError::Invalid("no such profile".into()))?;
            if profile.kind == ProfileKind::Subscription {
                let url = url
                    .filter(|url| url.starts_with("http://") || url.starts_with("https://"))
                    .ok_or_else(|| CoreError::Invalid("not an http(s) link".into()))?;
                profile.url = Some(url);
            }
            profile.name = name;
            profile.manual_update = !edit.auto_update;
            profile.update_hours = Some(edit.update_hours.max(1));
            Ok(())
        })?;
        self.emit(&[Change::Profiles]);
        self.profile(&id)
    }

    /// The profile's text as downloaded or imported, for export.
    pub fn profile_content(&self, id: String) -> Result<String> {
        match self.stored_content(&id) {
            Some(Content::Yaml(text) | Content::Links(text)) => Ok(text),
            None => Err(CoreError::Invalid("no such profile".into())),
        }
    }

    /// FlClash's profile editor. While the profile runs mihomo checks the text too, and an edit it rejects is undone.
    pub fn save_profile_content(&self, id: String, content: String) -> Result<Profile> {
        let content = profiles::classify(&content)?;
        let kind = self
            .store
            .read(|s| s.profile(&id).map(|profile| profile.kind))
            .ok_or_else(|| CoreError::Invalid("no such profile".into()))?;
        if kind == ProfileKind::Links && !matches!(content, Content::Links(_)) {
            return Err(CoreError::Invalid(
                "the share-link profile holds share links only".into(),
            ));
        }
        let previous = self
            .stored_content(&id)
            .ok_or_else(|| CoreError::Invalid("no such profile".into()))?;
        self.store_content(&id, &content)?;
        if let Err(error) = self.reload_if_current(&id) {
            self.store_content(&id, &previous)?;
            let _ = self.reload_if_current(&id);
            return Err(error);
        }
        logfile::info(format!("profile {id} edited"));
        self.emit(&[Change::Profiles, Change::Status]);
        self.profile(&id)
    }

    // Overrides.

    pub fn profile_override(&self, id: String) -> Result<ProfileOverride> {
        self.store
            .read(|s| s.profile(&id).map(|profile| profile.overrides.clone()))
            .ok_or_else(|| CoreError::Invalid("no such profile".into()))
    }

    /// Kept only if the profile still renders, and while it runs only if mihomo accepts it.
    pub fn set_profile_override(&self, id: String, overrides: ProfileOverride) -> Result<()> {
        let lines = |rules: Vec<String>| {
            rules
                .into_iter()
                .map(|rule| rule.trim().to_owned())
                .filter(|rule| !rule.is_empty())
                .collect::<Vec<_>>()
        };
        let overrides = ProfileOverride {
            added_rules: lines(overrides.added_rules),
            disabled_global_rules: lines(overrides.disabled_global_rules),
            custom_rules: lines(overrides.custom_rules),
            match_target: overrides
                .match_target
                .map(|target| target.trim().to_owned())
                .filter(|target| !target.is_empty()),
            ..overrides
        };
        config::custom_groups(&overrides.custom_groups)?;
        let previous = self.store.update(|s| {
            if let Some(script) = &overrides.script_id
                && s.script(script).is_none()
            {
                return Err(CoreError::Invalid("no such script".into()));
            }
            let profile = s
                .profile_mut(&id)
                .ok_or_else(|| CoreError::Invalid("no such profile".into()))?;
            Ok(std::mem::replace(&mut profile.overrides, overrides))
        })?;
        if let Err(error) = self.check_profile(&id) {
            self.store.update(|s| {
                if let Some(profile) = s.profile_mut(&id) {
                    profile.overrides = previous;
                }
                Ok(())
            })?;
            let _ = self.reload_if_current(&id);
            return Err(error);
        }
        logfile::info(format!("profile {id} override saved"));
        self.emit(&[Change::Profiles]);
        Ok(())
    }

    /// Renders the profile as it would run, then reloads it if it is the current one.
    fn check_profile(&self, id: &str) -> Result<()> {
        self.preview_config(id.to_owned())?;
        self.reload_if_current(id)
    }

    /// The profile's own proxy groups (as YAML) and rules, where a custom override starts.
    pub fn profile_groups_and_rules(&self, id: String) -> Result<(String, Vec<String>)> {
        let settings = self.store.get();
        let profile = settings
            .profile(&id)
            .ok_or_else(|| CoreError::Invalid("no such profile".into()))?;
        let (base, _) = self.config_base(profile, &settings)?;
        config::custom_parts(&base)
    }

    pub fn scripts(&self) -> Vec<Script> {
        self.store.read(|s| s.scripts.clone())
    }

    /// A script without an id is new. An edit to a script the current profile uses is undone if the profile then fails.
    pub fn save_script(&self, script: Script) -> Result<Script> {
        let name = script.name.trim().to_owned();
        if name.is_empty() {
            return Err(CoreError::Invalid("the script needs a name".into()));
        }
        script::check(&script.content)
            .map_err(|error| CoreError::Invalid(format!("override script: {error}")))?;
        let script = Script {
            id: if script.id.is_empty() {
                util::random_id()
            } else {
                script.id
            },
            name,
            content: script.content,
        };
        let previous = self.store.update(|s| {
            let index = s.scripts.iter().position(|saved| saved.id == script.id);
            Ok(match index {
                Some(index) => Some(std::mem::replace(&mut s.scripts[index], script.clone())),
                None => {
                    s.scripts.push(script.clone());
                    None
                }
            })
        })?;
        if let Some(current) = self.current_using(&script.id)
            && let Err(error) = self.check_profile(&current)
        {
            self.store.update(|s| {
                match previous {
                    Some(previous) => {
                        if let Some(saved) =
                            s.scripts.iter_mut().find(|saved| saved.id == previous.id)
                        {
                            *saved = previous;
                        }
                    }
                    None => s.scripts.retain(|saved| saved.id != script.id),
                }
                Ok(())
            })?;
            let _ = self.reload_if_current(&current);
            return Err(error);
        }
        logfile::info(format!("script {} saved", script.id));
        self.emit(&[Change::Profiles]);
        Ok(script)
    }

    /// Profiles that ran the script keep script mode without one, which leaves their config as it is.
    pub fn remove_script(&self, id: String) -> Result<()> {
        let current = self.current_using(&id);
        self.store.update(|s| {
            s.scripts.retain(|script| script.id != id);
            for profile in &mut s.profiles {
                if profile.overrides.script_id.as_deref() == Some(id.as_str()) {
                    profile.overrides.script_id = None;
                }
            }
            Ok(())
        })?;
        logfile::info(format!("script {id} removed"));
        let reloaded = current.map_or(Ok(()), |current| self.reload_if_current(&current));
        self.emit(&[Change::Profiles, Change::Status]);
        reloaded
    }

    fn current_using(&self, script: &str) -> Option<String> {
        self.store.read(|s| {
            s.current()
                .filter(|profile| {
                    profile.overrides.mode == OverrideMode::Script
                        && profile.overrides.script_id.as_deref() == Some(script)
                })
                .map(|profile| profile.id.clone())
        })
    }

    fn stored_content(&self, id: &str) -> Option<Content> {
        fs::read_to_string(self.paths.yaml(id))
            .map(Content::Yaml)
            .or_else(|_| fs::read_to_string(self.paths.links(id)).map(Content::Links))
            .ok()
    }

    /// The config mihomo would run for this profile, with the controller secret and po0's direct login hidden.
    pub fn preview_config(&self, id: String) -> Result<String> {
        let settings = self.store.get();
        let profile = settings
            .profile(&id)
            .ok_or_else(|| CoreError::Invalid("no such profile".into()))?;
        let (base, _) = self.overridden_base(profile, &settings)?;
        let session = self.engine.session();
        let hidden = "<hidden>";
        let direct = config::DirectListener {
            port: session
                .as_ref()
                .map_or(0, |session| session.runtime.direct.port),
            username: hidden.into(),
            password: hidden.into(),
        };
        let controller = session.as_ref().map_or_else(
            || (engine::Endpoint::Unix(PathBuf::from(hidden))).config_entry(),
            |session| session.runtime.controller.endpoint.config_entry(),
        );
        config::render(
            &base,
            &config::Params {
                platform: self.platform,
                mode: settings.mode,
                route_mode: settings.route_mode,
                tun_fd: session.as_ref().and_then(|session| session.runtime.tun_fd),
                mixed_port: session
                    .as_ref()
                    .map_or(settings.options.mixed_port, |session| {
                        session.runtime.mixed_port
                    }),
                controller,
                secret: hidden,
                direct: &direct,
                options: &settings.options,
                overrides: &profile.overrides,
            },
        )
    }

    pub fn reorder_profiles(&self, ids: Vec<String>) -> Result<()> {
        self.store.update(|s| {
            let mut ordered = Vec::with_capacity(s.profiles.len());
            for id in &ids {
                if let Some(index) = s.profile_index(id) {
                    ordered.push(s.profiles.remove(index));
                }
            }
            ordered.append(&mut s.profiles);
            s.profiles = ordered;
            Ok(())
        })?;
        self.emit(&[Change::Profiles]);
        Ok(())
    }

    pub fn import_links(&self, text: String) -> Result<ImportResult> {
        let links = profiles::extract_links(&text);
        if links.is_empty() {
            return Err(CoreError::Invalid("no share links found".into()));
        }
        let existing = self.store.read(|s| {
            s.profiles
                .iter()
                .find(|profile| profile.kind == ProfileKind::Links)
                .map(|profile| profile.id.clone())
        });
        let id = existing.unwrap_or_else(util::random_id);
        let mut merged =
            profiles::extract_links(&fs::read_to_string(self.paths.links(&id)).unwrap_or_default());
        let before = merged.len();
        for link in links {
            if !merged.contains(&link) {
                merged.push(link);
            }
        }
        let added = (merged.len() - before) as u32;
        self.store_content(&id, &Content::Links(merged.join("\n")))?;
        self.store.update(|s| {
            match s.profile_mut(&id) {
                Some(profile) => profile.updated_at = Some(util::now()),
                None => s.profiles.push(ProfileRecord::new(
                    id.clone(),
                    LINKS_PROFILE_NAME.into(),
                    ProfileKind::Links,
                )),
            }
            if s.current().is_none() {
                s.current_profile = Some(id.clone());
            }
            Ok(())
        })?;
        let reloaded = if added > 0 {
            self.reload_if_current(&id)
        } else {
            Ok(())
        };
        self.emit(&[Change::Profiles, Change::Status]);
        reloaded?;
        Ok(ImportResult {
            profile: self.profile(&id)?,
            added,
        })
    }

    // Proxy groups.

    fn proxies(&self, session: &Session) -> Result<serde_json::Map<String, Value>> {
        let value = session.controller().json("GET", "/proxies", None)?;
        match value.get("proxies") {
            Some(Value::Object(map)) => Ok(map.clone()),
            _ => Err(engine_error("unexpected /proxies answer")),
        }
    }

    fn group_names(proxies: &serde_json::Map<String, Value>, mode: Mode) -> Vec<String> {
        match mode {
            Mode::Direct => Vec::new(),
            Mode::Global => vec!["GLOBAL".to_owned()],
            Mode::Rule => proxies
                .get("GLOBAL")
                .and_then(|global| global.get("all"))
                .and_then(Value::as_array)
                .into_iter()
                .flatten()
                .filter_map(Value::as_str)
                .filter(|name| {
                    *name != "GLOBAL"
                        && proxies
                            .get(*name)
                            .and_then(|proxy| proxy.get("type"))
                            .and_then(Value::as_str)
                            .is_some_and(|kind| GROUP_TYPES.contains(&kind))
                })
                .map(str::to_owned)
                .collect(),
        }
    }

    fn build_group(proxies: &serde_json::Map<String, Value>, name: &str) -> Option<ProxyGroup> {
        let group = proxies.get(name)?;
        let kind = group
            .get("type")
            .and_then(Value::as_str)
            .unwrap_or_default()
            .to_owned();
        let nodes = group
            .get("all")
            .and_then(Value::as_array)
            .into_iter()
            .flatten()
            .filter_map(Value::as_str)
            .map(|node| {
                let proxy = proxies.get(node);
                Node {
                    name: node.to_owned(),
                    kind: proxy
                        .and_then(|proxy| proxy.get("type"))
                        .and_then(Value::as_str)
                        .unwrap_or_default()
                        .to_owned(),
                    delay: proxy
                        .and_then(|proxy| proxy.get("history"))
                        .and_then(Value::as_array)
                        .and_then(|history| history.last())
                        .and_then(|last| last.get("delay"))
                        .and_then(Value::as_u64)
                        .map(|delay| delay as u32),
                }
            })
            .collect();
        Some(ProxyGroup {
            name: name.to_owned(),
            selectable: kind == "Selector",
            now: group.get("now").and_then(Value::as_str).map(str::to_owned),
            icon: group
                .get("icon")
                .and_then(Value::as_str)
                .map(str::trim)
                .filter(|icon| !icon.is_empty())
                .map(str::to_owned),
            kind,
            nodes,
        })
    }

    fn resolve_node(proxies: &serde_json::Map<String, Value>, group: &str) -> Option<String> {
        let mut current = group.to_owned();
        for _ in 0..8 {
            let next = proxies.get(&current)?.get("now").and_then(Value::as_str)?;
            current = next.to_owned();
            if proxies
                .get(&current)
                .and_then(|proxy| proxy.get("now"))
                .is_none()
            {
                return Some(current);
            }
        }
        Some(current)
    }

    fn refresh_current_node(&self, session: &Session, mode: Mode) {
        let node = self.proxies(session).ok().and_then(|proxies| {
            let first = Self::group_names(&proxies, mode).into_iter().next()?;
            Self::resolve_node(&proxies, &first)
        });
        session.set_current_node(if mode == Mode::Direct {
            Some("DIRECT".into())
        } else {
            node
        });
    }

    pub fn groups(&self) -> Result<Vec<ProxyGroup>> {
        let Some(session) = self.engine.session() else {
            return Ok(Vec::new());
        };
        let proxies = self.proxies(&session)?;
        let mode = self.store.read(|s| s.mode);
        Ok(Self::group_names(&proxies, mode)
            .iter()
            .filter_map(|name| Self::build_group(&proxies, name))
            .collect())
    }

    pub fn select_node(&self, group: String, node: String) -> Result<()> {
        if let Some(session) = self.engine.session() {
            let path = format!("/proxies/{}", util::encode_component(&group));
            session
                .controller()
                .json("PUT", &path, Some(&json!({ "name": node })))?;
            if self.store.read(|s| s.app.close_connections_on_switch) {
                let _ = session.controller().json("DELETE", "/connections", None);
            }
            self.refresh_current_node(&session, self.store.read(|s| s.mode));
        }
        self.store.update(|s| {
            let id = s.current_profile.clone();
            if let Some(profile) = id.and_then(|id| s.profile_mut(&id)) {
                profile.selections.insert(group.clone(), node.clone());
            }
            Ok(())
        })?;
        self.emit(&[Change::Status, Change::Groups]);
        Ok(())
    }

    pub fn test_delay(&self, group: String) -> Result<ProxyGroup> {
        let session = self.live_session()?;
        let path = format!(
            "/group/{}/delay?{}",
            util::encode_component(&group),
            self.delay_query()
        );
        let delays = session
            .controller()
            .json("GET", &path, None)
            .unwrap_or(Value::Null);
        let proxies = self.proxies(&session)?;
        let mut result = Self::build_group(&proxies, &group)
            .ok_or_else(|| CoreError::Invalid("no such group".into()))?;
        for node in &mut result.nodes {
            node.delay = Some(delays.get(&node.name).and_then(Value::as_u64).unwrap_or(0) as u32);
        }
        self.refresh_current_node(&session, self.store.read(|s| s.mode));
        self.emit(&[Change::Status, Change::Groups]);
        Ok(result)
    }

    pub fn test_node_delay(&self, node: String) -> Result<u32> {
        let session = self.live_session()?;
        let providers = session.controller().json(
            "GET",
            &resources::provider_path(ProviderKind::Proxy, None),
            None,
        )?;
        let provider = resources::provider_of(&providers, &node)
            .ok_or_else(|| CoreError::Invalid("no such node".into()))?;
        let path = format!(
            "{}/{}/healthcheck?{}",
            resources::provider_path(ProviderKind::Proxy, Some(&provider)),
            util::encode_component(&node),
            self.delay_query()
        );
        let delay = session
            .controller()
            .json("GET", &path, None)
            .ok()
            .and_then(|value| value.get("delay")?.as_u64())
            .unwrap_or(0);
        self.emit(&[Change::Groups]);
        Ok(delay as u32)
    }

    fn delay_query(&self) -> String {
        let url = self.store.read(|s| s.options.delay_url().to_owned());
        format!(
            "url={}&timeout={DELAY_TIMEOUT_MS}",
            util::encode_component(&url)
        )
    }

    pub fn exit_ip(&self) -> Result<ExitIp> {
        let proxy = self
            .proxy_url()
            .map(|url| ureq::Proxy::new(&url))
            .transpose()
            .map_err(|error| CoreError::Network(error.to_string()))?;
        let agent = ureq::Agent::new_with_config(
            ureq::Agent::config_builder()
                .proxy(proxy)
                .timeout_global(Some(Duration::from_secs(8)))
                .build(),
        );
        let body = agent
            .get(EXIT_IP_URL)
            .call()
            .and_then(|mut response| response.body_mut().read_to_string())
            .map_err(|error| CoreError::Network(error.to_string()))?;
        let field = |name: &str| {
            body.lines()
                .find_map(|line| line.strip_prefix(name)?.strip_prefix('='))
                .map(str::to_owned)
        };
        let ip =
            field("ip").ok_or_else(|| CoreError::Network("no address in the answer".into()))?;
        Ok(ExitIp {
            ip,
            country: field("loc").filter(|loc| loc != "XX"),
        })
    }

    // Developer mode.

    pub fn crash_engine(&self) -> Result<()> {
        if self.live_session()?.runner.kill() {
            Ok(())
        } else {
            Err(CoreError::Invalid(
                "the engine runs inside the app on this platform".into(),
            ))
        }
    }

    pub fn add_test_logs(&self) {
        self.engine.monitor.add_test_logs();
    }

    pub fn prune_cache(&self) -> Result<u32> {
        let ids: Vec<String> = self.store.read(|s| {
            s.profiles
                .iter()
                .map(|profile| profile.id.clone())
                .collect()
        });
        let mut removed = 0;
        for entry in fs::read_dir(&self.paths.profiles)? {
            let path = entry?.path();
            let id = path.file_stem().and_then(|stem| stem.to_str());
            if path.is_file() && !id.is_some_and(|id| ids.iter().any(|known| known == id)) {
                fs::remove_file(&path)?;
                removed += 1;
            }
        }
        Ok(removed)
    }

    pub fn clear_data(&self) -> Result<()> {
        self.stop();
        fs::write(self.paths.profiles.with_file_name(CLEAR_MARKER), b"")?;
        Ok(())
    }

    /// Who announces the exit address and whether it looks like a data centre, asked through the engine's proxy.
    pub fn ip_quality(&self, ip: &str, refresh: bool) -> Result<IpQuality> {
        self.ip_qualities
            .lookup(ip, self.proxy_url().as_deref(), refresh)
    }

    /// The newest native release above this build, through the engine's proxy while it runs and then directly.
    pub fn check_update(&self) -> Result<Option<Release>> {
        let check = |proxy: Option<&str>| update::check(&self.app_version, proxy);
        match self.proxy_url() {
            Some(proxy) => match check(Some(&proxy)) {
                Err(CoreError::Network(_)) => check(None),
                other => other,
            },
            None => check(None),
        }
    }

    // Activity: what the engine is doing now and has done this run.

    fn live_session(&self) -> Result<Arc<Session>> {
        self.engine
            .session()
            .ok_or_else(|| CoreError::Engine("not connected".into()))
    }

    pub fn traffic_history(&self) -> Vec<Traffic> {
        self.engine
            .session()
            .map(|_| self.engine.monitor.traffic_history())
            .unwrap_or_default()
    }

    pub fn memory(&self) -> u64 {
        self.engine
            .session()
            .map_or(0, |_| self.engine.monitor.memory())
    }

    pub fn connections(&self) -> Connections {
        self.engine
            .session()
            .map(|_| self.engine.monitor.connections())
            .unwrap_or_default()
    }

    pub fn close_connection(&self, id: String) -> Result<()> {
        self.close_connections(&format!("/connections/{}", util::encode_component(&id)))
    }

    pub fn close_all_connections(&self) -> Result<()> {
        self.close_connections("/connections")
    }

    fn close_connections(&self, path: &str) -> Result<()> {
        let session = self.live_session()?;
        session.controller().json("DELETE", path, None)?;
        session.poll(&self.engine.monitor)
    }

    pub fn requests(&self) -> Vec<Connection> {
        self.engine.monitor.requests()
    }

    pub fn clear_requests(&self) {
        self.engine.monitor.clear_requests();
    }

    pub fn logs(&self) -> Vec<LogEntry> {
        self.engine.monitor.logs()
    }

    pub fn clear_logs(&self) {
        self.engine.monitor.clear_logs();
    }

    pub fn flush_dns_cache(&self) -> Result<()> {
        let session = self.live_session()?;
        session
            .controller()
            .json("POST", "/cache/fakeip/flush", None)?;
        session
            .controller()
            .json("POST", "/cache/dns/flush", None)?;
        Ok(())
    }

    // Providers, rules and geo databases.

    pub fn providers(&self) -> Result<Vec<Provider>> {
        let Some(session) = self.engine.session() else {
            return Ok(Vec::new());
        };
        let mut providers = Vec::new();
        for kind in [ProviderKind::Proxy, ProviderKind::Rule] {
            let value =
                session
                    .controller()
                    .json("GET", &resources::provider_path(kind, None), None)?;
            providers.extend(resources::parse_providers(kind, &value));
        }
        Ok(providers)
    }

    pub fn update_provider(&self, kind: ProviderKind, name: String) -> Result<()> {
        let session = self.live_session()?;
        session.controller().json_within(
            "PUT",
            &resources::provider_path(kind, Some(&name)),
            None,
            DOWNLOAD_TIMEOUT,
        )?;
        if kind == ProviderKind::Proxy {
            self.emit(&[Change::Groups]);
        }
        Ok(())
    }

    pub fn rules(&self) -> Result<Vec<Rule>> {
        let Some(session) = self.engine.session() else {
            return Ok(Vec::new());
        };
        Ok(resources::parse_rules(
            &session.controller().json("GET", "/rules", None)?,
        ))
    }

    fn mihomo_home(&self) -> PathBuf {
        self.engine.session().map_or_else(
            || self.paths.home_for(lock(&self.mihomo_path).as_deref()),
            |session| session.runtime.home.clone(),
        )
    }

    pub fn intranet_ip(&self) -> Option<IntranetIp> {
        network::intranet_ip()
    }

    pub fn geo_files(&self) -> Vec<GeoFile> {
        resources::geo_files(&self.mihomo_home())
    }

    /// A running engine updates the databases it uses and reloads them; otherwise all four are downloaded for the
    /// next start.
    pub fn update_geo(&self) -> Result<()> {
        if let Some(session) = self.engine.session() {
            session
                .controller()
                .json_within("POST", "/configs/geo", None, DOWNLOAD_TIMEOUT)?;
            return Ok(());
        }
        let home = self.mihomo_home();
        let urls = self.store.read(|s| s.options.geox_url.clone());
        for (name, url) in resources::geo_targets(&home, &urls) {
            let bytes = profiles::download(&url, None)?;
            util::write_atomic(&home.join(&name), &bytes)?;
            logfile::info(format!("downloaded {name}"));
        }
        Ok(())
    }

    // Whitelist.

    pub fn whitelist(&self) -> WhitelistState {
        self.whitelist.state()
    }

    fn update_whitelist<T>(
        &self,
        f: impl FnOnce(&mut settings::WhitelistSettings) -> Result<T>,
    ) -> Result<T> {
        let value = self.store.update(|s| f(&mut s.whitelist))?;
        self.whitelist
            .update(self.store.read(|s| s.whitelist.clone()));
        self.emit(&[Change::Whitelist]);
        Ok(value)
    }

    pub fn set_whitelist_enabled(&self, enabled: bool) -> Result<()> {
        self.update_whitelist(|w| {
            w.enabled = enabled;
            Ok(())
        })
    }

    pub fn add_whitelist_entries(&self, text: String, name: String) -> Result<Vec<WhitelistEntry>> {
        let secrets = whitelist::parse_secrets(&text);
        if secrets.is_empty() {
            return Err(CoreError::Invalid("no po0 token or ggy link found".into()));
        }
        let ids = self.update_whitelist(|w| {
            let mut ids = Vec::new();
            for secret in secrets {
                if w.entries.iter().any(|entry| entry.value == secret.value) {
                    continue;
                }
                let id = util::random_id();
                w.entries.push(EntryRecord {
                    id: id.clone(),
                    name: name.trim().to_owned(),
                    value: secret.value,
                });
                ids.push(id);
            }
            Ok(ids)
        })?;
        Ok(self
            .whitelist
            .state()
            .entries
            .into_iter()
            .filter(|entry| ids.contains(&entry.id))
            .collect())
    }

    pub fn remove_whitelist_entry(&self, id: String) -> Result<()> {
        self.update_whitelist(|w| {
            w.entries.retain(|entry| entry.id != id);
            Ok(())
        })
    }

    pub fn whitelist_now(&self) {
        self.whitelist.now();
    }

    pub fn network_changed(&self) {
        logfile::info("network changed");
        if let Some(session) = self.engine.session()
            && self.patches_system_dns(&self.store.get())
        {
            let mut saved = lock(&session.system_dns);
            *saved = sysdns::refresh(saved.take());
            drop(saved);
            engine::save_record(&self.paths.run, &session);
        }
        self.whitelist.network_changed();
        self.emit(&[Change::Status]);
    }

    pub fn set_active(&self, active: bool) {
        logfile::info(if active { "active" } else { "inactive" });
        self.engine.monitor.set_active(active);
        self.whitelist.set_active(active);
    }

    // Backup and restore.

    pub fn backup(&self) -> Result<Vec<u8>> {
        let settings = self.store.get();
        let files = settings
            .profiles
            .iter()
            .filter_map(|profile| Some((profile.id.clone(), self.stored_content(&profile.id)?)))
            .collect();
        Backup { settings, files }.to_zip(&self.app_version)
    }

    /// Merges or replaces the profiles as the restore strategy setting says, and the engine, if it runs,
    /// moves onto the result.
    pub fn restore(&self, data: Vec<u8>, scope: RestoreScope) -> Result<()> {
        let backup = Backup::from_zip(&data)?;
        let count = backup.files.len();
        for (id, content) in &backup.files {
            self.store_content(id, content)?;
        }
        let (before, dropped) = self.store.update(|s| {
            let before = (s.route_mode, s.options.mixed_port);
            let (next, dropped) = backup.restore_into(s, scope, s.app.restore_strategy);
            *s = next;
            Ok((before, dropped))
        })?;
        for id in &dropped {
            let _ = fs::remove_file(self.paths.yaml(id));
            let _ = fs::remove_file(self.paths.links(id));
        }
        logfile::info(format!("restored {count} profiles from a backup"));
        let after = self.store.get();
        let moved = (after.route_mode, after.options.mixed_port) != before;
        self.engine.monitor.set_log_level(after.options.log_level);
        self.whitelist.update(after.whitelist);
        let applied = if moved && self.platform != Platform::Android {
            self.restart()
        } else {
            self.reload()
        };
        self.emit(&[
            Change::Profiles,
            Change::Status,
            Change::Groups,
            Change::Whitelist,
        ]);
        applied
    }

    pub fn check_webdav(&self, dav: WebDav) -> Result<()> {
        self.webdav(&dav, webdav::Client::check)
    }

    pub fn backup_to_webdav(&self) -> Result<()> {
        let dav = self.saved_webdav()?;
        let data = self.backup()?;
        self.webdav(&dav, |client| client.upload(&dav.file_name, &data))?;
        logfile::info("backup uploaded to WebDAV");
        Ok(())
    }

    pub fn restore_from_webdav(&self, scope: RestoreScope) -> Result<()> {
        let dav = self.saved_webdav()?;
        let data = self.webdav(&dav, |client| client.download(&dav.file_name))?;
        self.restore(data, scope)
    }

    fn saved_webdav(&self) -> Result<WebDav> {
        self.store
            .read(|s| s.app.webdav.clone())
            .ok_or_else(|| CoreError::Invalid("set up WebDAV first".into()))
    }

    /// Through the engine's proxy while it runs, then directly if that fails, as subscriptions are fetched.
    fn webdav<T>(&self, dav: &WebDav, call: impl Fn(&webdav::Client) -> Result<T>) -> Result<T> {
        let verify = self.store.read(|s| s.app.check_certificate);
        let direct = || call(&webdav::Client::new(dav, None, verify)?);
        match self.proxy_url() {
            Some(proxy) => match call(&webdav::Client::new(dav, Some(&proxy), verify)?) {
                Err(CoreError::Network(_)) => direct(),
                other => other,
            },
            None => direct(),
        }
    }

    // Diagnostics and shutdown.

    pub fn export_diagnostics(&self, path: PathBuf) -> Result<()> {
        let settings = self.store.get();
        let mut text = format!(
            "po0-clash diagnostics\napp {} / core {} / {:?} / {} {}\ngenerated {}\nengine {:?}, mode {:?}, route {}\n",
            self.app_version,
            env!("CARGO_PKG_VERSION"),
            self.platform,
            std::env::consts::OS,
            std::env::consts::ARCH,
            util::now(),
            self.engine.state(),
            settings.mode,
            if self.platform == Platform::Android {
                "VPN".to_owned()
            } else {
                format!("{:?}", settings.route_mode)
            },
        );
        text.push_str("\nprofiles:\n");
        for profile in &settings.profiles {
            let host = profile
                .url
                .as_deref()
                .and_then(|url| url.split("://").nth(1))
                .and_then(|rest| rest.split(['/', '?']).next())
                .unwrap_or("-");
            let current = if settings.current_profile.as_deref() == Some(profile.id.as_str()) {
                "*"
            } else {
                " "
            };
            text.push_str(&format!(
                "{current} {} {:?} {host} updated {:?}\n",
                profile.name, profile.kind, profile.updated_at
            ));
        }
        let whitelist = self.whitelist.state();
        text.push_str(&format!("\nwhitelist enabled {}\n", whitelist.enabled));
        for entry in &whitelist.entries {
            let result = entry.result.as_ref();
            text.push_str(&format!(
                "  {:?} {} {:?} {} {}\n",
                entry.kind,
                entry.label,
                result.map(|r| r.outcome),
                result.and_then(|r| r.ip.as_deref()).unwrap_or("-"),
                result.and_then(|r| r.message.as_deref()).unwrap_or(""),
            ));
        }
        text.push_str("\n== core.log ==\n");
        text.push_str(&logfile::core().map(LogFile::read_all).unwrap_or_default());
        text.push_str("\n== mihomo.log ==\n");
        text.push_str(&self.mihomo_log.read_all());
        for entry in &settings.whitelist.entries {
            if let Some(secret) = whitelist::Secret::new(&entry.value) {
                text = secret.redact(&text);
            }
        }
        for url in settings
            .profiles
            .iter()
            .filter_map(|profile| profile.url.as_deref())
        {
            text = text.replace(url, "<subscription url>");
        }
        util::write_atomic(&path, text.as_bytes())?;
        Ok(())
    }

    pub fn shutdown(&self) {
        self.stop_engine();
        self.whitelist.stop();
        *lock(&self.updater.stopped) = true;
        self.updater.signal.notify_all();
        logfile::info("core shut down");
    }

    fn auto_update(&self) {
        let now = util::now();
        let due: Vec<String> = self.store.read(|s| {
            s.profiles
                .iter()
                .filter(|profile| {
                    profile.kind == ProfileKind::Subscription
                        && profile.url.is_some()
                        && !profile.manual_update
                })
                .filter(|profile| {
                    let hours =
                        i64::from(profile.update_hours.unwrap_or(DEFAULT_UPDATE_HOURS).max(1));
                    profile.updated_at.is_none_or(|at| now - at >= hours * 3600)
                })
                .map(|profile| profile.id.clone())
                .collect()
        });
        for id in due {
            let _ = self.update_profile(id);
        }
    }
}

fn run_updater(core: &Weak<Core>) {
    let mut wait = FIRST_UPDATE_CHECK;
    loop {
        {
            let Some(strong) = core.upgrade() else {
                return;
            };
            let stopped = lock(&strong.updater.stopped);
            let (stopped, _) = strong
                .updater
                .signal
                .wait_timeout_while(stopped, wait, |stopped| !*stopped)
                .unwrap_or_else(PoisonError::into_inner);
            if *stopped {
                return;
            }
        }
        wait = UPDATE_CHECK;
        if let Some(strong) = core.upgrade() {
            strong.auto_update();
        }
    }
}

const CLEAR_MARKER: &str = "clear-on-launch";

/// Clearing waits for the next start so nothing still in memory can write the old settings back, and a cleared
/// start does not import the Flutter app's settings again.
fn clear_if_requested(data_dir: &Path, paths: &Paths) -> bool {
    let marker = data_dir.join(CLEAR_MARKER);
    if !marker.exists() {
        return false;
    }
    logfile::info("clearing data as requested");
    for file in ["settings.json", "whitelist-results.json"] {
        let _ = fs::remove_file(data_dir.join(file));
    }
    for dir in [&paths.profiles, &paths.home] {
        let _ = fs::remove_dir_all(dir);
        let _ = fs::create_dir_all(dir);
    }
    let _ = fs::remove_file(marker);
    true
}

fn import_legacy(store: &Store, paths: &Paths, options: &CoreOptions) {
    if options.legacy_prefs.is_none() && options.legacy_database.is_none() {
        return;
    }
    let legacy = legacy::read(
        options.legacy_prefs.as_deref(),
        options.legacy_database.as_deref(),
    );
    let mut current = None;
    let mut records = Vec::new();
    for profile in &legacy.profiles {
        let id = util::random_id();
        if let Some(Ok(content)) = profile.yaml.as_deref().map(profiles::classify) {
            let (path, text) = match &content {
                Content::Yaml(text) => (paths.yaml(&id), text),
                Content::Links(text) => (paths.links(&id), text),
            };
            if util::write_atomic(&path, text.as_bytes()).is_err() {
                continue;
            }
        }
        if legacy.current.as_deref() == Some(profile.id.as_str()) {
            current = Some(id.clone());
        }
        records.push(ProfileRecord {
            url: Some(profile.url.clone()),
            updated_at: None,
            ..ProfileRecord::new(id, profile.name.clone(), ProfileKind::Subscription)
        });
    }
    let mut entries: Vec<EntryRecord> = Vec::new();
    for (name, text) in &legacy.entries {
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
    let (profile_count, entry_count) = (records.len(), entries.len());
    let result = store.update(|s| {
        s.current_profile = current.or_else(|| records.first().map(|record| record.id.clone()));
        s.profiles = records;
        s.whitelist.enabled = legacy.whitelist_enabled && !entries.is_empty();
        s.whitelist.entries = entries;
        Ok(())
    });
    match result {
        Ok(()) => logfile::info(format!(
            "imported {profile_count} subscriptions and {entry_count} whitelist entries from the Flutter app"
        )),
        Err(error) => logfile::warn(format!("legacy import failed: {error}")),
    }
}

#[cfg(test)]
mod tests;
