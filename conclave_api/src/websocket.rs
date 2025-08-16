use crate::{
    database,
    errors::{ApiError, Result},
    models::{WebSocketMessage, WebSocketRequest},
    state::AppState,
};
use axum::{
    extract::{
        Query, State, WebSocketUpgrade,
        ws::{Message, WebSocket},
    },
    response::IntoResponse,
};
use futures::{sink::SinkExt, stream::StreamExt};
use serde::Deserialize;
use tracing::{debug, error, info};
use uuid::Uuid;

#[derive(Debug, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct WebSocketQuery {
    pub game_id: Uuid,
    pub clerk_user_id: String,
}

pub async fn websocket_handler(
    ws: WebSocketUpgrade,
    Query(params): Query<WebSocketQuery>,
    State(state): State<AppState>,
) -> impl IntoResponse {
    info!(
        "WebSocket connection attempt - Game: {}, User: {}",
        params.game_id, params.clerk_user_id
    );

    ws.on_upgrade(move |socket| handle_socket(socket, params, state))
}

async fn handle_socket(socket: WebSocket, params: WebSocketQuery, state: AppState) {
    let (mut sender, mut receiver) = socket.split();
    let game_id = params.game_id;
    let clerk_user_id = params.clerk_user_id;

    // Verify game exists
    let verification_result = verify_game(&state, game_id).await;
    if let Err(e) = verification_result {
        error!("WebSocket verification failed: {:?}", e);
        let error_msg = WebSocketMessage::Error {
            message: e.to_string(),
        };
        if let Ok(msg) = serde_json::to_string(&error_msg) {
            let _ = sender.send(Message::Text(msg.into())).await;
        }
        return;
    }

    // Add user to the game if they are not part of it already
    let add_user_result = add_user_to_game(&state, game_id, &clerk_user_id).await;
    if let Err(e) = add_user_result {
        error!("Failed to add user to game: {:?}", e);
        let error_msg = WebSocketMessage::Error {
            message: e.to_string(),
        };
        if let Ok(msg) = serde_json::to_string(&error_msg) {
            let _ = sender.send(Message::Text(msg.into())).await;
        }
        return;
    }

    info!(
        "WebSocket connected - Game: {}, User: {}",
        game_id, clerk_user_id
    );

    // Get receiver for game room messages - this will create the room if it doesn't exist
    let mut game_receiver = state.get_game_receiver(game_id);

    // Send initial game state
    if let Err(e) = send_initial_game_state(&mut sender, &state, game_id).await {
        error!("Failed to send initial game state: {:?}", e);
        return;
    }

    // Handle incoming and outgoing messages
    let sender_task = tokio::spawn(async move {
        while let Ok(message) = game_receiver.recv().await {
            if let Ok(msg_text) = serde_json::to_string(&message) {
                if sender.send(Message::Text(msg_text.into())).await.is_err() {
                    break;
                }
            }
        }
    });

    let receiver_task = {
        let state = state.clone();
        let clerk_user_id = clerk_user_id.clone();
        tokio::spawn(async move {
            while let Some(msg) = receiver.next().await {
                match msg {
                    Ok(Message::Text(text)) => {
                        if let Err(e) = handle_websocket_message(&text, game_id, &state).await {
                            error!("Error handling websocket message: {:?}", e);
                        }
                    }
                    Ok(Message::Close(_)) => {
                        info!(
                            "WebSocket closed for user {} in game {}",
                            clerk_user_id, game_id
                        );
                        break;
                    }
                    Err(e) => {
                        error!("WebSocket error: {:?}", e);
                        break;
                    }
                    _ => {}
                }
            }
        })
    };

    // Wait for either task to complete
    tokio::select! {
        _ = sender_task => {},
        _ = receiver_task => {},
    }

    // Clean up when connection closes
    info!(
        "WebSocket disconnected - Game: {}, User: {}",
        game_id, clerk_user_id
    );
}

async fn verify_game(state: &AppState, game_id: Uuid) -> Result<()> {
    // Verify game exists
    let game = database::get_game_by_id(&state.db, game_id).await?;

    if game.status != "active" {
        return Err(ApiError::GameNotActive);
    }

    Ok(())
}

