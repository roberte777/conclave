export interface Game {
  id: string;
  status: "active" | "finished";
  startingLife: number;
  winnerPlayerId?: string;
  createdAt: string;
  finishedAt?: string;
}

export interface Player {
  id: string;
  gameId: string;
  clerkUserId: string;
  currentLife: number;
  position: number;
  // User display info (enriched from backend)
  displayName: string;
  username?: string;
  imageUrl?: string;
}

export interface LifeChange {
  id: string;
  gameId: string;
  playerId: string;
  changeAmount: number;
  newLifeTotal: number;
  createdAt: string;
}

export interface CommanderDamage {
  id: string;
  gameId: string;
  fromPlayerId: string;
  toPlayerId: string;
  commanderNumber: number;
  damage: number;
  createdAt: string;
  updatedAt: string;
}

export interface GameState {
  game: Game;
  players: Player[];
  recentChanges: LifeChange[];
  commanderDamage: CommanderDamage[];
}

export interface GameWithPlayers {
  game: Game;
  players: Player[];
  winner?: Player;
}

export interface GameHistory {
  games: GameWithPlayers[];
}

export interface UserInfo {
  clerkUserId: string;
}

export interface GameWithUsers {
  game: Game;
  users: UserInfo[];
}

export interface GameEndResult {
  winner?: Player;
}

export interface CreateGameRequest {
  startingLife?: number;
  // clerkUserId is now extracted from JWT token
}

// JoinGameRequest is no longer needed - clerkUserId comes from JWT

export interface UpdateLifeRequest {
  playerId: string;
  changeAmount: number;
}

export interface UpdateCommanderDamageRequest {
  fromPlayerId: string;
  toPlayerId: string;
  commanderNumber: number;
  damageAmount: number;
}

export interface TogglePartnerRequest {
  playerId: string;
  enablePartner: boolean;
}

export interface EndGameRequest {
  winnerPlayerId?: string;
}

export type WebSocketMessage =
  | {
    type: "lifeUpdate";
    gameId: string;
    playerId: string;
    newLife: number;
    changeAmount: number;
  }
  | {
    type: "playerJoined";
    gameId: string;
    player: Player;
  }
  | {
    type: "playerLeft";
    gameId: string;
    playerId: string;
  }
  | {
    type: "gameStarted";
    game: Game;
    players: Player[];
    recentChanges: LifeChange[];
    commanderDamage: CommanderDamage[];
  }
  | {
    type: "gameEnded";
    gameId: string;
    winner?: Player;
  }
  | {
    type: "commanderDamageUpdate";
    gameId: string;
    fromPlayerId: string;
    toPlayerId: string;
    commanderNumber: number;
    newDamage: number;
    damageAmount: number;
  }
  | {
    type: "partnerToggled";
    gameId: string;
    playerId: string;
    hasPartner: boolean;
  }
  | {
    type: "error";
    message: string;
  };

export type WebSocketRequest =
  | {
    action: "updateLife";
    playerId: string;
    changeAmount: number;
  }
  // joinGame action removed - auto-join happens on WebSocket connection with JWT
  | {
    action: "leaveGame";
    playerId: string;
  }
  | {
    action: "getGameState";
  }
  | {
    action: "endGame";
    winnerPlayerId?: string;
  }
  | {
    action: "setCommanderDamage";
    fromPlayerId: string;
    toPlayerId: string;
    commanderNumber: number;
    newDamage: number;
  }
  | {
    action: "updateCommanderDamage";
    fromPlayerId: string;
    toPlayerId: string;
    commanderNumber: number;
    damageAmount: number;
  }
  | {
    action: "togglePartner";
    playerId: string;
    enablePartner: boolean;
  };

export const DEFAULT_STARTING_LIFE = 20;
export const MAX_PLAYERS_PER_GAME = 8;