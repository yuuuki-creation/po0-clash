use std::sync::mpsc::{self, RecvTimeoutError, Sender};
use std::sync::{Arc, Mutex};
use std::thread;
use std::time::{Duration, Instant};

use serde::Serialize;
use serde_json::Value;

use crate::error::{CoreError, Result};
use crate::lock;

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize)]
#[serde(rename_all = "camelCase")]
pub enum IpType {
    Residential,
    Mobile,
    Business,
    Hosting,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize)]
#[serde(rename_all = "camelCase")]
pub enum IpQualityLevel {
    Good,
    Normal,
    Risky,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize)]
#[serde(rename_all = "camelCase")]
pub enum IpQualitySource {
    IdentMe,
    IpApiCom,
    IpQuery,
    IpLocate,
    ProxyCheck,
    IpApiIs,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct IpQuality {
    pub ip: String,
    pub source: IpQualitySource,
    pub kind: IpType,
    pub level: IpQualityLevel,
    pub organization: Option<String>,
    pub asn: Option<u32>,
    pub is_proxy: bool,
    pub is_vpn: bool,
    pub is_tor: bool,
    pub is_abuser: bool,
}

impl IpQualitySource {
    pub fn label(self) -> &'static str {
        match self {
            Self::IdentMe => "ident.me",
            Self::IpApiCom => "ip-api.com",
            Self::IpQuery => "ipquery.io",
            Self::IpLocate => "iplocate.io",
            Self::ProxyCheck => "proxycheck.io",
            Self::IpApiIs => "ipapi.is",
        }
    }

    fn url(self, ip: &str) -> String {
        match self {
            Self::IdentMe => "https://ident.me/json".into(),
            // ip-api.com serves HTTPS only on its paid plan.
            Self::IpApiCom => {
                format!("http://ip-api.com/json/{ip}?fields=status,isp,org,as,mobile,proxy,hosting")
            }
            Self::IpQuery => format!("https://api.ipquery.io/{ip}?format=json"),
            Self::IpLocate => format!("https://iplocate.io/api/lookup/{ip}"),
            Self::ProxyCheck => format!("https://proxycheck.io/v3/{ip}"),
            Self::IpApiIs => format!("https://api.ipapi.is/?q={ip}"),
        }
    }
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
enum Failure {
    NoType,
    Timeout,
    RateLimited,
    Failed,
    IpMismatch,
}

impl Failure {
    fn describe(self) -> &'static str {
        match self {
            Self::NoType => "no type",
            Self::Timeout => "timed out",
            Self::RateLimited => "rate limited",
            Self::Failed => "failed",
            Self::IpMismatch => "saw another address",
        }
    }
}

/// An inferred answer is a source's silence about hosting and mobile read as residential; it only stands in when
/// no source states a type.
#[derive(Debug)]
enum Answer {
    Stated(IpQuality),
    Inferred(IpQuality),
}

type Outcome = std::result::Result<Answer, Failure>;

/// A later wave starts only while the earlier ones are still unanswered, so the sources with the tightest free
/// quotas are asked last and rarely.
const WAVES: [&[IpQualitySource]; 4] = [
    &[
        IpQualitySource::IdentMe,
        IpQualitySource::IpApiCom,
        IpQualitySource::IpQuery,
    ],
    &[IpQualitySource::IpLocate],
    &[IpQualitySource::IpApiIs],
    &[IpQualitySource::ProxyCheck],
];
const TIMEOUT: Duration = Duration::from_secs(8);
const HEDGE: Duration = Duration::from_secs(1);
const FAILURE_COOLDOWN: Duration = Duration::from_secs(5 * 60);

/// Answers stay for the address; a failure is repeated for five minutes so a dashboard refresh cannot burn the
/// free quotas.
#[derive(Default)]
pub struct Cache {
    last: Mutex<Option<(String, Cached)>>,
}

enum Cached {
    Answer(IpQuality),
    Failure(Instant, String),
}

impl Cache {
    pub fn lookup(&self, ip: &str, proxy: Option<&str>, refresh: bool) -> Result<IpQuality> {
        if !refresh && let Some((cached_ip, cached)) = lock(&self.last).as_ref() {
            match cached {
                Cached::Answer(quality) if cached_ip == ip => return Ok(quality.clone()),
                Cached::Failure(at, message)
                    if cached_ip == ip && at.elapsed() < FAILURE_COOLDOWN =>
                {
                    return Err(CoreError::Network(message.clone()));
                }
                _ => {}
            }
        }
        let (owned_ip, proxy) = (ip.to_owned(), proxy.map(str::to_owned));
        let result = run(
            move |source| query(source, &owned_ip, proxy.as_deref()),
            HEDGE,
        );
        let cached = match &result {
            Ok(quality) => Cached::Answer(quality.clone()),
            Err(error) => Cached::Failure(Instant::now(), error.to_string()),
        };
        *lock(&self.last) = Some((ip.to_owned(), cached));
        result
    }
}

