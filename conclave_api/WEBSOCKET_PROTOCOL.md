# Conclave WebSocket Protocol Documentation

## Overview

The Conclave WebSocket API enables real-time communication for multiplayer games. It supports life tracking, player management, and game state synchronization across all connected clients.

## Connection

### Endpoint
```
ws://localhost:8080/ws
```

### Query Parameters
- `game_id` (UUID, required): The unique identifier of the game to connect to
- `clerk_user_id` (String, required): The Clerk user ID for authentication

### Example Connection
```
ws://localhost:8080/ws?game_id=123e4567-e89b-12d3-a456-426614174000&clerk_user_id=user_abc123
```

## Message Format

All messages are sent as JSON strings. The protocol uses camelCase for field names.

## Client → Server Messages (Requests)

### 1. Update Life
Updates a player's life total.

```json
{
  "action": "updateLife",
  "playerId": "123e4567-e89b-12d3-a456-426614174000",
  "changeAmount": -3
}
```

**Fields:**
- `playerId` (UUID): The player whose life to update
- `changeAmount` (integer): The amount to change life by (positive for gain, negative for loss)

### 2. Join Game
Adds the current user to the game as a player.

```json
{
  "action": "joinGame",
  "clerkUserId": "user_abc123"
}
```

**Fields:**
- `clerkUserId` (string): The Clerk user ID of the player joining

### 3. Leave Game
Removes a player from the game.

```json
{
  "action": "leaveGame",
  "playerId": "123e4567-e89b-12d3-a456-426614174000"
}
```

**Fields:**
- `playerId` (UUID): The player to remove from the game

### 4. Get Game State
Requests the current game state to be broadcast to all clients.

```json
{
  "action": "getGameState"
}
```

### 5. End Game
Ends the current game and determines the winner.

```json
{
  "action": "endGame"
}
```

## Server → Client Messages (Responses)

### 1. Life Update
Notifies all clients when a player's life changes.

```json
{
  "type": "lifeUpdate",
  "gameId": "123e4567-e89b-12d3-a456-426614174000",
  "playerId": "123e4567-e89b-12d3-a456-426614174000",
  "newLife": 17,
  "changeAmount": -3
}
```

**Fields:**
- `gameId` (UUID): The game this update belongs to
- `playerId` (UUID): The player whose life changed
- `newLife` (integer): The player's new life total
- `changeAmount` (integer): The amount that was added/subtracted

### 2. Player Joined
Notifies all clients when a new player joins the game.

```json
{
  "type": "playerJoined",
  "gameId": "123e4567-e89b-12d3-a456-426614174000",
  "player": {
    "id": "123e4567-e89b-12d3-a456-426614174000",
    "gameId": "123e4567-e89b-12d3-a456-426614174000",
    "clerkUserId": "user_abc123",
    "currentLife": 20,
    "position": 1,
    "isEliminated": false
  }
}
```

**Fields:**
- `gameId` (UUID): The game the player joined
- `player` (Player object): Complete player information

### 3. Player Left
Notifies all clients when a player leaves the game.

```json
{
  "type": "playerLeft",
  "gameId": "123e4567-e89b-12d3-a456-426614174000",
  "playerId": "123e4567-e89b-12d3-a456-426614174000"
}
```

**Fields:**
- `gameId` (UUID): The game the player left
- `playerId` (UUID): The player who left

### 4. Game Started / Game State
Sent when initially connecting and provides the current game state.

```json
{
  "type": "gameStarted",
  "gameId": "123e4567-e89b-12d3-a456-426614174000",
  "players": [
    {
      "id": "123e4567-e89b-12d3-a456-426614174000",
      "gameId": "123e4567-e89b-12d3-a456-426614174000",
      "clerkUserId": "user_abc123",
      "currentLife": 20,
      "position": 1,
      "isEliminated": false
    }
  ]
}
```

**Fields:**
- `gameId` (UUID): The game identifier
- `players` (Array): List of all players in the game

### 5. Game Ended
Notifies all clients when the game ends.

```json
{
  "type": "gameEnded",
  "gameId": "123e4567-e89b-12d3-a456-426614174000",
  "winner": {
    "id": "123e4567-e89b-12d3-a456-426614174000",
    "gameId": "123e4567-e89b-12d3-a456-426614174000",
    "clerkUserId": "user_abc123",
    "currentLife": 25,
    "position": 1,
    "isEliminated": false
  }
}
```

