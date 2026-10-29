mod client;
mod route;
mod transport;

use std::collections::HashMap;
use std::fs;
use std::path::{Path, PathBuf};
use std::sync::atomic::{AtomicBool, Ordering};
use std::sync::{Arc, Condvar, Mutex, MutexGuard, PoisonError};
use std::thread;
use std::time::{Duration, Instant};

use crate::logfile;
use crate::model::{
    WhitelistEntry, WhitelistKind, WhitelistOutcome, WhitelistResult, WhitelistState,
};
use crate::settings::{EntryRecord, WhitelistSettings};
use crate::util;
use client::Client;
use transport::Transport;

const PO0_PREFIX: &str = "pgnfw_";
const PO0_INTERVAL: Duration = Duration::from_secs(5);
const GGY_INTERVAL: Duration = Duration::from_secs(11);
const MAX_BACKOFF: Duration = Duration::from_secs(30);

/// A po0 token or a ggy link; `value` is what the user pasted.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct Secret {
    pub kind: WhitelistKind,
    pub value: String,
}

impl Secret {
    pub fn new(value: &str) -> Option<Self> {
        let value = value.trim();
        if is_po0_token(value) {
            return Some(Self {
                kind: WhitelistKind::Po0,
                value: value.to_owned(),
            });
        }
        ggy_token(value).map(|_| Self {
            kind: WhitelistKind::Ggy,
            value: value.to_owned(),
        })
    }

    fn secret(&self) -> &str {
        match self.kind {
            WhitelistKind::Po0 => &self.value,
            WhitelistKind::Ggy => ggy_token(&self.value).unwrap_or(&self.value),
        }
    }

    pub fn label(&self) -> String {
        let secret = self.secret();
        let head: String = secret.chars().take(12).collect();
        format!("{head}…")
    }

    pub fn redact(&self, text: &str) -> String {
        text.replace(self.secret(), &self.label())
    }
}

fn is_po0_token(value: &str) -> bool {
    value.len() > PO0_PREFIX.len()
        && value.starts_with(PO0_PREFIX)
        && !value.contains(|c: char| c.is_whitespace() || ",|;、@".contains(c))
}

fn ggy_token(value: &str) -> Option<&str> {
    if value.contains(char::is_whitespace) {
        return None;
    }
    let rest = value.strip_prefix("https://")?;
    let (authority, tail) = rest.split_at(rest.find(['/', '?', '#']).unwrap_or(rest.len()));
    let host = authority
        .rsplit('@')
        .next()?
        .split(':')
        .next()?
        .to_ascii_lowercase();
    if host != "guguyun.com" && !host.ends_with(".guguyun.com") {
        return None;
    }
    let query = tail.split_once('?')?.1.split('#').next()?;
    query
        .split('&')
        .find_map(|pair| pair.strip_prefix("token="))
        .filter(|token| !token.is_empty())
}

/// Splits pasted text into po0 tokens (`pgnfw_…`, an `@suffix` dropped) and ggy links.
pub fn parse_secrets(text: &str) -> Vec<Secret> {
    let mut secrets: Vec<Secret> = Vec::new();
    for part in text.split(|c: char| c.is_whitespace() || ",|;、".contains(c)) {
        let part = if part.starts_with(PO0_PREFIX) {
            part.split('@').next().unwrap_or(part)
        } else {
            part
        };
        if let Some(secret) = Secret::new(part)
            && !secrets.contains(&secret)
        {
            secrets.push(secret);
        }
    }
    secrets
}

pub fn next_delay(failures: u32, interval: Duration) -> Duration {
    if failures == 0 {
        return interval;
    }
    let backoff = interval * (1 << failures.min(5));
    backoff.min(interval.max(MAX_BACKOFF))
}

type RouteFn = Box<dyn Fn() -> String + Send + Sync>;
type NotifyFn = Box<dyn Fn() + Send + Sync>;

struct Shared {
    settings: Mutex<WhitelistSettings>,
    results: Mutex<HashMap<String, WhitelistResult>>,
    results_path: PathBuf,
    active: AtomicBool,
    stopped: AtomicBool,
    transport: Transport,
    route: RouteFn,
    notify: NotifyFn,
}

struct Lane {
    kind: WhitelistKind,
    interval: Duration,
    wake: Mutex<Wake>,
    signal: Condvar,
}

#[derive(Default)]
struct Wake {
    pending: bool,
    reset_failures: bool,
}

/// Keeps the current exit whitelisted for as long as the app runs, whether or not the proxy
/// is started: po0 every 5 s and ggy every 11 s, fixed (ADR 0014), each on its own thread.
pub struct Whitelist {
    shared: Arc<Shared>,
    lanes: [Arc<Lane>; 2],
}

fn lock<T>(mutex: &Mutex<T>) -> MutexGuard<'_, T> {
    mutex.lock().unwrap_or_else(PoisonError::into_inner)
}

