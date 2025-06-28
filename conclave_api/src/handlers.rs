use crate::{
    database,
    errors::{ApiError, Result},
    models::*,
    state::AppState,
    websocket,
};
use axum::{
    Json,
    extract::{Path, State},
    http::StatusCode,
};
use sqlx::Row;
use tracing::info;
use uuid::Uuid;

// User operations are handled by Clerk, so no local user endpoints needed

// Game endpoints
pub async fn create_game(
    State(state): State<AppState>,
    Json(request): Json<CreateGameRequest>,
) -> Result<Json<Game>> {
    info!(
        "Creating game: {} by user {} with starting life {}",
        request.name,
        request.clerk_user_id,
        request.starting_life.unwrap_or(DEFAULT_STARTING_LIFE)
    );

    if request.name.trim().is_empty() {
        return Err(ApiError::BadRequest(
            "Game name cannot be empty".to_string(),
        ));
    }

    if request.name.len() > 100 {
        return Err(ApiError::BadRequest(
            "Game name too long (max 100 characters)".to_string(),
        ));
    }

    let starting_life = request.starting_life.unwrap_or(DEFAULT_STARTING_LIFE);

    if !(1..=999).contains(&starting_life) {
        return Err(ApiError::BadRequest(
            "Starting life must be between 1 and 999".to_string(),
        ));
    }

    let game = database::create_game(
        &state.db,
        &request.name,
        starting_life,
        &request.clerk_user_id,
    )
    .await?;
    let players = database::get_players_in_game(&state.db, game.id).await?;

    // Broadcast game started event to WebSocket clients since the game is immediately active
    websocket::broadcast_game_started(&state, game.id, players).await;

    info!("Game created and started: {} ({})", game.name, game.id);
    Ok(Json(game))
}

pub async fn join_game(
    State(state): State<AppState>,
    Path(game_id): Path<Uuid>,
    Json(request): Json<JoinGameRequest>,
) -> Result<Json<Player>> {
    info!("User {} joining game {}", request.clerk_user_id, game_id);

    let player = database::join_game(&state.db, game_id, &request.clerk_user_id).await?;

    // Broadcast player joined event to WebSocket clients
    websocket::broadcast_player_joined(&state, game_id, player.clone()).await;

    info!(
        "User {} successfully joined game {} as player {}",
        request.clerk_user_id, game_id, player.position
    );
    Ok(Json(player))
}

pub async fn leave_game(
    State(state): State<AppState>,
    Path(game_id): Path<Uuid>,
    Json(request): Json<JoinGameRequest>, // Reusing JoinGameRequest since it just needs clerk_user_id
) -> Result<StatusCode> {
    info!("User {} leaving game {}", request.clerk_user_id, game_id);

    database::leave_game(&state.db, game_id, &request.clerk_user_id).await?;

    info!(
        "User {} successfully left game {}",
        request.clerk_user_id, game_id
    );
    Ok(StatusCode::OK)
}

pub async fn get_game(
    State(state): State<AppState>,
    Path(game_id): Path<Uuid>,
) -> Result<Json<Game>> {
    let game = database::get_game_by_id(&state.db, game_id).await?;
    Ok(Json(game))
}

pub async fn get_game_state(
    State(state): State<AppState>,
    Path(game_id): Path<Uuid>,
) -> Result<Json<GameState>> {
    let game_state = database::get_game_state(&state.db, game_id).await?;
    Ok(Json(game_state))
}

pub async fn get_user_games(
    State(state): State<AppState>,
    Path(clerk_user_id): Path<String>,
) -> Result<Json<Vec<GameWithUsers>>> {
    let games = database::get_user_games(&state.db, &clerk_user_id).await?;
    Ok(Json(games))
}

pub async fn get_available_games(
    State(state): State<AppState>,
    Path(clerk_user_id): Path<String>,
) -> Result<Json<Vec<GameWithUsers>>> {
    let games = database::get_available_games(&state.db, &clerk_user_id).await?;
    Ok(Json(games))
}

