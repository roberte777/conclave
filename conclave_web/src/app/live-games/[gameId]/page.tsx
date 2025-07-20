"use client";

import { useState, useEffect, useCallback } from "react";
import { useParams, useRouter } from "next/navigation";
import { useUser } from "@clerk/nextjs";
import useWebSocket, { ReadyState } from 'react-use-websocket';
import {
    gameApi,
    createWebSocketUrl,
    type GameState,
    type Player,
    type WebSocketMessage,
    type WebSocketRequest,
} from "@/lib/api";
import { Button } from "@/components/ui/button";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { Badge } from "@/components/ui/badge";
import { toast } from "sonner";
import {
    Heart,
    Minus,
    Plus,
    Users,
    ArrowLeft,
    LogOut,
} from "lucide-react";
import { CommanderDamageTracker } from "@/components/CommanderDamageTracker";


export default function LiveGamePage() {
    const params = useParams();
    const router = useRouter();
    const { user } = useUser();
    const gameId = params.gameId as string;

    const [gameState, setGameState] = useState<GameState | null>(null);
    const [isLoading, setIsLoading] = useState(true);
    const [connectionError, setConnectionError] = useState<string | null>(null);

    // Create WebSocket URL
    const socketUrl = user && gameId ? createWebSocketUrl(gameId, user.id) : null;

    // Use the WebSocket hook
    const { sendMessage, lastMessage, readyState } = useWebSocket(
        socketUrl,
        {
            onOpen: () => {
                console.log("WebSocket connected");
                setConnectionError(null);
            },
            onClose: (event) => {
                console.log("WebSocket disconnected", event.code, event.reason);
                if (event.code !== 1000) {
                    setConnectionError("Connection lost. Attempting to reconnect...");
                }
            },
            onError: (error) => {
                console.error("WebSocket error:", error);
                setConnectionError("Connection error");
            },
            shouldReconnect: (closeEvent) => {
                // Reconnect unless it was a normal closure
                return closeEvent.code !== 1000;
            },
            reconnectInterval: 3000,
            reconnectAttempts: 10,
        }
    );

    // Get connection status
    const connectionStatus = {
        [ReadyState.CONNECTING]: 'Connecting',
        [ReadyState.OPEN]: 'Connected',
        [ReadyState.CLOSING]: 'Closing',
        [ReadyState.CLOSED]: 'Disconnected',
        [ReadyState.UNINSTANTIATED]: 'Uninstantiated',
    }[readyState];

    const isConnected = readyState === ReadyState.OPEN;

    // Fetch initial game state and check if game is active
    useEffect(() => {
        const fetchGameState = async () => {
            if (!gameId) {
                console.error("No game ID");
                return;
            }

            try {
                const state = await gameApi.getState(gameId);

                // If game is finished, redirect to finished games page
                if (state.game.status === 'finished') {
                    router.replace(`/finished-games/${gameId}`);
                    return;
                }

                setGameState(state);
                setIsLoading(false);
            } catch (error) {
                console.error("Failed to fetch game state:", error);
                setConnectionError("Failed to load game");
                setIsLoading(false);
            }
        };

        fetchGameState();
    }, [gameId, router]);

    const handleWebSocketMessage = useCallback((message: WebSocketMessage) => {
        console.log("Received WebSocket message:", message);

        switch (message.type) {
            case "lifeUpdate":
                if (message.playerId && message.newLife !== undefined) {
                    console.log(`🔄 Processing life update for player ${message.playerId}: ${message.newLife} (change: ${message.changeAmount})`);

                    setGameState((prev) => {
                        if (!prev) {
                            console.log("❌ No previous game state, skipping update");
                            return prev;
                        }

                        console.log("📊 Previous players state:", prev.players.map(p => ({ id: p.id, life: p.currentLife, position: p.position })));

                        const updatedState = {
                            ...prev,
                            players: prev.players.map((p) => {
                                if (p.id === message.playerId) {
                                    console.log(`✅ Updating player ${p.position} (${p.id}) from ${p.currentLife} to ${message.newLife}`);
                                    return {
                                        ...p,
                                        currentLife: message.newLife!,
                                    };
                                }
                                return p;
                            }),
                        };

                        console.log("📊 Updated players state:", updatedState.players.map(p => ({ id: p.id, life: p.currentLife, position: p.position })));
                        return updatedState;
                    });

                    if (message.changeAmount) {
                        const changeText =
                            message.changeAmount > 0
                                ? `+${message.changeAmount}`
                                : `${message.changeAmount}`;
                        toast.info(`Life updated: ${changeText}`);
                    }
                } else {
                    console.log("❌ Invalid lifeUpdate message:", message);
                }
                break;

            case "playerJoined":
                if (message.player) {
                    setGameState((prev) => {
                        if (!prev) return prev;
                        const existingPlayer = prev.players.find(
                            (p) => p.id === message.player!.id,
                        );
                        if (existingPlayer) return prev;

                        return {
                            ...prev,
                            players: [...prev.players, message.player!].sort(
                                (a, b) => a.position - b.position,
                            ),
                        };
                    });
                    toast.success(`A player joined the game`);
                }
                break;

            case "playerLeft":
                if (message.playerId) {
                    setGameState((prev) => {
                        if (!prev) return prev;
                        return {
                            ...prev,
                            players: prev.players.filter((p) => p.id !== message.playerId),
                        };
                    });
                    toast.info(`A player left the game`);
                }
                break;

            case "gameEnded":
                if (message.winner) {
                    setGameState((prev) => {
                        if (!prev) return prev;
                        return {
                            ...prev,
                            game: {
                                ...prev.game,
                                status: "finished",
                            },
                        };
                    });
                    toast.success(`Game ended! Player ${message.winner.position} wins!`);
                    // Redirect to finished games page after a short delay
                    setTimeout(() => {
                        router.replace(`/finished-games/${gameId}`);
                    }, 3000);
                }
                break;

            case "gameStarted":
                if (message.players) {
                    console.log("📨 Received gameStarted message with players:", message.players);
                    setGameState((prev) => {
                        if (!prev) return prev;
                        return {
                            ...prev,
                            players: message.players!.sort((a, b) => a.position - b.position),
                            commanderDamage: message.commanderDamage || prev.commanderDamage || [],
                        };
                    });
                }
                break;

            case "commanderDamageUpdate":
                console.log("🗡️ Processing commander damage update:", message);
                setGameState((prev) => {
                    if (!prev) return prev;
                    
                    const updatedCommanderDamage = prev.commanderDamage.map((cd) => {
                        if (
                            cd.fromPlayerId === message.fromPlayerId &&
                            cd.toPlayerId === message.toPlayerId &&
                            cd.commanderNumber === message.commanderNumber
                        ) {
                            return {
                                ...cd,
                                damage: message.newDamage,
                            };
                        }
                        return cd;
                    });

                    return {
                        ...prev,
                        commanderDamage: updatedCommanderDamage,
                    };
                });
                
                const changeText = message.damageAmount > 0 
                    ? `+${message.damageAmount}` 
                    : `${message.damageAmount}`;
                toast.info(`Commander damage updated: ${changeText}`);
                break;

            case "partnerToggled":
                console.log("👥 Processing partner toggle:", message);
                setGameState((prev) => {
                    if (!prev) return prev;
                    
                    // The backend handles adding/removing commander damage entries
                    // We'll get the updated state in a subsequent message or via API
                    toast.info(`Partner ${message.hasPartner ? 'enabled' : 'disabled'}`);
                    return prev;
                });
                break;

            case "error":
                if (message.message) {
                    console.error("WebSocket error message:", message.message);
                    toast.error(`Server error: ${message.message}`);
                    setConnectionError(message.message);
                }
                break;

            default:
                console.log("Unknown message type:", message);
        }
    }, [gameId, router]);

    // Handle incoming WebSocket messages
    useEffect(() => {
        if (lastMessage !== null) {
            try {
                console.log("Raw WebSocket message received:", lastMessage.data);
                const message: WebSocketMessage = JSON.parse(lastMessage.data);
                handleWebSocketMessage(message);
            } catch (error) {
                console.error("Failed to parse WebSocket message:", error);
                console.error("Raw message data:", lastMessage.data);
            }
        }
    }, [lastMessage, handleWebSocketMessage]);

    const handleLifeChange = async (playerId: string, changeAmount: number) => {
        if (!isConnected) {
            toast.error("Not connected to game server");
            return;
        }

        try {
            const messageData: WebSocketRequest = {
                action: "updateLife",
                playerId: playerId,
                changeAmount: changeAmount,
            };

            console.log(`📤 Sending life change: ${changeAmount} for player ${playerId}`);
            // Send via WebSocket for real-time updates
            sendMessage(JSON.stringify(messageData));
        } catch (error) {
            console.error("Failed to update life:", error);
            toast.error("Failed to update life");
        }
    };

    const handleLeaveGame = async () => {
        if (!user) return;

        if (confirm("Are you sure you want to leave this game?")) {
            try {
                await gameApi.leave(gameId, { clerkUserId: user.id });
                toast.success("Left game successfully");
                router.push("/");
            } catch (error) {
                console.error("Failed to leave game:", error);
                toast.error("Failed to leave game");
            }
        }
    };

    const handleEndGame = async () => {
        if (!user) return;

        if (confirm("Are you sure you want to end this game?")) {
            try {
                const messageData: WebSocketRequest = {
                    action: "endGame",
                };

                console.log(`📤 Sending end game request for game ${gameId}`);
                sendMessage(JSON.stringify(messageData));
                toast.success("Game ending...");
                // The WebSocket will handle redirecting to finished games page
            } catch (error) {
                console.error("Failed to end game:", error);
                toast.error("Failed to end game");
            }
        }
    };

    const handleCommanderDamageUpdate = async (
        fromPlayerId: string,
        toPlayerId: string,
        commanderNumber: 1 | 2,
        damageAmount: number
    ) => {
        if (!isConnected) {
            toast.error("Not connected to game server");
            return;
        }

        try {
            const messageData: WebSocketRequest = {
                action: "updateCommanderDamage",
                fromPlayerId,
                toPlayerId,
                commanderNumber,
                damageAmount,
            };

            console.log(`📤 Sending commander damage update: ${damageAmount} from ${fromPlayerId} to ${toPlayerId} (commander ${commanderNumber})`);
            sendMessage(JSON.stringify(messageData));
        } catch (error) {
            console.error("Failed to update commander damage:", error);
            toast.error("Failed to update commander damage");
        }
    };

    const handlePartnerToggle = async (playerId: string, enablePartner: boolean) => {
        if (!isConnected) {
            toast.error("Not connected to game server");
            return;
        }

        try {
            const messageData: WebSocketRequest = {
                action: "togglePartner",
                playerId,
                enablePartner,
            };

            console.log(`📤 Sending partner toggle: ${enablePartner ? 'enable' : 'disable'} for player ${playerId}`);
            sendMessage(JSON.stringify(messageData));
        } catch (error) {
            console.error("Failed to toggle partner:", error);
            toast.error("Failed to toggle partner");
        }
    };

    const getCurrentUserPlayer = (): Player | null => {
        if (!gameState || !user) return null;
        return gameState.players.find((p) => p.clerkUserId === user.id) || null;
    };

    const isUserInGame = () => {
        return getCurrentUserPlayer() !== null;
    };

    if (isLoading) {
        return (
            <div className="container mx-auto p-6">
                <div className="text-center py-12">
                    <p className="text-muted-foreground">Loading game...</p>
                </div>
            </div>
        );
    }

    if (connectionError && !gameState) {
        return (
            <div className="container mx-auto p-6">
                <div className="text-center py-12">
                    <p className="text-red-500 mb-4">{connectionError}</p>
                    <Button onClick={() => router.push("/")}>
                        <ArrowLeft className="h-4 w-4 mr-2" />
                        Back to Dashboard
                    </Button>
                </div>
            </div>
        );
    }

    if (!gameState) {
        return (
            <div className="container mx-auto p-6">
                <div className="text-center py-12">
                    <p className="text-muted-foreground">Game not found</p>
                    <Button onClick={() => router.push("/")} className="mt-4">
                        <ArrowLeft className="h-4 w-4 mr-2" />
                        Back to Dashboard
                    </Button>
                </div>
            </div>
        );
    }

    const { game, players } = gameState;

    return (
        <div className="container mx-auto p-6 max-w-6xl">
            {/* Header */}
            <div className="mb-6">
                <div className="flex items-center justify-between mb-4">
                    <div className="flex items-center gap-4">
                        <Button
                            variant="outline"
                            size="sm"
                            onClick={() => router.push("/")}
                        >
                            <ArrowLeft className="h-4 w-4 mr-2" />
                            Back
                        </Button>
                        <div>
                            <h1 className="text-2xl font-bold">{game.name}</h1>
                            <p className="text-muted-foreground">
                                {players.length} player{players.length !== 1 ? "s" : ""} •{" "}
                                {game.startingLife} starting life • Live Game
                            </p>
                        </div>
                    </div>
                    <div className="flex items-center gap-2">
                        <Badge variant="default">Live</Badge>
                        <Badge variant={isConnected ? "default" : "destructive"}>
                            {connectionStatus}
                        </Badge>
                    </div>
                </div>

                {connectionError && (
                    <div className="bg-yellow-50 border border-yellow-200 rounded-lg p-3 mb-4">
                        <p className="text-yellow-800 text-sm">{connectionError}</p>
                    </div>
                )}

                {/* Game Controls */}
                <div className="flex items-center gap-2">
                    {isUserInGame() && (
                        <Button variant="outline" size="sm" onClick={handleLeaveGame}>
                            <LogOut className="h-4 w-4 mr-2" />
                            Leave Game
                        </Button>
                    )}
                    <Button variant="destructive" size="sm" onClick={handleEndGame}>
                        End Game
                    </Button>
                </div>
            </div>

            {/* Players Grid */}
            <div className="grid gap-4 md:grid-cols-2 lg:grid-cols-3 xl:grid-cols-4">
                {players.map((player) => {
                    const isCurrentUser = player.clerkUserId === user?.id;

                    return (
                        <Card
                            key={player.id}
                            className={`
                ${isCurrentUser ? "ring-2 ring-blue-500" : ""}
                ${player.currentLife <= 0 ? "border-red-300" : ""}
              `}
                        >
                            <CardHeader className="pb-3">
                                <div className="flex items-center justify-between">
                                    <CardTitle className="text-lg">
                                        Player {player.position}
                                        {isCurrentUser && (
                                            <span className="text-sm font-normal text-muted-foreground ml-2">
                                                (You)
                                            </span>
                                        )}
                                    </CardTitle>
                                </div>
                            </CardHeader>
                            <CardContent>
                                <div className="text-center space-y-4">
                                    <div className="flex items-center justify-center gap-2">
                                        <Heart
                                            className={`h-6 w-6 ${player.currentLife <= 0 ? "text-red-500" : "text-red-400"}`}
                                        />
                                        <span
                                            className={`text-3xl font-bold ${player.currentLife <= 0 ? "text-red-500" : ""}`}
                                        >
                                            {player.currentLife}
                                        </span>
                                    </div>

                                    <div className="space-y-2">
                                        <div className="flex gap-2">
                                            <Button
                                                variant="outline"
                                                size="sm"
                                                onClick={() => handleLifeChange(player.id, -1)}
                                                className="flex-1"
                                                disabled={!isConnected}
                                            >
                                                <Minus className="h-4 w-4" />
                                            </Button>
                                            <Button
                                                variant="outline"
                                                size="sm"
                                                onClick={() => handleLifeChange(player.id, 1)}
                                                className="flex-1"
                                                disabled={!isConnected}
                                            >
                                                <Plus className="h-4 w-4" />
                                            </Button>
                                        </div>
                                        <div className="flex gap-2">
                                            <Button
                                                variant="outline"
                                                size="sm"
                                                onClick={() => handleLifeChange(player.id, -5)}
                                                className="flex-1"
                                                disabled={!isConnected}
                                            >
                                                -5
                                            </Button>
                                            <Button
                                                variant="outline"
                                                size="sm"
                                                onClick={() => handleLifeChange(player.id, 5)}
                                                className="flex-1"
                                                disabled={!isConnected}
                                            >
                                                +5
                                            </Button>
                                        </div>
                                    </div>
                                </div>
                            </CardContent>
                        </Card>
                    );
                })}
            </div>

            {/* Commander Damage Tracker */}
            <div className="mt-8">
                <CommanderDamageTracker
                    gameId={gameId}
                    players={players}
                    commanderDamage={gameState.commanderDamage || []}
                    currentUserId={user?.id || ""}
                    onUpdateDamage={handleCommanderDamageUpdate}
                    onTogglePartner={handlePartnerToggle}
                    isConnected={isConnected}
                />
            </div>

            {/* Game Summary */}
            <div className="mt-8">
                <Card>
                    <CardHeader>
                        <CardTitle className="flex items-center gap-2">
                            <Users className="h-5 w-5" />
                            Live Game Status
                        </CardTitle>
                    </CardHeader>
                    <CardContent>
                        <div className="space-y-2">
                            <div className="flex justify-between">
                                <span>Total Players:</span>
                                <span className="font-semibold">{players.length}</span>
                            </div>
                            <div className="flex justify-between">
                                <span>Connection Status:</span>
                                <Badge variant={isConnected ? "default" : "destructive"}>
                                    {connectionStatus}
                                </Badge>
                            </div>
                        </div>
                    </CardContent>
                </Card>
            </div>
        </div>
    );
}