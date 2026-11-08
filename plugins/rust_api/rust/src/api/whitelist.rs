use std::time::Duration;

use crate::frb_generated::FLUTTER_RUST_BRIDGE_HANDLER;
use crate::whitelist;
use flutter_rust_bridge::frb;

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct WhitelistResponse {
    pub status: u16,
    pub body: String,
}

/// On a blocking worker, so a stalled request cannot hold the pool that carries Core IPC calls.
#[frb]
pub async fn whitelist_send(
    method: String,
    url: String,
    route: String,
    timeout_ms: u32,
) -> Result<WhitelistResponse, String> {
    let timeout = Duration::from_millis(timeout_ms.into());
    flutter_rust_bridge::spawn_blocking_with(
        move || whitelist::send(&method, &url, &route, timeout),
        FLUTTER_RUST_BRIDGE_HANDLER.thread_pool(),
    )
    .await
    .map_err(|error| error.to_string())?
    .map(|response| WhitelistResponse {
        status: response.status,
        body: response.body,
    })
    .map_err(|error| error.to_string())
}

#[frb(sync)]
pub fn whitelist_reset_connections() {
    whitelist::reset();
}
