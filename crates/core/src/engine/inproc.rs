use std::ffi::{CStr, CString, c_char, c_void};
use std::path::Path;
use std::sync::OnceLock;

type StartFn = unsafe extern "C" fn(*const c_char, *const c_char, *const c_char) -> *mut c_char;
type StopFn = unsafe extern "C" fn();
type FreeFn = unsafe extern "C" fn(*mut c_char);

/// The Android app ships mihomo as the Go c-shared library `libmihomo.so` with this C ABI.
struct Library {
    start: StartFn,
    stop: StopFn,
    free: FreeFn,
}

static LIBRARY: OnceLock<Result<Library, String>> = OnceLock::new();

fn library() -> Result<&'static Library, String> {
    LIBRARY.get_or_init(load).as_ref().map_err(Clone::clone)
}

fn dlerror() -> String {
    let error = unsafe { libc::dlerror() };
    if error.is_null() {
        return "unknown dlopen error".into();
    }
    unsafe { CStr::from_ptr(error) }
        .to_string_lossy()
        .into_owned()
}

fn load() -> Result<Library, String> {
    unsafe {
        let handle = libc::dlopen(c"libmihomo.so".as_ptr(), libc::RTLD_NOW);
        if handle.is_null() {
            return Err(dlerror());
        }
        let symbol = |name: &CStr| -> Result<*mut c_void, String> {
            let pointer = libc::dlsym(handle, name.as_ptr());
            if pointer.is_null() {
                Err(dlerror())
            } else {
                Ok(pointer)
            }
        };
        Ok(Library {
            start: std::mem::transmute::<*mut c_void, StartFn>(symbol(c"po0_mihomo_start")?),
            stop: std::mem::transmute::<*mut c_void, StopFn>(symbol(c"po0_mihomo_stop")?),
            free: std::mem::transmute::<*mut c_void, FreeFn>(symbol(c"po0_mihomo_free")?),
        })
    }
}

fn c_path(path: &Path) -> Result<CString, String> {
    CString::new(path.to_string_lossy().into_owned()).map_err(|error| error.to_string())
}

pub fn start(home: &Path, config: &Path, log: &Path) -> Result<(), String> {
    let library = library()?;
    let (home, config, log) = (c_path(home)?, c_path(config)?, c_path(log)?);
    let error = unsafe { (library.start)(home.as_ptr(), config.as_ptr(), log.as_ptr()) };
    if error.is_null() {
        return Ok(());
    }
    let message = unsafe { CStr::from_ptr(error) }
        .to_string_lossy()
        .into_owned();
    unsafe { (library.free)(error) };
    Err(message)
}

pub fn stop() {
    if let Ok(library) = library() {
        unsafe { (library.stop)() };
    }
}
