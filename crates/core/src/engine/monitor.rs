use std::collections::{HashMap, VecDeque};
use std::sync::atomic::{AtomicBool, AtomicU64, Ordering};
use std::sync::{Arc, Mutex};
use std::thread;
use std::time::{Duration, Instant};

use serde_json::Value;

use super::{Controller, lock};
use crate::error::Result;
use crate::model::{Connection, Connections, LogEntry, Traffic};
use crate::options::LogLevel;
use crate::util;

const TRAFFIC_HISTORY: usize = 60;
const KEPT: usize = 500;

/// What the engine reports while it runs. Logs and requests outlive a session so a failed start can still be read.
/// Requests are new connections seen by polling `/connections`, so very short ones can be missed, more often while
/// no window is open.
#[derive(Default)]
pub struct Monitor {
    inactive: AtomicBool,
    only_proxy: AtomicBool,
    log_level: Mutex<LogLevel>,
    traffic: Mutex<VecDeque<Traffic>>,
    memory: AtomicU64,
    connections: Mutex<Connections>,
    proxied: Mutex<Proxied>,
    logs: Mutex<VecDeque<LogEntry>>,
    requests: Mutex<VecDeque<Connection>>,
}

impl Monitor {
    pub fn watch(self: &Arc<Self>, controller: &Controller, stop: &Arc<AtomicBool>) {
        self.follow(
            controller,
            stop,
            |_| Some("/traffic".into()),
            |monitor, value| {
                if !monitor.only_proxy.load(Ordering::Relaxed) {
                    monitor.record(Traffic {
                        up: number(value, "up"),
                        down: number(value, "down"),
                    });
                }
            },
        );
        self.follow(
            controller,
            stop,
            |_| Some("/memory".into()),
            |monitor, value| {
                monitor
                    .memory
                    .store(number(value, "inuse"), Ordering::Relaxed);
            },
        );
        let logs_path = |monitor: &Self| {
            let level = *lock(&monitor.log_level);
            (level != LogLevel::Silent).then(|| format!("/logs?level={}", level.as_str()))
        };
        self.follow(controller, stop, logs_path, |monitor, value| {
            let entry = LogEntry {
                level: text(value, "type")
                    .and_then(LogLevel::parse)
                    .unwrap_or(LogLevel::Info),
                message: text(value, "payload").unwrap_or_default().to_owned(),
                at: util::now(),
            };
            push_capped(&mut lock(&monitor.logs), entry);
        });
        let (monitor, controller, stop) = (self.clone(), controller.clone(), stop.clone());
        thread::spawn(move || {
            while !stop.load(Ordering::SeqCst) {
                let _ = monitor.poll(&controller, &stop);
                let pause = if monitor.inactive.load(Ordering::Relaxed)
                    && !monitor.only_proxy.load(Ordering::Relaxed)
                {
                    5
                } else {
                    1
                };
                thread::sleep(Duration::from_secs(pause));
            }
        });
    }

    /// Streams `path` until the session stops, subscribing again whenever the path it gives changes.
    fn follow(
        self: &Arc<Self>,
        controller: &Controller,
        stop: &Arc<AtomicBool>,
        path: impl Fn(&Self) -> Option<String> + Send + 'static,
        on_value: impl Fn(&Self, &Value) + Send + 'static,
    ) {
        let (monitor, controller, stop) = (self.clone(), controller.clone(), stop.clone());
        thread::spawn(move || {
            while !stop.load(Ordering::SeqCst) {
                if let Some(current) = path(&monitor) {
                    let done = AtomicBool::new(false);
                    let _ = controller.stream(&current, &done, |line| {
                        if stop.load(Ordering::SeqCst) || path(&monitor).as_ref() != Some(&current)
                        {
                            done.store(true, Ordering::SeqCst);
                        } else if let Ok(value) = serde_json::from_str::<Value>(line) {
                            on_value(&monitor, &value);
                        }
                    });
                }
                thread::sleep(Duration::from_secs(1));
            }
        });
    }

