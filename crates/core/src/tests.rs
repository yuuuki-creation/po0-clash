use std::io::{Read, Write};
use std::net::TcpListener;
use std::sync::atomic::AtomicUsize;

use super::*;

fn temp_dir() -> PathBuf {
    let dir = std::env::temp_dir().join(format!("po0-core-{}", util::random_id()));
    fs::create_dir_all(&dir).unwrap();
    dir
}

fn options(dir: &Path) -> CoreOptions {
    CoreOptions {
        data_dir: dir.join("core"),
        platform: Platform::MacOs,
        mihomo_path: std::env::var_os("MIHOMO_BIN").map(PathBuf::from),
        legacy_prefs: None,
        legacy_database: None,
        app_version: "test".into(),
    }
}

#[derive(Default)]
struct Counter(AtomicUsize);

impl Listener for Counter {
    fn on_change(&self, _change: Change) {
        self.0.fetch_add(1, Ordering::SeqCst);
    }
}

#[test]
fn imports_links_into_one_profile() {
    let dir = temp_dir();
    let core = Core::new(options(&dir)).unwrap();
    let counter = Arc::new(Counter::default());
    core.set_listener(counter.clone());
    let first = core
        .import_links("ss://YWVzLTEyOC1nY206cA@1.1.1.1:1#a\nvless://u@h:1#b".into())
        .unwrap();
    assert_eq!(first.added, 2);
    assert!(first.profile.selected);
    assert_eq!(first.profile.kind, ProfileKind::Links);
    let again = core
        .import_links("vless://u@h:1#b\ntrojan://p@h:2#c".into())
        .unwrap();
    assert_eq!(again.added, 1);
    assert_eq!(again.profile.id, first.profile.id);
    assert_eq!(core.profiles().len(), 1);
    assert!(core.import_links("nothing here".into()).is_err());
    assert!(counter.0.load(Ordering::SeqCst) > 0);
    assert_eq!(core.status().profile_id, Some(first.profile.id.clone()));
    core.shutdown();
    fs::remove_dir_all(dir).unwrap();
}

#[test]
fn developer_tools_prune_and_clear_data() {
    let dir = temp_dir();
    let core = Core::new(options(&dir)).unwrap();
    let kept = core
        .import_links("ss://YWVzLTEyOC1nY206cA@1.1.1.1:1#a".into())
        .unwrap();
    let profiles = dir.join("core").join("profiles");
    fs::write(profiles.join("orphan.yaml"), "proxies: []").unwrap();
    assert_eq!(core.prune_cache().unwrap(), 1);
    assert_eq!(core.profiles().len(), 1);
    core.clear_data().unwrap();
    core.shutdown();
    drop(core);

    let core = Core::new(options(&dir)).unwrap();
    assert!(core.profiles().is_empty());
    assert!(!profiles.join(format!("{}.txt", kept.profile.id)).exists());
    assert!(!dir.join("core").join(CLEAR_MARKER).exists());
    core.shutdown();
    fs::remove_dir_all(dir).unwrap();
}

#[test]
fn profiles_can_be_switched_and_removed() {
    let dir = temp_dir();
    let core = Core::new(options(&dir)).unwrap();
    let links = core.import_links("vless://u@h:1#b".into()).unwrap().profile;
    let server = serve_once(
        "HTTP/1.1 200 OK\r\nsubscription-userinfo: upload=1; download=2; total=3; expire=4\r\ncontent-disposition: attachment; filename=\"airport.yaml\"\r\nContent-Length: 15\r\nConnection: close\r\n\r\nproxies: []\n\n\n\n",
    );
    let sub = core.add_subscription(server).unwrap();
    assert_eq!(sub.name, "airport");
    assert_eq!(sub.usage.as_ref().map(|u| u.total), Some(3));
    assert!(!sub.selected);
    core.select_profile(sub.id.clone()).unwrap();
    assert_eq!(core.status().profile_id.as_deref(), Some(sub.id.as_str()));
    core.remove_profile(sub.id.clone()).unwrap();
    assert_eq!(core.status().profile_id.as_deref(), Some(links.id.as_str()));
    assert!(core.update_profile(links.id.clone()).is_err());
    assert!(core.select_profile("missing".into()).is_err());
    core.shutdown();
    fs::remove_dir_all(dir).unwrap();
}

