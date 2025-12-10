use crate::errors::{ApiError, Result};
use jsonwebtoken::{DecodingKey, Validation, decode, decode_header};
use once_cell::sync::OnceCell;
use reqwest::Client;
use serde::{Deserialize, Serialize};
use std::collections::HashMap;
use std::sync::Arc;
use tokio::sync::RwLock;
use tracing::{debug, error, info, warn};

/// Clerk user information extracted from JWT or fetched from API
#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub struct ClerkUser {
    pub id: String,
    pub username: Option<String>,
    pub first_name: Option<String>,
    pub last_name: Option<String>,
    pub image_url: Option<String>,
}

impl ClerkUser {
    /// Get the display name for this user
    pub fn display_name(&self) -> String {
        // Try full name first
        match (&self.first_name, &self.last_name) {
            (Some(first), Some(last)) if !first.is_empty() && !last.is_empty() => {
                format!("{} {}", first, last)
            }
            (Some(first), _) if !first.is_empty() => first.clone(),
            (_, Some(last)) if !last.is_empty() => last.clone(),
            _ => {
                // Fall back to username
                self.username
                    .clone()
                    .filter(|u| !u.is_empty())
                    .unwrap_or_else(|| {
                        // Last resort: truncated user ID
                        if self.id.len() > 8 {
                            format!("User {}", &self.id[..8])
                        } else {
                            format!("User {}", self.id)
                        }
                    })
            }
        }
    }
}

/// JWT Claims from Clerk tokens (includes custom, snake_case user fields)
#[derive(Debug, Deserialize)]
#[serde(rename_all = "snake_case")]
pub struct ClerkClaims {
    /// Subject - the Clerk user ID
    pub sub: String,
    /// Expiration time
    pub exp: usize,
    /// Issued at
    pub iat: usize,
    /// Issuer
    pub iss: Option<String>,
    /// Authorized party (the frontend app)
    pub azp: Option<String>,
    // Custom user fields included in the token to avoid extra API calls
    pub id: Option<String>,
    pub username: Option<String>,
    pub first_name: Option<String>,
    pub last_name: Option<String>,
    pub image_url: Option<String>,
    // Some setups may use "image" instead of "image_url"
    pub image: Option<String>,
}

/// JWKS response from Clerk
#[derive(Debug, Deserialize)]
struct JwksResponse {
    keys: Vec<JwkKey>,
}

#[derive(Debug, Deserialize)]
struct JwkKey {
    kid: String,
    kty: String,
    n: String,
    e: String,
    #[serde(rename = "use")]
    key_use: Option<String>,
}

/// Clerk client for JWT validation and user info fetching
pub struct ClerkClient {
    http_client: Client,
    secret_key: Option<String>,
    jwks_url: Option<String>,
    /// Cache of JWKS keys by kid
    jwks_cache: Arc<RwLock<HashMap<String, DecodingKey>>>,
    /// Cache of user info by user ID
    user_cache: Arc<RwLock<HashMap<String, ClerkUser>>>,
}

// Global Clerk client instance
static CLERK_CLIENT: OnceCell<ClerkClient> = OnceCell::new();

impl ClerkClient {
    /// Initialize the global Clerk client
    pub fn init() -> Result<()> {
        let secret_key = std::env::var("CLERK_SECRET_KEY").ok();
        let jwks_url = std::env::var("CLERK_JWKS_URL").ok();

        match (secret_key.as_ref(), jwks_url.as_ref()) {
            (Some(_), Some(_)) => {
                // Strict mode enabled
            }
            (None, None) => {
                // Dev mode - skip signature validation
                warn!(
                    "CLERK_SECRET_KEY and CLERK_JWKS_URL not set - dev mode: JWT signature validation disabled"
                );
            }
            _ => {
                return Err(ApiError::Internal(anyhow::anyhow!(
                    "Invalid Clerk configuration: set BOTH CLERK_SECRET_KEY and CLERK_JWKS_URL, or NEITHER for development"
                )));
            }
        }

        let client = ClerkClient {
            http_client: Client::new(),
            secret_key,
            jwks_url,
            jwks_cache: Arc::new(RwLock::new(HashMap::new())),
            user_cache: Arc::new(RwLock::new(HashMap::new())),
        };

        CLERK_CLIENT
            .set(client)
            .map_err(|_| ApiError::Internal(anyhow::anyhow!("Clerk client already initialized")))?;

        info!("✅ Clerk client initialized");
        Ok(())
    }

