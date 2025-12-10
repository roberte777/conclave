# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Development Commands

### Quick Start
- `./start-conclave.sh` - Start both backend and frontend in tmux session

### Backend (Rust API - conclave_api/)
- `cargo run` - Start the API server (runs on http://localhost:3001)
- `cargo check` - Fast syntax and type checking
- `cargo build` - Full compilation
- `cargo test` - Run unit and integration tests
- `cargo clippy` - Lint checking
- `cargo fmt` - Format code

### Frontend (Next.js - conclave_web/)
- `bun run dev` - Start development server with Turbopack
- `bun run build` - Build for production and type check
- `bun run start` - Start production server
- `bun run lint` - ESLint checking
- `bun install` - Install dependencies

### iOS App (ios/)
- Build and run through Xcode
- Uses ConclaveKit Swift package for API integration
- Supports iOS 17+ and macOS 14+

## Project Architecture

Conclave is a real-time multiplayer Magic: The Gathering life tracker with three main components:

### 1. Backend API (conclave_api/)
**Technology**: Rust + Axum + SQLite + WebSockets

**Core Architecture**:
- **Dual Interface**: REST API for setup/queries + WebSocket for real-time updates
- **External Auth**: Clerk integration (no local user storage)
- **Real-time Sync**: WebSocket broadcasts for live game state
- **Game Lifecycle**: Active/finished states with winner determination

**Key Components**:
- `src/main.rs` - Server setup and routing
- `src/handlers.rs` - REST API endpoints (use JWT auth)
- `src/websocket.rs` - Real-time WebSocket handling (JWT authenticated)
- `src/models.rs` - Data structures and DTOs
- `src/database.rs` - SQLite database layer
- `src/state.rs` - Shared application state
- `src/clerk.rs` - JWT validation and Clerk API integration
- `src/auth.rs` - Authentication extractors for handlers

**WebSocket Protocol**: Documented in `WEBSOCKET_PROTOCOL.md`
- Client actions: updateLife, leaveGame, getGameState, endGame
- Server broadcasts: lifeUpdate, playerJoined, playerLeft, gameStarted, gameEnded
- Players are auto-joined on WebSocket connection with valid JWT

### 2. Web Frontend (conclave_web/)
**Technology**: Next.js 15 + TypeScript + Tailwind + shadcn/ui + Clerk

**Architecture**:
- App Router with TypeScript
- Clerk authentication integration
- React Query for server state management
- WebSocket client for real-time updates
- Responsive UI with Tailwind CSS and shadcn/ui components

**Key Directories**:
- `src/app/` - Next.js app router pages
- `src/components/` - Reusable UI components
- `src/lib/` - Utilities and API client

### 3. iOS App (ios/)
**Technology**: SwiftUI + ConclaveKit package

**ConclaveKit Features**:
- HTTP client for REST API integration
- WebSocket client for real-time updates
- Models matching backend data structures
- Configuration management
- Logging utilities

## Database Schema

SQLite database with three core tables:
- `games` - Game lifecycle and metadata
- `players` - Player participation with current life totals
- `life_changes` - Complete audit trail of life modifications

Uses UUID primary keys and foreign key relationships for data integrity.

## Authentication & User Management

- **Clerk Integration**: External authentication provider
- **JWT Authentication**: All API requests and WebSocket connections require JWT tokens from Clerk
- **Backend User Info**: Backend fetches user info (name, avatar) from Clerk API - clients don't need to
- **No Local Users**: All user data managed by Clerk, referenced by `clerk_user_id`
- **Multi-platform**: Same Clerk integration across web and mobile

## Real-time Communication

**WebSocket Connection Requirements**:
- Query parameters: `gameId` (UUID) and `token` (JWT from Clerk)
- JWT is validated and user info is extracted server-side
- Auto-join functionality when connecting with valid token
- Broadcast to all connected clients in same game
- Connection cleanup on disconnect

**Data Flow**:
1. Client obtains JWT token from Clerk
2. HTTP POST with JWT creates game and first player
3. WebSocket connection with gameId + JWT token
4. Server validates JWT and auto-joins player if not in game
5. Real-time updates broadcast to all connected players with user display info
6. Game end determines winner by highest life total

**Player Data Enrichment**:
- Backend fetches user display info from Clerk API
- Player objects include `displayName`, `username`, and `imageUrl`
- Clients don't need to make separate calls to Clerk for user info

## Environment Setup

### Backend
- Rust 1.70+ required
- SQLite database (created automatically)
- Runs on port 3001 by default
- Environment variables:
  ```
  CLERK_SECRET_KEY=your_secret  # For JWT validation and Clerk API calls
  CLERK_JWKS_URL=https://your-clerk-instance.clerk.accounts.dev/.well-known/jwks.json  # Optional: for JWKS validation
  DATABASE_URL=sqlite:conclave.db?mode=rwc  # Optional: defaults to this
  PORT=3001  # Optional: defaults to 3001
  ```

### Frontend
- Node.js 18+ and Bun package manager
- Requires `.env.local` with Clerk keys:
  ```
  NEXT_PUBLIC_API_URL=http://localhost:3001
  NEXT_PUBLIC_CLERK_PUBLISHABLE_KEY=your_key
  CLERK_SECRET_KEY=your_secret
  ```

### iOS
- Xcode with Swift 6.1+
- ConclaveKit package for API integration
- Supports iOS 17+ and macOS 14+

## Testing & Quality

- **Backend**: `cargo test` for Rust unit/integration tests
- **Frontend**: `bun run build` includes TypeScript checking
- **Linting**: `cargo clippy` for Rust, `bun run lint` for Next.js
- **Formatting**: `cargo fmt` for consistent Rust code style

## Development Workflow

1. Use `./start-conclave.sh` to start both services in tmux
2. Backend runs on http://localhost:3001
3. Frontend runs on http://localhost:3000 (or next available port)
4. Set up Clerk authentication keys in `conclave_web/.env.local`
5. iOS development through Xcode using ConclaveKit package

## Game Constants & Limits

- Default starting life: 20
- Maximum players per game: 8
- Player positions: 1-8
- Life changes: Support positive (healing) and negative (damage)
- Winner determination: Highest life total when game ends