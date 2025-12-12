import type { WebSocketMessage, WebSocketRequest } from "./types";

export type WebSocketEventHandler = (message: WebSocketMessage) => void;
export type ConnectionEventHandler = () => void;
export type ErrorEventHandler = (error: Error) => void;

export interface WebSocketClientConfig {
  url: string;
  gameId: string;
  /**
   * Function to get a fresh JWT token. Called on initial connection and before each reconnection
   * to ensure the token is valid for long-lived connections.
   */
  getToken: () => Promise<string>;
  /** Base interval for reconnection attempts (default: 1000ms) */
  baseReconnectInterval?: number;
  /** Maximum reconnect interval after exponential backoff (default: 30000ms) */
  maxReconnectInterval?: number;
}

interface ResolvedWebSocketClientConfig {
  url: string;
  gameId: string;
  getToken: () => Promise<string>;
  baseReconnectInterval: number;
  maxReconnectInterval: number;
}

export class WebSocketClient {
  private ws: WebSocket | null = null;
  private config: ResolvedWebSocketClientConfig;
  private currentToken: string | null = null;
  private eventHandlers: Map<string, Set<WebSocketEventHandler>> = new Map();
  private connectionHandlers: Set<ConnectionEventHandler> = new Set();
  private disconnectionHandlers: Set<ConnectionEventHandler> = new Set();
  private errorHandlers: Set<ErrorEventHandler> = new Set();
  private reconnectAttempts = 0;
  private reconnectTimeout: ReturnType<typeof setTimeout> | null = null;
  private isIntentionallyClosed = false;
  private messageQueue: WebSocketRequest[] = [];

  constructor(config: WebSocketClientConfig) {
    this.config = {
      url: config.url,
      gameId: config.gameId,
      getToken: config.getToken,
      baseReconnectInterval: config.baseReconnectInterval ?? 1000,
      maxReconnectInterval: config.maxReconnectInterval ?? 30000,
    };
  }

  connect(): void {
    if (
      this.ws?.readyState === WebSocket.OPEN ||
      this.ws?.readyState === WebSocket.CONNECTING
    ) {
      return;
    }

    this.isIntentionallyClosed = false;
    this.doConnect();
  }

  private async doConnect(): Promise<void> {
    try {
      // Fetch a fresh token before each connection attempt
      this.currentToken = await this.config.getToken();

      const wsUrl = new URL(this.config.url);
      // Server expects camelCase query params per serde rename_all = "camelCase"
      wsUrl.searchParams.set("gameId", this.config.gameId);
      // Pass JWT token for authentication
      wsUrl.searchParams.set("token", this.currentToken);

      this.ws = new WebSocket(wsUrl.toString());
      this.setupEventListeners();
    } catch (error) {
      this.handleError(error as Error);
      // If token fetch failed, schedule a reconnect
      if (!this.isIntentionallyClosed) {
        this.scheduleReconnect();
      }
    }
  }

  private setupEventListeners(): void {
    if (!this.ws) return;

    this.ws.onopen = () => {
      console.log("WebSocket connected");
      this.reconnectAttempts = 0;
      this.connectionHandlers.forEach((handler) => handler());

      this.flushMessageQueue();
    };

    this.ws.onmessage = (event) => {
      try {
        const message: WebSocketMessage = JSON.parse(event.data);
        this.handleMessage(message);
      } catch (error) {
        console.error("Failed to parse WebSocket message:", error);
        this.handleError(new Error("Invalid message format"));
      }
    };

    this.ws.onclose = () => {
      console.log("WebSocket disconnected");
      this.disconnectionHandlers.forEach((handler) => handler());

      if (!this.isIntentionallyClosed) {
        this.scheduleReconnect();
      }
    };

    this.ws.onerror = (event) => {
      console.error("WebSocket error:", event);
      // Avoid surfacing generic socket errors to UI; reconnection (or visibility resume)
      // is handled via onclose/attemptReconnect.
    };
  }

  private handleMessage(message: WebSocketMessage): void {
    const handlers = this.eventHandlers.get(message.type);
    if (handlers) {
      handlers.forEach((handler) => handler(message));
    }

    const allHandlers = this.eventHandlers.get("*");
    if (allHandlers) {
      allHandlers.forEach((handler) => handler(message));
    }

    if (message.type === "error") {
      this.handleError(new Error(message.message));
    }
  }

  private handleError(error: Error): void {
    this.errorHandlers.forEach((handler) => handler(error));
  }

