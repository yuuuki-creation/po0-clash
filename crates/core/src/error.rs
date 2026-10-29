use std::io;

#[derive(Debug, Clone, PartialEq, Eq, thiserror::Error)]
pub enum CoreError {
    #[error("{0}")]
    Invalid(String),
    #[error("{0}")]
    Network(String),
    #[error("{0}")]
    Engine(String),
    #[error("{0}")]
    Io(String),
}

impl From<io::Error> for CoreError {
    fn from(error: io::Error) -> Self {
        Self::Io(error.to_string())
    }
}

pub type Result<T> = std::result::Result<T, CoreError>;
