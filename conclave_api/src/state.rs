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

    pub fn broadcast_to_game(&self, game_id: Uuid, message: WebSocketMessage) {
        // Use the same pattern as other methods to ensure consistency
        let room_entry = self
            .game_rooms
            .get(&game_id)
            .expect("Should have a game if broadcasting to a game");

        tracing::info!("Broadcasting message to game {}", game_id,);

        let send_result = room_entry.sender.send(message);
        match send_result {
            Ok(receivers) => {
                tracing::info!(
                    "Message broadcast successful to {} receivers in game {}",
                    receivers,
                    game_id
                );
            }
            Err(e) => {
                tracing::error!(
                    "❌ Failed to broadcast message to game {}: {:?}",
                    game_id,
                    e
                );
            }
        }
    }

    pub fn get_game_receiver(&self, game_id: Uuid) -> Receiver {
        // Get or create the room entry and work with it directly
        let room_entry = self
            .game_rooms
            .get(&game_id)
            .expect("Expected game room to exist if getting receiver for it.");

        room_entry.sender.subscribe()
    }
}
