import type { WebSocketMessage, WebSocketRequest } from "./types";

export type WebSocketEventHandler = (message: WebSocketMessage) => void;
export type ConnectionEventHandler = () => void;
export type ErrorEventHandler = (error: Error) => void;

export interface WebSocketClientConfig {
  url: string;
  gameId: string;
  /** JWT token for authentication */
  token: string;
  reconnectInterval?: number;
  maxReconnectAttempts?: number;
  /**
   * Mobile browsers (especially iOS Safari) routinely suspend/kill WebSockets when the tab is
   * backgrounded. When enabled, we pause reconnection attempts while hidden and reconnect
   * immediately when the page becomes visible again.
   */
  pauseReconnectWhileHidden?: boolean;
}

export class WebSocketClient {
  private ws: WebSocket | null = null;
  private config: Required<WebSocketClientConfig>;
  private eventHandlers: Map<string, Set<WebSocketEventHandler>> = new Map();
  private connectionHandlers: Set<ConnectionEventHandler> = new Set();
  private disconnectionHandlers: Set<ConnectionEventHandler> = new Set();
  private errorHandlers: Set<ErrorEventHandler> = new Set();
  private reconnectAttempts = 0;
  private reconnectTimeout: ReturnType<typeof setTimeout> | null = null;
  private isIntentionallyClosed = false;
  private messageQueue: WebSocketRequest[] = [];
  private shouldReconnectOnVisible = false;
  private visibilityListenerInstalled = false;
  private handleVisibilityChangeBound = () => this.handleVisibilityChange();

  constructor(config: WebSocketClientConfig) {
    this.config = {
      reconnectInterval: 3000,
      maxReconnectAttempts: 10,
      pauseReconnectWhileHidden: true,
      ...config,
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

    if (this.config.pauseReconnectWhileHidden && this.isPageHidden()) {
      // Defer connecting until the page becomes visible again.
      this.shouldReconnectOnVisible = true;
      this.ensureVisibilityListener();
      return;
    }

    const wsUrl = new URL(this.config.url);
    // Server expects camelCase query params per serde rename_all = "camelCase"
    wsUrl.searchParams.set("gameId", this.config.gameId);
    // Pass JWT token for authentication instead of clerkUserId
    wsUrl.searchParams.set("token", this.config.token);

    try {
      this.ws = new WebSocket(wsUrl.toString());
      this.setupEventListeners();
      this.ensureVisibilityListener();
    } catch (error) {
      this.handleError(error as Error);
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
        if (this.config.pauseReconnectWhileHidden && this.isPageHidden()) {
          // Mobile browsers may close sockets when backgrounded; don't treat this as a failure.
          this.shouldReconnectOnVisible = true;
          this.ensureVisibilityListener();
          return;
        }
        this.attemptReconnect();
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

  private attemptReconnect(): void {
    if (this.config.pauseReconnectWhileHidden && this.isPageHidden()) {
      this.shouldReconnectOnVisible = true;
      this.ensureVisibilityListener();
      return;
    }

    if (this.reconnectAttempts >= this.config.maxReconnectAttempts) {
      console.error("Max reconnection attempts reached");
      this.handleError(new Error("Failed to reconnect to WebSocket"));
      return;
    }

    this.reconnectAttempts++;
    console.log(
      `Attempting to reconnect (${this.reconnectAttempts}/${this.config.maxReconnectAttempts})...`
    );

    this.reconnectTimeout = setTimeout(() => {
      this.connect();
    }, this.config.reconnectInterval);
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
    this.shouldReconnectOnVisible = false;

    if (this.reconnectTimeout) {
      clearTimeout(this.reconnectTimeout);
      this.reconnectTimeout = null;
    }

    if (this.ws) {
      this.ws.close();
      this.ws = null;
    }

    this.teardownVisibilityListener();
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

  private isPageHidden(): boolean {
    if (typeof document === "undefined") return false;
    return document.visibilityState === "hidden";
  }

  private ensureVisibilityListener(): void {
    if (!this.config.pauseReconnectWhileHidden) return;
    if (typeof document === "undefined") return;
    if (this.visibilityListenerInstalled) return;

    document.addEventListener("visibilitychange", this.handleVisibilityChangeBound);
    this.visibilityListenerInstalled = true;
  }

  private teardownVisibilityListener(): void {
    if (typeof document === "undefined") return;
    if (!this.visibilityListenerInstalled) return;

    document.removeEventListener("visibilitychange", this.handleVisibilityChangeBound);
    this.visibilityListenerInstalled = false;
  }

  private handleVisibilityChange(): void {
    if (!this.config.pauseReconnectWhileHidden) return;
    if (this.isIntentionallyClosed) return;
    if (this.isPageHidden()) return;

    if (this.shouldReconnectOnVisible) {
      this.shouldReconnectOnVisible = false;
      this.connect();
    }
  }
}