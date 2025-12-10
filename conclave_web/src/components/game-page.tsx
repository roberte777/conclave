"use client";

import { useEffect, useMemo, useState, useCallback } from "react";
import { useAuth } from "@clerk/nextjs";
import { Button } from "@/components/ui/button";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { ConclaveAPI, type GameState, type Player } from "@/lib/api";
import Image from "next/image";
import { Swords } from "lucide-react";

interface GamePageClientProps {
    gameId: string;
}

type PartnerState = Record<string, boolean>;

export function GamePageClient({ gameId }: GamePageClientProps) {
    const { getToken } = useAuth();
    const api = useMemo(() => new ConclaveAPI({}), []);

    const [isConnected, setIsConnected] = useState(false);
    const [error, setError] = useState<string | null>(null);
    const [state, setState] = useState<GameState | null>(null);
    const [partnerEnabled, setPartnerEnabled] = useState<PartnerState>({});
    const [winner, setWinner] = useState<Player | null>(null);
    const [showIncomingDamage, setShowIncomingDamage] = useState<Record<string, boolean>>({});

    // Establish websocket connection and wire up handlers
    useEffect(() => {
        let ws: ReturnType<typeof api.connectWebSocket> | null = null;
        let cleanupFunctions: (() => void)[] = [];

        const connect = async () => {
            // Get JWT token for authentication
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
                        // No need to fetch display names - they come from the backend now!
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
                        break;
                    }
                    case "playerJoined": {
                        // Add the new player directly - they come with display info!
                        setState((prev) => {
                            if (!prev) return prev;
                            // Check if player already exists
                            if (prev.players.some(p => p.id === message.player.id)) {
                                return prev;
                            }
                            return {
                                ...prev,
                                players: [...prev.players, message.player],
                            };
                        });
                        // Refresh full state to sync commander damage matrix
                        ws?.getGameState();
                        break;
                    }
                    case "playerLeft": {
                        // Optimistically remove player and refresh to sync damage matrix
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
            cleanupFunctions.forEach(fn => fn());
            api.disconnectWebSocket();
        };
    }, [api, gameId, getToken]);

    const changeLife = useCallback(
        (playerId: string, delta: number) => {
            api.ws?.updateLife(playerId, delta);
        },
        [api]
    );

    const endGame = useCallback(() => {
        api.ws?.endGame();
    }, [api]);

    const getCommanderDamage = useCallback(
        (fromId: string, toId: string, commanderNumber: number) => {
            if (!state) return 0;
            return (
                state.commanderDamage.find(
                    (cd) =>
                        cd.fromPlayerId === fromId &&
                        cd.toPlayerId === toId &&
                        cd.commanderNumber === commanderNumber
                )?.damage || 0
            );
        },
        [state]
    );

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

    if (error) {
        return (
            <div className="container mx-auto px-4 py-8">
                <Card>
                    <CardHeader>
                        <CardTitle>Error</CardTitle>
                    </CardHeader>
                    <CardContent>
                        <p className="text-red-500">{error}</p>
                    </CardContent>
                </Card>
            </div>
        );
    }

    return (
        <div className="container mx-auto px-4 py-8">
            <div className="flex items-center justify-between mb-6">
                <div>
                    <h1 className="text-2xl font-bold">{state?.game.name || "Game"}</h1>
                    <p className="text-sm text-muted-foreground">
                        {isConnected ? "Connected" : "Connecting..."} • ID: {gameId}
                    </p>
                </div>
                <div className="flex items-center gap-2">
                    <Button variant="outline" onClick={() => api.ws?.getGameState()} disabled={!isConnected}>
                        Refresh State
                    </Button>
                    <Button variant="destructive" onClick={endGame} disabled={!isConnected || !state || state.game.status === "finished"}>
                        End Game
                    </Button>
                </div>
            </div>

            {winner && (
                <Card className="mb-6">
                    <CardHeader>
                        <CardTitle>Game Ended</CardTitle>
                    </CardHeader>
                    <CardContent>
                        <p>
                            Winner: <span className="font-semibold">{winner.displayName}</span> with {winner.currentLife} life
                        </p>
                    </CardContent>
                </Card>
            )}

            <div className="grid gap-4 md:grid-cols-2 lg:grid-cols-3">
                {(state?.players || []).map((p) => (
                    <Card key={p.id}>
                        <CardHeader>
                            <CardTitle className="flex items-center justify-between">
                                <span className="flex items-center gap-2 min-w-0">
                                    {p.imageUrl ? (
                                        <Image
                                            src={p.imageUrl}
                                            alt={p.displayName}
                                            width={20}
                                            height={20}
                                            className="rounded-full"
                                        />
                                    ) : null}
                                    <span className="truncate max-w-[160px]">
                                        P{p.position}: {p.displayName}
                                    </span>
                                </span>
                                <div className="flex items-center gap-2">
                                    <Button
                                        size="icon"
                                        variant={showIncomingDamage[p.id] ? "default" : "outline"}
                                        className="h-8 w-8"
                                        onClick={() =>
                                            setShowIncomingDamage((prev) => ({ ...prev, [p.id]: !prev[p.id] }))
                                        }
                                        disabled={!isConnected}
                                        title={showIncomingDamage[p.id] ? "Hide commander damage" : "Show commander damage"}
                                    >
                                        <Swords className="h-4 w-4" />
                                    </Button>
                                    <Button size="sm" variant={partnerEnabled[p.id] ? "default" : "outline"} onClick={() => togglePartner(p.id)} disabled={!isConnected}>
                                        {partnerEnabled[p.id] ? "Partner On" : "Partner Off"}
                                    </Button>
                                </div>
                            </CardTitle>
                        </CardHeader>
                        <CardContent>
                            <div className="flex items-center justify-between">
                                <div>
                                    <div className="text-4xl font-bold leading-none">{p.currentLife}</div>
                                    <div className="text-sm text-muted-foreground">Life</div>
                                </div>
                                <div className="flex gap-2">
                                    <div className="flex flex-col gap-2">
                                        <Button size="sm" onClick={() => changeLife(p.id, +1)} disabled={!isConnected}>
                                            +1
                                        </Button>
                                        <Button size="sm" onClick={() => changeLife(p.id, +5)} disabled={!isConnected}>
                                            +5
                                        </Button>
                                    </div>
                                    <div className="flex flex-col gap-2">
                                        <Button size="sm" variant="secondary" onClick={() => changeLife(p.id, -1)} disabled={!isConnected}>
                                            -1
                                        </Button>
                                        <Button size="sm" variant="secondary" onClick={() => changeLife(p.id, -5)} disabled={!isConnected}>
                                            -5
                                        </Button>
                                    </div>
                                </div>
                            </div>

                            {/* Commander damage (incoming) - hidden by default and toggled via swords icon */}
                            {state && state.players.length > 1 && showIncomingDamage[p.id] ? (
                                <div className="mt-4">
                                    <div className="text-sm font-medium mb-2">Incoming commander damage</div>
                                    <div className="flex gap-3 overflow-x-auto">
                                        {state.players
                                            .filter((from) => from.id !== p.id)
                                            .map((from) => (
                                                <div key={from.id} className="border rounded-md p-2 min-w-[160px]">
                                                    <div className="text-xs mb-1">from P{from.position}</div>
                                                    {[1, ...(partnerEnabled[from.id] ? [2] : [])].map((cmd) => (
                                                        <div key={cmd} className="flex items-center justify-between gap-2">
                                                            <span className="text-xs">
                                                                C{cmd}: {getCommanderDamage(from.id, p.id, cmd)}
                                                            </span>
                                                            <div className="flex gap-1">
                                                                <Button
                                                                    size="icon"
                                                                    variant="secondary"
                                                                    className="h-7 w-7"
                                                                    onClick={() => changeCommanderDamage(from.id, p.id, cmd, -1)}
                                                                    disabled={!isConnected}
                                                                >
                                                                    -
                                                                </Button>
                                                                <Button
                                                                    size="icon"
                                                                    className="h-7 w-7"
                                                                    onClick={() => changeCommanderDamage(from.id, p.id, cmd, +1)}
                                                                    disabled={!isConnected}
                                                                >
                                                                    +
                                                                </Button>
                                                            </div>
                                                        </div>
                                                    ))}
                                                </div>
                                            ))}
                                    </div>
                                </div>
                            ) : null}
                        </CardContent>
                    </Card>
                ))}
            </div>
        </div>
    );
}


