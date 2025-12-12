import { HttpClient } from "./http-client";
import { WebSocketClient } from "./websocket-client";
import type { WebSocketEventHandler, ConnectionEventHandler, ErrorEventHandler } from "./websocket-client";

export * from "./types";
export { HttpClient } from "./http-client";
export { WebSocketClient } from "./websocket-client";

export interface ConclaveAPIConfig {
  httpUrl?: string;
  wsUrl?: string;
  getAuthToken?: () => Promise<string | null>;
}

export class ConclaveAPI {
  public readonly http: HttpClient;
  private wsClient: WebSocketClient | null = null;
  private config: ConclaveAPIConfig;

  constructor(config: ConclaveAPIConfig = {}) {
    this.config = config;

    const baseHttp = config.httpUrl || process.env.NEXT_PUBLIC_API_URL || "http://localhost:3001";
    // Ensure we point to API v1 by default
    const httpUrl = /\/api\//.test(baseHttp) ? baseHttp : `${baseHttp.replace(/\/$/, "")}/api/v1`;

    this.http = new HttpClient({
      baseUrl: httpUrl,
      getAuthToken: config.getAuthToken,
    });
  }

  /**
   * Connect to WebSocket for real-time game updates
   * @param gameId - The game ID to connect to
   * @param getToken - Function to get a fresh JWT token (called on connect and reconnect)
   */
  connectWebSocket(gameId: string, getToken: () => Promise<string>): WebSocketClient {
    if (this.wsClient) {
      this.wsClient.disconnect();
    }

    const httpBase = this.config.httpUrl || process.env.NEXT_PUBLIC_API_URL || "http://localhost:3001";
    let wsUrl = this.config.wsUrl;
    if (!wsUrl) {
      try {
        const parsed = new URL(httpBase);
        parsed.protocol = parsed.protocol.startsWith("https") ? "wss:" : "ws:";
        parsed.pathname = "/ws";
        parsed.search = "";
        parsed.hash = "";
        wsUrl = parsed.toString();
      } catch {
        wsUrl = httpBase.replace(/^http/, "ws").replace(/\/$/, "") + "/ws";
      }
    }

    this.wsClient = new WebSocketClient({
      url: wsUrl,
      gameId,
      getToken,
    });

    this.wsClient.connect();
    return this.wsClient;
  }

  disconnectWebSocket(): void {
    if (this.wsClient) {
      this.wsClient.disconnect();
      this.wsClient = null;
    }
  }

  get ws(): WebSocketClient | null {
    return this.wsClient;
  }

  onWebSocketMessage(event: string, handler: WebSocketEventHandler): () => void {
    if (!this.wsClient) {
      throw new Error("WebSocket not connected. Call connectWebSocket first.");
    }
    return this.wsClient.on(event, handler);
  }

  onWebSocketConnect(handler: ConnectionEventHandler): () => void {
    if (!this.wsClient) {
      throw new Error("WebSocket not connected. Call connectWebSocket first.");
    }
    return this.wsClient.onConnect(handler);
  }

  onWebSocketDisconnect(handler: ConnectionEventHandler): () => void {
    if (!this.wsClient) {
      throw new Error("WebSocket not connected. Call connectWebSocket first.");
    }
    return this.wsClient.onDisconnect(handler);
  }

  onWebSocketError(handler: ErrorEventHandler): () => void {
    if (!this.wsClient) {
      throw new Error("WebSocket not connected. Call connectWebSocket first.");
    }
    return this.wsClient.onError(handler);
  }
}

let defaultClient: ConclaveAPI | null = null;

export function getDefaultClient(config?: ConclaveAPIConfig): ConclaveAPI {
  if (!defaultClient) {
    defaultClient = new ConclaveAPI(config);
  }
  return defaultClient;
}

export function createClient(config?: ConclaveAPIConfig): ConclaveAPI {
  return new ConclaveAPI(config);
}