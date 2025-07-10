use crate::models::WebSocketMessage;
use dashmap::DashMap;
use sqlx::SqlitePool;
use std::sync::Arc;
use tokio::sync::broadcast;
use uuid::Uuid;

pub type Sender = broadcast::Sender<WebSocketMessage>;
pub type Receiver = broadcast::Receiver<WebSocketMessage>;

#[derive(Clone)]
pub struct AppState {
    pub db: SqlitePool,
    pub game_rooms: Arc<DashMap<Uuid, GameRoom>>,
}

#[derive(Clone)]
pub struct GameRoom {
    pub sender: Sender,
}

impl AppState {
    pub fn new(db: SqlitePool) -> Self {
        Self {
            db,
            game_rooms: Arc::new(DashMap::new()),
        }
    }

    /// Get or create a game room atomically to prevent race conditions
    pub fn get_or_create_game_room(&self, game_id: Uuid) -> Sender {
        // Use entry API for atomic get-or-insert
        let room = self.game_rooms.entry(game_id).or_insert_with(|| {
            let (sender, _) = broadcast::channel(100);
            tracing::info!("Created new WebSocket room for game {}", game_id);
            GameRoom { sender }
        });
        room.sender.clone()
    }

    /// Broadcast a message to all clients in a game room
    pub fn broadcast_to_game(&self, game_id: Uuid, message: WebSocketMessage) {
        let sender = self.get_or_create_game_room(game_id);

        match sender.send(message) {
            Ok(receiver_count) => {
                tracing::info!(
                    "Message broadcast successful to {} receivers in game {}",
                    receiver_count,
                    game_id
                );
            }
            Err(e) => {
                tracing::warn!("No active receivers for game {}: {:?}", game_id, e);
            }
        }
    }

    /// Get a receiver for game room messages
    pub fn get_game_receiver(&self, game_id: Uuid) -> Receiver {
        let sender = self.get_or_create_game_room(game_id);
        sender.subscribe()
    }

    /// Clean up a game room when the game ends
    pub fn cleanup_game_room(&self, game_id: Uuid) {
        if let Some((_, _)) = self.game_rooms.remove(&game_id) {
            // Room will be dropped, closing all receivers
            tracing::info!("Cleaned up WebSocket room for game {}", game_id);
        } else {
            tracing::debug!("No room found to clean up for game {}", game_id);
        }
    }
}