async fn add_user_to_game(state: &AppState, game_id: Uuid, clerk_user_id: &str) -> Result<()> {
    // Verify user is a player in this game
    let players = database::get_players_in_game(&state.db, game_id).await?;
    let player = players.iter().find(|p| p.clerk_user_id == clerk_user_id);
    if player.is_none() {
        handle_join_game(clerk_user_id, game_id, state).await?;
    }
    Ok(())
}

async fn send_initial_game_state(
    sender: &mut futures::stream::SplitSink<WebSocket, Message>,
    state: &AppState,
    game_id: Uuid,
) -> Result<()> {
    let game_state = database::get_game_state(&state.db, game_id).await?;

    info!(
        "Sending initial game state for game {} with {} players",
        game_id,
        game_state.players.len(),
    );

    let message = WebSocketMessage::GameStarted {
        game_state: game_state.clone(),
    };

    let msg_text = serde_json::to_string(&message).map_err(|e| ApiError::Internal(e.into()))?;

    sender
        .send(Message::Text(msg_text.into()))
        .await
        .map_err(|e| ApiError::WebSocket(e.to_string()))?;

    info!(
        "Complete initial game state sent successfully for game {}",
        game_id
    );

    Ok(())
}

async fn handle_websocket_message(text: &str, game_id: Uuid, state: &AppState) -> Result<()> {
    debug!("WebSocket message received for game {}: {}", game_id, text);

    let request: WebSocketRequest =
        serde_json::from_str(text).map_err(|_| ApiError::BadRequest("Invalid JSON".to_string()))?;

    debug!(
        "Parsed WebSocket request for game {}: {:?}",
        game_id, request
    );

    match request {
        WebSocketRequest::UpdateLife {
            player_id,
            change_amount,
        } => {
            debug!(
                "WebSocket UpdateLife: player_id={}, change_amount={}, game_id={}",
                player_id, change_amount, game_id
            );
            handle_life_update(player_id, change_amount, game_id, state).await
        }
        WebSocketRequest::JoinGame { clerk_user_id } => {
            debug!(
                "WebSocket JoinGame: clerk_user_id={}, game_id={}",
                clerk_user_id, game_id
            );
            handle_join_game(&clerk_user_id, game_id, state).await
        }
        WebSocketRequest::LeaveGame { player_id } => {
            debug!(
                "WebSocket LeaveGame: player_id={}, game_id={}",
                player_id, game_id
            );
            handle_leave_game(player_id, game_id, state).await
        }
        WebSocketRequest::GetGameState => {
            debug!("WebSocket GetGameState: game_id={}", game_id);
            handle_get_game_state(game_id, state).await
        }
        WebSocketRequest::EndGame => {
            debug!("WebSocket EndGame: game_id={}", game_id);
            handle_end_game(game_id, state).await
        }
        WebSocketRequest::SetCommanderDamage {
            from_player_id,
            to_player_id,
            commander_number,
            new_damage,
        } => {
            debug!(
                "WebSocket SetCommanderDamage: from_player_id={}, to_player_id={}, commander_number={}, new_damage={}, game_id={}",
                from_player_id, to_player_id, commander_number, new_damage, game_id
            );
            handle_set_commander_damage(
                from_player_id,
                to_player_id,
                commander_number,
                new_damage,
                game_id,
                state,
            )
            .await
        }
        WebSocketRequest::UpdateCommanderDamage {
            from_player_id,
            to_player_id,
            commander_number,
            damage_amount,
        } => {
            debug!(
                "WebSocket UpdateCommanderDamage: from_player_id={}, to_player_id={}, commander_number={}, damage_amount={}, game_id={}",
                from_player_id, to_player_id, commander_number, damage_amount, game_id
            );
            handle_update_commander_damage(
                from_player_id,
                to_player_id,
                commander_number,
                damage_amount,
                game_id,
                state,
            )
            .await
        }
        WebSocketRequest::TogglePartner {
            player_id,
            enable_partner,
        } => {
            debug!(
                "WebSocket TogglePartner: player_id={}, enable_partner={}, game_id={}",
                player_id, enable_partner, game_id
            );
            handle_toggle_partner(player_id, enable_partner, game_id, state).await
        }
    }
}

