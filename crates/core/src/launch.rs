//! FlClash's launch guard: a launch that ends before it finishes starting makes the next one skip
//! connecting automatically, and two in a row also deselect the profile they were starting.

use std::fs;
use std::io;
use std::path::Path;
use std::time::{SystemTime, UNIX_EPOCH};

use serde::{Deserialize, Serialize};

use crate::model::{ExitKind, LastExit, LaunchRecovery};
use crate::util;

const CLEAR_AFTER: u32 = 2;

#[derive(Debug, Default, Clone, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase", default)]
pub struct Record {
    pub starting: bool,
    pub profile_id: Option<String>,
    pub started_at: i64,
    pub failures: u32,
    pub handled_exit_at: i64,
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct Outcome {
    pub recovery: LaunchRecovery,
    pub failures: u32,
    pub profile_id: Option<String>,
}

pub fn read(path: &Path) -> Record {
    fs::read(path)
        .ok()
        .and_then(|bytes| serde_json::from_slice(&bytes).ok())
        .unwrap_or_default()
}

pub fn write(path: &Path, record: &Record) -> io::Result<()> {
    util::write_atomic(path, &serde_json::to_vec(record)?)
}

pub fn now_ms() -> i64 {
    SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .map_or(0, |elapsed| elapsed.as_millis() as i64)
}

/// A run the system stopped, such as one the user swiped away while it started, is no failure;
/// an exit the platform reported before is not counted twice.
pub fn decide(record: &Record, exit: Option<&LastExit>) -> Outcome {
    let stopped = exit.is_some_and(|exit| {
        exit.kind == ExitKind::Stopped
            && exit.at_ms > record.handled_exit_at
            && exit.at_ms >= record.started_at
    });
    if !record.starting || stopped {
        return Outcome {
            recovery: LaunchRecovery::Normal,
            failures: 0,
            profile_id: None,
        };
    }
    let failures = record.failures + 1;
    let recovery = if failures >= CLEAR_AFTER && record.profile_id.is_some() {
        LaunchRecovery::ClearProfile
    } else {
        LaunchRecovery::SkipAutoConnect
    };
    Outcome {
        recovery,
        failures,
        profile_id: record.profile_id.clone(),
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    fn starting(failures: u32, profile: Option<&str>) -> Record {
        Record {
            starting: true,
            profile_id: profile.map(str::to_owned),
            started_at: 1_000,
            failures,
            handled_exit_at: 500,
        }
    }

    #[test]
    fn interrupted_launches_skip_connecting_then_clear_the_profile() {
        assert_eq!(
            decide(&Record::default(), None).recovery,
            LaunchRecovery::Normal
        );
        let first = decide(&starting(0, Some("p")), None);
        assert_eq!(first.recovery, LaunchRecovery::SkipAutoConnect);
        assert_eq!(first.failures, 1);
        let second = decide(&starting(1, Some("p")), None);
        assert_eq!(second.recovery, LaunchRecovery::ClearProfile);
        assert_eq!(second.profile_id.as_deref(), Some("p"));
        assert_eq!(
            decide(&starting(1, None), None).recovery,
            LaunchRecovery::SkipAutoConnect
        );
    }

    #[test]
    fn a_stop_the_system_reports_for_that_launch_is_no_failure() {
        let exit = |kind, at_ms| LastExit { kind, at_ms };
        let record = starting(1, Some("p"));
        assert_eq!(
            decide(&record, Some(&exit(ExitKind::Stopped, 2_000))).recovery,
            LaunchRecovery::Normal
        );
        for earlier in [exit(ExitKind::Stopped, 500), exit(ExitKind::Stopped, 900)] {
            assert_eq!(
                decide(&record, Some(&earlier)).recovery,
                LaunchRecovery::ClearProfile
            );
        }
        assert_eq!(
            decide(&record, Some(&exit(ExitKind::Crashed, 2_000))).recovery,
            LaunchRecovery::ClearProfile
        );
    }
}
