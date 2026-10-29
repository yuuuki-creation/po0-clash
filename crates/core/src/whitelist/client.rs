use std::thread;
use std::time::Duration;

use serde_json::{Map, Value};

use super::Secret;
use super::transport::{Method, Response, SendError, Transport};
use crate::config::PO0_HOST;
use crate::model::{WhitelistKind, WhitelistOutcome, WhitelistResult};
use crate::util::{self, encode_component, snippet};

const PO0_API: &str = "https://124.221.69.228/api/firewall";
const RETRY_DELAY: Duration = Duration::from_millis(1500);
const REQUEST_TIMEOUT: Duration = Duration::from_secs(20);
const POLL_TIMEOUT: Duration = Duration::from_secs(5);
const ATTEMPTS: u32 = 3;
/// The request's own timeout fires first; the transport deadline only frees the worker.
const DEADLINE_SLACK: Duration = Duration::from_secs(1);

pub struct Client<'a> {
    pub transport: &'a Transport,
    pub route: String,
}

pub struct Polled {
    pub result: WhitelistResult,
    pub added: bool,
}

impl Client<'_> {
    /// po0: a read-only query, adding only when the exit is missing, since add claims a FIFO
    /// slot and evicts the oldest entry (ADR 0004). ggy has no read-only form: its link adds
    /// the caller's /24 on every GET (ADR 0012).
    pub fn poll(&self, secret: &Secret) -> Polled {
        let url = query_url(secret);
        let status = self.call(secret, Method::Get, &url, 1, POLL_TIMEOUT);
        if status.outcome != WhitelistOutcome::NotApplied {
            return Polled {
                result: status,
                added: false,
            };
        }
        Polled {
            result: self.whitelist(secret),
            added: true,
        }
    }

    pub fn whitelist(&self, secret: &Secret) -> WhitelistResult {
        match secret.kind {
            WhitelistKind::Po0 => {
                let url = format!("{}/add", po0_url(&secret.value));
                self.call(secret, Method::Post, &url, ATTEMPTS, REQUEST_TIMEOUT)
            }
            WhitelistKind::Ggy => self.call(
                secret,
                Method::Get,
                &secret.value,
                ATTEMPTS,
                REQUEST_TIMEOUT,
            ),
        }
    }

    fn call(
        &self,
        secret: &Secret,
        method: Method,
        url: &str,
        attempts: u32,
        timeout: Duration,
    ) -> WhitelistResult {
        let route = route_for(url, &self.route);
        let mut last_error = String::new();
        for attempt in 1..=attempts {
            if attempt > 1 {
                thread::sleep(RETRY_DELAY * (attempt - 1));
            }
            match self
                .transport
                .send(method, url, &route, timeout + DEADLINE_SLACK)
            {
                Ok(response) if is_transient(&response) => {
                    last_error = format!("HTTP {}", response.status);
                }
                Ok(response) => return parse(secret, &response),
                Err(SendError::Timeout) => {
                    last_error = SendError::Timeout.to_string();
                    self.transport.reset();
                }
                Err(error) => last_error = error.to_string(),
            }
        }
        result(
            WhitelistOutcome::Error,
            None,
            Some(secret.redact(&last_error)),
        )
    }
}

fn query_url(secret: &Secret) -> String {
    match secret.kind {
        WhitelistKind::Po0 => po0_url(&secret.value),
        WhitelistKind::Ggy => secret.value.clone(),
    }
}

fn po0_url(token: &str) -> String {
    format!("{PO0_API}/{}", encode_component(token))
}

/// po0's address is also kept out of TUN (ADR 0001), so only it may fall back to a plain socket.
fn route_for(url: &str, route: &str) -> String {
    let host = url
        .split_once("://")
        .map(|(_, rest)| rest.split(['/', '?', '#']).next().unwrap_or(""))
        .unwrap_or("");
    if route == "DIRECT" || host != PO0_HOST {
        route.to_owned()
    } else {
        format!("{route}; DIRECT")
    }
}

/// The API occasionally answers a bare 400 "Error" or a 5xx that succeeds a few seconds later;
/// a JSON error body (an invalid token) is final. Retrying add is safe: a listed exit is idempotent.
fn is_transient(response: &Response) -> bool {
    let status = response.status;
    if status >= 500 || status == 429 {
        return true;
    }
    if (200..300).contains(&status) || status == 403 {
        return false;
    }
    decode_map(&response.body).is_none()
}

