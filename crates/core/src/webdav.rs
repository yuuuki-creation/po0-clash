use std::time::Duration;

use base64::Engine as _;
use base64::engine::general_purpose::STANDARD;
use ureq::config::RedirectAuthHeaders;
use ureq::http::{Request, Response};
use ureq::{Agent, AsSendBody, Body, Proxy};

use crate::app_settings::WebDav;
use crate::error::{CoreError, Result};
use crate::util;

/// The Flutter app's folder and default file name, so both apps find the same account layout.
const FOLDER: &str = "po0-clash";
const DEFAULT_FILE: &str = "backup.zip";
const DOWNLOAD_LIMIT: u64 = 256 << 20;

/// The few WebDAV calls a backup needs, with Basic authentication.
pub struct Client {
    agent: Agent,
    root: String,
    authorization: String,
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
        let credentials = STANDARD.encode(format!("{}:{}", dav.user, dav.password));
        Ok(Self {
            agent,
            root: format!("{}/", root.trim_end_matches('/')),
            authorization: format!("Basic {credentials}"),
        })
    }

    /// Asks for the account's root folder, which needs the credentials, unlike the `OPTIONS` many servers answer
    /// to anyone.
    pub fn check(&self) -> Result<()> {
        self.send("PROPFIND", &self.root, (), &[200, 207]).map(drop)
    }

    pub fn upload(&self, file_name: &str, data: &[u8]) -> Result<()> {
        self.send("MKCOL", &self.folder(), (), &[200, 201, 204, 405])?;
        self.send("PUT", &self.file(file_name), data, &[200, 201, 204])
            .map(drop)
    }

    pub fn download(&self, file_name: &str) -> Result<Vec<u8>> {
        let mut response = self.send("GET", &self.file(file_name), (), &[200, 404])?;
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
        body: impl AsSendBody,
        accept: &[u16],
    ) -> Result<Response<Body>> {
        let mut request = Request::builder()
            .method(method)
            .uri(url)
            .header("Authorization", &self.authorization);
        if method == "PROPFIND" {
            request = request.header("Depth", "0");
        }
        let request = request
            .body(body)
            .map_err(|error| CoreError::Invalid(error.to_string()))?;
        let response = self
            .agent
            .run(request)
            .map_err(|error| CoreError::Network(error.to_string()))?;
        let status = response.status().as_u16();
        if accept.contains(&status) {
            return Ok(response);
        }
        Err(CoreError::Network(match status {
            401 | 403 => "WebDAV refused the user name or password".into(),
            _ => format!("WebDAV answered HTTP {status}"),
        }))
    }
}