impl Whitelist {
    /// Last results are kept in `results_path` so a restarted app shows them before its first round.
    pub fn start(
        settings: WhitelistSettings,
        results_path: PathBuf,
        route: RouteFn,
        notify: NotifyFn,
    ) -> Self {
        let results = fs::read(&results_path)
            .ok()
            .and_then(|bytes| serde_json::from_slice(&bytes).ok())
            .unwrap_or_default();
        let shared = Arc::new(Shared {
            settings: Mutex::new(settings),
            results: Mutex::new(results),
            results_path,
            active: AtomicBool::new(true),
            stopped: AtomicBool::new(false),
            transport: Transport::default(),
            route,
            notify,
        });
        let lane = |kind, interval| {
            Arc::new(Lane {
                kind,
                interval,
                wake: Mutex::new(Wake::default()),
                signal: Condvar::new(),
            })
        };
        let lanes = [
            lane(WhitelistKind::Po0, PO0_INTERVAL),
            lane(WhitelistKind::Ggy, GGY_INTERVAL),
        ];
        for lane in &lanes {
            let (shared, lane) = (shared.clone(), lane.clone());
            thread::Builder::new()
                .name(format!("whitelist-{:?}", lane.kind).to_lowercase())
                .spawn(move || run(&shared, &lane))
                .expect("spawn whitelist thread");
        }
        Self { shared, lanes }
    }

    pub fn state(&self) -> WhitelistState {
        let settings = lock(&self.shared.settings).clone();
        let results = lock(&self.shared.results);
        WhitelistState {
            enabled: settings.enabled,
            entries: settings
                .entries
                .iter()
                .filter_map(|entry| {
                    let secret = Secret::new(&entry.value)?;
                    Some(WhitelistEntry {
                        id: entry.id.clone(),
                        kind: secret.kind,
                        name: entry.name.clone(),
                        label: secret.label(),
                        result: results.get(&entry.id).cloned(),
                    })
                })
                .collect(),
        }
    }

    pub fn update(&self, settings: WhitelistSettings) {
        {
            let mut results = lock(&self.shared.results);
            let before = results.len();
            results.retain(|id, _| settings.entries.iter().any(|entry| &entry.id == id));
            if results.len() != before {
                save_results(&self.shared.results_path, &results);
            }
        }
        *lock(&self.shared.settings) = settings;
        self.kick(false);
    }

    pub fn now(&self) {
        self.kick(false);
    }

    pub fn network_changed(&self) {
        self.shared.transport.reset();
        self.kick(true);
    }

    pub fn set_active(&self, active: bool) {
        if self.shared.active.swap(active, Ordering::SeqCst) != active && active {
            self.kick(false);
        }
    }

    pub fn stop(&self) {
        self.shared.stopped.store(true, Ordering::SeqCst);
        self.kick(false);
    }

    fn kick(&self, reset_failures: bool) {
        for lane in &self.lanes {
            let mut wake = lock(&lane.wake);
            wake.pending = true;
            wake.reset_failures |= reset_failures;
            lane.signal.notify_all();
        }
    }
}

fn entries_of(shared: &Shared, kind: WhitelistKind) -> Option<Vec<(EntryRecord, Secret)>> {
    if !shared.active.load(Ordering::SeqCst) {
        return None;
    }
    let settings = lock(&shared.settings);
    if !settings.enabled {
        return None;
    }
    let entries: Vec<_> = settings
        .entries
        .iter()
        .filter_map(|entry| {
            let secret = Secret::new(&entry.value)?;
            (secret.kind == kind).then(|| (entry.clone(), secret))
        })
        .collect();
    (!entries.is_empty()).then_some(entries)
}

fn run(shared: &Shared, lane: &Lane) {
    let mut failures = 0u32;
    let mut due = Instant::now();
    let mut signatures: HashMap<String, String> = HashMap::new();
    loop {
        {
            let mut wake = lock(&lane.wake);
            loop {
                if shared.stopped.load(Ordering::SeqCst) {
                    return;
                }
                if wake.pending {
                    wake.pending = false;
                    if std::mem::take(&mut wake.reset_failures) {
                        failures = 0;
                    }
                    due = Instant::now();
                }
                let runnable = entries_of(shared, lane.kind).is_some();
                let now = Instant::now();
                if runnable && now >= due {
                    break;
                }
                wake = if runnable {
                    lane.signal
                        .wait_timeout(wake, due - now)
                        .unwrap_or_else(PoisonError::into_inner)
                        .0
                } else {
                    lane.signal
                        .wait(wake)
                        .unwrap_or_else(PoisonError::into_inner)
                };
            }
        }
        let Some(entries) = entries_of(shared, lane.kind) else {
            continue;
        };
        let client = Client {
            transport: &shared.transport,
            route: (shared.route)(),
        };
        let polled: Vec<_> = thread::scope(|scope| {
            let handles: Vec<_> = entries
                .iter()
                .map(|(_, secret)| scope.spawn(|| client.poll(secret)))
                .collect();
            handles
                .into_iter()
                .map(|handle| handle.join().expect("whitelist request thread"))
                .collect()
        });
        let failed = polled
            .iter()
            .any(|polled| polled.result.outcome == WhitelistOutcome::Error);
        failures = if failed { failures + 1 } else { 0 };
        due = Instant::now() + next_delay(failures, lane.interval);
        let current = entries_of(shared, lane.kind).unwrap_or_default();
        {
            let mut results = lock(&shared.results);
            let mut changed = false;
            for ((entry, secret), polled) in entries.iter().zip(&polled) {
                if current.iter().any(|(still, _)| still.id == entry.id) {
                    let previous = results.insert(entry.id.clone(), polled.result.clone());
                    changed |=
                        previous.is_none_or(|previous| !same_outcome(&previous, &polled.result));
                }
                log_result(&mut signatures, lane.kind, entry, secret, polled);
            }
            if changed {
                save_results(&shared.results_path, &results);
            }
        }
        (shared.notify)();
    }
}

