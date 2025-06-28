use axum::{
    Json,
    http::StatusCode,
    response::{IntoResponse, Response},
};
use serde_json::json;
use thiserror::Error;

#[derive(Error, Debug)]
pub enum ApiError {
    #[error("Database error: {0}")]
    Database(#[from] sqlx::Error),

    #[error("Game not found")]
    GameNotFound,

    #[error("Player not found")]
    PlayerNotFound,

    #[error("Game is not active")]
    GameNotActive,

    #[error("Invalid request: {0}")]
    BadRequest(String),

    #[error("WebSocket error: {0}")]
    WebSocket(String),

    #[error("Internal server error")]
    Internal(#[from] anyhow::Error),
}

impl IntoResponse for ApiError {
    fn into_response(self) -> Response {
        let (status, error_message) = match self {
            ApiError::Database(ref e) => {
                tracing::error!("Database error: {:?}", e);
                (StatusCode::INTERNAL_SERVER_ERROR, "Database error occurred")
            }
            ApiError::GameNotFound => (StatusCode::NOT_FOUND, "Game not found"),
            ApiError::PlayerNotFound => (StatusCode::NOT_FOUND, "Player not found"),
            ApiError::GameNotActive => (StatusCode::BAD_REQUEST, "Game is not active"),
            ApiError::BadRequest(ref msg) => (StatusCode::BAD_REQUEST, msg.as_str()),
            ApiError::WebSocket(ref msg) => (StatusCode::BAD_REQUEST, msg.as_str()),
            ApiError::Internal(ref e) => {
                tracing::error!("Internal error: {:?}", e);
                (StatusCode::INTERNAL_SERVER_ERROR, "Internal server error")
            }
        };

        let body = Json(json!({
            "error": error_message,
            "status": status.as_u16()
        }));

        (status, body).into_response()
    }
}

pub type Result<T> = std::result::Result<T, ApiError>;
