mod controller;
#[cfg(target_os = "android")]
mod inproc;
#[cfg(not(target_os = "android"))]
mod process;
pub mod sysproxy;

use std::fs;
use std::io;
use std::net::TcpListener;
use std::path::{Path, PathBuf};
use std::sync::atomic::{AtomicBool, AtomicU64, Ordering};
use std::sync::{Arc, Mutex, MutexGuard, PoisonError};
use std::thread;
use std::time::{Duration, Instant};

use serde::{Deserialize, Serialize};
use serde_json::Value;

pub use controller::{Controller, Endpoint};

use crate::config::DirectListener;
use crate::error::{CoreError, Result};
use crate::logfile::LogFile;
use crate::model::{EngineState, Platform, Traffic};
use crate::util::{self, random_id, random_secret};

const PREFERRED_MIXED_PORT: u16 = 7894;
const READY_TIMEOUT: Duration = Duration::from_secs(45);

fn lock<T>(mutex: &Mutex<T>) -> MutexGuard<'_, T> {
    mutex.lock().unwrap_or_else(PoisonError::into_inner)
}

/// Fresh per start: the controller secret and the po0-direct login never outlive a session.
pub struct Runtime {
    pub home: PathBuf,
    pub controller: Controller,
    pub direct: DirectListener,
    pub mixed_port: u16,
    pub tun_fd: Option<i32>,
}

fn free_port() -> io::Result<u16> {
    Ok(TcpListener::bind(("127.0.0.1", 0))?.local_addr()?.port())
}

fn socket_path(run_dir: &Path) -> PathBuf {
    let path = run_dir.join("ctl.sock");
    // sun_path holds 104 bytes on macOS.
    if path.as_os_str().len() < 100 {
        return path;
    }
    #[cfg(unix)]
    {
        PathBuf::from(format!("/tmp/po0clash-{}.sock", unsafe { libc::getuid() }))
    }
    #[cfg(not(unix))]
    {
        path
    }
}

impl Runtime {
    pub fn new(
        platform: Platform,
        run_dir: &Path,
        home: PathBuf,
        tun_fd: Option<i32>,
    ) -> io::Result<Self> {
        fs::create_dir_all(run_dir)?;
        fs::create_dir_all(&home)?;
        let endpoint = match platform {
            Platform::Windows => Endpoint::Pipe(format!(r"\\.\pipe\po0clash-{}", random_id())),
            Platform::MacOs | Platform::Android => Endpoint::Unix(socket_path(run_dir)),
        };
        let mixed_port = match TcpListener::bind(("127.0.0.1", PREFERRED_MIXED_PORT)) {
            Ok(_) => PREFERRED_MIXED_PORT,
            Err(_) => free_port()?,
        };
        Ok(Self {
            home,
            controller: Controller::new(endpoint, random_secret(32)),
            direct: DirectListener {
                port: free_port()?,
                username: random_secret(12),
                password: random_secret(24),
            },
            mixed_port,
            tun_fd,
        })
    }

    pub fn proxy_url(&self) -> String {
        format!("http://127.0.0.1:{}", self.mixed_port)
    }
}

pub enum Runner {
    #[cfg(not(target_os = "android"))]
    Process(process::Process),
    #[cfg(target_os = "android")]
    InProcess,
}

impl Runner {
    pub fn exited(&self) -> Option<String> {
        match self {
            #[cfg(not(target_os = "android"))]
            Self::Process(process) => process.exited(),
            #[cfg(target_os = "android")]
            Self::InProcess => None,
        }
    }

    pub fn stop(&self) {
        match self {
            #[cfg(not(target_os = "android"))]
            Self::Process(process) => process.stop(),
            #[cfg(target_os = "android")]
            Self::InProcess => inproc::stop(),
        }
    }

    fn pid(&self) -> Option<u32> {
        match self {
            #[cfg(not(target_os = "android"))]
            Self::Process(process) => Some(process.id()),
            #[cfg(target_os = "android")]
            Self::InProcess => None,
        }
    }
}

pub fn launch(
    binary: Option<&Path>,
    home: &Path,
    config: &Path,
    log: &Arc<LogFile>,
) -> Result<Runner> {
    #[cfg(target_os = "android")]
    {
        let _ = binary;
        inproc::start(home, config, log.path()).map_err(CoreError::Engine)?;
        Ok(Runner::InProcess)
    }
    #[cfg(not(target_os = "android"))]
    {
        let binary =
            binary.ok_or_else(|| CoreError::Engine("the mihomo binary is not set".into()))?;
        process::Process::spawn(binary, home, config, log)
            .map(Runner::Process)
            .map_err(|error| CoreError::Engine(format!("cannot start mihomo: {error}")))
    }
}

pub fn last_lines(log: &LogFile, count: usize) -> String {
    let text = log.read_all();
    let lines: Vec<&str> = text
        .lines()
        .filter(|line| !line.trim().is_empty())
        .collect();
    lines[lines.len().saturating_sub(count)..]
        .iter()
        .map(|line| util::snippet(line))
        .collect::<Vec<_>>()
        .join(" | ")
}

pub fn wait_ready(controller: &Controller, runner: &Runner, log: &LogFile) -> Result<()> {
    let deadline = Instant::now() + READY_TIMEOUT;
    loop {
        if let Some(status) = runner.exited() {
            return Err(CoreError::Engine(format!(
                "mihomo exited ({status}): {}",
                last_lines(log, 3)
            )));
        }
        if controller.json("GET", "/version", None).is_ok() {
            return Ok(());
        }
        if Instant::now() > deadline {
            return Err(CoreError::Engine(format!(
                "mihomo did not come up: {}",
                last_lines(log, 3)
            )));
        }
        thread::sleep(Duration::from_millis(100));
    }
}

