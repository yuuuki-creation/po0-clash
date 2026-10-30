use std::sync::Mutex;
use std::time::Duration;

use base64::Engine as _;
use base64::engine::general_purpose::STANDARD;
use md5::Md5;
use sha2::{Digest as _, Sha256};
use ureq::config::RedirectAuthHeaders;
use ureq::http::{Request, Response};
use ureq::{Agent, Body, Proxy};

use crate::app_settings::WebDav;
use crate::error::{CoreError, Result};
use crate::util;

/// The Flutter app's folder and default file name, so both apps find the same account layout.
const FOLDER: &str = "po0-clash";
const DEFAULT_FILE: &str = "backup.zip";
const DOWNLOAD_LIMIT: u64 = 256 << 20;

/// The few WebDAV calls a backup needs, with Basic authentication or the Digest a server asks for instead.
pub struct Client {
    agent: Agent,
    root: String,
    user: String,
    password: String,
    challenge: Mutex<Option<Challenge>>,
}

impl Client {
    pub fn new(dav: &WebDav, proxy: Option<&str>, verify_tls: bool) -> Result<Self> {
        let root = dav.url.trim();
        if !(root.starts_with("https://") || root.starts_with("http://")) {
            return Err(CoreError::Invalid("WebDAV needs an http(s) address".into()));
        }
        let proxy = proxy
            .map(Proxy::new)
            .transpose()
            .map_err(|error| CoreError::Network(error.to_string()))?;
        let agent = Agent::new_with_config(
            Agent::config_builder()
                .proxy(proxy)
                .allow_non_standard_methods(true)
                .http_status_as_error(false)
                .redirect_auth_headers(RedirectAuthHeaders::SameHost)
                .timeout_connect(Some(Duration::from_secs(10)))
                .timeout_global(Some(Duration::from_secs(120)))
                .tls_config(
                    ureq::tls::TlsConfig::builder()
                        .disable_verification(!verify_tls)
                        .build(),
                )
                .build(),
        );
        Ok(Self {
            agent,
            root: format!("{}/", root.trim_end_matches('/')),
            user: dav.user.clone(),
            password: dav.password.clone(),
            challenge: Mutex::new(None),
        })
    }

    /// Asks for the account's root folder, which needs the credentials, unlike the `OPTIONS` many servers answer
    /// to anyone.
    pub fn check(&self) -> Result<()> {
        self.send("PROPFIND", &self.root, None, &[200, 207])
            .map(drop)
    }

    pub fn upload(&self, file_name: &str, data: &[u8]) -> Result<()> {
        self.send("MKCOL", &self.folder(), None, &[200, 201, 204, 405])?;
        self.send("PUT", &self.file(file_name), Some(data), &[200, 201, 204])
            .map(drop)
    }

    pub fn download(&self, file_name: &str) -> Result<Vec<u8>> {
        let mut response = self.send("GET", &self.file(file_name), None, &[200, 404])?;
        if response.status().as_u16() == 404 {
            return Err(CoreError::Invalid(
                "there is no backup on WebDAV yet".into(),
            ));
        }
        response
            .body_mut()
            .with_config()
            .limit(DOWNLOAD_LIMIT)
            .read_to_vec()
            .map_err(|error| CoreError::Network(error.to_string()))
    }

    fn folder(&self) -> String {
        format!("{}{FOLDER}/", self.root)
    }

    fn file(&self, file_name: &str) -> String {
        let name = match file_name.trim() {
            "" => DEFAULT_FILE,
            name => name,
        };
        format!("{}{}", self.folder(), util::encode_component(name))
    }

    fn send(
        &self,
        method: &str,
        url: &str,
        body: Option<&[u8]>,
        accept: &[u16],
    ) -> Result<Response<Body>> {
        let mut response = self.attempt(method, url, body)?;
        if response.status().as_u16() == 401 {
            let offered = response
                .headers()
                .get_all("WWW-Authenticate")
                .iter()
                .filter_map(|value| value.to_str().ok())
                .find_map(Challenge::parse);
            let retry = offered.is_some();
            if let Some(challenge) = offered {
                *crate::lock(&self.challenge) = Some(challenge);
            }
            if retry {
                response = self.attempt(method, url, body)?;
            }
        }
        let status = response.status().as_u16();
        if accept.contains(&status) {
            return Ok(response);
        }
        Err(CoreError::Network(match status {
            401 | 403 => "WebDAV refused the user name or password".into(),
            _ => format!("WebDAV answered HTTP {status}"),
        }))
    }

    fn attempt(&self, method: &str, url: &str, body: Option<&[u8]>) -> Result<Response<Body>> {
        let authorization = match crate::lock(&self.challenge).as_mut() {
            Some(challenge) => challenge.answer(&self.user, &self.password, method, path_of(url)),
            None => format!(
                "Basic {}",
                STANDARD.encode(format!("{}:{}", self.user, self.password))
            ),
        };
        let mut request = Request::builder()
            .method(method)
            .uri(url)
            .header("Authorization", authorization);
        if method == "PROPFIND" {
            request = request.header("Depth", "0");
        }
        let invalid = |error: ureq::http::Error| CoreError::Invalid(error.to_string());
        let sent = match body {
            Some(data) => self.agent.run(request.body(data).map_err(invalid)?),
            None => self.agent.run(request.body(()).map_err(invalid)?),
        };
        sent.map_err(|error| CoreError::Network(error.to_string()))
    }
}

fn path_of(url: &str) -> &str {
    let rest = url.split_once("://").map_or(url, |(_, rest)| rest);
    rest.find('/').map_or("/", |index| &rest[index..])
}