fn serve_once(reply: &'static str) -> String {
    let listener = TcpListener::bind("127.0.0.1:0").unwrap();
    let port = listener.local_addr().unwrap().port();
    thread::spawn(move || {
        let (mut stream, _) = listener.accept().unwrap();
        let mut buf = [0u8; 4096];
        let _ = stream.read(&mut buf);
        stream.write_all(reply.as_bytes()).unwrap();
    });
    format!("http://127.0.0.1:{port}/sub?token=secret")
}

#[test]
fn whitelist_entries_persist() {
    let dir = temp_dir();
    let core = Core::new(options(&dir)).unwrap();
    let added = core
        .add_whitelist_entries(
            "pgnfw_abcdefghijkl https://guguyun.com/w?token=xyz".into(),
            " home ".into(),
        )
        .unwrap();
    assert_eq!(added.len(), 2);
    assert_eq!(added[0].name, "home");
    assert_eq!(added[0].kind, WhitelistKind::Po0);
    assert_eq!(added[1].kind, WhitelistKind::Ggy);
    assert!(
        core.add_whitelist_entries("pgnfw_abcdefghijkl".into(), String::new())
            .unwrap()
            .is_empty()
    );
    assert!(
        core.add_whitelist_entries("nope".into(), String::new())
            .is_err()
    );
    core.remove_whitelist_entry(added[1].id.clone()).unwrap();
    core.set_whitelist_enabled(false).unwrap();
    core.shutdown();
    let reopened = Core::new(options(&dir)).unwrap();
    let state = reopened.whitelist();
    assert!(!state.enabled);
    assert_eq!(state.entries.len(), 1);
    assert_eq!(state.entries[0].label, "pgnfw_abcdef…");
    reopened.shutdown();
    fs::remove_dir_all(dir).unwrap();
}

#[test]
fn imports_the_flutter_app_once() {
    let dir = temp_dir();
    let prefs = dir.join("shared_preferences.json");
    let config = r#"{"po0FirewallProps":{"enable":true,"tokenEntries":[{"token":"pgnfw_legacy1","name":"old"}]}}"#;
    fs::write(&prefs, json!({ "flutter.config": config }).to_string()).unwrap();
    let mut opts = options(&dir);
    opts.legacy_prefs = Some(prefs.clone());
    let core = Core::new(opts.clone()).unwrap();
    let state = core.whitelist();
    assert!(state.enabled);
    assert_eq!(state.entries[0].name, "old");
    core.set_whitelist_enabled(false).unwrap();
    core.shutdown();
    let again = Core::new(opts).unwrap();
    assert!(!again.whitelist().enabled);
    again.shutdown();
    fs::remove_dir_all(dir).unwrap();
}

#[test]
fn diagnostics_never_contain_secrets() {
    let dir = temp_dir();
    let core = Core::new(options(&dir)).unwrap();
    core.add_whitelist_entries("pgnfw_topsecretvalue123".into(), String::new())
        .unwrap();
    logfile::info("request for pgnfw_topsecretvalue123 failed");
    let out = dir.join("diag.txt");
    core.export_diagnostics(out.clone()).unwrap();
    let text = fs::read_to_string(out).unwrap();
    assert!(text.contains("po0-clash diagnostics"));
    assert!(!text.contains("pgnfw_topsecretvalue123"), "{text}");
    core.shutdown();
    fs::remove_dir_all(dir).unwrap();
}

#[test]
fn a_subscription_without_content_is_downloaded_before_starting() {
    let dir = temp_dir();
    let database = dir.join("database.sqlite");
    let url = serve_once("HTTP/1.1 200 OK\r\nContent-Length: 6\r\nConnection: close\r\n\r\nmode: ");
    let connection = rusqlite::Connection::open(&database).unwrap();
    connection
        .execute_batch(&format!(
            r#"CREATE TABLE profiles (id INTEGER PRIMARY KEY, label TEXT NOT NULL, url TEXT NOT NULL, "order" INTEGER);
            INSERT INTO profiles VALUES (1, 'old', '{url}', 0);"#
        ))
        .unwrap();
    drop(connection);
    let mut opts = options(&dir);
    opts.legacy_database = Some(database);
    let core = Core::new(opts).unwrap();
    assert_eq!(core.profiles()[0].updated_at, None);
    let error = core.start(None).unwrap_err();
    assert!(
        error.to_string().contains("not a Clash/mihomo config"),
        "{error}"
    );
    core.shutdown();
    fs::remove_dir_all(dir).unwrap();
}

