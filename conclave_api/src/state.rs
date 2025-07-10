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
    pub connected_users: DashMap<String, UserConnection>,
    pub sender: Sender,
}

#[derive(Clone)]
pub struct UserConnection {
    pub clerk_user_id: String,
}

impl AppState {
    pub fn new(db: SqlitePool) -> Self {
        Self {
            db,
            game_rooms: Arc::new(DashMap::new()),
        }
    }

    pub fn add_user_to_game(&self, game_id: Uuid, clerk_user_id: String) {
        // Get or create the room entry and work with it directly
        let room_entry = self.game_rooms.entry(game_id).or_insert_with(|| {
            let (sender, _) = broadcast::channel(100);
            GameRoom {
                connected_users: DashMap::new(),
                sender,
            }
        });

        // Insert the user into the room's connected_users
        room_entry
            .connected_users
            .insert(clerk_user_id.clone(), UserConnection { clerk_user_id });
    }

    pub fn remove_user_from_game(&self, game_id: Uuid, clerk_user_id: &str) {
        let should_delete = if let Some(room) = self.game_rooms.get(&game_id) {
            room.connected_users.remove(clerk_user_id);

            // If no users left, remove the room
            room.connected_users.is_empty()
        } else {
            false
        };
        if should_delete {
            self.game_rooms.remove(&game_id);
        }
    }

    pub fn broadcast_to_game(&self, game_id: Uuid, message: WebSocketMessage) {
        // Use the same pattern as other methods to ensure consistency
        let room_entry = self
            .game_rooms
            .get(&game_id)
            .expect("Should have a game if broadcasting to a game");

        let connected_count = room_entry.connected_users.len();

        tracing::debug!(
            game_id = %game_id,
            connected_count = connected_count,
            "Broadcasting message to game"
        );

        let send_result = room_entry.sender.send(message);
        match send_result {
            Ok(receivers) => {
                tracing::debug!(
                    game_id = %game_id,
                    receivers = receivers,
                    "Message broadcast successful"
                );
            }
            Err(e) => {
                tracing::error!(
                    game_id = %game_id,
                    error = ?e,
                    "Failed to broadcast message to game"
                );
            }
        }
    }

    pub fn get_connected_users_in_game(&self, game_id: Uuid) -> Vec<UserConnection> {
        // Use the same pattern as add_user_to_game to ensure consistency
        let room_entry = self.game_rooms.entry(game_id).or_insert_with(|| {
            let (sender, _) = broadcast::channel(100);
            GameRoom {
                connected_users: DashMap::new(),
                sender,
            }
        });

        room_entry
            .connected_users
            .iter()
            .map(|entry| entry.value().clone())
            .collect()
    }

    pub fn is_user_connected_to_game(&self, game_id: Uuid, clerk_user_id: &str) -> bool {
        if let Some(room) = self.game_rooms.get(&game_id) {
            room.connected_users.contains_key(clerk_user_id)
        } else {
            false
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
