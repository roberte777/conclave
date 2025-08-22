export interface Game {
  id: string;
  name: string;
  status: "active" | "finished";
  startingLife: number;
  createdAt: string;
  finishedAt?: string;
}

export interface Player {
  id: string;
  gameId: string;
  clerkUserId: string;
  currentLife: number;
  position: number;
  isEliminated: boolean;
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
  name: string;
  startingLife?: number;
  clerkUserId: string;
}

export interface JoinGameRequest {
  clerkUserId: string;
}

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
  | {
      action: "joinGame";
      clerkUserId: string;
    }
  | {
      action: "leaveGame";
      playerId: string;
    }
  | {
      action: "getGameState";
    }
  | {
      action: "endGame";
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