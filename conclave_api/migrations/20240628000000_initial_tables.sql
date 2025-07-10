-- Initial database schema for Conclave API
-- Creates all necessary tables for the Magic: The Gathering life tracker
-- Updated to work with Clerk authentication (no local users table)
-- Simplified: No lobbies or hosts - games are created directly

-- Create games table
CREATE TABLE IF NOT EXISTS games (
    id TEXT PRIMARY KEY,
    name TEXT NOT NULL,
    status TEXT NOT NULL DEFAULT 'active', -- 'active', 'finished'
    starting_life INTEGER NOT NULL DEFAULT 20,
    created_at TEXT NOT NULL,
    finished_at TEXT
);

-- Create players table
CREATE TABLE IF NOT EXISTS players (
    id TEXT PRIMARY KEY,
    game_id TEXT NOT NULL,
    clerk_user_id TEXT NOT NULL, -- Clerk user ID
    current_life INTEGER NOT NULL,
    position INTEGER NOT NULL,
    is_eliminated BOOLEAN NOT NULL DEFAULT FALSE,
    FOREIGN KEY (game_id) REFERENCES games (id) ON DELETE CASCADE
);

-- Create life_changes table
CREATE TABLE IF NOT EXISTS life_changes (
    id TEXT PRIMARY KEY,
    game_id TEXT NOT NULL,
    player_id TEXT NOT NULL,
    change_amount INTEGER NOT NULL,
    new_life_total INTEGER NOT NULL,
    created_at TEXT NOT NULL,
    FOREIGN KEY (game_id) REFERENCES games (id) ON DELETE CASCADE,
    FOREIGN KEY (player_id) REFERENCES players (id) ON DELETE CASCADE
); 

CREATE UNIQUE INDEX IF NOT EXISTS idx_unique_active_game_name 
ON games(name) WHERE status = 'active';

-- Add indexes for better performance and locking
CREATE INDEX IF NOT EXISTS idx_players_game_id ON players(game_id);
CREATE INDEX IF NOT EXISTS idx_players_clerk_user_id ON players(clerk_user_id);
CREATE INDEX IF NOT EXISTS idx_players_game_user ON players(game_id, clerk_user_id);
CREATE INDEX IF NOT EXISTS idx_life_changes_game_id ON life_changes(game_id);
CREATE INDEX IF NOT EXISTS idx_life_changes_created_at ON life_changes(game_id, created_at);

-- Add constraint to prevent duplicate positions in the same game
CREATE UNIQUE INDEX IF NOT EXISTS idx_unique_game_position 
ON players(game_id, position); 