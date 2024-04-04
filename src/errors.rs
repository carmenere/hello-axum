use sqlx::error::Error as SqlxErr;
use axum::http::StatusCode;
use axum::{response::{Response, IntoResponse}};
use std::error::Error;
use std::fmt;

#[derive(Debug)]
pub enum AppError {
    DB(String),
    IO(String),
    Serialize(String),
    UnprocessableInput(String)
}

impl Error for AppError {}

impl fmt::Display for AppError {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            AppError::DB(e) => write!(f, "DB error"),
            AppError::IO(e) => write!(f, "IO error"),
            AppError::Serialize(e) => write!(f, "Serialize/Deserialize error"),
            AppError::UnprocessableInput(e) => write!(f, "Unprocessable input"),
        }
    }
}

impl IntoResponse for AppError {
    fn into_response(self) -> Response {
        match self {
            AppError::DB(e) => (StatusCode::UNPROCESSABLE_ENTITY, e).into_response(),
            AppError::IO(e) => (StatusCode::NOT_FOUND, e).into_response(),
            AppError::Serialize(e) => (StatusCode::BAD_REQUEST, e).into_response(),
            AppError::UnprocessableInput(e) => (StatusCode::UNPROCESSABLE_ENTITY, e).into_response(),
        }
    }
}

/// This enables sqlx errors to be converted to AppError using `?` operator.
impl From<SqlxErr> for AppError {
    fn from(e: SqlxErr) -> Self {
        AppError::DB(e.to_string())
    }
}