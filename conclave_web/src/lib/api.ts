import axios from 'axios';

const API_BASE_URL = process.env.NEXT_PUBLIC_API_URL || 'http://localhost:3001';

const api = axios.create({
    baseURL: `${API_BASE_URL}/api/v1`,
    headers: {
        'Content-Type': 'application/json',
    },
});

// Types matching our Rust backend
export interface Game {
    id: string;
    name: string;
    status: string;
    startingLife: number;
    createdAt: string;
    finishedAt?: string;
}

export interface UserInfo {
    clerkUserId: string;
}

export interface GameWithUsers {
    game: Game;
    users: UserInfo[];
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
    commanderNumber: 1 | 2;
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

// Request types
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
    commanderNumber: 1 | 2;
    damageAmount: number;
}

export interface TogglePartnerRequest {
    playerId: string;
    enablePartner: boolean;
}

// API functions
export const gameApi = {
    create: async (data: CreateGameRequest): Promise<Game> => {
        const response = await api.post('/games', data);
        return response.data;
    },

    join: async (gameId: string, data: JoinGameRequest): Promise<Player> => {
        const response = await api.post(`/games/${gameId}/join`, data);
        return response.data;
    },

    leave: async (gameId: string, data: JoinGameRequest): Promise<void> => {
        await api.post(`/games/${gameId}/leave`, data);
    },

    get: async (gameId: string): Promise<Game> => {
        const response = await api.get(`/games/${gameId}`);
        return response.data;
    },

    getState: async (gameId: string): Promise<GameState> => {
        const response = await api.get(`/games/${gameId}/state`);
        return response.data;
    },

    updateLife: async (gameId: string, data: UpdateLifeRequest): Promise<Player> => {
        const response = await api.put(`/games/${gameId}/update-life`, data);
        return response.data;
    },

    end: async (gameId: string): Promise<Game> => {
        const response = await api.put(`/games/${gameId}/end`);
        return response.data;
    },

    getLifeChanges: async (gameId: string): Promise<LifeChange[]> => {
        const response = await api.get(`/games/${gameId}/life-changes`);
        return response.data;
    },

    // Commander Damage methods
    updateCommanderDamage: async (gameId: string, data: UpdateCommanderDamageRequest): Promise<CommanderDamage> => {
        const response = await api.put(`/games/${gameId}/commander-damage`, data);
        return response.data;
    },

    togglePartner: async (gameId: string, playerId: string, data: TogglePartnerRequest): Promise<void> => {
        await api.post(`/games/${gameId}/players/${playerId}/partner`, data);
    },
};

export const userApi = {
    getGames: async (clerkUserId: string): Promise<GameWithUsers[]> => {
        const response = await api.get(`/users/${clerkUserId}/games`);
        return response.data;
    },

    getAvailableGames: async (clerkUserId: string): Promise<GameWithUsers[]> => {
        const response = await api.get(`/users/${clerkUserId}/available-games`);
        return response.data;
    },

    getHistory: async (clerkUserId: string): Promise<GameHistory> => {
        const response = await api.get(`/users/${clerkUserId}/history`);
        return response.data;
    },
};

export const healthApi = {
    check: async (): Promise<{ status: string; service: string }> => {
        const response = await api.get('/health');
        return response.data;
    },

    getStats: async (): Promise<{ activeGames: number; service: string }> => {
        const response = await api.get('/stats');
        return response.data;
    },
};

// WebSocket Message Types
export type WebSocketMessage = 
    | { type: 'lifeUpdate'; gameId?: string; playerId?: string; newLife?: number; changeAmount?: number; }
    | { type: 'playerJoined'; gameId?: string; player?: Player; }
    | { type: 'playerLeft'; gameId?: string; playerId?: string; }
    | { type: 'gameStarted'; gameId?: string; players?: Player[]; commanderDamage?: CommanderDamage[]; }
    | { type: 'gameEnded'; gameId?: string; winner?: Player; }
    | { type: 'commanderDamageUpdate'; gameId: string; fromPlayerId: string; toPlayerId: string; commanderNumber: 1 | 2; newDamage: number; damageAmount: number; }
    | { type: 'partnerToggled'; gameId: string; playerId: string; hasPartner: boolean; }
    | { type: 'error'; message?: string; };

export type WebSocketRequest =
    | { action: 'updateLife'; playerId: string; changeAmount: number; }
    | { action: 'endGame'; }
    | { action: 'setCommanderDamage'; fromPlayerId: string; toPlayerId: string; commanderNumber: 1 | 2; newDamage: number; }
    | { action: 'updateCommanderDamage'; fromPlayerId: string; toPlayerId: string; commanderNumber: 1 | 2; damageAmount: number; }
    | { action: 'togglePartner'; playerId: string; enablePartner: boolean; };

// WebSocket utilities
export const createWebSocketUrl = (gameId: string, clerkUserId: string): string => {
    const wsUrl = API_BASE_URL.replace('http://', 'ws://').replace('https://', 'wss://');
    return `${wsUrl}/ws?gameId=${gameId}&clerkUserId=${encodeURIComponent(clerkUserId)}`;
};

export default api; 