use std::fs::{File, OpenOptions};
use std::io::{self, Read, Write};
use std::os::windows::fs::OpenOptionsExt;
use std::os::windows::io::{AsRawHandle, FromRawHandle, OwnedHandle};
use std::ptr;
use std::thread;
use std::time::{Duration, Instant};

use windows_sys::Win32::Foundation::{
    ERROR_BROKEN_PIPE, ERROR_IO_INCOMPLETE, ERROR_IO_PENDING, ERROR_PIPE_BUSY, HANDLE, WAIT_TIMEOUT,
};
use windows_sys::Win32::Storage::FileSystem::{FILE_FLAG_OVERLAPPED, ReadFile, WriteFile};
use windows_sys::Win32::System::IO::{
    CancelIoEx, GetOverlappedResult, GetOverlappedResultEx, OVERLAPPED,
};
use windows_sys::Win32::System::Threading::CreateEventW;

use super::{Timeout, timed_out};

pub(super) struct Pipe {
    file: File,
    timeout: Timeout,
}

impl Pipe {
    pub(super) fn connect(name: &str, timeout: Timeout) -> io::Result<Self> {
        let deadline = Timeout::Deadline(Instant::now() + timeout.remaining()?);
        loop {
            let remaining = deadline.remaining()?;
            match OpenOptions::new()
                .read(true)
                .write(true)
                .custom_flags(FILE_FLAG_OVERLAPPED)
                .open(name)
            {
                Ok(file) => return Ok(Self { file, timeout }),
                Err(error) if error.raw_os_error() == Some(ERROR_PIPE_BUSY as i32) => {
                    thread::sleep(remaining.min(Duration::from_millis(25)));
                }
                Err(error) => return Err(error),
            }
        }
    }

    fn transfer(&self, start: impl FnOnce(HANDLE, *mut OVERLAPPED) -> i32) -> io::Result<usize> {
        self.timeout.remaining()?;
        let event = unsafe { CreateEventW(ptr::null(), 1, 0, ptr::null()) };
        if event.is_null() {
            return Err(io::Error::last_os_error());
        }
        let event = unsafe { OwnedHandle::from_raw_handle(event) };
        let mut overlapped = OVERLAPPED {
            hEvent: event.as_raw_handle(),
            ..unsafe { std::mem::zeroed() }
        };
        let handle = self.file.as_raw_handle();
        if start(handle, &mut overlapped) == 0 {
            let error = io::Error::last_os_error();
            if error.raw_os_error() != Some(ERROR_IO_PENDING as i32) {
                return Err(error);
            }
        }
        let wait = self.timeout.remaining().map_or(0, |remaining| {
            remaining.as_millis().max(1).min(u32::MAX as u128 - 1) as u32
        });
        let mut transferred = 0;
        if unsafe { GetOverlappedResultEx(handle, &raw const overlapped, &mut transferred, wait, 0) } != 0 {
            return Ok(transferred as usize);
        }
        let error = io::Error::last_os_error();
        // Cancellation is asynchronous; the buffer and OVERLAPPED must live until completion.
        unsafe {
            CancelIoEx(handle, &raw const overlapped);
            GetOverlappedResult(handle, &raw const overlapped, &mut transferred, 1);
        }
        if matches!(error.raw_os_error(), Some(code) if code == WAIT_TIMEOUT as i32 || code == ERROR_IO_INCOMPLETE as i32) {
            Err(timed_out())
        } else {
            Err(error)
        }
    }
}

impl Read for Pipe {
    fn read(&mut self, buffer: &mut [u8]) -> io::Result<usize> {
        if buffer.is_empty() {
            return Ok(0);
        }
        let result = self.transfer(|handle, overlapped| unsafe {
            ReadFile(handle, buffer.as_mut_ptr().cast(), buffer.len().min(u32::MAX as usize) as u32, ptr::null_mut(), overlapped)
        });
        match result {
            Err(error) if error.raw_os_error() == Some(ERROR_BROKEN_PIPE as i32) => Ok(0),
            result => result,
        }
    }
}

impl Write for Pipe {
    fn write(&mut self, buffer: &[u8]) -> io::Result<usize> {
        if buffer.is_empty() {
            return Ok(0);
        }
        self.transfer(|handle, overlapped| unsafe {
            WriteFile(handle, buffer.as_ptr().cast(), buffer.len().min(u32::MAX as usize) as u32, ptr::null_mut(), overlapped)
        })
    }