fn result(
    outcome: WhitelistOutcome,
    ip: Option<String>,
    message: Option<String>,
) -> WhitelistResult {
    WhitelistResult {
        outcome,
        ip,
        message,
        at: util::now(),
    }
}

fn decode_map(body: &str) -> Option<Map<String, Value>> {
    match serde_json::from_str(body) {
        Ok(Value::Object(map)) => Some(map),
        _ => None,
    }
}

fn text(value: Option<&Value>) -> Option<String> {
    match value? {
        Value::Null => None,
        Value::String(text) => Some(text.clone()),
        other => Some(other.to_string()),
    }
}

pub fn parse(secret: &Secret, response: &Response) -> WhitelistResult {
    match secret.kind {
        WhitelistKind::Po0 => parse_po0(secret, response),
        WhitelistKind::Ggy => parse_ggy(secret, response),
    }
}

fn parse_po0(secret: &Secret, response: &Response) -> WhitelistResult {
    let status = response.status;
    let Some(data) = decode_map(&response.body) else {
        let message = format!("HTTP {status}: {}", snippet(&response.body));
        return result(WhitelistOutcome::Error, None, Some(secret.redact(&message)));
    };
    let current = text(data.get("currentIp"));
    if !(200..300).contains(&status) {
        let message = ["message", "msg", "error"]
            .iter()
            .find_map(|name| text(data.get(*name)))
            .unwrap_or_else(|| format!("HTTP {status}"));
        return result(
            WhitelistOutcome::Rejected,
            current,
            Some(secret.redact(&message)),
        );
    }
    let Some(Value::Array(list)) = data.get("whitelist") else {
        let message = snippet(&response.body);
        return result(
            WhitelistOutcome::Error,
            current,
            Some(secret.redact(&message)),
        );
    };
    let listed = list.iter().any(|item| {
        let ip = match item {
            Value::Object(entry) => text(entry.get("ip")),
            other => text(Some(other)),
        };
        same_c24(ip.as_deref(), current.as_deref())
    });
    let outcome = if data.get("enabled") == Some(&Value::Bool(false)) {
        WhitelistOutcome::Disabled
    } else if listed {
        WhitelistOutcome::Applied
    } else {
        WhitelistOutcome::NotApplied
    };
    result(outcome, current, None)
}

fn parse_ggy(secret: &Secret, response: &Response) -> WhitelistResult {
    let status = response.status;
    let Some(body) = decode_map(&response.body) else {
        let message = format!("HTTP {status}: {}", snippet(&secret.redact(&response.body)));
        return result(WhitelistOutcome::Error, None, Some(message));
    };
    let data = body.get("data").and_then(Value::as_object);
    let cidr = data
        .and_then(|data| text(data.get("cidr")))
        .unwrap_or_default();
    let api_status = text(body.get("status")).unwrap_or_else(|| "200".into());
    if !(200..300).contains(&status) || api_status != "200" || cidr.is_empty() {
        let message = text(body.get("msg"))
            .or_else(|| text(body.get("message")))
            .unwrap_or_else(|| format!("HTTP {status}"));
        return result(
            WhitelistOutcome::Rejected,
            None,
            Some(secret.redact(&message)),
        );
    }
    let removed = data
        .and_then(|data| text(data.get("removed_cidr")))
        .filter(|removed| !removed.is_empty())
        .map(|removed| format!("evicted {removed}"));
    result(WhitelistOutcome::Applied, Some(cidr), removed)
}

/// The server whitelists whole /24s and echoes entries as IPs or `x.x.x.0/24`.
pub fn same_c24(a: Option<&str>, b: Option<&str>) -> bool {
    let (Some(a), Some(b)) = (a, b) else {
        return false;
    };
    if a.is_empty() || b.is_empty() {
        return false;
    }
    if a == b {
        return true;
    }
    if !a.ends_with("/24") && !b.ends_with("/24") {
        return false;
    }
    let octets = |ip: &str| -> Vec<String> {
        ip.replace("/24", "")
            .split('.')
            .map(str::to_owned)
            .collect()
    };
    let (pa, pb) = (octets(a), octets(b));
    pa.len() == 4 && pb.len() == 4 && pa[..3] == pb[..3]
}

#[cfg(test)]
mod tests {
    use super::*;

    fn po0() -> Secret {
        Secret::new("pgnfw_abcdefghijklmnop").unwrap()
    }

    fn ggy() -> Secret {
        Secret::new("https://api.guguyun.com/whitelist?token=ggysecret123456").unwrap()
    }

