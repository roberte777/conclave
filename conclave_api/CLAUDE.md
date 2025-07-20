# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Development Commands

Build and check commands:
- `cargo check` - Fast syntax and type checking
- `cargo build` - Full compilation  
- `cargo run` - Build and run the server (starts on port 3001)
- `cargo test` - Run unit and integration tests
- `cargo clippy` - Lint checking with clippy
- `cargo fmt` - Format code with rustfmt

The server runs on `http://localhost:3001` with API endpoints at `/api/v1/` and WebSocket at `/ws`.

## Architecture Overview

This is a real-time multiplayer game life tracking API built with Rust and Axum. The application supports Magic: The Gathering style games where players track life totals in real-time.

### Core Components

**Database Layer** (`src/database.rs`):
- SQLite database with SQLx for async queries
- Three main tables: games, players, life_changes
- Automatic migrations on startup

**Models** (`src/models.rs`):
- Core entities: `Game`, `Player`, `LifeChange`
- Request/response DTOs with camelCase serialization
- WebSocket message types for real-time communication
- Constants: DEFAULT_STARTING_LIFE (20), MAX_PLAYERS_PER_GAME (8)

**WebSocket System** (`src/websocket.rs`):
- Real-time game state synchronization
- Connection management with DashMap for concurrent access
- Message broadcasting to all players in a game
- Auto-join functionality when connecting

**HTTP Handlers** (`src/handlers.rs`):
- RESTful API for game management
- User management integration with Clerk authentication
- Game lifecycle operations (create, join, leave, end)
- Life tracking and history endpoints

**Application State** (`src/state.rs`):
- Shared state with database pool and WebSocket connections
- Thread-safe connection management using DashMap

### Key Architectural Patterns

1. **Dual Interface Design**: Both HTTP REST API and WebSocket for different use cases
   - REST API for game setup and queries
   - WebSocket for real-time game events

2. **External Authentication**: Uses Clerk for user management (clerk_user_id field)
   - No local user storage, only reference to Clerk user IDs

3. **Real-time State Sync**: WebSocket connections automatically broadcast state changes
   - Life updates, player joins/leaves, game start/end events
   - All connected clients receive real-time updates

4. **Game Lifecycle Management**: 
   - Games have "active" and "finished" states
   - Winner determined by highest life total when game ends
   - Automatic player elimination tracking

### Data Flow

1. **Game Creation**: HTTP POST creates game and first player entry
2. **Player Connection**: WebSocket connection with game_id and clerk_user_id
3. **Auto-join**: Server automatically adds player if not already in game
4. **Real-time Updates**: All game actions broadcast via WebSocket to connected players
5. **Game End**: Determines winner and updates game status

### WebSocket Protocol

Detailed protocol documented in `WEBSOCKET_PROTOCOL.md`. Key message types:
- Client actions: updateLife, joinGame, leaveGame, getGameState, endGame
- Server broadcasts: lifeUpdate, playerJoined, playerLeft, gameStarted, gameEnded, error

Connection requires `game_id` and `clerk_user_id` query parameters.

### Database Schema

Three main tables with foreign key relationships:
- `games`: Core game information and lifecycle state
- `players`: Player participation in games with current life
- `life_changes`: Audit trail of all life modifications

Uses UUIDs for all primary keys and Chrono for timestamps.