async fn handle_life_update(
    player_id: Uuid,
    change_amount: i32,
    game_id: Uuid,
    state: &AppState,
) -> Result<()> {
    info!(
        "Processing life update for game {}, player {}, change {}",
        game_id, player_id, change_amount
    );

    // Update player life
    let (updated_player, _life_change) =
        database::update_player_life(&state.db, player_id, change_amount).await?;

    info!(
        "✅ Player life updated: new life = {}",
        updated_player.current_life
    );

    // Broadcast the update
    let message = WebSocketMessage::LifeUpdate {
        game_id,
        player_id,
        new_life: updated_player.current_life,
        change_amount,
    };

    info!(
        "Broadcasting life update message to all clients in game {}: {:?}",
        game_id, message
    );

    state.broadcast_to_game(game_id, message);

    info!("Life update broadcast completed for game {}", game_id);

    Ok(())
}

async fn handle_join_game(clerk_user_id: &str, game_id: Uuid, state: &AppState) -> Result<()> {
    // Add user to game if not already present
    let result = database::join_game(&state.db, game_id, clerk_user_id).await;

    match result {
        Ok(player) => {
            info!("Player {} joined game {}", clerk_user_id, game_id);

            // Broadcast player joined message
            let message = WebSocketMessage::PlayerJoined {
                game_id,
                player: player.clone(),
            };

            state.broadcast_to_game(game_id, message);
            Ok(())
        }
        Err(e) => {
            error!("Failed to add player to game: {:?}", e);
            Err(e)
        }
    }
}

async fn handle_leave_game(player_id: Uuid, game_id: Uuid, state: &AppState) -> Result<()> {
    info!("Player {} leaving game {}", player_id, game_id);

    // Get player info to extract clerk_user_id
    let players = database::get_players_in_game(&state.db, game_id).await?;
    let player = players
        .iter()
        .find(|p| p.id == player_id)
        .ok_or(ApiError::PlayerNotFound)?;

    let clerk_user_id = &player.clerk_user_id;

    // Remove player from game
    database::leave_game(&state.db, game_id, clerk_user_id).await?;

    // Broadcast player left message
    let message = WebSocketMessage::PlayerLeft { game_id, player_id };

    state.broadcast_to_game(game_id, message);

    info!("📤 Player left broadcast completed for game {}", game_id);
    Ok(())
}

async fn handle_get_game_state(game_id: Uuid, state: &AppState) -> Result<()> {
    let game_state = database::get_game_state(&state.db, game_id).await?;

    let message = WebSocketMessage::GameStarted { game_state };

    state.broadcast_to_game(game_id, message);

    Ok(())
}

async fn handle_end_game(game_id: Uuid, state: &AppState) -> Result<()> {
    info!("Ending game {} via WebSocket request", game_id);

    // End the game in the database
    let _ = database::end_game(&state.db, game_id).await?;

    // Get all players to determine winner (player with highest life)
    let players = database::get_players_in_game(&state.db, game_id).await?;
    let winner = players.iter().max_by_key(|p| p.current_life).cloned();

    // Broadcast game ended event
    let message = WebSocketMessage::GameEnded { game_id, winner };
    state.broadcast_to_game(game_id, message);

    // Clean up WebSocket room after a delay to allow final messages
    let state_clone = state.clone();
    tokio::spawn(async move {
        tokio::time::sleep(tokio::time::Duration::from_secs(5)).await;
        state_clone.cleanup_game_room(game_id);
    });

    info!("Game {} ended via WebSocket request", game_id);
    Ok(())
}

