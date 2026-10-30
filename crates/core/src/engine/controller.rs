use std::io::{self, BufRead, BufReader, Read, Write};
use std::path::PathBuf;
use std::sync::atomic::{AtomicBool, Ordering};
use std::time::Duration;

use serde_json::Value;

use crate::error::{CoreError, Result};

const TIMEOUT: Duration = Duration::from_secs(15);

#[derive(Debug, Clone, PartialEq, Eq)]
pub enum Endpoint {
    Unix(PathBuf),
    Pipe(String),
}

impl Endpoint {
    pub fn config_entry(&self) -> (&'static str, String) {
        match self {
            Self::Unix(path) => (
                "external-controller-unix",
                path.to_string_lossy().into_owned(),
            ),
            Self::Pipe(name) => ("external-controller-pipe", name.clone()),
        }
    }

    pub fn describe(&self) -> String {
        self.config_entry().1
    }

    #[cfg_attr(target_os = "android", allow(dead_code))]
    pub fn parse(text: &str) -> Self {
        if text.starts_with(r"\\.\pipe\") {
            Self::Pipe(text.to_owned())
        } else {
            Self::Unix(PathBuf::from(text))
        }
    }
}

trait Conn: Read + Write + Send {}
impl<T: Read + Write + Send> Conn for T {}

/// A minimal HTTP/1.1 client for mihomo's external-controller over a Unix socket or named pipe.
#[derive(Debug, Clone)]
pub struct Controller {
    pub endpoint: Endpoint,
    secret: String,
}

impl Controller {
    pub fn new(endpoint: Endpoint, secret: String) -> Self {
        Self { endpoint, secret }
    }

    pub fn secret(&self) -> &str {
        &self.secret
    }

    fn connect(&self, timeout: Option<Duration>) -> io::Result<Box<dyn Conn>> {
        match &self.endpoint {
            #[cfg(unix)]
            Endpoint::Unix(path) => {
                let stream = std::os::unix::net::UnixStream::connect(path)?;
                stream.set_read_timeout(timeout)?;
                stream.set_write_timeout(Some(TIMEOUT))?;
                Ok(Box::new(stream))
            }
            #[cfg(windows)]
            Endpoint::Pipe(name) => {
                let _ = timeout;
                const ERROR_PIPE_BUSY: i32 = 231;
                let mut attempts = 0;
                loop {
                    match std::fs::OpenOptions::new()
                        .read(true)
                        .write(true)
                        .open(name)
                    {
                        Ok(file) => return Ok(Box::new(file)),
                        Err(error)
                            if error.raw_os_error() == Some(ERROR_PIPE_BUSY) && attempts < 40 =>
                        {
                            attempts += 1;
                            std::thread::sleep(Duration::from_millis(50));
                        }
                        Err(error) => return Err(error),
                    }
                }
            }
            #[allow(unreachable_patterns)]
            _ => {
                let _ = timeout;
                Err(io::Error::new(
                    io::ErrorKind::Unsupported,
                    "controller endpoint",
                ))
            }
        }
    }

    fn send(
        &self,
        method: &str,
        path: &str,
        body: Option<&Value>,
        timeout: Option<Duration>,
    ) -> io::Result<BufReader<Box<dyn Conn>>> {
        let mut conn = self.connect(timeout)?;
        let body = body.map(Value::to_string).unwrap_or_default();
        let head = format!(
            "{method} {path} HTTP/1.1\r\nHost: mihomo\r\nAuthorization: Bearer {}\r\nConnection: close\r\nContent-Type: application/json\r\nContent-Length: {}\r\n\r\n",
            self.secret,
            body.len()
        );
        conn.write_all(head.as_bytes())?;
        conn.write_all(body.as_bytes())?;
        conn.flush()?;
        Ok(BufReader::new(conn))
    }

    pub fn request(
        &self,
        method: &str,
        path: &str,
        body: Option<&Value>,
    ) -> io::Result<(u16, String)> {
        self.request_within(method, path, body, TIMEOUT)
    }

