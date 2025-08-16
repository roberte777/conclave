mod database;
mod errors;
mod handlers;
mod models;
mod state;
mod websocket;

use axum::{
    Router,
    http::{Method, header::CONTENT_TYPE},
    routing::{get, post, put},
};
use state::AppState;
use std::net::SocketAddr;
use tower::ServiceBuilder;
use tower_http::{
    cors::{Any, CorsLayer},
    trace::TraceLayer,
};
use tracing::info;
use tracing_subscriber::{layer::SubscriberExt, util::SubscriberInitExt};

#[tokio::main]
async fn main() -> anyhow::Result<()> {
    // Initialize tracing
    tracing_subscriber::registry()
        .with(
            tracing_subscriber::EnvFilter::try_from_default_env().unwrap_or_else(|_| {
                "conclave_api=debug,tower_http=debug,axum::rejection=trace".into()
            }),
        )
        .with(tracing_subscriber::fmt::layer())
        .init();

    info!("🎯 Starting Conclave API Server...");

    // Initialize database
    let db_pool = database::create_pool().await?;
    info!("✅ Database connected and migrations completed");

    // Create application state
    let app_state = AppState::new(db_pool);

    // Configure CORS
    let cors = CorsLayer::new()
        .allow_methods([Method::GET, Method::POST, Method::PUT, Method::DELETE])
        .allow_headers([CONTENT_TYPE])
        .allow_origin(Any);

    // Build the API v1 router
    let api_v1_router = Router::new()
        // Health and monitoring endpoints
        .route("/health", get(handlers::health_check))
        .route("/stats", get(handlers::get_stats))
        // User endpoints (users managed by Clerk)
        .route(
            "/users/{clerk_user_id}/history",
            get(handlers::get_user_history),
        )
        .route(
            "/users/{clerk_user_id}/games",
            get(handlers::get_user_games),
        )
        .route(
            "/users/{clerk_user_id}/available-games",
            get(handlers::get_available_games),
        )
        // Game endpoints
        .route("/games", post(handlers::create_game))
        .route("/games", get(handlers::get_all_games))
        .route("/games/{game_id}", get(handlers::get_game))
        .route("/games/{game_id}/state", get(handlers::get_game_state))
        .route("/games/{game_id}/join", post(handlers::join_game))
        .route("/games/{game_id}/leave", post(handlers::leave_game))
        .route("/games/{game_id}/update-life", put(handlers::update_life))
        .route("/games/{game_id}/end", put(handlers::end_game))
        .route(
            "/games/{game_id}/life-changes",
            get(handlers::get_recent_life_changes),
        )
        // Commander Damage endpoints
        .route(
            "/games/{game_id}/commander-damage",
            put(handlers::update_commander_damage),
        )
        .route(
            "/games/{game_id}/players/{player_id}/partner",
            post(handlers::toggle_partner),
        );

    // Build the main router with nested API routes
    let app = Router::new()
        .nest("/api/v1", api_v1_router)
        // WebSocket endpoint at root level for easier access
        .route("/ws", get(websocket::websocket_handler))
        // Add middleware
        .layer(
            ServiceBuilder::new()
                .layer(TraceLayer::new_for_http())
                .layer(cors),
        )
        .with_state(app_state);

    // Start server
    let addr = SocketAddr::from(([0, 0, 0, 0], 3001));
    let listener = tokio::net::TcpListener::bind(addr).await?;

    info!("🚀 Conclave API Server running on http://{}", addr);
    info!("📡 API endpoints available at http://{}/api/v1/", addr);
    info!("📡 WebSocket endpoint available at ws://{}/ws", addr);

    axum::serve(listener, app).await?;

    Ok(())
}