#[test]
fn settings_and_whitelist_results_survive_a_restart() {
    let dir = temp_dir();
    let core = Core::new(options(&dir)).unwrap();
    assert!(
        dir.join("core/settings.json").exists(),
        "written on first run"
    );
    let entry = core
        .add_whitelist_entries("pgnfw_persisted01".into(), String::new())
        .unwrap()
        .remove(0);
    core.shutdown();
    let result = WhitelistResult {
        outcome: WhitelistOutcome::Applied,
        ip: Some("1.2.3.4".into()),
        message: None,
        at: 1,
    };
    fs::write(
        dir.join("core/whitelist-results.json"),
        serde_json::to_vec(&std::collections::HashMap::from([(
            entry.id.clone(),
            result.clone(),
        )]))
        .unwrap(),
    )
    .unwrap();
    let reopened = Core::new(options(&dir)).unwrap();
    assert_eq!(reopened.whitelist().entries[0].result, Some(result));
    assert!(!reopened.was_connected());
    reopened.shutdown();
    fs::remove_dir_all(dir).unwrap();
}

#[test]
fn only_a_setuid_root_binary_is_privileged() {
    let dir = temp_dir();
    let binary = dir.join("mihomo");
    fs::write(&binary, "").unwrap();
    assert!(!engine::is_privileged(&binary));
    assert!(!engine::is_privileged(&dir.join("missing")));
    fs::remove_dir_all(dir).unwrap();
}

#[test]
fn starting_without_a_profile_fails_cleanly() {
    let dir = temp_dir();
    let core = Core::new(options(&dir)).unwrap();
    assert!(matches!(core.start(None), Err(CoreError::Invalid(_))));
    assert!(matches!(core.status().engine, EngineState::Failed(_)));
    assert!(core.groups().unwrap().is_empty());
    assert_eq!(core.traffic(), Traffic::default());
    core.shutdown();
    fs::remove_dir_all(dir).unwrap();
}

#[test]
fn profile_text_can_be_edited() {
    let dir = temp_dir();
    let core = Core::new(options(&dir)).unwrap();
    let yaml = "proxies:\n  - {name: a, type: ss, server: 1.2.3.4, port: 1, cipher: aes-128-gcm, password: p}\n";
    let file = core.import_file("work.yaml".into(), yaml.into()).unwrap();
    let edited = yaml.replace("name: a", "name: c");
    core.save_profile_content(file.id.clone(), edited.clone())
        .unwrap();
    assert_eq!(core.profile_content(file.id.clone()).unwrap(), edited);
    assert!(
        core.save_profile_content(file.id.clone(), "hello".into())
            .is_err()
    );
    assert_eq!(core.profile_content(file.id.clone()).unwrap(), edited);
    let links = core
        .import_links("ss://YWVzLTEyOC1nY206cA@1.2.3.4:1#b".into())
        .unwrap()
        .profile;
    assert!(
        core.save_profile_content(links.id.clone(), yaml.into())
            .is_err()
    );
    assert!(
        core.save_profile_content("missing".into(), yaml.into())
            .is_err()
    );
    core.shutdown();
    fs::remove_dir_all(dir).unwrap();
}

#[test]
fn file_profiles_can_be_edited_exported_previewed_and_ordered() {
    let dir = temp_dir();
    let core = Core::new(options(&dir)).unwrap();
    let yaml = "proxies:\n  - {name: a, type: ss, server: 1.2.3.4, port: 1, cipher: aes-128-gcm, password: p}\n";
    let first = core.import_file("work.yaml".into(), yaml.into()).unwrap();
    assert_eq!(
        (first.name.as_str(), first.kind, first.selected),
        ("work", ProfileKind::File, true)
    );
    assert!(matches!(
        core.import_file("x.txt".into(), "hello".into()),
        Err(CoreError::Invalid(_))
    ));
    let links = "ss://YWVzLTEyOC1nY206cA@1.2.3.4:1#b";
    let second = core.import_file("nodes.txt".into(), links.into()).unwrap();
    assert_eq!(core.profile_content(second.id.clone()).unwrap(), links);
    assert!(matches!(
        core.update_profile(first.id.clone()),
        Err(CoreError::Invalid(_))
    ));

    let edited = core
        .edit_profile(
            first.id.clone(),
            ProfileEdit {
                name: " Work ".into(),
                url: Some("https://ignored.example".into()),
                auto_update: false,
                update_hours: 0,
            },
        )
        .unwrap();
    assert_eq!(
        (
            edited.name.as_str(),
            edited.url,
            edited.auto_update,
            edited.update_hours
        ),
        ("Work", None, false, 1)
    );
    assert!(
        core.edit_profile(
            first.id.clone(),
            ProfileEdit {
                name: " ".into(),
                url: None,
                auto_update: true,
                update_hours: 24,
            },
        )
        .is_err()
    );

    let preview = core.preview_config(first.id.clone()).unwrap();
    assert!(preview.contains("name: a"), "{preview}");
    assert!(preview.contains("<hidden>"));
    assert!(
        core.preview_config(second.id.clone())
            .unwrap()
            .contains("po0-links-")
    );

    core.reorder_profiles(vec![second.id.clone()]).unwrap();
    let order: Vec<String> = core.profiles().into_iter().map(|p| p.id).collect();
    assert_eq!(order, [second.id, first.id]);
    core.shutdown();
    fs::remove_dir_all(dir).unwrap();
}