fn run<F>(query: F, hedge: Duration) -> Result<IpQuality>
where
    F: Fn(IpQualitySource) -> Outcome + Send + Sync + 'static,
{
    let query = Arc::new(query);
    let (sender, receiver) = mpsc::channel();
    let mut waves = WAVES.iter();
    let (mut in_flight, mut fallback, mut failures) = (0, None, Vec::new());
    let mut next_wave = Instant::now();
    loop {
        if in_flight == 0 || Instant::now() >= next_wave {
            match waves.next() {
                Some(wave) => {
                    in_flight += spawn(wave, &query, &sender);
                    next_wave = Instant::now() + hedge;
                }
                None if in_flight == 0 => break,
                None => next_wave = Instant::now() + TIMEOUT,
            }
        }
        match receiver.recv_timeout(next_wave.saturating_duration_since(Instant::now())) {
            Ok((_, Ok(Answer::Stated(quality)))) => return Ok(quality),
            Ok((_, Ok(Answer::Inferred(quality)))) => {
                in_flight -= 1;
                fallback.get_or_insert(quality);
            }
            Ok((source, Err(failure))) => {
                in_flight -= 1;
                failures.push((source, failure));
            }
            Err(RecvTimeoutError::Timeout) => {}
            Err(RecvTimeoutError::Disconnected) => break,
        }
    }
    fallback.ok_or_else(|| {
        let reasons: Vec<String> = failures
            .iter()
            .map(|(source, failure)| format!("{} {}", source.label(), failure.describe()))
            .collect();
        CoreError::Network(format!("IP quality lookup failed: {}", reasons.join(", ")))
    })
}

fn spawn<F>(
    wave: &[IpQualitySource],
    query: &Arc<F>,
    sender: &Sender<(IpQualitySource, Outcome)>,
) -> usize
where
    F: Fn(IpQualitySource) -> Outcome + Send + Sync + 'static,
{
    for &source in wave {
        let (query, sender) = (query.clone(), sender.clone());
        thread::spawn(move || {
            let _ = sender.send((source, query(source)));
        });
    }
    wave.len()
}

fn query(source: IpQualitySource, ip: &str, proxy: Option<&str>) -> Outcome {
    let proxy = proxy
        .map(ureq::Proxy::new)
        .transpose()
        .map_err(|_| Failure::Failed)?;
    let agent = ureq::Agent::new_with_config(
        ureq::Agent::config_builder()
            .proxy(proxy)
            .timeout_global(Some(TIMEOUT))
            .http_status_as_error(false)
            .build(),
    );
    let mut response = agent
        .get(&source.url(ip))
        .call()
        .map_err(|error| match error {
            ureq::Error::Timeout(_) => Failure::Timeout,
            _ => Failure::Failed,
        })?;
    match response.status().as_u16() {
        200 => {}
        429 => return Err(Failure::RateLimited),
        _ => return Err(Failure::Failed),
    }
    let body = response
        .body_mut()
        .read_to_string()
        .map_err(|_| Failure::Failed)?;
    let json: Value = serde_json::from_str(&body).map_err(|_| Failure::Failed)?;
    parse(source, ip, &json)
}

#[derive(Default)]
struct Details {
    organization: Option<String>,
    asn: Option<u32>,
    is_proxy: bool,
    is_vpn: bool,
    is_tor: bool,
    is_abuser: bool,
}