// Commander Damage handlers
async fn handle_set_commander_damage(
    from_player_id: Uuid,
    to_player_id: Uuid,
    commander_number: i32,
    new_damage: i32,
    game_id: Uuid,
    state: &AppState,
) -> Result<()> {
    debug!(
        "Processing set commander damage for game {}, from {} to {} (commander {}), new damage: {}",
        game_id, from_player_id, to_player_id, commander_number, new_damage
    );

    // Verify game is active
    let game = database::get_game_by_id(&state.db, game_id).await?;
    if game.status != "active" {
        return Err(ApiError::GameNotActive);
    }

    // Update commander damage
    let updated_damage = database::update_commander_damage(
        &state.db,
        game_id,
        from_player_id,
        to_player_id,
        commander_number,
        new_damage,
    )
    .await?;

    info!("Commander damage updated: {} damage", updated_damage.damage);

    // Calculate damage amount for broadcast (difference from previous)
    let previous_damage = database::get_commander_damage_for_game(&state.db, game_id)
        .await?
        .into_iter()
        .find(|cd| {
            cd.from_player_id == from_player_id
                && cd.to_player_id == to_player_id
                && cd.commander_number == commander_number
        })
        .map(|cd| cd.damage)
        .unwrap_or(0);

    let damage_amount = new_damage - previous_damage;

    // Broadcast the update
    let message = WebSocketMessage::CommanderDamageUpdate {
        game_id,
        from_player_id,
        to_player_id,
        commander_number,
        new_damage,
        damage_amount,
    };

    info!(
        "Broadcasting commander damage update to all clients in game {}: {:?}",
        game_id, message
    );

    state.broadcast_to_game(game_id, message);

    debug!(
        "Commander damage update broadcast completed for game {}",
        game_id
    );
    Ok(())
}

async fn handle_update_commander_damage(
    from_player_id: Uuid,
    to_player_id: Uuid,
    commander_number: i32,
    damage_amount: i32,
    game_id: Uuid,
    state: &AppState,
) -> Result<()> {
    debug!(
        "Processing update commander damage for game {}, from {} to {} (commander {}), damage amount: {}",
        game_id, from_player_id, to_player_id, commander_number, damage_amount
    );

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
            cd.from_player_id == from_player_id
                && cd.to_player_id == to_player_id
                && cd.commander_number == commander_number
        })
        .map(|cd| cd.damage)
        .unwrap_or(0);

    let new_damage = current_damage + damage_amount;

    // Update commander damage
    let _updated_damage = database::update_commander_damage(
        &state.db,
        game_id,
        from_player_id,
        to_player_id,
        commander_number,
        new_damage,
    )
    .await?;

    info!(
        "Commander damage updated: {} -> {} (change: {})",
        current_damage, new_damage, damage_amount
    );

    // Broadcast the update
    let message = WebSocketMessage::CommanderDamageUpdate {
        game_id,
        from_player_id,
        to_player_id,
        commander_number,
        new_damage,
        damage_amount,
    };

    info!(
        "Broadcasting commander damage update to all clients in game {}: {:?}",
        game_id, message
    );

    state.broadcast_to_game(game_id, message);

    debug!(
        "Commander damage update broadcast completed for game {}",
        game_id
    );
    Ok(())
}

async fn handle_toggle_partner(
    player_id: Uuid,
    enable_partner: bool,
    game_id: Uuid,
    state: &AppState,
) -> Result<()> {
    debug!(
        "Processing toggle partner for game {}, player {}, enable: {}",
        game_id, player_id, enable_partner
    );

    // Verify game is active
    let game = database::get_game_by_id(&state.db, game_id).await?;
    if game.status != "active" {
        return Err(ApiError::GameNotActive);
    }

    // Toggle partner status
    database::toggle_partner(&state.db, game_id, player_id, enable_partner).await?;

    info!(
        "Partner {} for player {} in game {}",
        if enable_partner {
            "enabled"
        } else {
            "disabled"
        },
        player_id,
        game_id
    );

    // Broadcast the update
    let message = WebSocketMessage::PartnerToggled {
        game_id,
        player_id,
        has_partner: enable_partner,
    };

    info!(
        "Broadcasting partner toggle to all clients in game {}: {:?}",
        game_id, message
    );

    state.broadcast_to_game(game_id, message);

    debug!("Partner toggle broadcast completed for game {}", game_id);
    Ok(())
}

pub async fn broadcast_player_joined(
    state: &AppState,
    game_id: Uuid,
    player: crate::models::Player,
) {
    let message = WebSocketMessage::PlayerJoined { game_id, player };
    state.broadcast_to_game(game_id, message);
}
