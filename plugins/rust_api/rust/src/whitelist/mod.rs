mod route;
mod transport;

use std::sync::LazyLock;
use std::time::Duration;

use transport::{Method, Transport};
pub use transport::{Response, SendError};

static TRANSPORT: LazyLock<Transport> = LazyLock::new(Transport::default);

pub fn send(
    method: &str,
    url: &str,
    route: &str,
    timeout: Duration,
) -> Result<Response, SendError> {
    TRANSPORT.send(Method::parse(method)?, url, route, timeout)
}

pub fn reset() {
    TRANSPORT.reset();
}