fn parse(source: IpQualitySource, ip: &str, json: &Value) -> Outcome {
    let object = |value: &Value, name: &str| value.get(name).cloned().unwrap_or(Value::Null);
    match source {
        IpQualitySource::IdentMe => {
            if json.get("ip").and_then(Value::as_str) != Some(ip) {
                return Err(Failure::IpMismatch);
            }
            answer(
                ip,
                source,
                declared(json.get("type")),
                false,
                Details {
                    organization: text(json.get("aso")),
                    asn: asn(json.get("asn")),
                    ..Details::default()
                },
            )
        }
        IpQualitySource::IpApiCom => {
            if json.get("status").and_then(Value::as_str) != Some("success") {
                return Err(Failure::Failed);
            }
            let kind = pick(flag(json.get("hosting")), flag(json.get("mobile")), None);
            answer(
                ip,
                source,
                kind.or(Some(IpType::Residential)),
                kind.is_none(),
                Details {
                    organization: text(json.get("org")).or_else(|| text(json.get("isp"))),
                    asn: asn(json.get("as")),
                    is_proxy: flag(json.get("proxy")),
                    ..Details::default()
                },
            )
        }
        IpQualitySource::IpQuery => {
            let (risk, isp) = (object(json, "risk"), object(json, "isp"));
            let kind = pick(
                flag(risk.get("is_datacenter")),
                flag(risk.get("is_mobile")),
                None,
            );
            answer(
                ip,
                source,
                kind.or(Some(IpType::Residential)),
                kind.is_none(),
                Details {
                    organization: text(isp.get("org")).or_else(|| text(isp.get("isp"))),
                    asn: asn(isp.get("asn")),
                    is_proxy: flag(risk.get("is_proxy")),
                    is_vpn: flag(risk.get("is_vpn")),
                    is_tor: flag(risk.get("is_tor")),
                    is_abuser: false,
                },
            )
        }
        IpQualitySource::IpLocate => {
            let (privacy, company, network) = (
                object(json, "privacy"),
                object(json, "company"),
                object(json, "asn"),
            );
            let declared_type =
                declared(company.get("type")).or_else(|| declared(network.get("type")));
            let kind = pick(flag(privacy.get("is_hosting")), false, declared_type);
            answer(
                ip,
                source,
                kind,
                false,
                Details {
                    organization: text(company.get("name")).or_else(|| text(network.get("name"))),
                    asn: asn(network.get("asn")),
                    is_proxy: flag(privacy.get("is_proxy")),
                    is_vpn: flag(privacy.get("is_vpn")),
                    is_tor: flag(privacy.get("is_tor")),
                    is_abuser: flag(privacy.get("is_abuser")),
                },
            )
        }
        IpQualitySource::ProxyCheck => {
            match json.get("status").and_then(Value::as_str) {
                Some("denied") => return Err(Failure::RateLimited),
                Some("ok" | "warning") => {}
                _ => return Err(Failure::Failed),
            }
            let result = object(json, ip);
            let (network, detections) = (object(&result, "network"), object(&result, "detections"));
            let network_type = network.get("type").and_then(Value::as_str);
            let declared_type = match network_type {
                Some("Residential") => Some(IpType::Residential),
                Some("Business") => Some(IpType::Business),
                _ => None,
            };
            let kind = pick(
                flag(detections.get("hosting")) || network_type == Some("Hosting"),
                network_type == Some("Wireless"),
                declared_type,
            );
            answer(
                ip,
                source,
                kind,
                false,
                Details {
                    organization: text(network.get("organisation")),
                    asn: asn(network.get("asn")),
                    is_proxy: flag(detections.get("proxy")),
                    is_vpn: flag(detections.get("vpn")),
                    is_tor: flag(detections.get("tor")),
                    is_abuser: false,
                },
            )
        }
        IpQualitySource::IpApiIs => {
            let (company, network) = (object(json, "company"), object(json, "asn"));
            let declared_type =
                declared(company.get("type")).or_else(|| declared(network.get("type")));
            let kind = pick(
                flag(json.get("is_datacenter")),
                flag(json.get("is_mobile")),
                declared_type,
            );
            answer(
                ip,
                source,
                kind,
                false,
                Details {
                    organization: text(company.get("name")).or_else(|| text(network.get("org"))),
                    asn: asn(network.get("asn")),
                    is_proxy: flag(json.get("is_proxy")),
                    is_vpn: flag(json.get("is_vpn")),
                    is_tor: flag(json.get("is_tor")),
                    is_abuser: flag(json.get("is_abuser")),
                },
            )
        }
    }
}

fn answer(
    ip: &str,
    source: IpQualitySource,
    kind: Option<IpType>,
    inferred: bool,
    details: Details,
) -> Outcome {
    let kind = kind.ok_or(Failure::NoType)?;
    let level = if details.is_tor || details.is_abuser {
        IpQualityLevel::Risky
    } else if kind == IpType::Hosting {
        IpQualityLevel::Normal
    } else {
        IpQualityLevel::Good
    };
    let quality = IpQuality {
        ip: ip.to_owned(),
        source,
        kind,
        level,
        organization: details.organization,
        asn: details.asn,
        is_proxy: details.is_proxy,
        is_vpn: details.is_vpn,
        is_tor: details.is_tor,
        is_abuser: details.is_abuser,
    };
    Ok(if inferred {
        Answer::Inferred(quality)
    } else {
        Answer::Stated(quality)
    })
}

fn pick(hosting: bool, mobile: bool, declared: Option<IpType>) -> Option<IpType> {
    if hosting || declared == Some(IpType::Hosting) {
        Some(IpType::Hosting)
    } else if mobile {
        Some(IpType::Mobile)
    } else {
        declared
    }
}

fn declared(value: Option<&Value>) -> Option<IpType> {
    match value?.as_str()? {
        "isp" => Some(IpType::Residential),
        "business" | "education" | "government" | "banking" => Some(IpType::Business),
        "hosting" => Some(IpType::Hosting),
        _ => None,
    }
}

