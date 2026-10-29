/// One entry of a Dart `findProxy` result such as `PROXY user:pass@127.0.0.1:7890; DIRECT`.
#[derive(Debug, Clone, PartialEq, Eq)]
pub enum Hop {
    Direct,
    Proxy(String),
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub struct InvalidRoute;

pub fn parse(route: &str) -> Result<Vec<Hop>, InvalidRoute> {
    let hops = route
        .split(';')
        .map(str::trim)
        .filter(|entry| !entry.is_empty())
        .map(parse_hop)
        .collect::<Result<Vec<_>, _>>()?;
    if hops.is_empty() {
        return Err(InvalidRoute);
    }
    Ok(hops)
}

fn parse_hop(entry: &str) -> Result<Hop, InvalidRoute> {
    if entry == "DIRECT" {
        return Ok(Hop::Direct);
    }
    let target = entry.strip_prefix("PROXY ").ok_or(InvalidRoute)?.trim();
    let (userinfo, address) = match target.rsplit_once('@') {
        Some((userinfo, address)) => (Some(userinfo), address),
        None => (None, target),
    };
    let (host, port) = address.rsplit_once(':').ok_or(InvalidRoute)?;
    let port: u16 = port.parse().map_err(|_| InvalidRoute)?;
    if host.is_empty() || port == 0 || host.contains('/') {
        return Err(InvalidRoute);
    }
    let credentials = match userinfo {
        Some(userinfo) => {
            let (username, password) = userinfo.split_once(':').ok_or(InvalidRoute)?;
            if username.is_empty() {
                return Err(InvalidRoute);
            }
            format!("{}:{}@", encode(username), encode(password))
        }
        None => String::new(),
    };
    Ok(Hop::Proxy(format!("http://{credentials}{host}:{port}")))
}

fn encode(value: &str) -> String {
    value
        .bytes()
        .map(|byte| {
            if byte.is_ascii_alphanumeric() || b"-._~".contains(&byte) {
                char::from(byte).to_string()
            } else {
                format!("%{byte:02X}")
            }
        })
        .collect()
}

#[cfg(test)]
mod tests {
    use super::*;

    fn proxy(uri: &str) -> Hop {
        Hop::Proxy(uri.to_owned())
    }

    #[test]
    fn parses_the_routes_the_app_builds() {
        assert_eq!(parse("DIRECT"), Ok(vec![Hop::Direct]));
        assert_eq!(
            parse("PROXY user:pass@127.0.0.1:7890"),
            Ok(vec![proxy("http://user:pass@127.0.0.1:7890")])
        );
        assert_eq!(
            parse("PROXY user:pass@127.0.0.1:7890; DIRECT"),
            Ok(vec![proxy("http://user:pass@127.0.0.1:7890"), Hop::Direct])
        );
    }

    #[test]
    fn tolerates_spacing_and_a_missing_login() {
        assert_eq!(
            parse(" PROXY  localhost:80 ;DIRECT; "),
            Ok(vec![proxy("http://localhost:80"), Hop::Direct])
        );
    }

    #[test]
    fn encodes_credentials_that_a_uri_cannot_carry() {
        assert_eq!(
            parse("PROXY a b:p@ss@127.0.0.1:1"),
            Ok(vec![proxy("http://a%20b:p%40ss@127.0.0.1:1")])
        );
    }

    #[test]
    fn rejects_anything_else() {
        for route in [
            "",
            " ; ",
            "direct",
            "SOCKS 127.0.0.1:1",
            "PROXY 127.0.0.1",
            "PROXY :80",
            "PROXY 127.0.0.1:0",
            "PROXY 127.0.0.1:70000",
            "PROXY user@127.0.0.1:80",
            "PROXY :pass@127.0.0.1:80",
            "PROXY host/path:80",
            "DIRECT; PROXY",
        ] {
            assert_eq!(parse(route), Err(InvalidRoute), "{route:?}");
        }
    }
}