**Fields:**
- `gameId` (UUID): The game that ended
- `winner` (Player object, optional): The winning player (player with highest life), null if no winner

### 6. Error
Sent when an error occurs.

```json
{
  "type": "error",
  "message": "Game not found or not active"
}
```

**Fields:**
- `message` (string): Human-readable error description

## Data Types

### Player Object
```json
{
  "id": "123e4567-e89b-12d3-a456-426614174000",
  "gameId": "123e4567-e89b-12d3-a456-426614174000", 
  "clerkUserId": "user_abc123",
  "currentLife": 20,
  "position": 1,
  "isEliminated": false
}
```

**Fields:**
- `id` (UUID): Unique player identifier
- `gameId` (UUID): The game this player belongs to
- `clerkUserId` (string): The Clerk user ID
- `currentLife` (integer): Current life total
- `position` (integer): Player position in the game (1-8)
- `isEliminated` (boolean): Whether the player has been eliminated

## Connection Lifecycle

1. **Connect**: Client connects with `game_id` and `clerk_user_id` query parameters
2. **Verification**: Server verifies the game exists and is active
3. **Auto-join**: If user is not already in the game, they are automatically added
4. **Initial State**: Server sends `gameStarted` message with current game state
5. **Real-time Updates**: Server broadcasts all game events to connected clients
6. **Disconnect**: Connection cleanup when client disconnects

## Error Handling

Errors are sent as `error` type messages. Common error scenarios:
- Game not found or not active
- Invalid JSON format
- Player not found
- Database connection issues

## Example Client Implementation (JavaScript)

```javascript
class ConclaveWebSocket {
  constructor(gameId, clerkUserId) {
    this.gameId = gameId;
    this.clerkUserId = clerkUserId;
    this.ws = null;
  }

  connect() {
    const url = `ws://localhost:8080/ws?game_id=${this.gameId}&clerk_user_id=${this.clerkUserId}`;
    this.ws = new WebSocket(url);
    
    this.ws.onopen = () => {
      console.log('Connected to Conclave WebSocket');
    };
    
    this.ws.onmessage = (event) => {
      const message = JSON.parse(event.data);
      this.handleMessage(message);
    };
    
    this.ws.onclose = () => {
      console.log('Disconnected from Conclave WebSocket');
    };
    
    this.ws.onerror = (error) => {
      console.error('WebSocket error:', error);
    };
  }

  handleMessage(message) {
    switch (message.type) {
      case 'lifeUpdate':
        console.log(`Player ${message.playerId} life changed to ${message.newLife}`);
        break;
      case 'playerJoined':
        console.log(`Player ${message.player.clerkUserId} joined the game`);
        break;
      case 'playerLeft':
        console.log(`Player ${message.playerId} left the game`);
        break;
      case 'gameStarted':
        console.log('Game state received:', message.players);
        break;
      case 'gameEnded':
        console.log('Game ended. Winner:', message.winner);
        break;
      case 'error':
        console.error('Game error:', message.message);
        break;
    }
  }

  updateLife(playerId, changeAmount) {
    this.send({
      action: 'updateLife',
      playerId,
      changeAmount
    });
  }

  joinGame() {
    this.send({
      action: 'joinGame',
      clerkUserId: this.clerkUserId
    });
  }

  leaveGame(playerId) {
    this.send({
      action: 'leaveGame',
      playerId
    });
  }

  getGameState() {
    this.send({
      action: 'getGameState'
    });
  }

  endGame() {
    this.send({
      action: 'endGame'
    });
  }

  send(message) {
    if (this.ws && this.ws.readyState === WebSocket.OPEN) {
      this.ws.send(JSON.stringify(message));
    }
  }

  disconnect() {
    if (this.ws) {
      this.ws.close();
    }
  }
}

// Usage
const client = new ConclaveWebSocket(
  '123e4567-e89b-12d3-a456-426614174000',
  'user_abc123'
);
client.connect();
```

## Notes

- All UUIDs should be in standard UUID format (8-4-4-4-12 hex digits)
- The default starting life is 20
- Maximum 8 players per game
- Games must be in "active" status to accept WebSocket connections
- Life changes can be positive (healing) or negative (damage)
- The winner is determined by the player with the highest life when the game ends 