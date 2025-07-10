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
use std::sync::Arc;
use tokio::sync::{broadcast, mpsc};
use tracing::{debug, error, info, instrument, span, Level};
use uuid::Uuid;

#[derive(Debug, Deserialize)]
pub struct WebSocketQuery {
    pub game_id: Uuid,
    pub clerk_user_id: String,
}

#[derive(Debug, Clone)]
pub enum ConnectionEvent {
    Connected,
    Disconnected,
    Error(String),
}

pub struct WebSocketConnection {
    game_id: Uuid,
    clerk_user_id: String,
    state: Arc<AppState>,
    shutdown_tx: mpsc::Sender<()>,
    _shutdown_rx: mpsc::Receiver<()>,
}

impl WebSocketConnection {
    pub fn new(game_id: Uuid, clerk_user_id: String, state: Arc<AppState>) -> Self {
        let (shutdown_tx, shutdown_rx) = mpsc::channel(1);
        
        Self {
            game_id,
            clerk_user_id,
            state,
            shutdown_tx,
            _shutdown_rx: shutdown_rx,
        }
    }

    #[instrument(skip(self, socket), fields(game_id = %self.game_id, user_id = %self.clerk_user_id))]
    pub async fn handle(&mut self, socket: WebSocket) -> Result<()> {
        // Initialize connection
        if let Err(e) = self.initialize_connection().await {
            error!("Connection initialization failed: {}", e);
            return Err(e);
        }

        let (tx, rx) = socket.split();
        let (msg_tx, msg_rx) = mpsc::channel(100);

        // Spawn sender task
        let sender_handle = {
            let game_id = self.game_id;
            let state = self.state.clone();
            let msg_rx = msg_rx;
            tokio::spawn(Self::sender_task(tx, msg_rx, game_id, state))
        };

        // Spawn receiver task
        let receiver_handle = {
            let game_id = self.game_id;
            let state = self.state.clone();
            let msg_tx = msg_tx.clone();
            tokio::spawn(Self::receiver_task(rx, msg_tx, game_id, state))
        };

        // Spawn broadcast listener task
        let broadcast_handle = {
            let game_id = self.game_id;
            let state = self.state.clone();
            let msg_tx = msg_tx;
            tokio::spawn(Self::broadcast_listener_task(msg_tx, game_id, state))
        };

        // Send initial game state
        if let Err(e) = self.send_initial_state().await {
            error!("Failed to send initial state: {}", e);
        }

        // Wait for any task to complete
        tokio::select! {
            _ = sender_handle => debug!("Sender task completed"),
            _ = receiver_handle => debug!("Receiver task completed"),
            _ = broadcast_handle => debug!("Broadcast listener completed"),
        }

        self.cleanup().await;
        info!("WebSocket connection closed");
        
        Ok(())
    }

    #[instrument(skip(self), fields(game_id = %self.game_id, user_id = %self.clerk_user_id))]
    async fn initialize_connection(&self) -> Result<()> {
        // Verify game exists and is active
        let game = database::get_game_by_id(&self.state.db, self.game_id).await?;
        if game.status != "active" {
            return Err(ApiError::GameNotActive);
        }

        // Add user to game if not already present
        let players = database::get_players_in_game(&self.state.db, self.game_id).await?;
        let player_exists = players.iter().any(|p| p.clerk_user_id == self.clerk_user_id);
        
        if !player_exists {
            database::join_game(&self.state.db, self.game_id, &self.clerk_user_id).await?;
            info!("User added to game");
        }

        // Add to connection tracking
        if !self.state.is_user_connected_to_game(self.game_id, &self.clerk_user_id) {
            self.state.add_user_to_game(self.game_id, self.clerk_user_id.clone());
            info!("User connected to game room");
        }

        Ok(())
    }

    #[instrument(skip(self), fields(game_id = %self.game_id))]
    async fn send_initial_state(&self) -> Result<()> {
        let game_state = database::get_game_state(&self.state.db, self.game_id).await?;
        
        let message = WebSocketMessage::GameStarted {
            game_id: self.game_id,
            players: game_state.players,
        };

        self.state.broadcast_to_game(self.game_id, message);
        debug!("Initial game state sent");
        
        Ok(())
    }

    #[instrument(skip(self), fields(game_id = %self.game_id, user_id = %self.clerk_user_id))]
    async fn cleanup(&self) {
        self.state.remove_user_from_game(self.game_id, &self.clerk_user_id);
        debug!("Connection cleanup completed");
    }

    async fn sender_task(
        mut tx: futures::stream::SplitSink<WebSocket, Message>,
        mut msg_rx: mpsc::Receiver<WebSocketMessage>,
        game_id: Uuid,
        _state: Arc<AppState>,
    ) {
        let span = span!(Level::DEBUG, "sender_task", game_id = %game_id);
        let _enter = span.enter();

        while let Some(message) = msg_rx.recv().await {
            match serde_json::to_string(&message) {
                Ok(msg_text) => {
                    if let Err(e) = tx.send(Message::Text(msg_text.into())).await {
                        debug!("Failed to send message: {}", e);
                        break;
                    }
                }
                Err(e) => {
                    error!("Failed to serialize message: {}", e);
                }
            }
        }
        
        debug!("Sender task shutting down");
    }