/// Runs the real engine: `MIHOMO_BIN=/path/to/mihomo cargo test -- --ignored engine`.
#[cfg(unix)]
#[test]
#[ignore = "needs MIHOMO_BIN and network access"]
fn engine_runs_a_real_mihomo() {
    let binary = PathBuf::from(std::env::var("MIHOMO_BIN").expect("MIHOMO_BIN"));
    let dir = temp_dir();
    let port = TcpListener::bind("127.0.0.1:0")
        .unwrap()
        .local_addr()
        .unwrap()
        .port();
    let server_dir = dir.join("server");
    fs::create_dir_all(&server_dir).unwrap();
    fs::write(
        server_dir.join("config.yaml"),
        format!(
            "log-level: warning\nlisteners:\n  - {{name: ss-in, type: shadowsocks, listen: 127.0.0.1, port: {port}, cipher: aes-128-gcm, password: test-password-123}}\n"
        ),
    )
    .unwrap();
    let mut server = std::process::Command::new(&binary)
        .args([
            "-d",
            server_dir.to_str().unwrap(),
            "-f",
            server_dir.join("config.yaml").to_str().unwrap(),
        ])
        .spawn()
        .unwrap();
    thread::sleep(Duration::from_secs(1));

    let core = Core::new(options(&dir)).unwrap();
    let userinfo = base64::Engine::encode(
        &base64::engine::general_purpose::STANDARD,
        "aes-128-gcm:test-password-123",
    );
    core.import_links(format!("ss://{userinfo}@127.0.0.1:{port}#local-ss"))
        .unwrap();
    let mut engine_options = core.engine_options();
    engine_options.log_level = LogLevel::Info;
    core.set_engine_options(engine_options).unwrap();
    core.start(None).unwrap();
    assert_eq!(core.status().engine, EngineState::Running);

    let groups = core.groups().unwrap();
    let group = groups
        .iter()
        .find(|g| g.name == "PROXY")
        .expect("PROXY group");
    assert_eq!(
        group
            .nodes
            .iter()
            .map(|n| n.name.as_str())
            .collect::<Vec<_>>(),
        ["local-ss"]
    );
    assert_eq!(core.status().current_node.as_deref(), Some("local-ss"));
    let tested = core.test_delay("PROXY".into()).unwrap();
    assert!(tested.nodes[0].delay.unwrap_or(0) > 0, "{tested:?}");

    let exit = core.exit_ip().unwrap();
    assert!(!exit.ip.is_empty());
    thread::sleep(Duration::from_millis(1500));

    let mixed = core.proxy_url().unwrap();
    let mut held = std::net::TcpStream::connect(mixed.trim_start_matches("http://")).unwrap();
    write!(held, "CONNECT 127.0.0.1:{port} HTTP/1.1\r\n\r\n").unwrap();
    thread::sleep(Duration::from_millis(2500));
    let target = format!("127.0.0.1:{port}");
    let connections = core.connections();
    assert!(
        connections.items.iter().any(|c| c.host == target),
        "{connections:?}"
    );
    assert!(connections.download_total > 0);
    assert!(core.requests().iter().any(|c| c.host == target));
    assert!(
        core.logs().iter().any(|l| l.message.contains(&target)),
        "{:?}",
        core.logs()
    );
    assert!(!core.traffic_history().is_empty());
    assert!(core.memory() > 0);
    core.close_all_connections().unwrap();
    assert!(core.connections().items.iter().all(|c| c.host != target));
    drop(held);
    assert!(core.test_node_delay("local-ss".into()).unwrap() > 0);
    assert!(!core.rules().unwrap().is_empty());
    let providers = core.providers().unwrap();
    let links = providers
        .iter()
        .find(|p| p.kind == ProviderKind::Proxy && p.vehicle == "File")
        .unwrap_or_else(|| panic!("{providers:?}"));
    assert_eq!(links.count, 1);
    core.update_provider(ProviderKind::Proxy, links.name.clone())
        .unwrap();
    assert_eq!(core.geo_files().len(), 4);

    core.set_mode(Mode::Global).unwrap();
    assert_eq!(core.groups().unwrap()[0].name, "GLOBAL");
    core.set_mode(Mode::Rule).unwrap();
    core.import_links(format!("ss://{userinfo}@127.0.0.1:{port}#second"))
        .unwrap();
    let nodes = core.groups().unwrap()[0].nodes.len();
    assert_eq!(nodes, 2, "reload picked up the new link");
    core.select_node("PROXY".into(), "second".into()).unwrap();
    assert_eq!(core.status().current_node.as_deref(), Some("second"));

    let pid: u32 =
        serde_json::from_slice::<Value>(&fs::read(dir.join("core/run/session.json")).unwrap())
            .unwrap()["pid"]
            .as_u64()
            .unwrap() as u32;
    unsafe { libc::kill(pid as i32, libc::SIGKILL) };
    thread::sleep(Duration::from_secs(2));
    assert!(
        matches!(core.status().engine, EngineState::Failed(_)),
        "{:?}",
        core.status()
    );

    core.start(None).unwrap();
    assert_eq!(core.status().engine, EngineState::Running);
    assert!(core.was_connected());
    core.shutdown();
    let reopened = Core::new(options(&dir)).unwrap();
    assert!(reopened.was_connected(), "quitting keeps the intent");
    reopened.start(None).unwrap();
    reopened.stop();
    assert_eq!(reopened.status().engine, EngineState::Stopped);
    assert!(reopened.connections().items.is_empty());
    assert!(reopened.traffic_history().is_empty());
    assert!(!reopened.was_connected());
    reopened.shutdown();
    server.kill().unwrap();
    server.wait().unwrap();
    fs::remove_dir_all(dir).unwrap();
}