    pub fn poll(&self, controller: &Controller, stop: &AtomicBool) -> Result<()> {
        let value = controller.json("GET", "/connections", None)?;
        if stop.load(Ordering::SeqCst) {
            return Ok(());
        }
        let items: Vec<Connection> = value
            .get("connections")
            .and_then(Value::as_array)
            .into_iter()
            .flatten()
            .filter_map(parse_connection)
            .collect();
        {
            let mut requests = lock(&self.requests);
            for item in &items {
                match requests.iter_mut().rev().find(|seen| seen.id == item.id) {
                    Some(seen) => seen.clone_from(item),
                    None => push_capped(&mut requests, item.clone()),
                }
            }
        }
        let (rate, proxied_totals) = {
            let mut proxied = lock(&self.proxied);
            (proxied.add(&items), (proxied.upload, proxied.download))
        };
        let (upload_total, download_total) = if self.only_proxy.load(Ordering::Relaxed) {
            if let Some(rate) = rate {
                self.record(rate);
            }
            proxied_totals
        } else {
            (
                number(&value, "uploadTotal"),
                number(&value, "downloadTotal"),
            )
        };
        *lock(&self.connections) = Connections {
            upload_total,
            download_total,
            items,
        };
        Ok(())
    }

    fn record(&self, traffic: Traffic) {
        let mut history = lock(&self.traffic);
        if history.len() == TRAFFIC_HISTORY {
            history.pop_front();
        }
        history.push_back(traffic);
    }

    /// The history restarts on a switch, so the chart never mixes all traffic with proxied traffic.
    pub fn set_only_proxy(&self, only_proxy: bool) {
        if self.only_proxy.swap(only_proxy, Ordering::Relaxed) != only_proxy {
            lock(&self.traffic).clear();
        }
    }

    pub fn set_log_level(&self, level: LogLevel) {
        *lock(&self.log_level) = level;
    }

    pub fn set_active(&self, active: bool) {
        self.inactive.store(!active, Ordering::Relaxed);
    }

    pub fn traffic(&self) -> Traffic {
        lock(&self.traffic).back().copied().unwrap_or_default()
    }

    pub fn traffic_history(&self) -> Vec<Traffic> {
        lock(&self.traffic).iter().copied().collect()
    }

    pub fn memory(&self) -> u64 {
        self.memory.load(Ordering::Relaxed)
    }

    pub fn connections(&self) -> Connections {
        lock(&self.connections).clone()
    }

    pub fn logs(&self) -> Vec<LogEntry> {
        lock(&self.logs).iter().cloned().collect()
    }

    pub fn requests(&self) -> Vec<Connection> {
        lock(&self.requests).iter().cloned().collect()
    }

    /// Developer mode's log test fills the log list with lines of varied length.
    pub fn add_test_logs(&self) {
        let mut logs = lock(&self.logs);
        for index in 0..1000 {
            push_capped(
                &mut logs,
                LogEntry {
                    level: LogLevel::Info,
                    message: format!("[{index}] {}", util::random_secret(20 + index * 37 % 180)),
                    at: util::now(),
                },
            );
        }
    }

    pub fn clear_logs(&self) {
        lock(&self.logs).clear();
    }

    pub fn clear_requests(&self) {
        lock(&self.requests).clear();
    }

    /// Live figures end with the session; logs and requests stay.
    pub fn reset(&self) {
        lock(&self.traffic).clear();
        self.memory.store(0, Ordering::Relaxed);
        *lock(&self.connections) = Connections::default();
        *lock(&self.proxied) = Proxied::default();
    }
}

/// mihomo's `/traffic` and totals include direct traffic, so proxy-only figures add up how much each proxied
/// connection grew between polls. What a connection moves after the last poll before it closes is missed.
#[derive(Default)]
struct Proxied {
    seen: HashMap<String, (u64, u64)>,
    polled_at: Option<Instant>,
    upload: u64,
    download: u64,
}

impl Proxied {
    /// Adds what proxied connections moved since the last poll and returns it as a rate.
    fn add(&mut self, items: &[Connection]) -> Option<Traffic> {
        let (mut up, mut down) = (0, 0);
        let mut seen = HashMap::with_capacity(items.len());
        for item in items {
            let (last_up, last_down) = self.seen.get(&item.id).copied().unwrap_or_default();
            if item.chains.first().is_some_and(|node| node != "DIRECT") {
                up += item.upload.saturating_sub(last_up);
                down += item.download.saturating_sub(last_down);
            }
            seen.insert(item.id.clone(), (item.upload, item.download));
        }
        self.seen = seen;
        self.upload += up;
        self.download += down;
        let now = Instant::now();
        let seconds = now
            .duration_since(self.polled_at.replace(now)?)
            .as_secs_f64();
        (seconds > 0.0).then(|| Traffic {
            up: (up as f64 / seconds) as u64,
            down: (down as f64 / seconds) as u64,
        })
    }
}

