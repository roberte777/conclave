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

-- Create commander_damage table
CREATE TABLE IF NOT EXISTS commander_damage (
    id TEXT PRIMARY KEY,
    game_id TEXT NOT NULL,
    from_player_id TEXT NOT NULL,  -- Player dealing damage
    to_player_id TEXT NOT NULL,    -- Player receiving damage
    commander_number INTEGER NOT NULL CHECK (commander_number IN (1, 2)), -- 1 or 2 for partners
    damage INTEGER NOT NULL DEFAULT 0,
    created_at TEXT NOT NULL,
    updated_at TEXT NOT NULL,
    FOREIGN KEY (game_id) REFERENCES games (id) ON DELETE CASCADE,
    FOREIGN KEY (from_player_id) REFERENCES players (id) ON DELETE CASCADE,
    FOREIGN KEY (to_player_id) REFERENCES players (id) ON DELETE CASCADE
); 

CREATE UNIQUE INDEX IF NOT EXISTS idx_unique_active_game_name 
ON games(name) WHERE status = 'active';

-- Add indexes for better performance and locking
CREATE INDEX IF NOT EXISTS idx_players_game_id ON players(game_id);
CREATE INDEX IF NOT EXISTS idx_players_clerk_user_id ON players(clerk_user_id);
CREATE INDEX IF NOT EXISTS idx_players_game_user ON players(game_id, clerk_user_id);
CREATE INDEX IF NOT EXISTS idx_life_changes_game_id ON life_changes(game_id);
CREATE INDEX IF NOT EXISTS idx_life_changes_created_at ON life_changes(game_id, created_at);

-- Unique constraint: one row per from_player -> to_player -> commander combination
CREATE UNIQUE INDEX IF NOT EXISTS idx_unique_commander_damage 
ON commander_damage(game_id, from_player_id, to_player_id, commander_number);

-- Performance indexes for commander damage
CREATE INDEX IF NOT EXISTS idx_commander_damage_game ON commander_damage(game_id);
CREATE INDEX IF NOT EXISTS idx_commander_damage_from_player ON commander_damage(from_player_id);
CREATE INDEX IF NOT EXISTS idx_commander_damage_to_player ON commander_damage(to_player_id);

-- Add constraint to prevent duplicate positions in the same game
CREATE UNIQUE INDEX IF NOT EXISTS idx_unique_game_position 
ON players(game_id, position); 