/// RFC 7616 Digest, as the Flutter app's WebDAV client answered it: MD5 or SHA-256, `qop=auth` when offered.
#[derive(Debug, Clone, PartialEq, Eq)]
struct Challenge {
    realm: String,
    nonce: String,
    opaque: Option<String>,
    algorithm: String,
    qop: bool,
    count: u32,
}

impl Challenge {
    fn parse(header: &str) -> Option<Self> {
        let (scheme, params) = header.trim().split_once(' ')?;
        if !scheme.eq_ignore_ascii_case("digest") {
            return None;
        }
        let params = auth_params(params);
        let get = |name: &str| {
            params
                .iter()
                .find(|(key, _)| key.eq_ignore_ascii_case(name))
                .map(|(_, value)| value.clone())
        };
        let algorithm = get("algorithm")
            .unwrap_or_else(|| "MD5".into())
            .to_ascii_uppercase();
        if !["MD5", "MD5-SESS", "SHA-256", "SHA-256-SESS"].contains(&algorithm.as_str()) {
            return None;
        }
        Some(Self {
            realm: get("realm").unwrap_or_default(),
            nonce: get("nonce")?,
            opaque: get("opaque"),
            algorithm,
            qop: get("qop").is_some_and(|qop| qop.split(',').any(|item| item.trim() == "auth")),
            count: 0,
        })
    }

    fn answer(&mut self, user: &str, password: &str, method: &str, uri: &str) -> String {
        let cnonce = util::random_secret(16);
        self.answer_with(user, password, method, uri, &cnonce)
    }

    fn answer_with(
        &mut self,
        user: &str,
        password: &str,
        method: &str,
        uri: &str,
        cnonce: &str,
    ) -> String {
        self.count += 1;
        let hash = |text: String| -> String {
            if self.algorithm.starts_with("SHA-256") {
                hex(&Sha256::digest(text.as_bytes()))
            } else {
                hex(&Md5::digest(text.as_bytes()))
            }
        };
        let nc = format!("{:08x}", self.count);
        let mut ha1 = hash(format!("{user}:{}:{password}", self.realm));
        if self.algorithm.ends_with("-SESS") {
            ha1 = hash(format!("{ha1}:{}:{cnonce}", self.nonce));
        }
        let ha2 = hash(format!("{method}:{uri}"));
        let response = if self.qop {
            hash(format!("{ha1}:{}:{nc}:{cnonce}:auth:{ha2}", self.nonce))
        } else {
            hash(format!("{ha1}:{}:{ha2}", self.nonce))
        };
        let mut header = format!(
            r#"Digest username="{user}", realm="{}", nonce="{}", uri="{uri}", algorithm={}, response="{response}""#,
            self.realm, self.nonce, self.algorithm
        );
        if self.qop {
            header += &format!(r#", qop=auth, nc={nc}, cnonce="{cnonce}""#);
        }
        if let Some(opaque) = &self.opaque {
            header += &format!(r#", opaque="{opaque}""#);
        }
        header
    }
}

fn hex(bytes: &[u8]) -> String {
    bytes.iter().map(|byte| format!("{byte:02x}")).collect()
}

/// `key=value` pairs where a value may be a quoted string holding commas.
fn auth_params(text: &str) -> Vec<(String, String)> {
    let mut params = Vec::new();
    let mut rest = text.trim();
    while let Some((key, after)) = rest.split_once('=') {
        let key = key.trim().trim_start_matches(',').trim().to_owned();
        let after = after.trim_start();
        let (value, remaining) = match after.strip_prefix('"') {
            Some(quoted) => {
                let mut value = String::new();
                let mut chars = quoted.char_indices();
                let mut end = quoted.len();
                while let Some((index, c)) = chars.next() {
                    match c {
                        '\\' => value.extend(chars.next().map(|(_, c)| c)),
                        '"' => {
                            end = index + 1;
                            break;
                        }
                        c => value.push(c),
                    }
                }
                (value, &quoted[end..])
            }
            None => {
                let end = after.find(',').unwrap_or(after.len());
                (after[..end].trim().to_owned(), &after[end..])
            }
        };
        params.push((key, value));
        rest = remaining.trim_start().trim_start_matches(',');
    }
    params
}

#[cfg(test)]
mod tests {
    use super::*;

    const CHALLENGE: &str = r#"Digest realm="http-auth@example.org", qop="auth, auth-int", algorithm=SHA-256, nonce="7ypf/xlj9XXwfDPEoM4URrv/xwf94BcCAzFZH4GiTo0v", opaque="FQhe/qaU925kfnzjCev0ciny7QMkPqMAFRtzCUYo5tdS""#;

    #[test]
    fn digest_answers_match_rfc_7616() {
        let cnonce = "f2/wE4q74E6zIJEtWaHKaf5wv/H5QzzpXusqGemxURZJ";
        let mut sha = Challenge::parse(CHALLENGE).unwrap();
        assert!(sha.qop && sha.opaque.is_some());
        let header = sha.answer_with("Mufasa", "Circle of Life", "GET", "/dir/index.html", cnonce);
        assert!(header.contains(
            r#"response="753927fa0e85d155564e2e272a28d1802ca10daf4496794697cf8db5856cb6c1""#
        ));
        assert!(header.contains("nc=00000001") && header.contains("algorithm=SHA-256"));
        let mut md5 = Challenge::parse(&CHALLENGE.replace("SHA-256", "MD5")).unwrap();
        let header = md5.answer_with("Mufasa", "Circle of Life", "GET", "/dir/index.html", cnonce);
        assert!(header.contains(r#"response="8ca523f5e9506fed4657c9700eebdbec""#));
        assert!(Challenge::parse(r#"Basic realm="x""#).is_none());
        assert_eq!(path_of("https://dav.example/a/b%20c"), "/a/b%20c");
        assert_eq!(path_of("https://dav.example"), "/");
    }
}
