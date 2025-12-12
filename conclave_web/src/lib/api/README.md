# Conclave API Client Library

A TypeScript library for interacting with the Conclave API, providing both HTTP and WebSocket clients for real-time multiplayer game management.

## Installation

The library is already included in the conclave_web project. No additional installation needed.

## Basic Usage

### Import the API Client

```typescript
import { ConclaveAPI, createClient } from '@/lib/api';
```

### Create a Client Instance

```typescript
const api = createClient({
  httpUrl: 'http://localhost:3001', // Optional, defaults to NEXT_PUBLIC_API_URL
  wsUrl: 'ws://localhost:3001/ws',   // Optional, auto-derived from httpUrl
  getAuthToken: async () => {        // Optional, for authenticated requests
    return await getAuth().getToken();
  }
});
```

### HTTP API Usage

```typescript
// Create a new game
const game = await api.http.createGame({
  name: "Friday Night Magic",
  startingLife: 20,
  clerkUserId: "user_123"
});

// Join an existing game
const player = await api.http.joinGame(game.id, {
  clerkUserId: "user_456"
});

// Get game state
const gameState = await api.http.getGameState(game.id);

// Update player life
const lifeChange = await api.http.updateLife(game.id, {
  playerId: player.id,
  changeAmount: -3
});

// End the game
const result = await api.http.endGame(game.id);
console.log('Winner:', result.winner);
```

### WebSocket Real-time Updates

```typescript
// Connect to game WebSocket with a token getter function
// The token getter is called on initial connection AND on each reconnection
// to ensure fresh tokens for long-lived connections
const ws = api.connectWebSocket(gameId, async () => {
  const token = await getAuth().getToken();
  if (!token) throw new Error('Not authenticated');
  return token;
});

// Listen for all messages
ws.on('*', (message) => {
  console.log('Received:', message);
});

// Listen for specific events
ws.on('lifeUpdate', (message) => {
  if (message.type === 'lifeUpdate') {
    console.log(`Player ${message.playerId} life: ${message.newLife}`);
  }
});

ws.on('playerJoined', (message) => {
  if (message.type === 'playerJoined') {
    console.log(`${message.player.clerkUserId} joined the game`);
  }
});

// Send WebSocket commands
ws.updateLife(playerId, -2);
ws.getGameState();
ws.endGame();

// Disconnect when done
api.disconnectWebSocket();
```

## React Hooks

### useConclave Hook

```typescript
import { useConclave } from '@/lib/api/hooks';

function GameComponent() {
  const { getToken } = useAuth();
  
  // Create a stable token getter function
  const tokenGetter = useCallback(async () => {
    const token = await getToken();
    if (!token) throw new Error('Not authenticated');
    return token;
  }, [getToken]);
  
  const { api, isConnected, gameState, lastMessage, error } = useConclave({
    gameId: 'game-uuid',
    getToken: tokenGetter,
    autoConnect: true, // Auto-connect WebSocket
  });

  if (error) return <div>Error: {error.message}</div>;
  if (!isConnected) return <div>Connecting...</div>;

  return (
    <div>
      <h2>{gameState?.game.name}</h2>
      {gameState?.players.map(player => (
        <div key={player.id}>
          Player {player.position}: {player.currentLife} life
        </div>
      ))}
    </div>
  );
}
```

### useGameState Hook

```typescript
import { useGameState } from '@/lib/api/hooks';

function GameStats({ gameId }: { gameId: string }) {
  const { gameState, loading, error, refetch } = useGameState(gameId);

  if (loading) return <div>Loading...</div>;
  if (error) return <div>Error: {error.message}</div>;

  return (
    <div>
      <h3>Game: {gameState?.game.name}</h3>
      <button onClick={() => refetch(api)}>Refresh</button>
    </div>
  );
}
```

## API Methods

### HTTP Client Methods

- `createGame(request)` - Create a new game
- `joinGame(gameId, request)` - Join an existing game
- `leaveGame(gameId, playerId)` - Leave a game
- `getGame(gameId)` - Get game details
- `getGameState(gameId)` - Get full game state
- `getUserGames(clerkUserId)` - Get user's active games
- `getAvailableGames()` - Get joinable games
- `updateLife(gameId, request)` - Update player life
- `endGame(gameId)` - End game and determine winner
- `getUserHistory(clerkUserId)` - Get user's game history
- `getRecentLifeChanges(gameId, limit?)` - Get recent life changes
- `updateCommanderDamage(gameId, request)` - Update commander damage
- `togglePartner(gameId, request)` - Toggle partner commander
- `healthCheck()` - Check API health
- `getStats()` - Get server statistics

### WebSocket Client Methods

- `connect()` - Connect to WebSocket
- `disconnect()` - Disconnect from WebSocket
- `send(request)` - Send raw WebSocket message
- `updateLife(playerId, changeAmount)` - Update life via WebSocket
- `joinGame(clerkUserId)` - Join game via WebSocket
- `leaveGame(playerId)` - Leave game via WebSocket
- `getGameState()` - Request game state
- `endGame()` - End the game
- `setCommanderDamage(...)` - Set commander damage
- `updateCommanderDamage(...)` - Update commander damage
- `togglePartner(playerId, enable)` - Toggle partner

### WebSocket Events

Listen for these event types:

- `lifeUpdate` - Player life changed
- `playerJoined` - New player joined
- `playerLeft` - Player left game
- `gameStarted` - Game started (includes full state)
- `gameEnded` - Game ended with winner
- `commanderDamageUpdate` - Commander damage updated
- `partnerToggled` - Partner commander toggled
- `error` - Error occurred
- `*` - Catch all events

## Types

All TypeScript types are exported from the main module:

```typescript
import type {
  Game,
  Player,
  GameState,
  LifeChange,
  CommanderDamage,
  WebSocketMessage,
  WebSocketRequest,
  // ... and more
} from '@/lib/api';
```

## Error Handling

Both HTTP and WebSocket clients include built-in error handling:

```typescript
try {
  const game = await api.http.createGame({ ... });
} catch (error) {
  console.error('Failed to create game:', error.message);
}

// WebSocket errors
ws.onError((error) => {
  console.error('WebSocket error:', error);
});
```

## Auto-reconnection

The WebSocket client automatically attempts to reconnect on disconnect using exponential backoff with jitter:

- **Exponential backoff**: Delays increase exponentially (1s, 2s, 4s, 8s, 16s, 30s, 30s, ...)
- **Jitter**: Random delay added (0-50% of current delay) to prevent thundering herd
- **Max interval**: Capped at 30 seconds
- **Unlimited retries**: Will keep attempting to reconnect indefinitely
- **Token refresh**: Fetches a fresh JWT token before each reconnection attempt
- **Message queuing**: Messages are queued while disconnected and sent on reconnect

Configure reconnection:

```typescript
const ws = new WebSocketClient({
  url: wsUrl,
  gameId,
  getToken: async () => fetchFreshToken(),
  baseReconnectInterval: 1000,  // 1 second (default)
  maxReconnectInterval: 30000,  // 30 seconds (default)
});
```