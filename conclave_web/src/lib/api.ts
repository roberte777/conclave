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
    starting_life: number;
    created_at: string;
    finished_at?: string;
}

export interface UserInfo {
    clerk_user_id: string;
}

export interface GameWithUsers {
    game: Game;
    users: UserInfo[];
}

export interface Player {
    id: string;
    game_id: string;
    clerk_user_id: string;
    current_life: number;
    position: number;
    is_eliminated: boolean;
}

export interface LifeChange {
    id: string;
    game_id: string;
    player_id: string;
    change_amount: number;
    new_life_total: number;
    created_at: string;
}

export interface GameState {
    game: Game;
    players: Player[];
    recent_changes: LifeChange[];
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
    starting_life?: number;
    clerk_user_id: string;
}

export interface JoinGameRequest {
    clerk_user_id: string;
}

export interface UpdateLifeRequest {
    player_id: string;
    change_amount: number;
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

    getStats: async (): Promise<{ active_games: number; service: string }> => {
        const response = await api.get('/stats');
        return response.data;
    },
};

// WebSocket utilities
export const createWebSocketUrl = (gameId: string, clerkUserId: string): string => {
    const wsUrl = API_BASE_URL.replace('http://', 'ws://').replace('https://', 'wss://');
    return `${wsUrl}/ws?game_id=${gameId}&clerk_user_id=${encodeURIComponent(clerkUserId)}`;
};

export default api; 