fn flag(value: Option<&Value>) -> bool {
    value.and_then(Value::as_bool) == Some(true)
}

fn text(value: Option<&Value>) -> Option<String> {
    value
        .and_then(Value::as_str)
        .filter(|text| !text.is_empty())
        .map(str::to_owned)
}

fn asn(value: Option<&Value>) -> Option<u32> {
    let number = match value? {
        Value::Number(number) => number.as_u64().and_then(|n| u32::try_from(n).ok()),
        Value::String(text) => {
            let digits: String = text
                .chars()
                .skip_while(|c| !c.is_ascii_digit())
                .take_while(char::is_ascii_digit)
                .collect();
            digits.parse().ok()
        }
        _ => None,
    };
    number.filter(|&asn| asn != 0)
}

#[cfg(test)]
mod tests {
    use super::*;
    use serde_json::json;

    fn stated(outcome: Outcome) -> IpQuality {
        match outcome {
            Ok(Answer::Stated(quality)) => quality,
            other => panic!("expected a stated answer, got {other:?}"),
        }
    }

    #[test]
    fn reads_each_source() {
        let ip = "203.0.113.7";
        let ident = stated(parse(
            IpQualitySource::IdentMe,
            ip,
            &json!({"ip": ip, "type": "hosting", "aso": "Example Cloud", "asn": "64500"}),
        ));
        assert_eq!(
            (ident.kind, ident.level, ident.asn),
            (IpType::Hosting, IpQualityLevel::Normal, Some(64500))
        );
        assert_eq!(ident.organization.as_deref(), Some("Example Cloud"));

        let silent = parse(
            IpQualitySource::IpApiCom,
            ip,
            &json!({"status": "success", "isp": "Home ISP", "as": "AS64501 Home", "proxy": false}),
        );
        assert!(
            matches!(silent, Ok(Answer::Inferred(ref q)) if q.kind == IpType::Residential && q.asn == Some(64501))
        );

        let check = stated(parse(
            IpQualitySource::ProxyCheck,
            ip,
            &json!({"status": "ok", ip: {
                "network": {"type": "Wireless", "organisation": "Mobile Co", "asn": "AS64502"},
                "detections": {"tor": true}
            }}),
        ));
        assert_eq!(
            (check.kind, check.level, check.is_tor),
            (IpType::Mobile, IpQualityLevel::Risky, true)
        );

        let located = stated(parse(
            IpQualitySource::IpLocate,
            ip,
            &json!({"privacy": {}, "company": {"type": "education", "name": "A University"}, "asn": {"asn": 64503}}),
        ));
        assert_eq!((located.kind, located.asn), (IpType::Business, Some(64503)));
    }

    #[test]
    fn rejects_unusable_answers() {
        let ip = "203.0.113.7";
        let other = parse(
            IpQualitySource::IdentMe,
            ip,
            &json!({"ip": "198.51.100.1", "type": "isp"}),
        );
        assert!(matches!(other, Err(Failure::IpMismatch)));
        let untyped = parse(
            IpQualitySource::IpApiIs,
            ip,
            &json!({"company": {}, "asn": {}}),
        );
        assert!(matches!(untyped, Err(Failure::NoType)));
        let denied = parse(
            IpQualitySource::ProxyCheck,
            ip,
            &json!({"status": "denied"}),
        );
        assert!(matches!(denied, Err(Failure::RateLimited)));
    }

    fn quality(source: IpQualitySource) -> IpQuality {
        let kind = Some(IpType::Residential);
        match answer("203.0.113.7", source, kind, false, Details::default()) {
            Ok(Answer::Stated(quality)) => quality,
            _ => unreachable!(),
        }
    }

    #[test]
    fn later_waves_answer_when_the_first_is_silent() {
        let result = run(
            |source| match source {
                IpQualitySource::IpLocate => Ok(Answer::Stated(quality(source))),
                IpQualitySource::IpApiCom => Ok(Answer::Inferred(quality(source))),
                _ => Err(Failure::RateLimited),
            },
            Duration::from_millis(5),
        );
        assert_eq!(result.unwrap().source, IpQualitySource::IpLocate);
    }

    #[test]
    fn falls_back_to_an_inferred_answer_then_fails() {
        let inferred = run(
            |source| match source {
                IpQualitySource::IpQuery => Ok(Answer::Inferred(quality(source))),
                _ => Err(Failure::Timeout),
            },
            Duration::from_millis(5),
        );
        assert_eq!(inferred.unwrap().source, IpQualitySource::IpQuery);
        let failed = run(|_| Err(Failure::Failed), Duration::from_millis(5));
        assert!(
            failed
                .unwrap_err()
                .to_string()
                .contains("ip-api.com failed")
        );
    }
}