#[test]
fn groups_carry_their_icon() {
    let proxies = json!({
        "Proxy": {"type": "Selector", "now": "a", "all": ["a"], "icon": " https://example.com/hk.png "},
        "Auto": {"type": "URLTest", "now": "a", "all": ["a"], "icon": ""},
        "a": {"type": "Shadowsocks", "history": [{"delay": 42}]},
    });
    let proxies = proxies.as_object().unwrap();
    let group = Core::build_group(proxies, "Proxy").unwrap();
    assert_eq!(group.icon.as_deref(), Some("https://example.com/hk.png"));
    assert_eq!(group.nodes[0].delay, Some(42));
    assert_eq!(Core::build_group(proxies, "Auto").unwrap().icon, None);
}

#[test]
fn a_backup_restores_profiles_and_settings() {
    let dir = temp_dir();
    let core = Core::new(options(&dir)).unwrap();
    let saved = core.import_links("vless://u@h:1#a".into()).unwrap().profile;
    core.set_mode(Mode::Global).unwrap();
    core.set_app_settings(AppSettings {
        pure_black: true,
        ..core.app_settings()
    })
    .unwrap();
    let backup = core.backup().unwrap();
    core.shutdown();

    let other = temp_dir();
    let restored = Core::new(options(&other)).unwrap();
    let local = restored
        .import_file("local.yaml".into(), "proxies: []\n".into())
        .unwrap();
    restored
        .restore(backup.clone(), RestoreScope::Profiles)
        .unwrap();
    assert_eq!(
        restored.profiles().len(),
        2,
        "the default strategy keeps local profiles"
    );
    assert_eq!(restored.status().mode, Mode::Rule);
    assert!(!restored.app_settings().pure_black);

    restored
        .set_app_settings(AppSettings {
            restore_strategy: RestoreStrategy::Override,
            ..restored.app_settings()
        })
        .unwrap();
    restored.restore(backup, RestoreScope::All).unwrap();
    let profiles = restored.profiles();
    assert_eq!(profiles.len(), 1);
    assert_eq!(profiles[0].id, saved.id);
    assert!(profiles[0].selected);
    assert_eq!(restored.status().mode, Mode::Global);
    assert!(restored.app_settings().pure_black);
    assert!(restored.profile_content(local.id).is_err());
    assert!(
        restored
            .restore(b"not a zip".to_vec(), RestoreScope::All)
            .is_err()
    );
    restored.shutdown();
    fs::remove_dir_all(dir).unwrap();
    fs::remove_dir_all(other).unwrap();
}

