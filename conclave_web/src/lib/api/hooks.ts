import { useEffect, useRef, useState, useCallback } from "react";
import { ConclaveAPI, createClient } from "./index";
import type { ConclaveAPIConfig, WebSocketMessage, GameState } from "./index";

export interface UseConclaveOptions extends ConclaveAPIConfig {
  autoConnect?: boolean;
  gameId?: string;
  /**
   * Function to get a fresh JWT token. Called on initial connection and before
   * each reconnection to ensure the token is valid for long-lived connections.
   */
  getToken?: () => Promise<string>;
}

export interface ConclaveState {
  api: ConclaveAPI;
  isConnected: boolean;
  gameState: GameState | null;
  lastMessage: WebSocketMessage | null;
  error: Error | null;
}

export function useConclave(options: UseConclaveOptions = {}): ConclaveState {
  const [isConnected, setIsConnected] = useState(false);
  const [gameState, setGameState] = useState<GameState | null>(null);
  const [lastMessage, setLastMessage] = useState<WebSocketMessage | null>(null);
  const [error, setError] = useState<Error | null>(null);

  const apiRef = useRef<ConclaveAPI | null>(null);

  if (!apiRef.current) {
    apiRef.current = createClient({
      httpUrl: options.httpUrl,
      wsUrl: options.wsUrl,
      getAuthToken: options.getAuthToken,
    });
  }

  useEffect(() => {
    const api = apiRef.current!;

    if (options.autoConnect !== false && options.gameId && options.getToken) {
      const ws = api.connectWebSocket(options.gameId, options.getToken);

      const unsubConnect = ws.onConnect(() => {
        setIsConnected(true);
        setError(null);
        ws.getGameState();
      });

      const unsubDisconnect = ws.onDisconnect(() => {
        setIsConnected(false);
      });

      const unsubError = ws.onError((err) => {
        setError(err);
      });

      const unsubMessage = ws.on("*", (message) => {
        setLastMessage(message);

        if (message.type === "gameStarted") {
          setGameState({
            game: message.game,
            players: message.players,
            recentChanges: message.recentChanges,
            commanderDamage: message.commanderDamage,
          });
        }
      });

      return () => {
        unsubConnect();
        unsubDisconnect();
        unsubError();
        unsubMessage();
        api.disconnectWebSocket();
      };
    }
  }, [options.gameId, options.getToken, options.autoConnect]);

  return {
    api: apiRef.current!,
    isConnected,
    gameState,
    lastMessage,
    error,
  };
}

export function useGameState(gameId: string | undefined) {
  const [gameState, setGameState] = useState<GameState | null>(null);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<Error | null>(null);

  const fetchGameState = useCallback(async (api: ConclaveAPI) => {
    if (!gameId) return;

    setLoading(true);
    setError(null);

    try {
      const state = await api.http.getGameState(gameId);
      setGameState(state);
    } catch (err) {
      setError(err as Error);
    } finally {
      setLoading(false);
    }
  }, [gameId]);

  return {
    gameState,
    loading,
    error,
    refetch: fetchGameState,
  };
}