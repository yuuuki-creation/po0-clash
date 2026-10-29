use std::fmt;
use std::sync::{Mutex, MutexGuard, PoisonError};
use std::time::{Duration, Instant};

use ureq::config::IpFamily;
use ureq::{Agent, Proxy};

use super::route::{self, Hop};

const CONNECT_TIMEOUT: Duration = Duration::from_secs(5);
const IDLE_TIMEOUT: Duration = Duration::from_secs(30);
const MAX_REDIRECTS: u32 = 5;
const BODY_LIMIT: u64 = 1 << 20;
const USER_AGENT: &str = "po0-clash";
const CONTENT_TYPE: &str = "application/json; charset=utf-8";

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum Method {
    Get,
    Post,
}

impl Method {
    pub fn parse(method: &str) -> Result<Self, SendError> {
        match method {
            "GET" => Ok(Self::Get),
            "POST" => Ok(Self::Post),
            _ => Err(SendError::Invalid("unsupported method")),
        }
    }
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct Response {
    pub status: u16,
    pub body: String,
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub enum SendError {
    Invalid(&'static str),
    Timeout,
    Failed(String),
}

impl SendError {
    /// Whitelist URLs carry credentials, so no message may repeat one.
    fn from_ureq(error: ureq::Error, url: &str) -> Self {
        match error {
            ureq::Error::Timeout(_) => Self::Timeout,
            ureq::Error::BadUri(_) | ureq::Error::Http(_) => Self::Invalid("invalid url"),
            other => Self::Failed(other.to_string().replace(url, "<url>")),
        }
    }
}

impl fmt::Display for SendError {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            Self::Invalid(reason) => f.write_str(reason),
            Self::Timeout => f.write_str("timed out"),
            Self::Failed(reason) => f.write_str(reason),
        }
    }
}

impl std::error::Error for SendError {}

/// Keeps the DIRECT agent and the agent of the latest proxy. A failure drops
/// both: the socket it used may belong to a network that is already gone.
#[derive(Default)]
pub struct Transport {
    pool: Mutex<Pool>,
}

#[derive(Default)]
struct Pool {
    generation: u64,
    direct: Option<Agent>,
    proxy: Option<(String, Agent)>,
}

impl Transport {
    pub fn send(
        &self,
        method: Method,
        url: &str,
        route: &str,
        timeout: Duration,
    ) -> Result<Response, SendError> {
        let hops = route::parse(route).map_err(|_| SendError::Invalid("invalid route"))?;
        let (generation, agents) = self.agents(&hops)?;
        let deadline = Instant::now() + timeout;
        let mut failure = SendError::Timeout;
        for agent in &agents {
            let remaining = deadline.saturating_duration_since(Instant::now());
            if remaining.is_zero() {
                failure = SendError::Timeout;
                break;
            }
            match execute(agent, method, url, remaining) {
                Ok(response) => return Ok(response),
                Err(error) => failure = error,
            }
        }
        let mut pool = self.lock();
        if pool.generation == generation {
            pool.clear();
        }
        Err(failure)
    }

    pub fn reset(&self) {
        self.lock().clear();
    }

    fn agents(&self, hops: &[Hop]) -> Result<(u64, Vec<Agent>), SendError> {
        let mut pool = self.lock();
        let mut agents = Vec::with_capacity(hops.len());
        for hop in hops {
            let agent = match hop {
                Hop::Direct => pool.direct.get_or_insert_with(|| new_agent(None)).clone(),
                Hop::Proxy(uri) => pool.proxy_agent(uri)?,
            };
            agents.push(agent);
        }
        Ok((pool.generation, agents))
    }

    fn lock(&self) -> MutexGuard<'_, Pool> {
        self.pool.lock().unwrap_or_else(PoisonError::into_inner)
    }
}

impl Pool {
    fn proxy_agent(&mut self, uri: &str) -> Result<Agent, SendError> {
        if let Some((current, agent)) = &self.proxy {
            if current == uri {
                return Ok(agent.clone());
            }
        }
        let proxy = Proxy::new(uri).map_err(|_| SendError::Invalid("invalid route"))?;
        let agent = new_agent(Some(proxy));
        self.proxy = Some((uri.to_owned(), agent.clone()));
        Ok(agent)
    }

    fn clear(&mut self) {
        self.generation += 1;
        self.direct = None;
        self.proxy = None;
    }
}

/// Both services whitelist the caller's IPv4 /24, so a request must never leave over IPv6.
fn new_agent(proxy: Option<Proxy>) -> Agent {
    Agent::new_with_config(
        Agent::config_builder()
            .ip_family(IpFamily::Ipv4Only)
            .proxy(proxy)
            .timeout_connect(Some(CONNECT_TIMEOUT))
            .max_idle_age(IDLE_TIMEOUT)
            .max_redirects(MAX_REDIRECTS)
            .http_status_as_error(false)
            .user_agent(USER_AGENT)
            .build(),
    )
}