  /**
   * Calculate the next reconnect delay using exponential backoff with jitter.
   * Formula: min(maxInterval, baseInterval * 2^attempts) + random jitter
   */
  private calculateReconnectDelay(): number {
    const { baseReconnectInterval, maxReconnectInterval } = this.config;

    // Exponential backoff: base * 2^attempts
    const exponentialDelay = baseReconnectInterval * Math.pow(2, this.reconnectAttempts);

    // Cap at max interval
    const cappedDelay = Math.min(exponentialDelay, maxReconnectInterval);

    // Add jitter: random value between 0 and 50% of the delay
    const jitter = Math.random() * cappedDelay * 0.5;

    return cappedDelay + jitter;
  }

  private scheduleReconnect(): void {
    if (this.reconnectTimeout) {
      clearTimeout(this.reconnectTimeout);
    }

    const delay = this.calculateReconnectDelay();
    this.reconnectAttempts++;

    console.log(
      `Scheduling reconnect attempt ${this.reconnectAttempts} in ${Math.round(delay)}ms...`
    );

    this.reconnectTimeout = setTimeout(() => {
      this.doConnect();
    }, delay);
  }

  private flushMessageQueue(): void {
    while (this.messageQueue.length > 0) {
      const message = this.messageQueue.shift();
      if (message) {
        this.send(message);
      }
    }
  }

  disconnect(): void {
    this.isIntentionallyClosed = true;

    if (this.reconnectTimeout) {
      clearTimeout(this.reconnectTimeout);
      this.reconnectTimeout = null;
    }

    if (this.ws) {
      this.ws.close();
      this.ws = null;
    }

    this.reconnectAttempts = 0;
  }

  send(request: WebSocketRequest): void {
    if (!this.ws || this.ws.readyState !== WebSocket.OPEN) {
      console.log("WebSocket not connected, queueing message");
      this.messageQueue.push(request);
      return;
    }

    try {
      this.ws.send(JSON.stringify(request));
    } catch (error) {
      console.error("Failed to send WebSocket message:", error);
      this.handleError(error as Error);
    }
  }

  on(event: string, handler: WebSocketEventHandler): () => void {
    if (!this.eventHandlers.has(event)) {
      this.eventHandlers.set(event, new Set());
    }
    this.eventHandlers.get(event)!.add(handler);

    return () => {
      const handlers = this.eventHandlers.get(event);
      if (handlers) {
        handlers.delete(handler);
      }
    };
  }

  onConnect(handler: ConnectionEventHandler): () => void {
    this.connectionHandlers.add(handler);
    return () => this.connectionHandlers.delete(handler);
  }

  onDisconnect(handler: ConnectionEventHandler): () => void {
    this.disconnectionHandlers.add(handler);
    return () => this.disconnectionHandlers.delete(handler);
  }

  onError(handler: ErrorEventHandler): () => void {
    this.errorHandlers.add(handler);
    return () => this.errorHandlers.delete(handler);
  }

  updateLife(playerId: string, changeAmount: number): void {
    this.send({
      action: "updateLife",
      playerId,
      changeAmount,
    });
  }

  // joinGame is no longer needed - auto-join happens on WebSocket connection with JWT

  leaveGame(playerId: string): void {
    this.send({
      action: "leaveGame",
      playerId,
    });
  }

  getGameState(): void {
    this.send({
      action: "getGameState",
    });
  }

  endGame(winnerPlayerId?: string): void {
    this.send({
      action: "endGame",
      winnerPlayerId,
    });
  }

  setCommanderDamage(
    fromPlayerId: string,
    toPlayerId: string,
    commanderNumber: number,
    newDamage: number
  ): void {
    this.send({
      action: "setCommanderDamage",
      fromPlayerId,
      toPlayerId,
      commanderNumber,
      newDamage,
    });
  }

  updateCommanderDamage(
    fromPlayerId: string,
    toPlayerId: string,
    commanderNumber: number,
    damageAmount: number
  ): void {
    this.send({
      action: "updateCommanderDamage",
      fromPlayerId,
      toPlayerId,
      commanderNumber,
      damageAmount,
    });
  }

  togglePartner(playerId: string, enablePartner: boolean): void {
    this.send({
      action: "togglePartner",
      playerId,
      enablePartner,
    });
  }

  get isConnected(): boolean {
    return this.ws?.readyState === WebSocket.OPEN;
  }

  get connectionState(): number {
    return this.ws?.readyState ?? WebSocket.CLOSED;
  }
}