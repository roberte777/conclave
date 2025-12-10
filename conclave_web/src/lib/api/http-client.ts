import type {
  Game,
  GameState,
  GameHistory,
  GameWithUsers,
  LifeChange,
  CommanderDamage,
  CreateGameRequest,
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

  async joinGame(gameId: string): Promise<Player> {
    // clerkUserId now comes from JWT token in Authorization header
    return this.request<Player>(`/games/${gameId}/join`, {
      method: "POST",
    });
  }

  async leaveGame(gameId: string): Promise<void> {
    // clerkUserId now comes from JWT token in Authorization header
    await this.request<void>(`/games/${gameId}/leave`, {
      method: "POST",
    });
  }

  async getGame(gameId: string): Promise<Game> {
    return this.request<Game>(`/games/${gameId}`);
  }

  async getGameState(gameId: string): Promise<GameState> {
    return this.request<GameState>(`/games/${gameId}/state`);
  }

  async getUserGames(): Promise<GameWithUsers[]> {
    // Uses /users/me/ endpoint - clerkUserId comes from JWT
    return this.request<GameWithUsers[]>(`/users/me/games`);
  }

  async getAvailableGames(): Promise<GameWithUsers[]> {
    // Uses /users/me/ endpoint - clerkUserId comes from JWT
    return this.request<GameWithUsers[]>(`/users/me/available-games`);
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

  async endGame(gameId: string, request: { winnerPlayerId?: string }): Promise<Game> {
    return this.request<Game>(`/games/${gameId}/end`, {
      method: "PUT",
      body: JSON.stringify(request),
    });
  }

  async getUserHistory(): Promise<GameHistory> {
    // Uses /users/me/ endpoint - clerkUserId comes from JWT
    return this.request<GameHistory>(`/users/me/history`);
  }

  async getUserHistoryWithPod(podUserIds: string[]): Promise<GameHistory> {
    // Uses /users/me/history/pod/ endpoint - clerkUserId comes from JWT
    // podUserIds is an array of clerk user IDs to filter by (the "pod")
    const podFilter = podUserIds.join(',');
    return this.request<GameHistory>(`/users/me/history/pod/${encodeURIComponent(podFilter)}`);
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