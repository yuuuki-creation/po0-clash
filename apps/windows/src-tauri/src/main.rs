#![cfg_attr(not(debug_assertions), windows_subsystem = "windows")]

#[cfg(windows)]
mod shell;

fn main() {
    #[cfg(windows)]
    shell::run();
}
