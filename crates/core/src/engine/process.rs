use std::io::{BufRead, BufReader, Read};
use std::path::Path;
use std::process::{Child, Command, Stdio};
use std::sync::{Arc, Mutex, PoisonError};
use std::thread;
#[cfg(unix)]
use std::time::{Duration, Instant};

use crate::logfile::LogFile;

pub struct Process {
    child: Mutex<Child>,
    #[cfg(target_os = "macos")]
    tun_runner: bool,
    #[cfg(windows)]
    _job: job::Job,
}

impl Process {
    pub fn spawn(
        binary: &Path,
        home: &Path,
        config: &Path,
        log: &Arc<LogFile>,
    ) -> std::io::Result<Self> {
        let mut command = Command::new(binary);
        command
            .arg("-d")
            .arg(home)
            .arg("-f")
            .arg(config)
            .stdin(Stdio::null())
            .stdout(Stdio::piped())
            .stderr(Stdio::piped());
        #[cfg(windows)]
        {
            use std::os::windows::process::CommandExt;
            const CREATE_NO_WINDOW: u32 = 0x0800_0000;
            command.creation_flags(CREATE_NO_WINDOW);
        }
        let mut child = command.spawn()?;
        #[cfg(windows)]
        let job = job::Job::kill_on_close(&child);
        if let Some(out) = child.stdout.take() {
            pipe_lines(out, log.clone());
        }
        if let Some(err) = child.stderr.take() {
            pipe_lines(err, log.clone());
        }
        Ok(Self {
            child: Mutex::new(child),
            #[cfg(target_os = "macos")]
            tun_runner: is_tun_runner(binary),
            #[cfg(windows)]
            _job: job,
        })
    }

    pub fn id(&self) -> u32 {
        self.child
            .lock()
            .unwrap_or_else(PoisonError::into_inner)
            .id()
    }

    pub fn kill(&self) -> std::io::Result<()> {
        let mut child = self.child.lock().unwrap_or_else(PoisonError::into_inner);
        #[cfg(target_os = "macos")]
        if self.tun_runner {
            return stop_tun_runner(&mut child, libc::SIGUSR1);
        }
        child.kill()
    }

    pub fn exited(&self) -> Option<String> {
        let mut child = self.child.lock().unwrap_or_else(PoisonError::into_inner);
        match child.try_wait() {
            Ok(Some(status)) => Some(status.to_string()),
            Ok(None) => None,
            Err(error) => Some(error.to_string()),
        }
    }

    /// SIGTERM first so mihomo removes its routes and TUN device; Windows has no such signal.
    pub fn stop(&self) -> std::io::Result<()> {
        let mut child = self.child.lock().unwrap_or_else(PoisonError::into_inner);
        #[cfg(target_os = "macos")]
        if self.tun_runner {
            return stop_tun_runner(&mut child, libc::SIGTERM);
        }
        if child.try_wait()?.is_some() {
            return Ok(());
        }
        #[cfg(unix)]
        {
            if let Ok(pid) = i32::try_from(child.id()) {
                unsafe { libc::kill(pid, libc::SIGTERM) };
            }
            let deadline = Instant::now() + Duration::from_secs(3);
            while Instant::now() < deadline {
                if child.try_wait()?.is_some() {
                    return Ok(());
                }
                thread::sleep(Duration::from_millis(50));
            }
        }
        child.kill()?;
        child.wait()?;
        Ok(())
    }
}

#[cfg(target_os = "macos")]
pub(super) fn is_tun_runner(binary: &Path) -> bool {
    binary.file_name().is_some_and(|name| name == "po0-tun-runner")
}

#[cfg(target_os = "macos")]
fn stop_tun_runner(child: &mut Child, signal: i32) -> std::io::Result<()> {
    use std::os::unix::process::ExitStatusExt;

    let deadline = Instant::now() + Duration::from_secs(8);
    if child.try_wait()?.is_none() {
        let pid = i32::try_from(child.id()).map_err(std::io::Error::other)?;
        if unsafe { libc::kill(pid, signal) } != 0 {
            let error = std::io::Error::last_os_error();
            if error.raw_os_error() != Some(libc::ESRCH) {
                return Err(error);
            }
        }
    }
    loop {
        if let Some(status) = child.try_wait()? {
            return if status.code() == Some(70) || status.signal().is_some() {
                Err(std::io::Error::other("TUN root engine exit was not confirmed"))
            } else {
                Ok(())
            };
        }
        if Instant::now() >= deadline {
            return Err(std::io::Error::new(
                std::io::ErrorKind::TimedOut,
                "TUN root engine has not confirmed shutdown",
            ));
        }
        thread::sleep(Duration::from_millis(20));
    }
}

fn pipe_lines(stream: impl Read + Send + 'static, log: Arc<LogFile>) {
    thread::spawn(move || {
        for line in BufReader::new(stream).lines().map_while(Result::ok) {
            log.line(&line);
        }
    });
}

/// Best effort for a process left behind by a crashed app: only a pid that still serves our
/// controller endpoint is ours.
pub fn kill_stale(pid: u32) {
    #[cfg(unix)]
    if let Ok(pid) = i32::try_from(pid) {
        unsafe { libc::kill(pid, libc::SIGTERM) };
    }
    #[cfg(windows)]
    unsafe {
        use windows_sys::Win32::Foundation::CloseHandle;
        use windows_sys::Win32::System::Threading::{
            OpenProcess, PROCESS_TERMINATE, TerminateProcess,
        };
        let process = OpenProcess(PROCESS_TERMINATE, 0, pid);
        if !process.is_null() {
            TerminateProcess(process, 1);
            CloseHandle(process);
        }
    }
}

#[cfg(windows)]
mod job {
    use std::os::windows::io::AsRawHandle;
    use std::process::Child;

    use windows_sys::Win32::Foundation::{CloseHandle, HANDLE};
    use windows_sys::Win32::System::JobObjects::{
        AssignProcessToJobObject, CreateJobObjectW, JOB_OBJECT_LIMIT_KILL_ON_JOB_CLOSE,
        JOBOBJECT_EXTENDED_LIMIT_INFORMATION, JobObjectExtendedLimitInformation,
        SetInformationJobObject,
    };

    /// The app may be killed without running its shutdown; the job takes mihomo down with it.
    pub struct Job(HANDLE);

    unsafe impl Send for Job {}
    unsafe impl Sync for Job {}

    impl Job {
        pub fn kill_on_close(child: &Child) -> Self {
            unsafe {
                let job = CreateJobObjectW(std::ptr::null(), std::ptr::null());
                if job.is_null() {
                    return Self(job);
                }
                let mut info: JOBOBJECT_EXTENDED_LIMIT_INFORMATION = std::mem::zeroed();
                info.BasicLimitInformation.LimitFlags = JOB_OBJECT_LIMIT_KILL_ON_JOB_CLOSE;
                SetInformationJobObject(
                    job,
                    JobObjectExtendedLimitInformation,
                    (&raw const info).cast(),
                    size_of::<JOBOBJECT_EXTENDED_LIMIT_INFORMATION>() as u32,
                );
                AssignProcessToJobObject(job, child.as_raw_handle() as HANDLE);
                Self(job)
            }
        }
    }

    impl Drop for Job {
        fn drop(&mut self) {
            if !self.0.is_null() {
                unsafe { CloseHandle(self.0) };
            }
        }
    }
}
