import type {
  Game,
  GameState,
  GameHistory,
  GameWithUsers,
  GameEndResult,
  LifeChange,
  CommanderDamage,
  CreateGameRequest,
  JoinGameRequest,
  UpdateLifeRequest,
  UpdateCommanderDamageRequest,
  TogglePartnerRequest,
  Player,
} from "./types";

export interface HttpClientConfig {
  baseUrl: string;
  getAuthToken?: () => Promise<string | null>;
}

export class HttpClient {
  private baseUrl: string;
  private getAuthToken?: () => Promise<string | null>;

  constructor(config: HttpClientConfig) {
    this.baseUrl = config.baseUrl.replace(/\/$/, "");
    this.getAuthToken = config.getAuthToken;
  }

  private async request<T>(
    path: string,
    options: RequestInit = {}
  ): Promise<T> {
    const url = `${this.baseUrl}${path}`;

    const headers: Record<string, string> = {
      "Content-Type": "application/json",
      ...(options.headers as Record<string, string>),
    };

    if (this.getAuthToken) {
      const token = await this.getAuthToken();
      if (token) {
        headers["Authorization"] = `Bearer ${token}`;
      }
    }

    const response = await fetch(url, {
      ...options,
      headers,
    });

    if (!response.ok) {
      const errorText = await response.text();
      let errorMessage = `HTTP ${response.status}: ${response.statusText}`;

      try {
        const errorJson = JSON.parse(errorText);
        if (errorJson.error || errorJson.message) {
          errorMessage = errorJson.error || errorJson.message;
        }
      } catch {
        if (errorText) {
          errorMessage = errorText;
        }
      }

      throw new Error(errorMessage);
    }

    const contentType = response.headers.get("content-type") || "";
    if (contentType.includes("application/json")) {
      return response.json();
    }
    // No JSON body (e.g., 200 OK with empty body). Return undefined for void endpoints.
    return undefined as unknown as T;
  }

  async createGame(request: CreateGameRequest): Promise<Game> {
    return this.request<Game>("/games", {
      method: "POST",
      body: JSON.stringify(request),
    });
  }

  async joinGame(gameId: string, request: JoinGameRequest): Promise<Player> {
    return this.request<Player>(`/games/${gameId}/join`, {
      method: "POST",
      body: JSON.stringify(request),
    });
  }

  async leaveGame(gameId: string, clerkUserId: string): Promise<void> {
    // Backend expects clerkUserId in body at /games/{game_id}/leave
    const body: JoinGameRequest = { clerkUserId };
    await this.request<void>(`/games/${gameId}/leave`, {
      method: "POST",
      body: JSON.stringify(body),
    });
  }

  async getGame(gameId: string): Promise<Game> {
    return this.request<Game>(`/games/${gameId}`);
  }

  async getGameState(gameId: string): Promise<GameState> {
    return this.request<GameState>(`/games/${gameId}/state`);
  }

  async getUserGames(clerkUserId: string): Promise<GameWithUsers[]> {
    return this.request<GameWithUsers[]>(`/users/${clerkUserId}/games`);
  }

  async getAvailableGames(clerkUserId: string): Promise<GameWithUsers[]> {
    return this.request<GameWithUsers[]>(`/users/${clerkUserId}/available-games`);
  }

  async updateLife(
    gameId: string,
    request: UpdateLifeRequest
  ): Promise<Player> {
    return this.request<Player>(`/games/${gameId}/update-life`, {
      method: "PUT",
      body: JSON.stringify(request),
    });
  }

  async endGame(gameId: string): Promise<Game> {
    return this.request<Game>(`/games/${gameId}/end`, {
      method: "PUT",
    });
  }

  async getUserHistory(clerkUserId: string): Promise<GameHistory> {
    return this.request<GameHistory>(`/users/${clerkUserId}/history`);
  }

  async getRecentLifeChanges(
    gameId: string,
    limit: number = 10
  ): Promise<LifeChange[]> {
    return this.request<LifeChange[]>(
      `/games/${gameId}/life-changes?limit=${limit}`
    );
  }

  async updateCommanderDamage(
    gameId: string,
    request: UpdateCommanderDamageRequest
  ): Promise<CommanderDamage> {
    return this.request<CommanderDamage>(`/games/${gameId}/commander-damage`, {
      method: "PUT",
      body: JSON.stringify(request),
    });
  }

  async togglePartner(
    gameId: string,
    request: TogglePartnerRequest
  ): Promise<void> {
    await this.request<void>(`/games/${gameId}/players/${request.playerId}/partner`, {
      method: "POST",
      body: JSON.stringify(request),
    });
  }

  async healthCheck(): Promise<{ status: string; service: string }> {
    return this.request<{ status: string; service: string }>("/health");
  }

  async getStats(): Promise<{
    activeGames: number;
    service: string;
  }> {
    return this.request("/stats");
  }
}