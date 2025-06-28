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
use tracing::{error, info};
use uuid::Uuid;

#[derive(Debug, Deserialize)]
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

    // add user to the game if they are not part of it already
    let add_user_result = add_user_to_game(&state, game_id, &clerk_user_id).await;
    if let Err(e) = add_user_result {
        error!("Failed to add user to game");
        let error_msg = WebSocketMessage::Error {
            message: e.to_string(),
        };
        if let Ok(msg) = serde_json::to_string(&error_msg) {
            let _ = sender.send(Message::Text(msg.into())).await;
        }
    }

    info!(
        "WebSocket connected - Game: {}, User: {}",
        game_id, clerk_user_id
    );

    // Add user to game room if they aren't already (maybe connected on two devices).
    if !state.is_user_connected_to_game(game_id, &clerk_user_id) {
        state.add_user_to_game(game_id, clerk_user_id.clone());
    }

    // Get receiver for game room messages
    let mut game_receiver = state.get_game_receiver(game_id);

    // Log current connected users
    let connected_users = state.get_connected_users_in_game(game_id);
    info!(
        "🔗 Connected users in game {}: {} total - {:?}",
        game_id,
        connected_users.len(),
        connected_users
            .iter()
            .map(|u| &u.clerk_user_id)
            .collect::<Vec<_>>()
    );

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
    state.remove_user_from_game(game_id, &clerk_user_id);

    // Log remaining connected users
    let remaining_users = state.get_connected_users_in_game(game_id);
    info!(
        "🔗 Remaining users in game {} after disconnect: {} total - {:?}",
        game_id,
        remaining_users.len(),
        remaining_users
            .iter()
            .map(|u| &u.clerk_user_id)
            .collect::<Vec<_>>()
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
        database::join_game(&state.db, game_id, clerk_user_id).await?;
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
        game_state.players.len()
    );

    let message = WebSocketMessage::GameStarted {
        game_id,
        players: game_state.players.clone(),
    };

    let msg_text = serde_json::to_string(&message).map_err(|e| ApiError::Internal(e.into()))?;

    sender
        .send(Message::Text(msg_text.into()))
        .await
        .map_err(|e| ApiError::WebSocket(e.to_string()))?;

    info!("Initial game state sent successfully for game {}", game_id);
    Ok(())
}

async fn handle_websocket_message(text: &str, game_id: Uuid, state: &AppState) -> Result<()> {
    let request: WebSocketRequest =
        serde_json::from_str(text).map_err(|_| ApiError::BadRequest("Invalid JSON".to_string()))?;

    match request.action.as_str() {
        "update_life" => handle_life_update(request, game_id, state).await,
        "get_game_state" => handle_get_game_state(game_id, state).await,
        _ => Err(ApiError::BadRequest(format!(
            "Unknown action: {}",
            request.action
        ))),
    }
}

async fn handle_life_update(
    request: WebSocketRequest,
    game_id: Uuid,
    state: &AppState,
) -> Result<()> {
    let player_id = request
        .player_id
        .ok_or_else(|| ApiError::BadRequest("player_id required".to_string()))?;

    let change_amount = request
        .change_amount
        .ok_or_else(|| ApiError::BadRequest("change_amount required".to_string()))?;

    info!(
        "🎮 Processing life update for game {}, player {}, change {}",
        game_id, player_id, change_amount
    );

    let (updated_player, _life_change) =
        database::update_player_life(&state.db, player_id, change_amount).await?;

    info!(
        "✅ Player life updated: {} -> {}",
        updated_player.current_life - change_amount,
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
        "📡 Broadcasting life update message to all clients in game {}: {:?}",
        game_id, message
    );

    state.broadcast_to_game(game_id, message);

    info!("📤 Life update broadcast completed for game {}", game_id);

    Ok(())
}

async fn handle_get_game_state(game_id: Uuid, state: &AppState) -> Result<()> {
    let game_state = database::get_game_state(&state.db, game_id).await?;

    let message = WebSocketMessage::GameStarted {
        game_id,
        players: game_state.players,
    };

    state.broadcast_to_game(game_id, message);

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

pub async fn broadcast_game_started(
    state: &AppState,
    game_id: Uuid,
    players: Vec<crate::models::Player>,
) {
    let message = WebSocketMessage::GameStarted { game_id, players };
    state.broadcast_to_game(game_id, message);
}