    async fn receiver_task(
        mut rx: futures::stream::SplitStream<WebSocket>,
        msg_tx: mpsc::Sender<WebSocketMessage>,
        game_id: Uuid,
        state: Arc<AppState>,
    ) {
        let span = span!(Level::DEBUG, "receiver_task", game_id = %game_id);
        let _enter = span.enter();

        while let Some(msg) = rx.next().await {
            match msg {
                Ok(Message::Text(text)) => {
                    if let Err(e) = Self::handle_incoming_message(&text, game_id, &state).await {
                        error!("Error handling message: {}", e);
                    }
                }
                Ok(Message::Close(_)) => {
                    debug!("WebSocket close message received");
                    break;
                }
                Err(e) => {
                    debug!("WebSocket error: {}", e);
                    break;
                }
                _ => {}
            }
        }

        debug!("Receiver task shutting down");
    }

    async fn broadcast_listener_task(
        msg_tx: mpsc::Sender<WebSocketMessage>,
        game_id: Uuid,
        state: Arc<AppState>,
    ) {
        let span = span!(Level::DEBUG, "broadcast_listener", game_id = %game_id);
        let _enter = span.enter();

        let mut game_receiver = state.get_game_receiver(game_id);

        while let Ok(message) = game_receiver.recv().await {
            if msg_tx.send(message).await.is_err() {
                debug!("Message channel closed, stopping broadcast listener");
                break;
            }
        }

        debug!("Broadcast listener shutting down");
    }

    #[instrument(skip(state), fields(game_id = %game_id))]
    async fn handle_incoming_message(text: &str, game_id: Uuid, state: &AppState) -> Result<()> {
        let request: WebSocketRequest = serde_json::from_str(text)
            .map_err(|_| ApiError::BadRequest("Invalid JSON".to_string()))?;

        match request {
            WebSocketRequest::UpdateLife { player_id, change_amount } => {
                Self::handle_life_update(player_id, change_amount, game_id, state).await
            }
            WebSocketRequest::JoinGame { clerk_user_id } => {
                Self::handle_join_game(clerk_user_id, game_id, state).await
            }
            WebSocketRequest::LeaveGame { player_id } => {
                Self::handle_leave_game(player_id, game_id, state).await
            }
            WebSocketRequest::GetGameState => {
                Self::handle_get_game_state(game_id, state).await
            }
        }
    }

    #[instrument(skip(state), fields(game_id = %game_id, player_id = %player_id, change = %change_amount))]
    async fn handle_life_update(
        player_id: Uuid,
        change_amount: i32,
        game_id: Uuid,
        state: &AppState,
    ) -> Result<()> {
        let (updated_player, _) = database::update_player_life(&state.db, player_id, change_amount).await?;

        let message = WebSocketMessage::LifeUpdate {
            game_id,
            player_id,
            new_life: updated_player.current_life,
            change_amount,
        };

        state.broadcast_to_game(game_id, message);
        debug!("Life update processed and broadcast");

        Ok(())
    }

    #[instrument(skip(state), fields(game_id = %game_id, user_id = %clerk_user_id))]
    async fn handle_join_game(clerk_user_id: String, game_id: Uuid, state: &AppState) -> Result<()> {
        match database::join_game(&state.db, game_id, &clerk_user_id).await {
            Ok(player) => {
                let message = WebSocketMessage::PlayerJoined {
                    game_id,
                    player: player.clone(),
                };
                
                state.broadcast_to_game(game_id, message);
                info!("Player joined game");
                Ok(())
            }
            Err(e) => {
                error!("Failed to add player to game: {}", e);
                Err(e)
            }
        }
    }

    #[instrument(skip(state), fields(game_id = %game_id, player_id = %player_id))]
    async fn handle_leave_game(player_id: Uuid, game_id: Uuid, state: &AppState) -> Result<()> {
        let players = database::get_players_in_game(&state.db, game_id).await?;
        let player = players.iter().find(|p| p.id == player_id)
            .ok_or(ApiError::PlayerNotFound)?;
        
        database::leave_game(&state.db, game_id, &player.clerk_user_id).await?;
        
        let message = WebSocketMessage::PlayerLeft {
            game_id,
            player_id,
        };
        
        state.broadcast_to_game(game_id, message);
        info!("Player left game");
        
        Ok(())
    }

    #[instrument(skip(state), fields(game_id = %game_id))]
    async fn handle_get_game_state(game_id: Uuid, state: &AppState) -> Result<()> {
        let game_state = database::get_game_state(&state.db, game_id).await?;

        let message = WebSocketMessage::GameStarted {
            game_id,
            players: game_state.players,
        };

        state.broadcast_to_game(game_id, message);
        debug!("Game state broadcast");

        Ok(())
    }
}

// Public API functions
#[instrument(skip(ws, state), fields(game_id = %params.game_id, user_id = %params.clerk_user_id))]
pub async fn websocket_handler(
    ws: WebSocketUpgrade,
    Query(params): Query<WebSocketQuery>,
    State(state): State<AppState>,
) -> impl IntoResponse {
    info!("WebSocket connection attempt");

    ws.on_upgrade(move |socket| async move {
        let mut connection = WebSocketConnection::new(
            params.game_id,
            params.clerk_user_id,
            Arc::new(state),
        );

        if let Err(e) = connection.handle(socket).await {
            error!("WebSocket connection error: {}", e);
        }
    })
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
