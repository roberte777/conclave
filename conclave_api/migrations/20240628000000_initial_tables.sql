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