    fn reply(status: u16, body: &str) -> Response {
        Response {
            status,
            body: body.into(),
        }
    }

    #[test]
    fn po0_listed_exit_is_applied() {
        let body =
            r#"{"currentIp":"1.2.3.4","whitelist":[{"ip":"1.2.3.0/24","slot":1}],"limit":3}"#;
        let parsed = parse(&po0(), &reply(200, body));
        assert_eq!(parsed.outcome, WhitelistOutcome::Applied);
        assert_eq!(parsed.ip.as_deref(), Some("1.2.3.4"));
    }

    #[test]
    fn po0_missing_or_disabled() {
        let missing = r#"{"currentIp":"1.2.3.4","whitelist":["5.6.7.0/24"]}"#;
        assert_eq!(
            parse(&po0(), &reply(200, missing)).outcome,
            WhitelistOutcome::NotApplied
        );
        let disabled = r#"{"currentIp":"1.2.3.4","whitelist":[],"enabled":false}"#;
        assert_eq!(
            parse(&po0(), &reply(200, disabled)).outcome,
            WhitelistOutcome::Disabled
        );
    }

    #[test]
    fn po0_errors_never_echo_the_token() {
        let body = r#"{"message":"invalid token pgnfw_abcdefghijklmnop"}"#;
        let parsed = parse(&po0(), &reply(403, body));
        assert_eq!(parsed.outcome, WhitelistOutcome::Rejected);
        let message = parsed.message.unwrap();
        assert!(!message.contains("pgnfw_abcdefghijklmnop"), "{message}");
        assert!(message.contains(&po0().label()));
        assert_eq!(
            parse(&po0(), &reply(200, "oops")).outcome,
            WhitelistOutcome::Error
        );
    }

    #[test]
    fn ggy_reports_the_cidr_and_evictions() {
        let body = r#"{"status":200,"data":{"cidr":"1.2.3.0/24","removed_cidr":"9.9.9.0/24"}}"#;
        let parsed = parse(&ggy(), &reply(200, body));
        assert_eq!(parsed.outcome, WhitelistOutcome::Applied);
        assert_eq!(parsed.ip.as_deref(), Some("1.2.3.0/24"));
        assert_eq!(parsed.message.as_deref(), Some("evicted 9.9.9.0/24"));
        let quiet = r#"{"data":{"cidr":"1.2.3.0/24","removed_cidr":""}}"#;
        assert_eq!(parse(&ggy(), &reply(200, quiet)).message, None);
    }

    #[test]
    fn ggy_refusals() {
        let body = r#"{"status":"401","msg":"bad ggysecret123456"}"#;
        let parsed = parse(&ggy(), &reply(200, body));
        assert_eq!(parsed.outcome, WhitelistOutcome::Rejected);
        assert!(!parsed.message.unwrap().contains("ggysecret123456"));
    }

    #[test]
    fn transient_answers_are_retried() {
        assert!(is_transient(&reply(502, "{}")));
        assert!(is_transient(&reply(429, "{}")));
        assert!(is_transient(&reply(400, "Error")));
        assert!(!is_transient(&reply(400, r#"{"message":"bad"}"#)));
        assert!(!is_transient(&reply(403, "Forbidden")));
        assert!(!is_transient(&reply(200, "x")));
    }

    #[test]
    fn compares_by_slash_24() {
        assert!(same_c24(Some("1.2.3.4"), Some("1.2.3.0/24")));
        assert!(same_c24(Some("1.2.3.4"), Some("1.2.3.4")));
        assert!(!same_c24(Some("1.2.3.4"), Some("1.2.3.5")));
        assert!(!same_c24(Some("1.2.4.0/24"), Some("1.2.3.4")));
        assert!(!same_c24(None, Some("1.2.3.4")));
        assert!(!same_c24(Some(""), Some("")));
    }

    #[test]
    fn only_po0_falls_back_to_a_plain_socket() {
        let route = "PROXY u:p@127.0.0.1:1";
        assert_eq!(
            route_for(&po0_url("pgnfw_x"), route),
            format!("{route}; DIRECT")
        );
        assert_eq!(route_for(&ggy().value, route), route);
        assert_eq!(route_for(&po0_url("pgnfw_x"), "DIRECT"), "DIRECT");
        assert_eq!(
            po0_url("pgnfw_a/b"),
            "https://124.221.69.228/api/firewall/pgnfw_a%2Fb"
        );
    }
}
