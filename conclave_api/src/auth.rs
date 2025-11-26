use axum::{
    extract::FromRequestParts,
    http::{header::AUTHORIZATION, request::Parts, StatusCode},
    response::{IntoResponse, Response},
    Json,
};
use serde_json::json;

use crate::clerk::{self, ClerkUser};

/// Authenticated user extracted from JWT token
#[derive(Debug, Clone)]
pub struct AuthenticatedUser {
    pub clerk_user_id: String,
    pub user: ClerkUser,
}

/// Error type for authentication failures
pub struct AuthError(pub String);

impl IntoResponse for AuthError {
    fn into_response(self) -> Response {
        (
            StatusCode::UNAUTHORIZED,
            Json(json!({
                "error": self.0,
                "status": 401
            })),
        )
            .into_response()
    }
}

impl<S> FromRequestParts<S> for AuthenticatedUser
where
    S: Send + Sync,
{
    type Rejection = AuthError;

    async fn from_request_parts(parts: &mut Parts, _state: &S) -> Result<Self, Self::Rejection> {
        // Get Authorization header
        let auth_header = parts
            .headers
            .get(AUTHORIZATION)
            .and_then(|v| v.to_str().ok())
            .ok_or_else(|| AuthError("Missing Authorization header".to_string()))?;

        // Extract Bearer token
        let token = clerk::extract_token_from_header(auth_header)
            .ok_or_else(|| AuthError("Invalid Authorization header format".to_string()))?;

        // Validate token and get user
        let user = clerk::validate_and_get_user(token)
            .await
            .map_err(|e| AuthError(e.to_string()))?;

        Ok(AuthenticatedUser {
            clerk_user_id: user.id.clone(),
            user,
        })
    }
}

/// Optional authenticated user - doesn't fail if no token is present
#[derive(Debug, Clone)]
pub struct OptionalAuthenticatedUser(pub Option<AuthenticatedUser>);

impl<S> FromRequestParts<S> for OptionalAuthenticatedUser
where
    S: Send + Sync,
{
    type Rejection = std::convert::Infallible;

    async fn from_request_parts(parts: &mut Parts, state: &S) -> Result<Self, Self::Rejection> {
        match AuthenticatedUser::from_request_parts(parts, state).await {
            Ok(user) => Ok(OptionalAuthenticatedUser(Some(user))),
            Err(_) => Ok(OptionalAuthenticatedUser(None)),
        }
    }
}