#[derive(Default)]
pub struct TrafficCell {
    up: AtomicU64,
    down: AtomicU64,
    stop: AtomicBool,
}

impl TrafficCell {
    pub fn get(&self) -> Traffic {
        Traffic {
            up: self.up.load(Ordering::Relaxed),
            down: self.down.load(Ordering::Relaxed),
        }
    }

    pub fn stop(&self) {
        self.stop.store(true, Ordering::SeqCst);
    }
}

fn watch_traffic(controller: Controller, cell: Arc<TrafficCell>) {
    thread::spawn(move || {
        while !cell.stop.load(Ordering::SeqCst) {
            let _ = controller.stream("/traffic", &cell.stop, |line| {
                if let Ok(value) = serde_json::from_str::<Value>(line) {
                    let read = |name: &str| value.get(name).and_then(Value::as_u64).unwrap_or(0);
                    cell.up.store(read("up"), Ordering::Relaxed);
                    cell.down.store(read("down"), Ordering::Relaxed);
                }
            });
            thread::sleep(Duration::from_secs(1));
        }
    });
}

pub struct Session {
    pub runtime: Runtime,
    pub runner: Runner,
    pub traffic: Arc<TrafficCell>,
    pub system_proxy: AtomicBool,
    pub current_node: Mutex<Option<String>>,
    pub generation: u64,
}

impl Session {
    pub fn new(runtime: Runtime, runner: Runner, generation: u64) -> Self {
        Self {
            runtime,
            runner,
            traffic: Arc::default(),
            system_proxy: AtomicBool::new(false),
            current_node: Mutex::new(None),
            generation,
        }
    }

    pub fn controller(&self) -> &Controller {
        &self.runtime.controller
    }

    pub fn start_traffic(&self) {
        watch_traffic(self.runtime.controller.clone(), self.traffic.clone());
    }

    pub fn current_node(&self) -> Option<String> {
        lock(&self.current_node).clone()
    }

    pub fn set_current_node(&self, node: Option<String>) {
        *lock(&self.current_node) = node;
    }

    /// Everything but the runner's own shutdown, which differs between a stop and a crash.
    pub fn release(&self, run_dir: &Path) {
        self.traffic.stop();
        if self.system_proxy.swap(false, Ordering::SeqCst) {
            sysproxy::clear(self.runtime.mixed_port);
        }
        clear_record(run_dir);
    }
}

#[derive(Default)]
pub struct Engine {
    pub ops: Mutex<()>,
    state: Mutex<EngineState>,
    session: Mutex<Option<Arc<Session>>>,
    generation: AtomicU64,
}

impl Engine {
    pub fn state(&self) -> EngineState {
        lock(&self.state).clone()
    }

    pub fn set_state(&self, state: EngineState) {
        *lock(&self.state) = state;
    }

    pub fn session(&self) -> Option<Arc<Session>> {
        lock(&self.session).clone()
    }

    pub fn install(&self, session: Arc<Session>) {
        *lock(&self.session) = Some(session);
    }

    pub fn take(&self) -> Option<Arc<Session>> {
        lock(&self.session).take()
    }

    pub fn next_generation(&self) -> u64 {
        self.generation.fetch_add(1, Ordering::SeqCst) + 1
    }
}

/// Written while mihomo runs, so the next launch can undo what a crashed app left behind.
#[derive(Serialize, Deserialize)]
struct Record {
    pid: Option<u32>,
    endpoint: String,
    mixed_port: u16,
    system_proxy: bool,
}

fn record_path(run_dir: &Path) -> PathBuf {
    run_dir.join("session.json")
}

pub fn save_record(run_dir: &Path, session: &Session) {
    let record = Record {
        pid: session.runner.pid(),
        endpoint: session.runtime.controller.endpoint.describe(),
        mixed_port: session.runtime.mixed_port,
        system_proxy: session.system_proxy.load(Ordering::SeqCst),
    };
    if let Ok(json) = serde_json::to_vec(&record) {
        let _ = util::write_atomic(&record_path(run_dir), &json);
    }
}

pub fn clear_record(run_dir: &Path) {
    let _ = fs::remove_file(record_path(run_dir));
}

pub fn recover(run_dir: &Path) {
    let Some(record) = fs::read(record_path(run_dir))
        .ok()
        .and_then(|bytes| serde_json::from_slice::<Record>(&bytes).ok())
    else {
        return;
    };
    if record.system_proxy && sysproxy::points_at(record.mixed_port) {
        sysproxy::clear(record.mixed_port);
    }
    #[cfg(not(target_os = "android"))]
    if let Some(pid) = record.pid {
        let probe = Controller::new(Endpoint::parse(&record.endpoint), String::new());
        if probe.request("GET", "/version", None).is_ok() {
            process::kill_stale(pid);
        }
    }
    clear_record(run_dir);
}

pub fn is_privileged(binary: &Path) -> bool {
    #[cfg(unix)]
    {
        use std::os::unix::fs::MetadataExt;
        fs::metadata(binary).is_ok_and(|meta| meta.uid() == 0 && meta.mode() & 0o4000 != 0)
    }
    #[cfg(not(unix))]
    {
        let _ = binary;
        false
    }
}
