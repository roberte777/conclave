use crate::{
    auth::AuthenticatedUser,
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
use tracing::{debug, info};
use uuid::Uuid;

// User operations are handled by Clerk, so no local user endpoints needed

// Game endpoints
pub async fn create_game(
    State(state): State<AppState>,
    auth: AuthenticatedUser,
    Json(request): Json<CreateGameRequest>,
) -> Result<Json<Game>> {
    info!(
        "Creating game: {} by user {} ({}) with starting life {}",
        request.name,
        auth.clerk_user_id,
        auth.user.display_name(),
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
        &auth.clerk_user_id,
    )
    .await?;

    // Initialize WebSocket room for the new game
    state.get_or_create_game_room(game.id);

    info!("Game created and started: {} ({})", game.name, game.id);
    Ok(Json(game))
}

pub async fn join_game(
    State(state): State<AppState>,
    Path(game_id): Path<Uuid>,
    auth: AuthenticatedUser,
) -> Result<Json<PlayerWithUser>> {
    info!("User {} ({}) joining game {}", auth.clerk_user_id, auth.user.display_name(), game_id);

    let player = database::join_game(&state.db, game_id, &auth.clerk_user_id).await?;

    // Broadcast player joined event to WebSocket clients
    websocket::broadcast_player_joined(&state, game_id, player.clone()).await;

    // Return enriched player
    let enriched_player = PlayerWithUser::from_player(
        player.clone(),
        auth.user.display_name(),
        auth.user.username,
        auth.user.image_url,
    );

    info!(
        "User {} successfully joined game {} as player {}",
        auth.clerk_user_id, game_id, player.position
    );
    Ok(Json(enriched_player))
}

pub async fn leave_game(
    State(state): State<AppState>,
    Path(game_id): Path<Uuid>,
    auth: AuthenticatedUser,
) -> Result<StatusCode> {
    info!("User {} leaving game {}", auth.clerk_user_id, game_id);

    database::leave_game(&state.db, game_id, &auth.clerk_user_id).await?;

    info!(
        "User {} successfully left game {}",
        auth.clerk_user_id, game_id
    );
    Ok(StatusCode::OK)
}

pub async fn get_game(
    State(state): State<AppState>,
    Path(game_id): Path<Uuid>,
) -> Result<Json<Game>> {
    debug!("GET /api/v1/games/{} - Getting game details", game_id);
    let game = database::get_game_by_id(&state.db, game_id).await?;
    Ok(Json(game))
}

pub async fn get_game_state(
    State(state): State<AppState>,
    Path(game_id): Path<Uuid>,
) -> Result<Json<GameState>> {
    debug!("GET /api/v1/games/{}/state - Getting game state", game_id);
    // Use enriched game state with user display info
    let game_state = database::get_game_state_with_users(&state.db, game_id).await?;
    Ok(Json(game_state))
}

pub async fn get_user_games(
    State(state): State<AppState>,
    auth: AuthenticatedUser,
) -> Result<Json<Vec<GameWithUsers>>> {
    debug!(
        "GET /api/v1/users/me/games - Getting user's games for {}",
        auth.clerk_user_id
    );
    let games = database::get_user_games(&state.db, &auth.clerk_user_id).await?;
    Ok(Json(games))
}

pub async fn get_available_games(
    State(state): State<AppState>,
    auth: AuthenticatedUser,
) -> Result<Json<Vec<GameWithUsers>>> {
    debug!(
        "GET /api/v1/users/me/available-games - Getting available games for user {}",
        auth.clerk_user_id
    );
    let games = database::get_available_games(&state.db, &auth.clerk_user_id).await?;
    Ok(Json(games))
}

pub async fn get_all_games(State(state): State<AppState>) -> Result<Json<Vec<GameWithUsers>>> {
    debug!("GET /api/v1/games - Getting all games");
    let games = database::get_all_games(&state.db).await?;
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

    // Update player life
    let (updated_player, _life_change) =
        database::update_player_life(&state.db, request.player_id, request.change_amount).await?;

    // Broadcast life update via WebSocket
    let message = WebSocketMessage::LifeUpdate {
        game_id,
        player_id: request.player_id,
        new_life: updated_player.current_life,
        change_amount: request.change_amount,
    };
    state.broadcast_to_game(game_id, message);

    info!(
        "Life updated for player {} in game {}: new life = {}",
        request.player_id, game_id, updated_player.current_life
    );
    Ok(Json(updated_player))
}

pub async fn end_game(
    State(state): State<AppState>,
    Path(game_id): Path<Uuid>,
) -> Result<Json<Game>> {
    info!("Manually ending game {}", game_id);

    let game = database::end_game(&state.db, game_id).await?;

    // Get all players to determine winner (player with highest life)
    let players = database::get_players_in_game(&state.db, game_id).await?;
    let winner = players.iter().max_by_key(|p| p.current_life).cloned();

    // Enrich winner with user info
    let enriched_winner = if let Some(w) = winner {
        Some(database::enrich_player_with_user(w).await)
    } else {
        None
    };

    // Broadcast game ended event with enriched winner
    let message = WebSocketMessage::GameEnded { game_id, winner: enriched_winner };
    state.broadcast_to_game(game_id, message);

    // Clean up WebSocket room
    tokio::spawn(async move {
        tokio::time::sleep(tokio::time::Duration::from_secs(5)).await;
        state.cleanup_game_room(game_id);
    });

    info!("Game ended: {} ({})", game.name, game.id);
    Ok(Json(game))
}

pub async fn get_user_history(
    State(state): State<AppState>,
    auth: AuthenticatedUser,
) -> Result<Json<GameHistory>> {
    debug!(
        "GET /api/v1/users/me/history - Getting game history for user {}",
        auth.clerk_user_id
    );
    let history = database::get_user_game_history(&state.db, &auth.clerk_user_id).await?;
    Ok(Json(history))
}

pub async fn get_recent_life_changes(
    State(state): State<AppState>,
    Path(game_id): Path<Uuid>,
) -> Result<Json<Vec<LifeChange>>> {
    debug!(
        "GET /api/v1/games/{}/life-changes - Getting recent life changes",
        game_id
    );
    let changes = database::get_recent_life_changes(&state.db, game_id, 50).await?;
    Ok(Json(changes))
}

pub async fn health_check() -> Result<Json<serde_json::Value>> {
    debug!("GET /health - Health check endpoint called");
    Ok(Json(serde_json::json!({
        "status": "ok",
        "service": "conclave-api"
    })))
}

pub async fn get_stats(State(state): State<AppState>) -> Result<Json<serde_json::Value>> {
    debug!("GET /api/v1/stats - Getting API statistics");
    let active_games_count =
        sqlx::query("SELECT COUNT(*) as count FROM games WHERE status = 'active'")
            .fetch_one(&state.db)
            .await?;

    let count: i64 = active_games_count.get("count");

    Ok(Json(serde_json::json!({
        "activeGames": count,
        "service": "conclave-api"
    })))
}

// Commander Damage endpoints
pub async fn update_commander_damage(
    State(state): State<AppState>,
    Path(game_id): Path<Uuid>,
    Json(request): Json<UpdateCommanderDamageRequest>,
) -> Result<Json<CommanderDamage>> {
    info!(
        "Updating commander damage in game {} from player {} to player {} (commander {}) by {}",
        game_id,
        request.from_player_id,
        request.to_player_id,
        request.commander_number,
        request.damage_amount
    );

    // Validate damage amount change
    if request.damage_amount.abs() > 50 {
        return Err(ApiError::BadRequest(
            "Commander damage change too large (max ±50)".to_string(),
        ));
    }

    // Verify game is active
    let game = database::get_game_by_id(&state.db, game_id).await?;
    if game.status != "active" {
        return Err(ApiError::GameNotActive);
    }

    // Get current damage to calculate new damage
    let current_damage = database::get_commander_damage_for_game(&state.db, game_id)
        .await?
        .into_iter()
        .find(|cd| {
            cd.from_player_id == request.from_player_id
                && cd.to_player_id == request.to_player_id
                && cd.commander_number == request.commander_number
        })
        .map(|cd| cd.damage)
        .unwrap_or(0);

    let new_damage = current_damage + request.damage_amount;

    // Update commander damage
    let updated_damage = database::update_commander_damage(
        &state.db,
        game_id,
        request.from_player_id,
        request.to_player_id,
        request.commander_number,
        new_damage,
    )
    .await?;

    // Broadcast commander damage update via WebSocket
    let message = WebSocketMessage::CommanderDamageUpdate {
        game_id,
        from_player_id: request.from_player_id,
        to_player_id: request.to_player_id,
        commander_number: request.commander_number,
        new_damage,
        damage_amount: request.damage_amount,
    };
    state.broadcast_to_game(game_id, message);

    info!(
        "Commander damage updated in game {} from player {} to player {} (commander {}): new damage = {}",
        game_id, request.from_player_id, request.to_player_id, request.commander_number, new_damage
    );
    Ok(Json(updated_damage))
}

pub async fn toggle_partner(
    State(state): State<AppState>,
    Path((game_id, player_id)): Path<(Uuid, Uuid)>,
    Json(request): Json<TogglePartnerRequest>,
) -> Result<StatusCode> {
    info!(
        "Toggling partner for player {} in game {} to {}",
        player_id, game_id, request.enable_partner
    );

    // Verify game is active
    let game = database::get_game_by_id(&state.db, game_id).await?;
    if game.status != "active" {
        return Err(ApiError::GameNotActive);
    }

    // Verify the player_id in path matches the one in request
    if player_id != request.player_id {
        return Err(ApiError::BadRequest(
            "Player ID in path does not match request".to_string(),
        ));
    }

    // Toggle partner status
    database::toggle_partner(&state.db, game_id, player_id, request.enable_partner).await?;

    // Broadcast partner toggle event via WebSocket
    let message = WebSocketMessage::PartnerToggled {
        game_id,
        player_id,
        has_partner: request.enable_partner,
    };
    state.broadcast_to_game(game_id, message);

    info!(
        "Partner {} for player {} in game {}",
        if request.enable_partner {
            "enabled"
        } else {
            "disabled"
        },
        player_id,
        game_id
    );
    Ok(StatusCode::OK)
}