    /// Get the global Clerk client instance
    pub fn get() -> Result<&'static ClerkClient> {
        CLERK_CLIENT
            .get()
            .ok_or_else(|| ApiError::Internal(anyhow::anyhow!("Clerk client not initialized")))
    }

    /// Validate a JWT token and extract claims
    pub async fn validate_token(&self, token: &str) -> Result<ClerkClaims> {
        // Dev mode: neither environment variable set -> skip signature validation
        if self.secret_key.is_none() && self.jwks_url.is_none() {
            let mut validation = Validation::default();
            validation.insecure_disable_signature_validation();
            validation.validate_exp = false;

            let token_data =
                decode::<ClerkClaims>(token, &DecodingKey::from_secret(&[]), &validation).map_err(
                    |e| {
                        error!("Failed to decode JWT: {:?}", e);
                        ApiError::Unauthorized("Invalid token format".to_string())
                    },
                )?;

            warn!("JWT signature validation skipped (dev mode)");
            return Ok(token_data.claims);
        }

        // Strict mode: require both to be set, and validate via JWKS only
        if !(self.secret_key.is_some() && self.jwks_url.is_some()) {
            return Err(ApiError::Internal(anyhow::anyhow!(
                "Invalid Clerk configuration: both CLERK_SECRET_KEY and CLERK_JWKS_URL must be set together"
            )));
        }
        let jwks_url = self
            .jwks_url
            .as_ref()
            .ok_or_else(|| ApiError::Internal(anyhow::anyhow!("JWKS URL missing")))?;
        self.validate_with_jwks(token, jwks_url).await
    }

    async fn validate_with_jwks(&self, token: &str, jwks_url: &str) -> Result<ClerkClaims> {
        // Get the key ID from the token header
        let header = decode_header(token).map_err(|e| {
            error!("Failed to decode token header: {:?}", e);
            ApiError::Unauthorized("Invalid token header".to_string())
        })?;

        let kid = header
            .kid
            .ok_or_else(|| ApiError::Unauthorized("Token missing key ID".to_string()))?;

        // Check cache first
        let cached_key = None;
        // let cached_key = {
        //     let cache = self.jwks_cache.read().await;
        //     cache.get(&kid).cloned()
        // };

        let decoding_key = match cached_key {
            Some(key) => key,
            None => {
                // Fetch JWKS
                let response: JwksResponse = self
                    .http_client
                    .get(jwks_url)
                    .send()
                    .await
                    .map_err(|e| {
                        error!("Failed to fetch JWKS: {:?}", e);
                        ApiError::Internal(anyhow::anyhow!("Failed to fetch JWKS"))
                    })?
                    .json()
                    .await
                    .map_err(|e| {
                        error!("Failed to parse JWKS response: {:?}", e);
                        ApiError::Internal(anyhow::anyhow!("Failed to parse JWKS"))
                    })?;

                // Find the matching key
                let jwk =
                    response.keys.iter().find(|k| k.kid == kid).ok_or_else(|| {
                        ApiError::Unauthorized("Key not found in JWKS".to_string())
                    })?;

                // Create decoding key from JWK
                let decoding_key =
                    DecodingKey::from_rsa_components(&jwk.n, &jwk.e).map_err(|e| {
                        error!("Failed to create decoding key: {:?}", e);
                        ApiError::Internal(anyhow::anyhow!("Failed to create decoding key"))
                    })?;

                // Cache all keys
                let mut cache = self.jwks_cache.write().await;
                for key in response.keys {
                    if let Ok(dk) = DecodingKey::from_rsa_components(&key.n, &key.e) {
                        cache.insert(key.kid, dk);
                    }
                }

                cache.get(&kid).cloned().ok_or_else(|| {
                    ApiError::Unauthorized("Key not found after caching".to_string())
                })?
            }
        };

        // Validate token
        let mut validation = Validation::new(jsonwebtoken::Algorithm::RS256);
        validation.validate_exp = true;

        let token_data = decode::<ClerkClaims>(token, &decoding_key, &validation).map_err(|e| {
            error!("JWT validation failed: {:?}", e);
            ApiError::Unauthorized("Invalid or expired token".to_string())
        })?;

        Ok(token_data.claims)
    }

    /// Fetch user info from Clerk API
    pub async fn get_user(&self, user_id: &str) -> Result<ClerkUser> {
        // Check cache first
        {
            let cache = self.user_cache.read().await;
            if let Some(user) = cache.get(user_id) {
                return Ok(user.clone());
            }
        }

        // Fetch from Clerk API if we have a secret key
        let secret = self.secret_key.as_ref().ok_or_else(|| {
            // If no secret key, return a minimal user object
            debug!("No CLERK_SECRET_KEY set, returning minimal user info");
            ApiError::Internal(anyhow::anyhow!("No Clerk secret key configured"))
        })?;

        let url = format!("https://api.clerk.com/v1/users/{}", user_id);
        let response = self
            .http_client
            .get(&url)
            .header("Authorization", format!("Bearer {}", secret))
            .send()
            .await
            .map_err(|e| {
                error!("Failed to fetch user from Clerk: {:?}", e);
                ApiError::Internal(anyhow::anyhow!("Failed to fetch user info"))
            })?;

        if !response.status().is_success() {
            let status = response.status();
            let body = response.text().await.unwrap_or_default();
            error!("Clerk API error: {} - {}", status, body);
            // Return a minimal user on error
            return Ok(ClerkUser {
                id: user_id.to_string(),
                username: None,
                first_name: None,
                last_name: None,
                image_url: None,
            });
        }
        let user: ClerkUser = response.json().await.map_err(|e| {
            error!("Failed to parse Clerk user response: {:?}", e);
            ApiError::Internal(anyhow::anyhow!("Failed to parse user info"))
        })?;

        // Cache the user
        {
            let mut cache = self.user_cache.write().await;
            cache.insert(user_id.to_string(), user.clone());
        }
        Ok(user)
    }

    /// Get user info, returning a default if fetch fails
    pub async fn get_user_or_default(&self, user_id: &str) -> ClerkUser {
        match self.get_user(user_id).await {
            Ok(user) => user,
            Err(e) => {
                debug!("Failed to fetch user {}: {:?}", user_id, e);
                ClerkUser {
                    id: user_id.to_string(),
                    username: None,
                    first_name: None,
                    last_name: None,
                    image_url: None,
                }
            }
        }
    }

    /// Clear user from cache (e.g., when they update their profile)
    #[allow(dead_code)]
    pub async fn invalidate_user_cache(&self, user_id: &str) {
        let mut cache = self.user_cache.write().await;
        cache.remove(user_id);
    }
}

