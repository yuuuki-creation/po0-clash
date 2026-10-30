use std::os::windows::process::CommandExt;
use std::path::Path;
use std::process::{Command, Output};

const TASK_NAME: &str = "po0-clash";
const CREATE_NO_WINDOW: u32 = 0x0800_0000;

pub const ARG: &str = "--autostart";

fn schtasks(args: &[&str]) -> std::io::Result<Output> {
    Command::new("schtasks").args(args).creation_flags(CREATE_NO_WINDOW).output()
}

fn check(output: std::io::Result<Output>) -> Result<(), String> {
    let output = output.map_err(|e| e.to_string())?;
    if output.status.success() {
        return Ok(());
    }
    let stderr = String::from_utf8_lossy(&output.stderr);
    let message = stderr.trim();
    Err(if message.is_empty() { format!("schtasks exited with {}", output.status) } else { message.to_string() })
}

pub fn enabled() -> bool {
    schtasks(&["/Query", "/TN", TASK_NAME]).is_ok_and(|o| o.status.success())
}

pub fn set(enabled: bool) -> Result<(), String> {
    if !enabled {
        return check(schtasks(&["/Delete", "/TN", TASK_NAME, "/F"]));
    }
    let exe = std::env::current_exe().map_err(|e| e.to_string())?;
    let user = match (std::env::var("USERDOMAIN"), std::env::var("USERNAME")) {
        (Ok(domain), Ok(name)) => format!("{domain}\\{name}"),
        (_, Ok(name)) => name,
        _ => return Err("cannot determine the current user".into()),
    };
    let file = std::env::temp_dir().join("po0-clash-autostart.xml");
    std::fs::write(&file, utf16_with_bom(&task_xml(&exe, &user))).map_err(|e| e.to_string())?;
    let result = check(schtasks(&["/Create", "/TN", TASK_NAME, "/XML", &file.to_string_lossy(), "/F"]));
    let _ = std::fs::remove_file(&file);
    result
}

fn utf16_with_bom(text: &str) -> Vec<u8> {
    std::iter::once(0xFEFF).chain(text.encode_utf16()).flat_map(u16::to_le_bytes).collect()
}

fn escape(text: &str) -> String {
    text.replace('&', "&amp;").replace('<', "&lt;").replace('>', "&gt;").replace('"', "&quot;")
}

// Written as XML because schtasks /SC ONLOGON would keep its defaults: a 72-hour run limit that kills the app, no start
// on battery, and below-normal priority.
fn task_xml(exe: &Path, user: &str) -> String {
    let exe = escape(&exe.to_string_lossy());
    let user = escape(user);
    format!(
        r#"<?xml version="1.0" encoding="UTF-16"?>
<Task version="1.2" xmlns="http://schemas.microsoft.com/windows/2004/02/mit/task">
  <RegistrationInfo><Description>po0-clash</Description></RegistrationInfo>
  <Triggers><LogonTrigger><Enabled>true</Enabled><UserId>{user}</UserId></LogonTrigger></Triggers>
  <Principals>
    <Principal id="Author">
      <UserId>{user}</UserId>
      <LogonType>InteractiveToken</LogonType>
      <RunLevel>HighestAvailable</RunLevel>
    </Principal>
  </Principals>
  <Settings>
    <MultipleInstancesPolicy>IgnoreNew</MultipleInstancesPolicy>
    <DisallowStartIfOnBatteries>false</DisallowStartIfOnBatteries>
    <StopIfGoingOnBatteries>false</StopIfGoingOnBatteries>
    <AllowHardTerminate>true</AllowHardTerminate>
    <StartWhenAvailable>false</StartWhenAvailable>
    <RunOnlyIfNetworkAvailable>false</RunOnlyIfNetworkAvailable>
    <IdleSettings><StopOnIdleEnd>false</StopOnIdleEnd><RestartOnIdle>false</RestartOnIdle></IdleSettings>
    <AllowStartOnDemand>true</AllowStartOnDemand>
    <Enabled>true</Enabled>
    <Hidden>false</Hidden>
    <RunOnlyIfIdle>false</RunOnlyIfIdle>
    <ExecutionTimeLimit>PT0S</ExecutionTimeLimit>
    <Priority>4</Priority>
  </Settings>
  <Actions Context="Author">
    <Exec><Command>"{exe}"</Command><Arguments>{ARG}</Arguments></Exec>
  </Actions>
</Task>
"#
    )
}
