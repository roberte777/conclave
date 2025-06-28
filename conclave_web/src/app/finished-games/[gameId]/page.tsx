"use client";

import { useState, useEffect } from "react";
import { useParams, useRouter } from "next/navigation";
import { useUser } from "@clerk/nextjs";
import {
    gameApi,
    type GameState,
    type Player,
} from "@/lib/api";
import { Button } from "@/components/ui/button";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { Badge } from "@/components/ui/badge";
import { Separator } from "@/components/ui/separator";
import {
    Heart,
    Users,
    ArrowLeft,
    Crown,
    Trophy,
    Calendar,
} from "lucide-react";
import { format } from "date-fns";

export default function FinishedGamePage() {
    const params = useParams();
    const router = useRouter();
    const { user } = useUser();
    const gameId = params.gameId as string;

    const [gameState, setGameState] = useState<GameState | null>(null);
    const [isLoading, setIsLoading] = useState(true);
    const [error, setError] = useState<string | null>(null);

    // Fetch game state and check if game is finished
    useEffect(() => {
        const fetchGameState = async () => {
            if (!gameId) {
                console.error("No game ID");
                return;
            }

            try {
                const state = await gameApi.getState(gameId);

                // If game is still active, redirect to live games page
                if (state.game.status === 'active') {
                    router.replace(`/live-games/${gameId}`);
                    return;
                }

                setGameState(state);
                setIsLoading(false);
            } catch (error) {
                console.error("Failed to fetch game state:", error);
                setError("Failed to load game");
                setIsLoading(false);
            }
        };

        fetchGameState();
    }, [gameId, router]);

    if (isLoading) {
        return (
            <div className="container mx-auto p-6">
                <div className="text-center py-12">
                    <p className="text-muted-foreground">Loading game...</p>
                </div>
            </div>
        );
    }

    if (error && !gameState) {
        return (
            <div className="container mx-auto p-6">
                <div className="text-center py-12">
                    <p className="text-red-500 mb-4">{error}</p>
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
    const activePlayers = players.filter((p) => !p.is_eliminated);
    const eliminatedPlayers = players.filter((p) => p.is_eliminated);
    const winner = activePlayers.length === 1 ? activePlayers[0] : null;

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
                                {game.starting_life} starting life • Finished Game
                            </p>
                            {game.finished_at && (
                                <p className="text-sm text-muted-foreground">
                                    <Calendar className="h-4 w-4 inline mr-1" />
                                    Finished {format(new Date(game.finished_at), "PPp")}
                                </p>
                            )}
                        </div>
                    </div>
                    <div className="flex items-center gap-2">
                        <Badge variant="outline">
                            <Trophy className="h-3 w-3 mr-1" />
                            Finished
                        </Badge>
                    </div>
                </div>
            </div>

            {/* Winner announcement */}
            {winner && (
                <Card className="mb-6 bg-yellow-50 border-yellow-200">
                    <CardContent className="pt-6">
                        <div className="flex items-center justify-center gap-2 text-yellow-800">
                            <Crown className="h-5 w-5" />
                            <span className="font-semibold">
                                Player {winner.position} won this game!
                            </span>
                        </div>
                    </CardContent>
                </Card>
            )}

            {/* Final Standings */}
            <div className="mb-6">
                <Card>
                    <CardHeader>
                        <CardTitle className="flex items-center gap-2">
                            <Trophy className="h-5 w-5" />
                            Final Standings
                        </CardTitle>
                    </CardHeader>
                    <CardContent>
                        <div className="space-y-3">
                            {/* Winner */}
                            {winner && (
                                <div className="flex items-center justify-between p-3 bg-yellow-50 rounded-lg border border-yellow-200">
                                    <div className="flex items-center gap-3">
                                        <Crown className="h-5 w-5 text-yellow-600" />
                                        <div>
                                            <span className="font-semibold">
                                                Player {winner.position}
                                                {winner.clerk_user_id === user?.id && " (You)"}
                                            </span>
                                            <Badge variant="default" className="ml-2">
                                                Winner
                                            </Badge>
                                        </div>
                                    </div>
                                    <div className="flex items-center gap-2">
                                        <Heart className="h-4 w-4 text-red-400" />
                                        <span className="font-bold text-lg">{winner.current_life}</span>
                                    </div>
                                </div>
                            )}

                            {/* Eliminated Players */}
                            {eliminatedPlayers.length > 0 && (
                                <div className="space-y-2">
                                    <h4 className="text-sm font-medium text-muted-foreground">
                                        Eliminated Players
                                    </h4>
                                    {eliminatedPlayers
                                        .sort((a, b) => b.current_life - a.current_life)
                                        .map((player, index) => (
                                            <div
                                                key={player.id}
                                                className="flex items-center justify-between p-2 bg-gray-50 rounded-lg"
                                            >
                                                <div className="flex items-center gap-3">
                                                    <span className="text-sm text-muted-foreground">
                                                        #{eliminatedPlayers.length - index + (winner ? 1 : 0)}
                                                    </span>
                                                    <span>
                                                        Player {player.position}
                                                        {player.clerk_user_id === user?.id && " (You)"}
                                                    </span>
                                                    <Badge variant="destructive" className="text-xs">
                                                        Eliminated
                                                    </Badge>
                                                </div>
                                                <div className="flex items-center gap-2">
                                                    <Heart className="h-4 w-4 text-red-500" />
                                                    <span className="font-semibold text-red-500">
                                                        {player.current_life}
                                                    </span>
                                                </div>
                                            </div>
                                        ))}
                                </div>
                            )}
                        </div>
                    </CardContent>
                </Card>
            </div>

            {/* Players Grid - Historical View */}
            <div className="grid gap-4 md:grid-cols-2 lg:grid-cols-3 xl:grid-cols-4 mb-6">
                {players.map((player) => {
                    const isCurrentUser = player.clerk_user_id === user?.id;
                    const isWinner = winner?.id === player.id;

                    return (
                        <Card
                            key={player.id}
                            className={`
                ${player.is_eliminated ? "opacity-75" : ""}
                ${isCurrentUser ? "ring-2 ring-blue-500" : ""}
                ${isWinner ? "ring-2 ring-yellow-500 bg-yellow-50" : ""}
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
                                    <div className="flex gap-1">
                                        {isWinner && <Crown className="h-4 w-4 text-yellow-600" />}
                                        {player.is_eliminated ? (
                                            <Badge variant="destructive" className="text-xs">
                                                Eliminated
                                            </Badge>
                                        ) : (
                                            <Badge variant="default" className="text-xs">
                                                Survived
                                            </Badge>
                                        )}
                                    </div>
                                </div>
                            </CardHeader>
                            <CardContent>
                                <div className="text-center">
                                    <div className="flex items-center justify-center gap-2">
                                        <Heart
                                            className={`h-6 w-6 ${player.current_life <= 0 ? "text-red-500" : "text-red-400"
                                                }`}
                                        />
                                        <span
                                            className={`text-3xl font-bold ${player.current_life <= 0 ? "text-red-500" : ""
                                                }`}
                                        >
                                            {player.current_life}
                                        </span>
                                    </div>
                                    <p className="text-sm text-muted-foreground mt-2">
                                        Final Life Total
                                    </p>
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
                            Game Summary
                        </CardTitle>
                    </CardHeader>
                    <CardContent>
                        <div className="space-y-2">
                            <div className="flex justify-between">
                                <span>Game Status:</span>
                                <Badge variant="outline">Finished</Badge>
                            </div>
                            <div className="flex justify-between">
                                <span>Total Players:</span>
                                <span className="font-semibold">{players.length}</span>
                            </div>
                            <div className="flex justify-between">
                                <span>Players Eliminated:</span>
                                <span className="font-semibold">{eliminatedPlayers.length}</span>
                            </div>
                            <div className="flex justify-between">
                                <span>Starting Life:</span>
                                <span className="font-semibold">{game.starting_life}</span>
                            </div>
                            {game.finished_at && (
                                <div className="flex justify-between">
                                    <span>Finished At:</span>
                                    <span className="font-semibold">
                                        {format(new Date(game.finished_at), "PPp")}
                                    </span>
                                </div>
                            )}
                            {winner && (
                                <div className="flex justify-between">
                                    <span>Winner:</span>
                                    <span className="font-semibold flex items-center gap-1">
                                        <Crown className="h-4 w-4 text-yellow-600" />
                                        Player {winner.position}
                                    </span>
                                </div>
                            )}
                        </div>
                    </CardContent>
                </Card>
            </div>
        </div>
    );
} 