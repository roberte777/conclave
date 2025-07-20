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

### 6. Set Commander Damage
Sets the commander damage from one player to another to a specific value.

```json
{
  "action": "setCommanderDamage",
  "fromPlayerId": "123e4567-e89b-12d3-a456-426614174000",
  "toPlayerId": "456e7890-e89b-12d3-a456-426614174000",
  "commanderNumber": 1,
  "newDamage": 5
}
```

**Fields:**
- `fromPlayerId` (UUID): The player dealing commander damage
- `toPlayerId` (UUID): The player receiving commander damage
- `commanderNumber` (integer): Commander number (1 or 2 for partners)
- `newDamage` (integer): The new total commander damage value

### 7. Update Commander Damage
Updates the commander damage by a relative amount.

```json
{
  "action": "updateCommanderDamage",
  "fromPlayerId": "123e4567-e89b-12d3-a456-426614174000",
  "toPlayerId": "456e7890-e89b-12d3-a456-426614174000",
  "commanderNumber": 1,
  "damageAmount": 2
}
```

**Fields:**
- `fromPlayerId` (UUID): The player dealing commander damage
- `toPlayerId` (UUID): The player receiving commander damage
- `commanderNumber` (integer): Commander number (1 or 2 for partners)
- `damageAmount` (integer): Amount to add/subtract (positive for damage, negative to reduce)

### 8. Toggle Partner
Enables or disables partner commander mode for a player.

```json
{
  "action": "togglePartner",
  "playerId": "123e4567-e89b-12d3-a456-426614174000",
  "enablePartner": true
}
```

**Fields:**
- `playerId` (UUID): The player to toggle partner mode for
- `enablePartner` (boolean): True to enable partner (Commander 2), false to disable

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

### 4. Game State
Sent when initially connecting and provides the complete current game state.

```json
{
  "type": "gameState",
  "gameId": "123e4567-e89b-12d3-a456-426614174000",
  "game": {
    "id": "123e4567-e89b-12d3-a456-426614174000",
    "name": "Epic Commander Game",
    "status": "active",
    "startingLife": 40,
    "createdAt": "2023-06-28T10:30:00Z",
    "finishedAt": null
  },
  "players": [
    {
      "id": "123e4567-e89b-12d3-a456-426614174000",
      "gameId": "123e4567-e89b-12d3-a456-426614174000",
      "clerkUserId": "user_abc123",
      "currentLife": 38,
      "position": 1,
      "isEliminated": false
    }
  ],
  "recentChanges": [
    {
      "id": "987e6543-e89b-12d3-a456-426614174000",
      "gameId": "123e4567-e89b-12d3-a456-426614174000",
      "playerId": "123e4567-e89b-12d3-a456-426614174000",
      "changeAmount": -2,
      "newLifeTotal": 38,
      "createdAt": "2023-06-28T10:35:00Z"
    }
  ],
  "commanderDamage": [
    {
      "id": "456e7890-e89b-12d3-a456-426614174000",
      "gameId": "123e4567-e89b-12d3-a456-426614174000",
      "fromPlayerId": "123e4567-e89b-12d3-a456-426614174000",
      "toPlayerId": "456e7890-e89b-12d3-a456-426614174000",
      "commanderNumber": 1,
      "damage": 5,
      "createdAt": "2023-06-28T10:30:00Z",
      "updatedAt": "2023-06-28T10:34:00Z"
    }
  ]
}
```

**Fields:**
- `gameId` (UUID): The game identifier
- `game` (Game object): Complete game information
- `players` (Array): List of all players in the game
- `recentChanges` (Array): Recent life changes for context
- `commanderDamage` (Array): All commander damage relationships in the game

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

### 6. Commander Damage Update
Notifies all clients when commander damage is updated between players.

```json
{
  "type": "commanderDamageUpdate",
  "gameId": "123e4567-e89b-12d3-a456-426614174000",
  "fromPlayerId": "123e4567-e89b-12d3-a456-426614174000",
  "toPlayerId": "456e7890-e89b-12d3-a456-426614174000",
  "commanderNumber": 1,
  "newDamage": 7,
  "damageAmount": 2
}
```

**Fields:**
- `gameId` (UUID): The game this update belongs to
- `fromPlayerId` (UUID): The player dealing commander damage
- `toPlayerId` (UUID): The player receiving commander damage
- `commanderNumber` (integer): Commander number (1 or 2)
- `newDamage` (integer): The new total commander damage value
- `damageAmount` (integer): The amount that was added/subtracted

### 7. Partner Toggled
Notifies all clients when a player enables or disables partner commander mode.