fn execute(
    agent: &Agent,
    method: Method,
    url: &str,
    timeout: Duration,
) -> Result<Response, SendError> {
    let failed = |error: ureq::Error| SendError::from_ureq(error, url);
    let sent = match method {
        Method::Get => agent
            .get(url)
            .header("content-type", CONTENT_TYPE)
            .config()
            .timeout_global(Some(timeout))
            .build()
            .call(),
        Method::Post => agent
            .post(url)
            .header("content-type", CONTENT_TYPE)
            .config()
            .timeout_global(Some(timeout))
            .build()
            .send_empty(),
    };
    let mut response = sent.map_err(failed)?;
    let status = response.status().as_u16();
    let body = response
        .body_mut()
        .with_config()
        .limit(BODY_LIMIT)
        .read_to_string()
        .map_err(failed)?;
    Ok(Response { status, body })
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::io::{copy, BufRead, BufReader, Write};
    use std::net::{Shutdown, TcpListener, TcpStream};
    use std::sync::atomic::{AtomicUsize, Ordering::SeqCst};
    use std::sync::{mpsc, Arc};
    use std::thread;

    const SECOND: Duration = Duration::from_secs(1);

    struct Server {
        port: u16,
        heads: mpsc::Receiver<String>,
        connections: Arc<AtomicUsize>,
    }

    impl Server {
        fn url(&self, path: &str) -> String {
            format!("http://127.0.0.1:{}{path}", self.port)
        }

        fn head(&self) -> String {
            self.heads
                .recv_timeout(SECOND * 5)
                .expect("a request arrived")
        }

        fn connections(&self) -> usize {
            self.connections.load(SeqCst)
        }
    }

    fn serve<F>(handle: F) -> Server
    where
        F: Fn(BufReader<TcpStream>, TcpStream, mpsc::Sender<String>) + Send + Sync + 'static,
    {
        let listener = TcpListener::bind("127.0.0.1:0").unwrap();
        let port = listener.local_addr().unwrap().port();
        let (sender, heads) = mpsc::channel();
        let connections = Arc::new(AtomicUsize::new(0));
        let accepted = connections.clone();
        let handle = Arc::new(handle);
        thread::spawn(move || {
            for stream in listener.incoming().flatten() {
                accepted.fetch_add(1, SeqCst);
                let (handle, sender) = (handle.clone(), sender.clone());
                thread::spawn(move || {
                    let reader = BufReader::new(stream.try_clone().unwrap());
                    handle(reader, stream, sender);
                });
            }
        });
        Server {
            port,
            heads,
            connections,
        }
    }

    fn read_head(reader: &mut BufReader<TcpStream>) -> Option<String> {
        let mut head = String::new();
        loop {
            let mut line = String::new();
            if reader.read_line(&mut line).ok()? == 0 {
                return None;
            }
            head.push_str(&line);
            if line == "\r\n" {
                return Some(head);
            }
        }
    }

    fn header<'a>(head: &'a str, name: &str) -> Option<&'a str> {
        head.lines().find_map(|line| {
            let (key, value) = line.split_once(':')?;
            key.eq_ignore_ascii_case(name).then(|| value.trim())
        })
    }

    /// Answers every request on a connection, which stays open for the next one.
    fn origin(status: u16, body: &'static str) -> Server {
        serve(move |mut reader, mut stream, heads| {
            while let Some(head) = read_head(&mut reader) {
                heads.send(head).ok();
                let reply = format!(
                    "HTTP/1.1 {status} X\r\ncontent-length: {}\r\n\r\n{body}",
                    body.len()
                );
                if stream.write_all(reply.as_bytes()).is_err() {
                    return;
                }
            }
        })
    }

    fn connect_proxy() -> Server {
        serve(|mut reader, mut stream, heads| {
            let Some(head) = read_head(&mut reader) else {
                return;
            };
            heads.send(head.clone()).ok();
            if header(&head, "proxy-authorization") != Some("Basic dXNlcjpwYXNz") {
                stream
                    .write_all(
                        b"HTTP/1.1 407 Proxy Authentication Required\r\ncontent-length: 0\r\n\r\n",
                    )
                    .ok();
                return;
            }
            let target = head.split_whitespace().nth(1).unwrap_or_default();
            let Ok(upstream) = TcpStream::connect(target) else {
                return;
            };
            stream
                .write_all(b"HTTP/1.1 200 Connection established\r\n\r\n")
                .ok();
            let mut upstream_writer = upstream.try_clone().unwrap();
            thread::spawn(move || {
                copy(&mut reader, &mut upstream_writer).ok();
                upstream_writer.shutdown(Shutdown::Write).ok();
            });
            let mut upstream = upstream;
            copy(&mut upstream, &mut stream).ok();
            stream.shutdown(Shutdown::Write).ok();
        })
    }

    fn stalled() -> Server {
        serve(|mut reader, _stream, heads| {
            if let Some(head) = read_head(&mut reader) {
                heads.send(head).ok();
            }
            thread::sleep(SECOND * 10);
        })
    }

    fn closed_port() -> u16 {
        TcpListener::bind("127.0.0.1:0")
            .unwrap()
            .local_addr()
            .unwrap()
            .port()
    }

    fn get(transport: &Transport, url: &str, route: &str) -> Result<Response, SendError> {
        transport.send(Method::Get, url, route, SECOND * 5)
    }

    #[test]
    fn direct_requests_return_any_status_with_its_body() {
        let server = origin(503, "busy");
        let response = get(&Transport::default(), &server.url("/api"), "DIRECT");
        assert_eq!(
            response,
            Ok(Response {
                status: 503,
                body: "busy".into()
            })
        );
        let head = server.head();
        assert!(head.starts_with("GET /api HTTP/1.1\r\n"), "{head}");
        assert_eq!(header(&head, "content-type"), Some(CONTENT_TYPE));
        assert_eq!(header(&head, "user-agent"), Some(USER_AGENT));
    }

    #[test]
    fn posts_carry_an_empty_body() {
        let server = origin(200, "{}");
        let transport = Transport::default();
        transport
            .send(Method::Post, &server.url("/add"), "DIRECT", SECOND * 5)
            .unwrap();
        let head = server.head();
        assert!(head.starts_with("POST /add HTTP/1.1\r\n"), "{head}");
        assert_eq!(header(&head, "content-length"), Some("0"));
    }

    #[test]
    fn proxies_tunnel_with_the_session_login() {
        let server = origin(200, "ok");
        let proxy = connect_proxy();
        let route = format!("PROXY user:pass@127.0.0.1:{}", proxy.port);
        let response = get(&Transport::default(), &server.url("/"), &route).unwrap();
        assert_eq!(response.body, "ok");
        let head = proxy.head();
        let expected = format!("CONNECT 127.0.0.1:{} HTTP/1.1\r\n", server.port);
        assert!(head.starts_with(&expected), "{head}");
    }

    #[test]
    fn a_wrong_login_never_reaches_the_target() {
        let server = origin(200, "ok");
        let proxy = connect_proxy();
        let route = format!("PROXY user:nope@127.0.0.1:{}", proxy.port);
        assert!(get(&Transport::default(), &server.url("/"), &route).is_err());
        assert_eq!(server.connections(), 0);
    }

    #[test]
    fn only_a_listed_direct_hop_replaces_a_dead_proxy() {
        let server = origin(200, "ok");
        let dead = format!("PROXY user:pass@127.0.0.1:{}", closed_port());
        let transport = Transport::default();
        assert!(get(&transport, &server.url("/"), &dead).is_err());
        assert_eq!(server.connections(), 0);
        let response = get(&transport, &server.url("/"), &format!("{dead}; DIRECT")).unwrap();
        assert_eq!(response.body, "ok");
    }

    #[test]
    fn a_silent_server_runs_out_the_deadline() {
        let server = stalled();
        let started = Instant::now();
        let result = Transport::default().send(
            Method::Get,
            &server.url("/"),
            "DIRECT",
            Duration::from_millis(300),
        );
        assert_eq!(result, Err(SendError::Timeout));
        assert!(started.elapsed() < SECOND * 3);
    }

    #[test]
    fn requests_never_leave_over_ipv6() {
        let Ok(listener) = TcpListener::bind("[::1]:0") else {
            return;
        };
        listener.set_nonblocking(true).unwrap();
        let url = format!("http://[::1]:{}/", listener.local_addr().unwrap().port());
        assert!(get(&Transport::default(), &url, "DIRECT").is_err());
        assert!(listener.accept().is_err());
    }

    #[test]
    fn connections_are_pooled_until_a_reset_or_a_failure() {
        let server = origin(200, "ok");
        let transport = Transport::default();
        get(&transport, &server.url("/"), "DIRECT").unwrap();
        get(&transport, &server.url("/"), "DIRECT").unwrap();
        assert_eq!(server.connections(), 1);

        transport.reset();
        get(&transport, &server.url("/"), "DIRECT").unwrap();
        assert_eq!(server.connections(), 2);

        let dead = format!("http://127.0.0.1:{}/", closed_port());
        assert!(get(&transport, &dead, "DIRECT").is_err());
        get(&transport, &server.url("/"), "DIRECT").unwrap();
        assert_eq!(server.connections(), 3);
    }

    #[test]
    fn refuses_what_it_cannot_send_without_echoing_the_url() {
        let transport = Transport::default();
        assert_eq!(
            Method::parse("PUT"),
            Err(SendError::Invalid("unsupported method"))
        );
        assert_eq!(
            get(&transport, "http://127.0.0.1/", "SOCKS 127.0.0.1:1"),
            Err(SendError::Invalid("invalid route"))
        );
        let error = get(&transport, "http://exa mple/pgnfw_secret", "DIRECT").unwrap_err();
        assert!(!error.to_string().contains("pgnfw_secret"), "{error}");
    }

    #[test]
    #[ignore = "reaches the real po0 API"]
    fn the_po0_certificate_verifies() {
        let response = new_agent(None)
            .get("https://124.221.69.228/")
            .config()
            .max_redirects(0)
            .build()
            .call();
        assert!(response.is_ok(), "{response:?}");
    }
}