    fn flush(&mut self) -> io::Result<()> {
        Ok(())
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::io::{BufRead, BufReader};
    use std::sync::mpsc;

    use windows_sys::Win32::Foundation::{ERROR_PIPE_CONNECTED, INVALID_HANDLE_VALUE};
    use windows_sys::Win32::Storage::FileSystem::PIPE_ACCESS_DUPLEX;
    use windows_sys::Win32::System::Pipes::{
        ConnectNamedPipe, CreateNamedPipeW, PIPE_TYPE_BYTE, PIPE_WAIT,
    };

    use super::super::{Controller, Endpoint};

    fn serve(
        read_head: bool,
        reply: impl FnOnce(File) + Send + 'static,
    ) -> (Controller, thread::JoinHandle<()>) {
        let name = format!(r"\\.\pipe\po0-controller-test-{}", crate::util::random_id());
        let wide: Vec<_> = name.encode_utf16().chain(Some(0)).collect();
        let handle = unsafe {
            CreateNamedPipeW(wide.as_ptr(), PIPE_ACCESS_DUPLEX, PIPE_TYPE_BYTE | PIPE_WAIT, 1, 4096, 4096, 0, ptr::null())
        };
        assert_ne!(handle, INVALID_HANDLE_VALUE);
        let file = unsafe { File::from_raw_handle(handle) };
        let server = thread::spawn(move || {
            if unsafe { ConnectNamedPipe(file.as_raw_handle(), ptr::null_mut()) } == 0 {
                assert_eq!(io::Error::last_os_error().raw_os_error(), Some(ERROR_PIPE_CONNECTED as i32));
            }
            if read_head {
                let mut reader = BufReader::new(file.try_clone().unwrap());
                loop {
                    let mut line = String::new();
                    assert!(reader.read_line(&mut line).unwrap() > 0);
                    if line == "\r\n" {
                        break;
                    }
                }
            }
            reply(file);
        });
        (Controller::new(Endpoint::Pipe(name), String::new()), server)
    }

    #[test]
    fn reads_named_pipe_responses() {
        let (release, released) = mpsc::channel();
        let (controller, server) = serve(true, move |mut file| {
            file.write_all(b"HTTP/1.1 200 OK\r\nContent-Length: 2\r\n\r\n{}").unwrap();
            let _ = released.recv_timeout(Duration::from_secs(2));
        });
        assert_eq!(controller.request("GET", "/version", None).unwrap(), (200, "{}".into()));
        release.send(()).unwrap();
        server.join().unwrap();
    }

    #[test]
    fn cancels_a_stalled_response_head_or_body() {
        for prefix in [b"".as_slice(), b"HTTP/1.1 200 OK\r\nContent-Length: 10\r\n\r\nx"] {
            let (release, released) = mpsc::channel();
            let (controller, server) = serve(true, move |mut file| {
                file.write_all(prefix).unwrap();
                let _ = released.recv_timeout(Duration::from_secs(2));
            });
            let result = controller.request_within("GET", "/version", None, Duration::from_millis(100));
            release.send(()).unwrap();
            server.join().unwrap();
            assert_eq!(result.unwrap_err().kind(), io::ErrorKind::TimedOut);
        }
    }

    #[test]
    fn a_slow_body_cannot_extend_the_request_deadline() {
        let (controller, server) = serve(true, |mut file| {
            file.write_all(b"HTTP/1.1 200 OK\r\nContent-Length: 10\r\n\r\n").unwrap();
            for _ in 0..10 {
                thread::sleep(Duration::from_millis(40));
                if file.write_all(b"x").is_err() {
                    break;
                }
            }
        });
        let result = controller.request_within("GET", "/version", None, Duration::from_millis(100));
        server.join().unwrap();
        assert_eq!(result.unwrap_err().kind(), io::ErrorKind::TimedOut);
    }

    #[test]
    fn cancels_a_write_when_the_server_does_not_read() {
        let (release, released) = mpsc::channel();
        let (controller, server) = serve(false, move |_file| {
            let _ = released.recv_timeout(Duration::from_secs(2));
        });
        let body = serde_json::json!({ "config": "x".repeat(1 << 20) });
        let result = controller.request_within("PUT", "/configs", Some(&body), Duration::from_millis(100));
        release.send(()).unwrap();
        server.join().unwrap();
        assert_eq!(result.unwrap_err().kind(), io::ErrorKind::TimedOut);
    }
}