/// Extract JWT token from Authorization header
pub fn extract_token_from_header(auth_header: &str) -> Option<&str> {
    auth_header.strip_prefix("Bearer ")
}

/// Validate a token and return the user ID
pub async fn validate_and_get_user_id(token: &str) -> Result<String> {
    let client = ClerkClient::get()?;
    let claims = client.validate_token(token).await?;
    Ok(claims.sub)
}

/// Validate a token and return full user info
pub async fn validate_and_get_user(token: &str) -> Result<ClerkUser> {
    let client = ClerkClient::get()?;
    let claims = client.validate_token(token).await?;
    // Prefer user info from claims (trusted if JWKS validated)
    let id = claims.id.clone().unwrap_or_else(|| claims.sub.clone());
    let image_url = claims.image_url.clone().or(claims.image.clone());
    // If any profile fields are present in claims, use them directly
    if claims.username.is_some()
        || claims.first_name.is_some()
        || claims.last_name.is_some()
        || image_url.is_some()
    {
        return Ok(ClerkUser {
            id,
            username: claims.username.clone(),
            first_name: claims.first_name.clone(),
            last_name: claims.last_name.clone(),
            image_url,
        });
    }
    // Otherwise, fall back to REST fetch only if secret is available; else minimal user
    if client.secret_key.is_some() {
        return client.get_user(&claims.sub).await;
    }
    Ok(ClerkUser {
        id,
        username: None,
        first_name: None,
        last_name: None,
        image_url: None,
    })
}
