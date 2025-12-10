"use client";

import { useEffect, useMemo, useState, useCallback } from "react";
import { useAuth } from "@clerk/nextjs";
import { Button } from "@/components/ui/button";
import {
  Dialog,
  DialogContent,
  DialogDescription,
  DialogFooter,
  DialogHeader,
  DialogTitle,
} from "@/components/ui/dialog";
import { ConclaveAPI, type GameState, type Player } from "@/lib/api";
import Image from "next/image";
import Link from "next/link";
import {
  Crown,
  Users,
  Wifi,
  WifiOff,
  Home,
  RefreshCw,
  Power,
  Sparkles,
  X,
  Share2,
  Check,
} from "lucide-react";
import { PlayerPanel } from "@/components/game";
import { GameLayout, GameContainer } from "@/components/game/game-layout";

interface GamePageClientProps {
  gameId: string;
}

type PartnerState = Record<string, boolean>;
type PoisonState = Record<string, number>;

export function GamePageClient({ gameId }: GamePageClientProps) {
  const { getToken } = useAuth();
  const api = useMemo(() => new ConclaveAPI({}), []);

  const [isConnected, setIsConnected] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [state, setState] = useState<GameState | null>(null);
  const [partnerEnabled, setPartnerEnabled] = useState<PartnerState>({});
  const [poisonCounters, setPoisonCounters] = useState<PoisonState>({});
  const [winner, setWinner] = useState<Player | null>(null);
  const [animatingLife, setAnimatingLife] = useState<Record<string, boolean>>({});
  const [showEndGameDialog, setShowEndGameDialog] = useState(false);
  const [selectedWinnerId, setSelectedWinnerId] = useState<string | null>(null);
  const [copied, setCopied] = useState(false);

  // Establish websocket connection and wire up handlers
  useEffect(() => {
    let ws: ReturnType<typeof api.connectWebSocket> | null = null;
    let cleanupFunctions: (() => void)[] = [];

    const connect = async () => {
      const token = await getToken({ template: "default" });
      if (!token) {
        setError("Not authenticated");
        return;
      }

      ws = api.connectWebSocket(gameId, token);

      const offConnect = ws.onConnect(() => {
        setIsConnected(true);
        setError(null);
        ws?.getGameState();
      });

      const offDisconnect = ws.onDisconnect(() => {
        setIsConnected(false);
      });

      const offError = ws.onError((e) => {
        setError(e.message || "WebSocket error");
      });

      const offAll = ws.on("*", (message) => {
        switch (message.type) {
          case "gameStarted": {
            const next: GameState = {
              game: message.game,
              players: message.players,
              recentChanges: message.recentChanges,
              commanderDamage: message.commanderDamage,
            };
            setState(next);
            break;
          }
          case "lifeUpdate": {
            setState((prev) => {
              if (!prev) return prev;
              const players = prev.players.map((p) =>
                p.id === message.playerId ? { ...p, currentLife: message.newLife } : p
              );
              return { ...prev, players };
            });
            // Trigger animation
            setAnimatingLife((prev) => ({ ...prev, [message.playerId]: true }));
            setTimeout(() => {
              setAnimatingLife((prev) => ({ ...prev, [message.playerId]: false }));
            }, 200);
            break;
          }
          case "playerJoined": {
            setState((prev) => {
              if (!prev) return prev;
              if (prev.players.some((p) => p.id === message.player.id)) {
                return prev;
              }
              return {
                ...prev,
                players: [...prev.players, message.player],
              };
            });
            ws?.getGameState();
            break;
          }
          case "playerLeft": {
            setState((prev) => {
              if (!prev) return prev;
              const players = prev.players.filter((p) => p.id !== message.playerId);
              const commanderDamage = prev.commanderDamage.filter(
                (cd) => cd.fromPlayerId !== message.playerId && cd.toPlayerId !== message.playerId
              );
              return { ...prev, players, commanderDamage };
            });
            ws?.getGameState();
            break;
          }
          case "commanderDamageUpdate": {
            setState((prev) => {
              if (!prev) return prev;
              const idx = prev.commanderDamage.findIndex(
                (cd) =>
                  cd.fromPlayerId === message.fromPlayerId &&
                  cd.toPlayerId === message.toPlayerId &&
                  cd.commanderNumber === message.commanderNumber
              );
              if (idx >= 0) {
                const next = [...prev.commanderDamage];
                next[idx] = { ...next[idx], damage: message.newDamage };
                return { ...prev, commanderDamage: next };
              }
              return {
                ...prev,
                commanderDamage: [
                  ...prev.commanderDamage,
                  {
                    id: `${message.fromPlayerId}-${message.toPlayerId}-${message.commanderNumber}`,
                    gameId: prev.game.id,
                    fromPlayerId: message.fromPlayerId,
                    toPlayerId: message.toPlayerId,
                    commanderNumber: message.commanderNumber,
                    damage: message.newDamage,
                    createdAt: new Date().toISOString(),
                    updatedAt: new Date().toISOString(),
                  },
                ],
              };
            });
            break;
          }
          case "partnerToggled": {
            setPartnerEnabled((prev) => ({ ...prev, [message.playerId]: message.hasPartner }));
            break;
          }
          case "gameEnded": {
            setWinner(message.winner || null);
            break;
          }
          case "error": {
            setError(message.message);
            break;
          }
        }
      });

      cleanupFunctions = [offConnect, offDisconnect, offError, offAll];
    };

    connect();

    return () => {
      cleanupFunctions.forEach((fn) => fn());
      api.disconnectWebSocket();
    };
  }, [api, gameId, getToken]);

  const changeLife = useCallback(
    (playerId: string, delta: number) => {
      api.ws?.updateLife(playerId, delta);
    },
    [api]
  );

  const changePoisonCounters = useCallback((playerId: string, delta: number) => {
    setPoisonCounters((prev) => {
      const current = prev[playerId] || 0;
      const newValue = Math.max(0, current + delta);
      return { ...prev, [playerId]: newValue };
    });
  }, []);

  const endGame = useCallback(() => {
    setShowEndGameDialog(true);
  }, []);

  const confirmEndGame = useCallback(() => {
    api.ws?.endGame(selectedWinnerId || undefined);
    setShowEndGameDialog(false);
    setSelectedWinnerId(null);
  }, [api, selectedWinnerId]);

  const changeCommanderDamage = useCallback(
    (fromId: string, toId: string, commanderNumber: number, delta: number) => {
      api.ws?.updateCommanderDamage(fromId, toId, commanderNumber, delta);
    },
    [api]
  );

  const togglePartner = useCallback(
    (playerId: string) => {
      const enabled = !!partnerEnabled[playerId];
      api.ws?.togglePartner(playerId, !enabled);
    },
    [api, partnerEnabled]
  );

  const copyGameLink = useCallback(async () => {
    const url = `${window.location.origin}/game/${gameId}`;
    try {
      await navigator.clipboard.writeText(url);
      setCopied(true);
      setTimeout(() => setCopied(false), 2000);
    } catch {
      // Fallback for older browsers
      const input = document.createElement("input");
      input.value = url;
      document.body.appendChild(input);
      input.select();
      document.execCommand("copy");
      document.body.removeChild(input);
      setCopied(true);
      setTimeout(() => setCopied(false), 2000);
    }
  }, [gameId]);

  if (error) {
    return (
      <div className="min-h-screen bg-gradient-mesh flex items-center justify-center p-4">
        <div className="glass-card rounded-2xl p-8 max-w-md w-full text-center animate-fade-in-up">
          <div className="w-16 h-16 mx-auto mb-6 rounded-full bg-red-500/20 flex items-center justify-center">
            <X className="w-8 h-8 text-red-400" />
          </div>
          <h2 className="text-2xl font-bold mb-3">Connection Error</h2>
          <p className="text-muted-foreground mb-6">{error}</p>
          <div className="flex gap-3 justify-center">
            <Button asChild variant="outline">
              <Link href="/">
                <Home className="w-4 h-4 mr-2" />
                Go Home
              </Link>
            </Button>
            <Button onClick={() => window.location.reload()}>
              <RefreshCw className="w-4 h-4 mr-2" />
              Retry
            </Button>
          </div>
        </div>
      </div>
    );
  }

  return (
    <div className="min-h-screen min-h-dvh bg-gradient-mesh flex flex-col">
      {/* Header Bar - Compact */}
      <header className="glass border-b border-white/10 sticky top-0 z-50 shrink-0">
        <div className="px-3 py-2 md:px-4 md:py-3 flex items-center justify-between">
          <div className="flex items-center gap-3">
            <Link
              href="/"
              className="p-2 rounded-lg hover:bg-white/10 transition-colors"
              title="Back to Dashboard"
            >
              <Home className="w-5 h-5" />
            </Link>
            <div className="hidden sm:block">
              <h1 className="text-sm font-bold flex items-center gap-2">
                Game #{gameId.slice(0, 8)}
                {winner && (
                  <span className="text-xs px-2 py-0.5 rounded-full bg-amber-500/20 text-amber-400 font-medium">
                    Finished
                  </span>
                )}
              </h1>
              <div className="flex items-center gap-3 text-xs text-muted-foreground">
                <span className="flex items-center gap-1">
                  {isConnected ? (
                    <>
                      <Wifi className="w-3 h-3 text-emerald-400" />
                      <span className="text-emerald-400">Live</span>
                    </>
                  ) : (
                    <>
                      <WifiOff className="w-3 h-3 text-red-400" />
                      <span className="text-red-400">Connecting...</span>
                    </>
                  )}
                </span>
                <span className="flex items-center gap-1">
                  <Users className="w-3 h-3" />
                  {state?.players.length || 0}
                </span>
              </div>
            </div>
            {/* Mobile: Just show connection status */}
            <div className="sm:hidden flex items-center gap-2">
              {isConnected ? (
                <Wifi className="w-4 h-4 text-emerald-400" />
              ) : (
                <WifiOff className="w-4 h-4 text-red-400" />
              )}
              <span className="flex items-center gap-1 text-xs text-muted-foreground">
                <Users className="w-3 h-3" />
                {state?.players.length || 0}
              </span>
            </div>
          </div>
          <div className="flex items-center gap-1 md:gap-2">
            <Button
              variant="ghost"
              size="sm"
              onClick={copyGameLink}
              className="text-muted-foreground hover:text-foreground h-8 px-2 md:px-3"
              title="Copy game link"
            >
              {copied ? (
                <Check className="w-4 h-4 text-emerald-400" />
              ) : (
                <Share2 className="w-4 h-4" />
              )}
              <span className="hidden md:inline ml-1">Share</span>
            </Button>
            <Button
              variant="ghost"
              size="sm"
              onClick={() => api.ws?.getGameState()}
              disabled={!isConnected}
              className="text-muted-foreground hover:text-foreground h-8 px-2"
              title="Refresh game state"
            >
              <RefreshCw className="w-4 h-4" />
            </Button>
            <Button
              variant="ghost"
              size="sm"
              onClick={endGame}
              disabled={!isConnected || !state || state.game.status === "finished"}
              className="text-red-400 hover:text-red-300 hover:bg-red-500/10 h-8 px-2 md:px-3"
            >
              <Power className="w-4 h-4" />
              <span className="hidden md:inline ml-1">End</span>
            </Button>
          </div>
        </div>
      </header>

      {/* Winner Banner */}
      {winner && (
        <div className="bg-gradient-to-r from-amber-500/20 via-yellow-500/20 to-amber-500/20 border-b border-amber-500/30 animate-fade-in-up shrink-0">
          <div className="px-4 py-3 flex items-center justify-center gap-3">
            <Crown className="w-5 h-5 text-amber-400" />
            <span className="text-sm font-semibold">
              <span className="text-amber-400">{winner.displayName}</span> wins with{" "}
              <span className="text-amber-400">{winner.currentLife}</span> life!
            </span>
            <Crown className="w-5 h-5 text-amber-400" />
          </div>
        </div>
      )}

      {/* Main Content */}
      <GameContainer hasWinnerBanner={!!winner}>
        {!state ? (
          <div className="flex items-center justify-center h-full">
            <div className="text-center">
              <div className="w-16 h-16 mx-auto mb-6 rounded-full bg-primary/20 animate-pulse flex items-center justify-center">
                <Sparkles className="w-8 h-8 text-primary" />
              </div>
              <p className="text-lg text-muted-foreground">Loading game...</p>
            </div>
          </div>
        ) : (
          <GameLayout playerCount={state.players.length}>
            {state.players.map((player, index) => (
              <PlayerPanel
                key={player.id}
                player={player}
                playerIndex={index}
                allPlayers={state.players}
                commanderDamage={state.commanderDamage}
                partnerEnabled={partnerEnabled}
                poisonCounters={poisonCounters[player.id] || 0}
                isWinner={winner?.id === player.id}
                isConnected={isConnected}
                isAnimating={animatingLife[player.id]}
                playerCount={state.players.length}
                onLifeChange={(delta) => changeLife(player.id, delta)}
                onPoisonChange={(delta) => changePoisonCounters(player.id, delta)}
                onCommanderDamageChange={changeCommanderDamage}
                onPartnerToggle={() => togglePartner(player.id)}
              />
            ))}
          </GameLayout>
        )}
      </GameContainer>

      {/* End Game Dialog */}
      <Dialog open={showEndGameDialog} onOpenChange={setShowEndGameDialog}>
        <DialogContent>
          <DialogHeader>
            <DialogTitle>End Game</DialogTitle>
            <DialogDescription>
              Select the winner of this game, or choose &quot;No winner&quot; if the game was not
              completed.
            </DialogDescription>
          </DialogHeader>
          <div className="py-4">
            <div className="space-y-2">
              <Button
                variant={selectedWinnerId === null ? "default" : "outline"}
                className="w-full justify-start"
                onClick={() => setSelectedWinnerId(null)}
              >
                No winner (game not completed)
              </Button>
              {(state?.players || []).map((player) => (
                <Button
                  key={player.id}
                  variant={selectedWinnerId === player.id ? "default" : "outline"}
                  className="w-full justify-start"
                  onClick={() => setSelectedWinnerId(player.id)}
                >
                  <div className="flex items-center gap-2">
                    {player.imageUrl && (
                      <Image
                        src={player.imageUrl}
                        alt={player.displayName}
                        width={20}
                        height={20}
                        className="rounded-full"
                      />
                    )}
                    <span>
                      P{player.position}: {player.displayName} ({player.currentLife} life)
                    </span>
                  </div>
                </Button>
              ))}
            </div>
          </div>
          <DialogFooter>
            <Button variant="outline" onClick={() => setShowEndGameDialog(false)}>
              Cancel
            </Button>
            <Button variant="destructive" onClick={confirmEndGame}>
              End Game
            </Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>
    </div>
  );
}