pub async fn update_life(
    State(state): State<AppState>,
    Path(game_id): Path<Uuid>,
    Json(request): Json<UpdateLifeRequest>,
) -> Result<Json<Player>> {
    info!(
        "Updating life for player {} in game {} by {}",
        request.player_id, game_id, request.change_amount
    );

    if request.change_amount.abs() > 100 {
        return Err(ApiError::BadRequest(
            "Life change too large (max ±100)".to_string(),
        ));
    }

    // Verify game is active
    let game = database::get_game_by_id(&state.db, game_id).await?;
    if game.status != "active" {
        return Err(ApiError::GameNotActive);
    }

    // Verify player belongs to this game
    let players = database::get_players_in_game(&state.db, game_id).await?;
    let target_player = players
        .iter()
        .find(|p| p.id == request.player_id)
        .ok_or(ApiError::PlayerNotFound)?;

    if target_player.is_eliminated {
        return Err(ApiError::BadRequest(
            "Cannot modify life of eliminated player".to_string(),
        ));
    }

    let (updated_player, _life_change) =
        database::update_player_life(&state.db, request.player_id, request.change_amount).await?;

    // Broadcast update via WebSocket
    let message = WebSocketMessage::LifeUpdate {
        game_id,
        player_id: request.player_id,
        new_life: updated_player.current_life,
        change_amount: request.change_amount,
    };
    state.broadcast_to_game(game_id, message);

    // Check if player was eliminated
    if updated_player.is_eliminated && !target_player.is_eliminated {
        let elimination_message = WebSocketMessage::PlayerEliminated {
            game_id,
            player_id: request.player_id,
        };
        state.broadcast_to_game(game_id, elimination_message);
    }

    // Check if game should end (only one player left)
    let remaining_players_count = players.iter().filter(|p| !p.is_eliminated).count();
    if remaining_players_count <= 1 {
        database::end_game(&state.db, game_id).await?;
        let winner = players.iter().find(|p| !p.is_eliminated).cloned();
        let end_message = WebSocketMessage::GameEnded { game_id, winner };
        state.broadcast_to_game(game_id, end_message);
    }

    info!(
        "Life updated for player {} in game {}: {} -> {}",
        request.player_id, game_id, target_player.current_life, updated_player.current_life
    );
    Ok(Json(updated_player))
}

pub async fn end_game(
    State(state): State<AppState>,
    Path(game_id): Path<Uuid>,
) -> Result<Json<Game>> {
    info!("Manually ending game {}", game_id);

    let game = database::end_game(&state.db, game_id).await?;

    // Get remaining players to determine winner
    let players = database::get_players_in_game(&state.db, game_id).await?;
    let winner = players.iter().find(|p| !p.is_eliminated).cloned();

    // Broadcast game ended event
    let message = WebSocketMessage::GameEnded { game_id, winner };
    state.broadcast_to_game(game_id, message);

    info!("Game ended: {} ({})", game.name, game.id);
    Ok(Json(game))
}

pub async fn get_user_history(
    State(state): State<AppState>,
    Path(clerk_user_id): Path<String>,
) -> Result<Json<GameHistory>> {
    let history = database::get_user_game_history(&state.db, &clerk_user_id).await?;
    Ok(Json(history))
}

pub async fn get_recent_life_changes(
    State(state): State<AppState>,
    Path(game_id): Path<Uuid>,
) -> Result<Json<Vec<LifeChange>>> {
    let changes = database::get_recent_life_changes(&state.db, game_id, 50).await?;
    Ok(Json(changes))
}

pub async fn health_check() -> Result<Json<serde_json::Value>> {
    Ok(Json(serde_json::json!({
        "status": "ok",
        "service": "conclave-api"
    })))
}

pub async fn get_stats(State(state): State<AppState>) -> Result<Json<serde_json::Value>> {
    let active_games_count =
        sqlx::query("SELECT COUNT(*) as count FROM games WHERE status = 'active'")
            .fetch_one(&state.db)
            .await?;

    let count: i64 = active_games_count.get("count");

    Ok(Json(serde_json::json!({
        "active_games": count,
        "service": "conclave-api"
    })))
}