```json
{
  "type": "partnerToggled",
  "gameId": "123e4567-e89b-12d3-a456-426614174000",
  "playerId": "123e4567-e89b-12d3-a456-426614174000",
  "hasPartner": true
}
```

**Fields:**
- `gameId` (UUID): The game this update belongs to
- `playerId` (UUID): The player whose partner status changed
- `hasPartner` (boolean): True if partner is now enabled, false if disabled

### 8. Error
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

### Game Object
```json
{
  "id": "123e4567-e89b-12d3-a456-426614174000",
  "name": "Epic Commander Game",
  "status": "active",
  "startingLife": 40,
  "createdAt": "2023-06-28T10:30:00Z",
  "finishedAt": null
}
```

**Fields:**
- `id` (UUID): Unique game identifier
- `name` (string): Game name
- `status` (string): Game status ("active" or "finished")
- `startingLife` (integer): Starting life total for all players
- `createdAt` (string): ISO 8601 timestamp when game was created
- `finishedAt` (string, optional): ISO 8601 timestamp when game ended

### Commander Damage Object
```json
{
  "id": "456e7890-e89b-12d3-a456-426614174000",
  "gameId": "123e4567-e89b-12d3-a456-426614174000",
  "fromPlayerId": "123e4567-e89b-12d3-a456-426614174000",
  "toPlayerId": "456e7890-e89b-12d3-a456-426614174000",
  "commanderNumber": 1,
  "damage": 5,
  "createdAt": "2023-06-28T10:30:00Z",
  "updatedAt": "2023-06-28T10:34:00Z"
}
```

**Fields:**
- `id` (UUID): Unique commander damage identifier
- `gameId` (UUID): The game this damage belongs to
- `fromPlayerId` (UUID): Player dealing the commander damage
- `toPlayerId` (UUID): Player receiving the commander damage
- `commanderNumber` (integer): Commander number (1 or 2 for partners)
- `damage` (integer): Current commander damage total
- `createdAt` (string): ISO 8601 timestamp when entry was created
- `updatedAt` (string): ISO 8601 timestamp when damage was last updated

### Life Change Object
```json
{
  "id": "987e6543-e89b-12d3-a456-426614174000",
  "gameId": "123e4567-e89b-12d3-a456-426614174000",
  "playerId": "123e4567-e89b-12d3-a456-426614174000",
  "changeAmount": -2,
  "newLifeTotal": 38,
  "createdAt": "2023-06-28T10:35:00Z"
}
```

**Fields:**
- `id` (UUID): Unique life change identifier
- `gameId` (UUID): The game this change belongs to
- `playerId` (UUID): Player whose life changed
- `changeAmount` (integer): Amount life was changed (positive for gain, negative for loss)
- `newLifeTotal` (integer): Player's life total after the change
- `createdAt` (string): ISO 8601 timestamp when change occurred

## Connection Lifecycle

1. **Connect**: Client connects with `game_id` and `clerk_user_id` query parameters
2. **Verification**: Server verifies the game exists and is active
3. **Auto-join**: If user is not already in the game, they are automatically added
4. **Initial State**: Server sends `gameState` message with complete current game state including commander damage
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
      case 'gameState':
        console.log('Game state received:', message);
        break;
      case 'gameEnded':
        console.log('Game ended. Winner:', message.winner);
        break;
      case 'commanderDamageUpdate':
        console.log(`Commander damage: Player ${message.fromPlayerId} dealt ${message.damageAmount} to ${message.toPlayerId} (Commander ${message.commanderNumber}). New total: ${message.newDamage}`);
        break;
      case 'partnerToggled':
        console.log(`Player ${message.playerId} ${message.hasPartner ? 'enabled' : 'disabled'} partner commander`);
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

  setCommanderDamage(fromPlayerId, toPlayerId, commanderNumber, newDamage) {
    this.send({
      action: 'setCommanderDamage',
      fromPlayerId,
      toPlayerId,
      commanderNumber,
      newDamage
    });
  }

  updateCommanderDamage(fromPlayerId, toPlayerId, commanderNumber, damageAmount) {
    this.send({
      action: 'updateCommanderDamage',
      fromPlayerId,
      toPlayerId,
      commanderNumber,
      damageAmount
    });
  }

  togglePartner(playerId, enablePartner) {
    this.send({
      action: 'togglePartner',
      playerId,
      enablePartner
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
- Commander damage is tracked separately from life total
- Each player can have 1-2 commanders (partner support)
- Commander damage of 21 or more results in player elimination
- Commander damage is automatically initialized when players join
- All commander damage entries are cleaned up when players leave 