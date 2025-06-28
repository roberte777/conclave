# 🎯 Conclave - MTG Life Tracker

The ultimate Magic: The Gathering life tracker for multiplayer games with real-time synchronization.

## ✨ Features

- **Real-time Life Tracking**: Track life totals for up to 8 players with instant updates
- **Multiplayer Lobbies**: Create and join lobbies before starting games
- **WebSocket Integration**: Real-time updates across all connected devices
- **User Authentication**: Secure authentication powered by Clerk
- **Modern UI**: Beautiful, responsive interface built with Next.js and Tailwind CSS
- **Game History**: Track your wins and game statistics (coming soon)
- **Mobile Optimized**: Works seamlessly on phones, tablets, and desktops

## 🛠️ Tech Stack

### Frontend
- **Next.js 15** - React framework with app router
- **TypeScript** - Type safety and better DX
- **Tailwind CSS** - Utility-first CSS framework
- **shadcn/ui** - High-quality UI components
- **Clerk** - User authentication and management
- **React Query** - Server state management
- **WebSocket** - Real-time communication

### Backend
- **Rust** - High-performance backend
- **Axum** - Modern web framework
- **SQLite** - Embedded database
- **WebSocket** - Real-time updates
- **Clerk Integration** - User authentication

## 🚀 Quick Start

### Prerequisites

- **Node.js** 18+ (frontend)
- **Rust** 1.70+ (backend)
- **Clerk Account** for authentication

### 1. Clone the Repository

\`\`\`bash
git clone <your-repo-url>
cd conclave
\`\`\`

### 2. Backend Setup

\`\`\`bash
cd conclave_api

# Install Rust dependencies and run
cargo run
\`\`\`

The API server will start on `http://localhost:3000`

### 3. Frontend Setup

\`\`\`bash
cd conclave_web

# Install dependencies
bun install

# Create environment file
cp .env.example .env.local

# Edit .env.local and add your Clerk keys
\`\`\`

Create a `.env.local` file with:

\`\`\`env
# API Configuration
NEXT_PUBLIC_API_URL=http://localhost:3000

# Clerk Configuration
NEXT_PUBLIC_CLERK_PUBLISHABLE_KEY=your_clerk_publishable_key
CLERK_SECRET_KEY=your_clerk_secret_key
\`\`\`

### 4. Set Up Clerk Authentication

1. Create a [Clerk account](https://clerk.dev)
2. Create a new application
3. Copy the publishable key and secret key to your `.env.local`
4. Configure the sign-in/sign-up flows in the Clerk dashboard

### 5. Start the Frontend

\`\`\`bash
bun run dev
\`\`\`

The web app will be available at `http://localhost:3001`

## 🎮 How to Play

1. **Sign In**: Create an account or sign in with Clerk
2. **Create a Lobby**: Click "Create Lobby" and give it a name
3. **Invite Friends**: Share the lobby with friends who can join
4. **Start Game**: The lobby host can set starting life and start the game
5. **Track Life**: Use the +/- buttons to adjust life totals in real-time
6. **Win!**: The last player standing wins!

## 🏗️ Architecture

### Backend API Endpoints

- `GET /health` - Health check
- `GET /stats` - Server statistics
- `POST /lobbies` - Create a new lobby
- `GET /lobbies` - List active lobbies
- `GET /lobbies/:id` - Get lobby details
- `POST /lobbies/:id/join` - Join a lobby
- `POST /lobbies/:id/start-game` - Start a game
- `GET /games/:id` - Get game details
- `GET /games/:id/state` - Get complete game state
- `PUT /games/:id/update-life` - Update player life
- `PUT /games/:id/end` - End a game
- `GET /games/:id/life-changes` - Get recent life changes
- `GET /users/:clerk_user_id/history` - Get user's game history
- `WS /ws` - WebSocket endpoint for real-time updates

### Database Schema

The app uses SQLite with the following main tables:
- `lobbies` - Game lobbies
- `lobby_users` - Many-to-many relationship for lobby membership
- `games` - Active and finished games
- `players` - Players in each game
- `life_changes` - Audit trail of all life changes

User data is managed by Clerk, so no local user table is needed.

### WebSocket Messages

Real-time updates are handled via WebSocket with these message types:
- `life_update` - Player life changed
- `player_eliminated` - Player was eliminated
- `game_started` - Game has started
- `game_ended` - Game has ended
- `error` - Error occurred

## 🔧 Development

### Backend Development

\`\`\`bash
cd conclave_api

# Run with auto-reload
cargo watch -x run

# Run tests
cargo test

# Check code
cargo check
\`\`\`

### Frontend Development

\`\`\`bash
cd conclave_web

# Development server
bun run dev

# Type checking
bun run build

# Linting
bun run lint
\`\`\`

### Adding New Features

1. **Database Changes**: Update the migration file in `conclave_api/migrations/`
2. **API Changes**: Update models, handlers, and routes in the backend
3. **Frontend Changes**: Update the API client and add new components
4. **Real-time Features**: Add WebSocket message types for live updates

## 📱 Mobile App (Future)

The separate API design makes it easy to add a mobile app later using:
- **React Native** with the same API endpoints
- **Flutter** with WebSocket support
- **Native iOS/Android** apps

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Add tests if applicable
5. Submit a pull request

## 📄 License

This project is open source and available under the [MIT License](LICENSE).

## 🎯 Roadmap

- [ ] Game history and statistics
- [ ] Tournament mode
- [ ] Custom life totals and formats
- [ ] Player avatars and themes
- [ ] Sound effects and animations
- [ ] Mobile app
- [ ] Deck tracking integration
- [ ] Commander damage tracking

---

**Ready to track those life totals? Let the games begin! ⚔️**