fn push_capped<T>(queue: &mut VecDeque<T>, item: T) {
    if queue.len() == KEPT {
        queue.pop_front();
    }
    queue.push_back(item);
}

fn number(value: &Value, name: &str) -> u64 {
    value.get(name).and_then(Value::as_u64).unwrap_or(0)
}

fn text<'a>(value: &'a Value, name: &str) -> Option<&'a str> {
    value.get(name).and_then(Value::as_str)
}

fn parse_connection(value: &Value) -> Option<Connection> {
    let meta = value.get("metadata")?;
    let field = |name: &str| text(meta, name).unwrap_or_default().to_owned();
    let address = |host: String, port: String| {
        if host.contains(':') {
            format!("[{host}]:{port}")
        } else {
            format!("{host}:{port}")
        }
    };
    let host = [field("host"), field("sniffHost"), field("destinationIP")]
        .into_iter()
        .find(|host| !host.is_empty())
        .unwrap_or_default();
    let optional = |name: &str| Some(field(name)).filter(|value| !value.is_empty());
    Some(Connection {
        id: text(value, "id")?.to_owned(),
        network: field("network"),
        inbound: field("type"),
        host: address(host, field("destinationPort")),
        destination: address(field("destinationIP"), field("destinationPort")),
        source: address(field("sourceIP"), field("sourcePort")),
        process: optional("process"),
        process_path: optional("processPath"),
        rule: text(value, "rule").unwrap_or_default().to_owned(),
        rule_payload: text(value, "rulePayload").unwrap_or_default().to_owned(),
        chains: value
            .get("chains")
            .and_then(Value::as_array)
            .into_iter()
            .flatten()
            .filter_map(Value::as_str)
            .map(str::to_owned)
            .collect(),
        upload: number(value, "upload"),
        download: number(value, "download"),
        start: text(value, "start")
            .and_then(util::parse_time)
            .unwrap_or_else(util::now),
    })
}

#[cfg(test)]
mod tests {
    use super::*;
    use serde_json::json;

    #[test]
    fn reads_mihomo_connections() {
        let connection = parse_connection(&json!({
            "id": "c1",
            "metadata": {
                "network": "tcp", "type": "HTTP Connect", "sourceIP": "127.0.0.1", "sourcePort": "50000",
                "destinationIP": "2001:db8::1", "destinationPort": "443", "host": "", "sniffHost": "example.com",
                "process": "curl", "processPath": ""
            },
            "upload": 10, "download": 20, "start": "2024-03-01T08:00:00+08:00",
            "chains": ["Tokyo 01", "Proxy"], "rule": "Match", "rulePayload": ""
        }))
        .unwrap();
        assert_eq!(connection.host, "example.com:443");
        assert_eq!(connection.destination, "[2001:db8::1]:443");
        assert_eq!(connection.source, "127.0.0.1:50000");
        assert_eq!(connection.process.as_deref(), Some("curl"));
        assert_eq!(connection.process_path, None);
        assert_eq!(connection.chains, ["Tokyo 01", "Proxy"]);
        assert_eq!(connection.start, 1_709_251_200);
    }

    #[test]
    fn counts_only_proxied_growth() {
        let connection = |id: &str, chain: &str, upload, download| Connection {
            id: id.into(),
            chains: vec![chain.into(), "Proxy".into()],
            upload,
            download,
            ..parse_connection(&json!({"id": id, "metadata": {}})).unwrap()
        };
        let mut proxied = Proxied::default();
        assert_eq!(
            proxied.add(&[
                connection("a", "Tokyo", 100, 1000),
                connection("b", "DIRECT", 7, 70)
            ]),
            None
        );
        proxied.add(&[
            connection("a", "Tokyo", 150, 1600),
            connection("b", "DIRECT", 9, 90),
            connection("c", "Osaka", 5, 50),
        ]);
        assert_eq!((proxied.upload, proxied.download), (155, 1650));
        proxied.add(&[connection("c", "Osaka", 5, 50)]);
        assert_eq!((proxied.upload, proxied.download), (155, 1650));
        assert_eq!(proxied.seen.len(), 1);
    }

    #[test]
    fn keeps_the_newest_entries() {
        let mut queue = VecDeque::new();
        for n in 0..KEPT + 3 {
            push_capped(&mut queue, n);
        }
        assert_eq!(queue.len(), KEPT);
        assert_eq!(queue.front(), Some(&3));
    }
}
