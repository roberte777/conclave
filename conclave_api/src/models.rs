use chrono::{DateTime, Utc};
use serde::{Deserialize, Serialize};
use sqlx::FromRow;
use uuid::Uuid;

#[derive(Debug, Clone, Serialize, Deserialize, FromRow)]
#[serde(rename_all = "camelCase")]
pub struct Game {
    pub id: Uuid,
    pub name: String,
    pub status: String, // "active", "finished"
    pub starting_life: i32,
    pub created_at: DateTime<Utc>,
    pub finished_at: Option<DateTime<Utc>>,
}

#[derive(Debug, Clone, Serialize, Deserialize, FromRow)]
#[serde(rename_all = "camelCase")]
pub struct Player {
    pub id: Uuid,
    pub game_id: Uuid,
    pub clerk_user_id: String, // Clerk user ID
    pub current_life: i32,
    pub position: i32, // Player position in game (1-8 for MTG)
    pub is_eliminated: bool,
}

#[derive(Debug, Clone, Serialize, Deserialize, FromRow)]
#[serde(rename_all = "camelCase")]
pub struct LifeChange {
    pub id: Uuid,
    pub game_id: Uuid,
    pub player_id: Uuid,
    pub change_amount: i32,
    pub new_life_total: i32,
    pub created_at: DateTime<Utc>,
}

// Request/Response DTOs
#[derive(Debug, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct CreateGameRequest {
    pub name: String,
    pub starting_life: Option<i32>, // Default to 20 if not provided
    pub clerk_user_id: String,      // Creator's Clerk user ID
}

#[derive(Debug, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct JoinGameRequest {
    pub clerk_user_id: String, // Clerk user ID
}

#[derive(Debug, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct UpdateLifeRequest {
    pub player_id: Uuid,
    pub change_amount: i32,
}

// Helper struct for representing user info from Clerk
#[derive(Debug, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct UserInfo {
    pub clerk_user_id: String,
}

#[derive(Debug, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct GameState {
    pub game: Game,
    pub players: Vec<Player>,
    pub recent_changes: Vec<LifeChange>,
}

#[derive(Debug, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct GameHistory {
    pub games: Vec<GameWithPlayers>,
}

#[derive(Debug, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct GameWithPlayers {
    pub game: Game,
    pub players: Vec<Player>,
    pub winner: Option<Player>,
}

#[derive(Debug, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct GameWithUsers {
    pub game: Game,
    pub users: Vec<UserInfo>, // User info from players
}

// Result type for game ending operations
#[derive(Debug, Clone, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct GameEndResult {
    pub winner: Option<Player>,
}

// WebSocket Message Types
#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(
    tag = "type",
    rename_all = "camelCase",
    rename_all_fields = "camelCase"
)]
pub enum WebSocketMessage {
    LifeUpdate {
        game_id: Uuid,
        player_id: Uuid,
        new_life: i32,
        change_amount: i32,
    },
    PlayerJoined {
        game_id: Uuid,
        player: Player,
    },
    PlayerLeft {
        game_id: Uuid,
        player_id: Uuid,
    },

    GameStarted {
        game_id: Uuid,
        players: Vec<Player>,
    },
    GameEnded {
        game_id: Uuid,
        winner: Option<Player>,
    },
    Error {
        message: String,
    },
}

#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(
    tag = "action",
    rename_all = "camelCase",
    rename_all_fields = "camelCase"
)]
pub enum WebSocketRequest {
    UpdateLife { player_id: Uuid, change_amount: i32 },
    JoinGame { clerk_user_id: String },
    LeaveGame { player_id: Uuid },
    GetGameState,
    EndGame,
}

// Constants
pub const DEFAULT_STARTING_LIFE: i32 = 20;
pub const MAX_PLAYERS_PER_GAME: usize = 8;