/// Only a change in what the entry shows is written, not every poll's timestamp.
fn same_outcome(a: &WhitelistResult, b: &WhitelistResult) -> bool {
    a.outcome == b.outcome && a.ip == b.ip && a.message == b.message
}

fn save_results(path: &Path, results: &HashMap<String, WhitelistResult>) {
    if let Ok(json) = serde_json::to_vec(results) {
        let _ = util::write_atomic(path, &json);
    }
}

fn log_result(
    signatures: &mut HashMap<String, String>,
    kind: WhitelistKind,
    entry: &EntryRecord,
    secret: &Secret,
    polled: &client::Polled,
) {
    let result = &polled.result;
    let signature = format!("{:?} {:?}", result.outcome, result.ip);
    let changed = signatures.insert(entry.id.clone(), signature.clone()) != Some(signature);
    let evicted = result.outcome == WhitelistOutcome::Applied && result.message.is_some();
    if !changed && !evicted && !polled.added {
        return;
    }
    let action = if polled.added { "whitelist" } else { "poll" };
    let detail = [result.ip.as_deref(), result.message.as_deref()]
        .into_iter()
        .flatten()
        .collect::<Vec<_>>()
        .join(" ");
    let line = format!(
        "{kind:?} {action} {} {:?} {detail}",
        secret.label(),
        result.outcome
    );
    if result.outcome == WhitelistOutcome::Applied {
        logfile::info(line);
    } else {
        logfile::warn(line);
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn recognizes_tokens_and_links() {
        let po0 = Secret::new("pgnfw_abc123").unwrap();
        assert_eq!(po0.kind, WhitelistKind::Po0);
        assert_eq!(po0.label(), "pgnfw_abc123…");
        let ggy = Secret::new("https://x.guguyun.com/api/wl?a=1&token=t0ken").unwrap();
        assert_eq!(ggy.kind, WhitelistKind::Ggy);
        assert_eq!(ggy.secret(), "t0ken");
        for invalid in [
            "pgnfw_",
            "pgnfw_a b",
            "http://guguyun.com/?token=x",
            "https://guguyun.com.evil.com/?token=x",
            "https://guguyun.com/?token=",
            "https://evilguguyun.com/?token=x",
            "token",
        ] {
            assert_eq!(Secret::new(invalid), None, "{invalid}");
        }
    }

    #[test]
    fn splits_pasted_text() {
        let text = "pgnfw_one@note, pgnfw_two;https://guguyun.com/w?token=g、pgnfw_one\nrubbish";
        let values: Vec<_> = parse_secrets(text).into_iter().map(|s| s.value).collect();
        assert_eq!(
            values,
            ["pgnfw_one", "pgnfw_two", "https://guguyun.com/w?token=g"]
        );
    }

    #[test]
    fn backs_off_up_to_the_cap() {
        let five = Duration::from_secs(5);
        assert_eq!(next_delay(0, five), five);
        assert_eq!(next_delay(1, five), Duration::from_secs(10));
        assert_eq!(next_delay(2, five), Duration::from_secs(20));
        assert_eq!(next_delay(9, five), MAX_BACKOFF);
        assert_eq!(
            next_delay(3, Duration::from_secs(60)),
            Duration::from_secs(60)
        );
    }

    #[test]
    fn a_disabled_whitelist_sends_nothing_and_stops() {
        let route_calls = Arc::new(std::sync::atomic::AtomicUsize::new(0));
        let counted = route_calls.clone();
        let dir = std::env::temp_dir().join(format!("po0-wl-{}", util::random_id()));
        let whitelist = Whitelist::start(
            WhitelistSettings {
                enabled: false,
                entries: vec![EntryRecord {
                    id: "a".into(),
                    name: String::new(),
                    value: "pgnfw_abc".into(),
                }],
            },
            dir.join("whitelist.json"),
            Box::new(move || {
                counted.fetch_add(1, Ordering::SeqCst);
                "DIRECT".into()
            }),
            Box::new(|| {}),
        );
        whitelist.now();
        thread::sleep(Duration::from_millis(200));
        assert_eq!(route_calls.load(Ordering::SeqCst), 0);
        let state = whitelist.state();
        assert!(!state.enabled);
        assert_eq!(state.entries[0].label, "pgnfw_abc…");
        whitelist.stop();
    }
}
