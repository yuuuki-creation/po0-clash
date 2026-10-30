//! UWP loopback exemption: what EnableLoopback.exe and `CheckNetIsolation LoopbackExempt` edit, without either tool.

use std::collections::HashSet;
use std::ptr::{null, null_mut};

use serde::Serialize;
use windows_sys::Win32::Foundation::LocalFree;
use windows_sys::Win32::NetworkManagement::WindowsFirewall::{
    INET_FIREWALL_APP_CONTAINER, NetworkIsolationEnumAppContainers, NetworkIsolationFreeAppContainers,
    NetworkIsolationGetAppContainerConfig, NetworkIsolationSetAppContainerConfig,
};
use windows_sys::Win32::Security::Authorization::{ConvertSidToStringSidW, ConvertStringSidToSidW};
use windows_sys::Win32::Security::{PSID, SID_AND_ATTRIBUTES};
use windows_sys::Win32::UI::Shell::SHLoadIndirectString;
use windows_sys::core::PWSTR;

#[derive(Serialize)]
#[serde(rename_all = "camelCase")]
pub struct AppContainer {
    sid: String,
    name: String,
    display_name: String,
    exempt: bool,
}

fn check(code: u32) -> Result<(), String> {
    match code {
        0 => Ok(()),
        code => Err(std::io::Error::from_raw_os_error(code as i32).to_string()),
    }
}

/// SAFETY: `text` is null or a NUL-terminated UTF-16 string.
unsafe fn wide(text: *const u16) -> String {
    if text.is_null() {
        return String::new();
    }
    let len = (0..).take_while(|&i| unsafe { *text.add(i) } != 0).count();
    String::from_utf16_lossy(unsafe { std::slice::from_raw_parts(text, len) })
}

/// Package display names are often `@{Package?ms-resource://…}` references into the package's resources.
fn display_name(text: PWSTR) -> String {
    let raw = unsafe { wide(text) };
    if !raw.starts_with('@') {
        return raw;
    }
    let mut buf = [0u16; 512];
    let resolved = unsafe { SHLoadIndirectString(text, buf.as_mut_ptr(), buf.len() as u32, null()) };
    if resolved >= 0 { unsafe { wide(buf.as_ptr()) } } else { String::new() }
}

fn sid_string(sid: PSID) -> Option<String> {
    let mut text: PWSTR = null_mut();
    unsafe {
        if sid.is_null() || ConvertSidToStringSidW(sid, &mut text) == 0 {
            return None;
        }
        let result = wide(text);
        LocalFree(text.cast());
        Some(result)
    }
}

fn exempt_sids() -> Result<HashSet<String>, String> {
    let (mut count, mut entries) = (0u32, null_mut::<SID_AND_ATTRIBUTES>());
    // SAFETY: on success the caller owns the array and every SID in it, each freed with LocalFree.
    unsafe {
        check(NetworkIsolationGetAppContainerConfig(&mut count, &mut entries))?;
        if entries.is_null() {
            return Ok(HashSet::new());
        }
        let list = std::slice::from_raw_parts(entries, count as usize);
        let sids = list.iter().filter_map(|entry| sid_string(entry.Sid)).collect();
        for entry in list {
            LocalFree(entry.Sid);
        }
        LocalFree(entries.cast());
        Ok(sids)
    }
}

pub fn apps() -> Result<Vec<AppContainer>, String> {
    let exempt = exempt_sids()?;
    let (mut count, mut list) = (0u32, null_mut::<INET_FIREWALL_APP_CONTAINER>());
    // SAFETY: the array stays valid until NetworkIsolationFreeAppContainers.
    let containers = unsafe {
        check(NetworkIsolationEnumAppContainers(0, &mut count, &mut list))?;
        if list.is_null() {
            return Ok(Vec::new());
        }
        let containers: Vec<_> = std::slice::from_raw_parts(list, count as usize)
            .iter()
            .filter_map(|c| {
                let sid = sid_string(c.appContainerSid.cast())?;
                let name = wide(c.appContainerName);
                let display_name = Some(display_name(c.displayName)).filter(|d| !d.is_empty()).unwrap_or_else(|| name.clone());
                Some(AppContainer { exempt: exempt.contains(&sid), sid, name, display_name })
            })
            .collect();
        NetworkIsolationFreeAppContainers(list);
        containers
    };
    let mut seen = HashSet::new();
    let mut apps: Vec<_> = containers.into_iter().filter(|app| seen.insert(app.sid.clone())).collect();
    apps.sort_by_cached_key(|app| app.display_name.to_lowercase());
    Ok(apps)
}

/// Replaces the whole exemption list, as the API only takes it whole.
pub fn set(sids: &[String]) -> Result<(), String> {
    let mut owned: Vec<PSID> = Vec::with_capacity(sids.len());
    let free = |owned: &[PSID]| owned.iter().for_each(|&sid| unsafe { LocalFree(sid); });
    for text in sids {
        let text16: Vec<u16> = text.encode_utf16().chain(Some(0)).collect();
        let mut sid: PSID = null_mut();
        if unsafe { ConvertStringSidToSidW(text16.as_ptr(), &mut sid) } == 0 {
            free(&owned);
            return Err(format!("{text}: {}", std::io::Error::last_os_error()));
        }
        owned.push(sid);
    }
    let entries: Vec<_> = owned.iter().map(|&sid| SID_AND_ATTRIBUTES { Sid: sid, Attributes: 0 }).collect();
    let code = unsafe { NetworkIsolationSetAppContainerConfig(entries.len() as u32, entries.as_ptr()) };
    free(&owned);
    check(code)
}
