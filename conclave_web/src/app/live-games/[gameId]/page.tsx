"use client";

import { useState, useEffect } from "react";
import { useParams, useRouter } from "next/navigation";
import { useUser } from "@clerk/nextjs";
import useWebSocket, { ReadyState } from 'react-use-websocket';
import {
    gameApi,
    createWebSocketUrl,
    type GameState,
    type Player,
} from "@/lib/api";
import { Button } from "@/components/ui/button";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { Badge } from "@/components/ui/badge";
import { Separator } from "@/components/ui/separator";
import { toast } from "sonner";
import {
    Heart,
    Minus,
    Plus,
    Users,
    ArrowLeft,
    LogOut,
    Crown,
} from "lucide-react";

interface WebSocketMessage {
    type: string;
    game_id?: string;
    player_id?: string;
    new_life?: number;
    change_amount?: number;
    username?: string;
    player?: Player;
    players?: Player[];
    winner?: Player;
}

interface WebSocketSendMessage {
    action: string;
    player_id?: string;
    change_amount?: number;
    game_id?: string;
}

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
    }, [lastMessage]);

    const handleWebSocketMessage = (message: WebSocketMessage) => {
        console.log("Received WebSocket message:", message);
        console.log("Current gameState players before update:", gameState?.players);

        switch (message.type) {
            case "life_update":
                if (message.player_id && message.new_life !== undefined) {
                    console.log(`🔄 Processing life update for player ${message.player_id}: ${message.new_life} (change: ${message.change_amount})`);

                    setGameState((prev) => {
                        if (!prev) {
                            console.log("❌ No previous game state, skipping update");
                            return prev;
                        }

                        console.log("📊 Previous players state:", prev.players.map(p => ({ id: p.id, life: p.current_life, position: p.position })));

                        const updatedState = {
                            ...prev,
                            players: prev.players.map((p) => {
                                if (p.id === message.player_id) {
                                    console.log(`✅ Updating player ${p.position} (${p.id}) from ${p.current_life} to ${message.new_life}`);
                                    return {
                                        ...p,
                                        current_life: message.new_life!,
                                    };
                                }
                                return p;
                            }),
                        };

                        console.log("📊 Updated players state:", updatedState.players.map(p => ({ id: p.id, life: p.current_life, position: p.position })));
                        return updatedState;
                    });

                    if (message.change_amount) {
                        const changeText =
                            message.change_amount > 0
                                ? `+${message.change_amount}`
                                : `${message.change_amount}`;
                        toast.info(`Life updated: ${changeText}`);
                    }
                } else {
                    console.log("❌ Invalid life_update message:", message);
                }
                break;

            case "player_joined":
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

            case "player_left":
                if (message.player_id) {
                    setGameState((prev) => {
                        if (!prev) return prev;
                        return {
                            ...prev,
                            players: prev.players.filter((p) => p.id !== message.player_id),
                        };
                    });
                    toast.info(`A player left the game`);
                }
                break;

            case "game_ended":
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

            default:
                console.log("Unknown message type:", message.type);
        }
    };

    const handleLifeChange = async (playerId: string, changeAmount: number) => {
        if (!isConnected) {
            toast.error("Not connected to game server");
            return;
        }

        try {
            const messageData: WebSocketSendMessage = {
                action: "update_life",
                player_id: playerId,
                change_amount: changeAmount,
                game_id: gameId,
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
                await gameApi.leave(gameId, { clerk_user_id: user.id });
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
                const messageData: WebSocketSendMessage = {
                    action: "end_game",
                    game_id: gameId,
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

    const getCurrentUserPlayer = (): Player | null => {
        if (!gameState || !user) return null;
        return gameState.players.find((p) => p.clerk_user_id === user.id) || null;
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
                                {game.starting_life} starting life • Live Game
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
                    const isCurrentUser = player.clerk_user_id === user?.id;

                    return (
                        <Card
                            key={player.id}
                            className={`
                ${isCurrentUser ? "ring-2 ring-blue-500" : ""}
                ${player.current_life <= 0 ? "border-red-300" : ""}
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
                                            className={`h-6 w-6 ${player.current_life <= 0 ? "text-red-500" : "text-red-400"}`}
                                        />
                                        <span
                                            className={`text-3xl font-bold ${player.current_life <= 0 ? "text-red-500" : ""}`}
                                        >
                                            {player.current_life}
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