    fn request_within(
        &self,
        method: &str,
        path: &str,
        body: Option<&Value>,
        timeout: Duration,
    ) -> io::Result<(u16, String)> {
        let mut reader = self.send(method, path, body, Some(timeout))?;
        let (status, chunked, length) = read_head(&mut reader)?;
        let mut bytes = Vec::new();
        if chunked {
            while let Some(chunk) = read_chunk(&mut reader)? {
                bytes.extend_from_slice(&chunk);
            }
        } else if let Some(length) = length {
            bytes.resize(length, 0);
            reader.read_exact(&mut bytes)?;
        } else {
            reader.read_to_end(&mut bytes)?;
        }
        Ok((status, String::from_utf8_lossy(&bytes).into_owned()))
    }

    pub fn json(&self, method: &str, path: &str, body: Option<&Value>) -> Result<Value> {
        self.json_within(method, path, body, TIMEOUT)
    }

    /// For calls that make mihomo download something, which can take far longer than a lookup.
    pub fn json_within(
        &self,
        method: &str,
        path: &str,
        body: Option<&Value>,
        timeout: Duration,
    ) -> Result<Value> {
        let (status, text) = self
            .request_within(method, path, body, timeout)
            .map_err(|error| CoreError::Engine(format!("controller: {error}")))?;
        let value: Value = serde_json::from_str(&text).unwrap_or(Value::Null);
        if !(200..300).contains(&status) {
            let message = value
                .get("message")
                .and_then(Value::as_str)
                .map_or_else(|| format!("HTTP {status}"), str::to_owned);
            return Err(CoreError::Engine(message));
        }
        Ok(value)
    }

    /// Reads a streaming endpoint such as `/traffic` line by line until `stop` or an error.
    pub fn stream(
        &self,
        path: &str,
        stop: &AtomicBool,
        mut on_line: impl FnMut(&str),
    ) -> io::Result<()> {
        let mut reader = self.send("GET", path, None, Some(Duration::from_secs(5)))?;
        let (status, chunked, _) = read_head(&mut reader)?;
        if status != 200 {
            return Err(io::Error::other(format!("HTTP {status}")));
        }
        let mut pending = Vec::new();
        while !stop.load(Ordering::SeqCst) {
            let chunk = if chunked {
                match read_chunk(&mut reader)? {
                    Some(chunk) => chunk,
                    None => return Ok(()),
                }
            } else {
                let mut line = Vec::new();
                if reader.read_until(b'\n', &mut line)? == 0 {
                    return Ok(());
                }
                line
            };
            pending.extend_from_slice(&chunk);
            while let Some(end) = pending.iter().position(|b| *b == b'\n') {
                let line: Vec<u8> = pending.drain(..=end).collect();
                let line = String::from_utf8_lossy(&line);
                if !line.trim().is_empty() {
                    on_line(line.trim());
                }
            }
        }
        Ok(())
    }
}

fn read_line(reader: &mut impl BufRead) -> io::Result<String> {
    let mut line = String::new();
    if reader.read_line(&mut line)? == 0 {
        return Err(io::Error::new(
            io::ErrorKind::UnexpectedEof,
            "connection closed",
        ));
    }
    Ok(line.trim_end_matches(['\r', '\n']).to_owned())
}

fn read_head(reader: &mut impl BufRead) -> io::Result<(u16, bool, Option<usize>)> {
    let status_line = read_line(reader)?;
    let status = status_line
        .split_whitespace()
        .nth(1)
        .and_then(|code| code.parse().ok())
        .ok_or_else(|| io::Error::new(io::ErrorKind::InvalidData, "bad status line"))?;
    let (mut chunked, mut length) = (false, None);
    loop {
        let line = read_line(reader)?;
        if line.is_empty() {
            return Ok((status, chunked, length));
        }
        let Some((name, value)) = line.split_once(':') else {
            continue;
        };
        let (name, value) = (name.trim().to_ascii_lowercase(), value.trim());
        if name == "transfer-encoding" && value.to_ascii_lowercase().contains("chunked") {
            chunked = true;
        } else if name == "content-length" {
            length = value.parse().ok();
        }
    }
}