/// A WebDAV server holding one file, which answers each request on its own connection and logs its request line.
fn serve_webdav() -> (String, Arc<Mutex<Vec<String>>>) {
    let listener = TcpListener::bind("127.0.0.1:0").unwrap();
    let port = listener.local_addr().unwrap().port();
    let log = Arc::new(Mutex::new(Vec::new()));
    let seen = log.clone();
    thread::spawn(move || {
        let mut stored: Option<Vec<u8>> = None;
        for stream in listener.incoming() {
            let mut stream = stream.unwrap();
            let mut data = Vec::new();
            let mut buf = [0u8; 8192];
            let head_end = loop {
                if let Some(at) = data.windows(4).position(|w| w == b"\r\n\r\n") {
                    break at + 4;
                }
                let read = stream.read(&mut buf).unwrap();
                assert!(read > 0, "the request ended early");
                data.extend_from_slice(&buf[..read]);
            };
            let head = String::from_utf8_lossy(&data[..head_end]).to_ascii_lowercase();
            let length: usize = head
                .lines()
                .find_map(|line| line.strip_prefix("content-length:"))
                .map_or(0, |value| value.trim().parse().unwrap());
            while data.len() < head_end + length {
                let read = stream.read(&mut buf).unwrap();
                data.extend_from_slice(&buf[..read]);
            }
            let line = head
                .lines()
                .next()
                .unwrap()
                .trim_end_matches(" http/1.1")
                .to_owned();
            lock(&seen).push(line.clone());
            let reply = |status: &str, body: &[u8]| {
                let mut reply = format!(
                    "HTTP/1.1 {status}\r\nContent-Length: {}\r\nConnection: close\r\n\r\n",
                    body.len()
                )
                .into_bytes();
                reply.extend_from_slice(body);
                reply
            };
            let response = if !head.contains("authorization: basic dxnlcjpwyxnz") {
                reply("401 Unauthorized", b"")
            } else if line == "propfind /dav/" {
                reply("207 Multi-Status", b"<multistatus xmlns=\"DAV:\"/>")
            } else if line == "mkcol /dav/po0-clash/" {
                reply("201 Created", b"")
            } else if line == "put /dav/po0-clash/backup.zip" {
                stored = Some(data[head_end..].to_vec());
                reply("201 Created", b"")
            } else if let ("get /dav/po0-clash/backup.zip", Some(file)) = (line.as_str(), &stored) {
                reply("200 OK", file)
            } else {
                reply("404 Not Found", b"")
            };
            stream.write_all(&response).unwrap();
        }
    });
    (format!("http://127.0.0.1:{port}/dav"), log)
}

#[test]
fn backups_go_to_webdav_and_come_back() {
    let dir = temp_dir();
    let core = Core::new(options(&dir)).unwrap();
    let links = core.import_links("vless://u@h:1#b".into()).unwrap().profile;
    let (url, requests) = serve_webdav();
    let dav = WebDav {
        url,
        user: "user".into(),
        password: "pass".into(),
        file_name: String::new(),
    };
    let wrong = WebDav {
        password: "wrong".into(),
        ..dav.clone()
    };
    assert!(core.check_webdav(wrong).is_err());
    core.check_webdav(dav.clone()).unwrap();
    assert!(core.backup_to_webdav().is_err(), "nothing set up yet");
    core.set_app_settings(AppSettings {
        webdav: Some(dav),
        ..core.app_settings()
    })
    .unwrap();
    assert!(
        core.restore_from_webdav(RestoreScope::All).is_err(),
        "nothing uploaded yet"
    );
    core.backup_to_webdav().unwrap();
    core.remove_profile(links.id.clone()).unwrap();
    core.restore_from_webdav(RestoreScope::Profiles).unwrap();
    assert_eq!(core.profiles()[0].id, links.id);
    assert_eq!(core.profile_content(links.id).unwrap(), "vless://u@h:1#b");
    assert_eq!(
        *lock(&requests),
        [
            "propfind /dav/",
            "propfind /dav/",
            "get /dav/po0-clash/backup.zip",
            "mkcol /dav/po0-clash/",
            "put /dav/po0-clash/backup.zip",
            "get /dav/po0-clash/backup.zip",
        ]
    );
    core.shutdown();
    fs::remove_dir_all(dir).unwrap();
}
