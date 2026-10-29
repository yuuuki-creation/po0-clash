use std::fs::{self, File, OpenOptions};
use std::io::Write;
use std::path::PathBuf;
use std::sync::{Mutex, OnceLock, PoisonError};

const LIMIT: u64 = 2 << 20;

/// Appends lines to `path`, moving it to `path.1` once it passes 2 MiB.
pub struct LogFile {
    path: PathBuf,
    file: Mutex<Option<(File, u64)>>,
}

impl LogFile {
    pub fn new(path: PathBuf) -> Self {
        Self {
            path,
            file: Mutex::new(None),
        }
    }

    #[cfg(target_os = "android")]
    pub fn path(&self) -> &std::path::Path {
        &self.path
    }

    pub fn line(&self, text: &str) {
        let mut guard = self.file.lock().unwrap_or_else(PoisonError::into_inner);
        if guard.as_ref().is_some_and(|(_, size)| *size > LIMIT) {
            *guard = None;
            let _ = fs::rename(&self.path, self.path.with_extension("log.1"));
        }
        if guard.is_none() {
            if let Some(parent) = self.path.parent() {
                let _ = fs::create_dir_all(parent);
            }
            let Ok(file) = OpenOptions::new()
                .create(true)
                .append(true)
                .open(&self.path)
            else {
                return;
            };
            let size = file.metadata().map_or(0, |meta| meta.len());
            *guard = Some((file, size));
        }
        if let Some((file, size)) = guard.as_mut() {
            let line = format!("{} {text}\n", timestamp());
            if file.write_all(line.as_bytes()).is_ok() {
                *size += line.len() as u64;
            }
        }
    }

    /// The rotated file first, so the result reads oldest to newest.
    pub fn read_all(&self) -> String {
        let mut text = fs::read_to_string(self.path.with_extension("log.1")).unwrap_or_default();
        text.push_str(&fs::read_to_string(&self.path).unwrap_or_default());
        text
    }
}

fn timestamp() -> String {
    let secs = crate::util::now();
    let (days, rem) = (secs.div_euclid(86_400), secs.rem_euclid(86_400));
    let (y, m, d) = civil_from_days(days);
    format!(
        "{y:04}-{m:02}-{d:02}T{:02}:{:02}:{:02}Z",
        rem / 3600,
        rem % 3600 / 60,
        rem % 60
    )
}

fn civil_from_days(days: i64) -> (i64, i64, i64) {
    let z = days + 719_468;
    let era = z.div_euclid(146_097);
    let doe = z.rem_euclid(146_097);
    let yoe = (doe - doe / 1460 + doe / 36_524 - doe / 146_096) / 365;
    let doy = doe - (365 * yoe + yoe / 4 - yoe / 100);
    let mp = (5 * doy + 2) / 153;
    let d = doy - (153 * mp + 2) / 5 + 1;
    let m = if mp < 10 { mp + 3 } else { mp - 9 };
    (yoe + era * 400 + i64::from(m <= 2), m, d)
}

static CORE_LOG: OnceLock<LogFile> = OnceLock::new();

pub fn init(path: PathBuf) {
    let _ = CORE_LOG.set(LogFile::new(path));
}

pub fn core() -> Option<&'static LogFile> {
    CORE_LOG.get()
}

pub fn info(text: impl AsRef<str>) {
    if let Some(log) = CORE_LOG.get() {
        log.line(&format!("INFO {}", text.as_ref()));
    }
}

pub fn warn(text: impl AsRef<str>) {
    if let Some(log) = CORE_LOG.get() {
        log.line(&format!("WARN {}", text.as_ref()));
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn converts_days_to_dates() {
        assert_eq!(civil_from_days(0), (1970, 1, 1));
        assert_eq!(civil_from_days(20_755), (2026, 10, 29));
    }

    #[test]
    fn rotates_past_the_limit() {
        let dir = std::env::temp_dir().join(format!("po0-log-{}", crate::util::random_id()));
        let log = LogFile::new(dir.join("core.log"));
        let line = "x".repeat(1024);
        for _ in 0..2100 {
            log.line(&line);
        }
        assert!(dir.join("core.log.1").exists());
        assert!(fs::metadata(dir.join("core.log")).unwrap().len() < LIMIT);
        assert!(log.read_all().len() > LIMIT as usize);
        fs::remove_dir_all(dir).unwrap();
    }
}