fn read_chunk(reader: &mut impl BufRead) -> io::Result<Option<Vec<u8>>> {
    let size_line = read_line(reader)?;
    let size = usize::from_str_radix(size_line.split(';').next().unwrap_or("").trim(), 16)
        .map_err(|_| io::Error::new(io::ErrorKind::InvalidData, "bad chunk size"))?;
    if size == 0 {
        let _ = read_line(reader);
        return Ok(None);
    }
    let mut chunk = vec![0; size];
    reader.read_exact(&mut chunk)?;
    read_line(reader)?;
    Ok(Some(chunk))
}

#[cfg(all(test, unix))]
mod tests {
    use super::*;
    use std::os::unix::net::UnixListener;
    use std::thread;

    fn serve(reply: &'static str) -> (Controller, thread::JoinHandle<String>) {
        let dir = std::env::temp_dir().join(format!("po0-ctl-{}", crate::util::random_id()));
        std::fs::create_dir_all(&dir).unwrap();
        let path = dir.join("ctl.sock");
        let listener = UnixListener::bind(&path).unwrap();
        let handle = thread::spawn(move || {
            let (mut stream, _) = listener.accept().unwrap();
            let mut reader = BufReader::new(stream.try_clone().unwrap());
            let mut head = String::new();
            loop {
                let mut line = String::new();
                reader.read_line(&mut line).unwrap();
                head.push_str(&line);
                if line == "\r\n" {
                    break;
                }
            }
            stream.write_all(reply.as_bytes()).unwrap();
            head
        });
        (
            Controller::new(Endpoint::Unix(path), "s3cret".into()),
            handle,
        )
    }

    #[test]
    fn reads_sized_bodies_and_sends_the_secret() {
        let (controller, server) =
            serve("HTTP/1.1 200 OK\r\nContent-Length: 15\r\n\r\n{\"version\":\"x\"}");
        let value = controller.json("GET", "/version", None).unwrap();
        assert_eq!(value["version"], "x");
        let head = server.join().unwrap();
        assert!(head.starts_with("GET /version HTTP/1.1\r\n"));
        assert!(head.contains("Authorization: Bearer s3cret\r\n"));
    }

    #[test]
    fn decodes_chunked_bodies_and_errors() {
        let (controller, _server) = serve(
            "HTTP/1.1 400 Bad Request\r\nTransfer-Encoding: chunked\r\n\r\n7\r\n{\"messa\r\n10\r\nge\":\"bad group\"}\r\n0\r\n\r\n",
        );
        assert_eq!(
            controller.json("PUT", "/proxies/x", None),
            Err(CoreError::Engine("bad group".into()))
        );
    }

    #[test]
    fn streams_lines_across_chunks() {
        let (controller, _server) = serve(
            "HTTP/1.1 200 OK\r\nTransfer-Encoding: chunked\r\n\r\n8\r\n{\"up\":1,\r\na\r\n\"down\":2}\n\r\n0\r\n\r\n",
        );
        let mut lines = Vec::new();
        controller
            .stream("/traffic", &AtomicBool::new(false), |line| {
                lines.push(line.to_owned())
            })
            .unwrap();
        assert_eq!(lines, ["{\"up\":1,\"down\":2}"]);
    }

    #[test]
    fn parses_endpoints() {
        assert_eq!(
            Endpoint::parse(r"\\.\pipe\x"),
            Endpoint::Pipe(r"\\.\pipe\x".into())
        );
        assert_eq!(
            Endpoint::parse("/tmp/x.sock"),
            Endpoint::Unix("/tmp/x.sock".into())
        );
    }
}
