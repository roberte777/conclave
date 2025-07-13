"use client";

import { useState } from "react";
import { useUser } from "@clerk/nextjs";
import { useRouter } from "next/navigation";
import { useQuery, useMutation, useQueryClient } from "@tanstack/react-query";
import { gameApi, userApi, type GameWithUsers, type CreateGameRequest, type JoinGameRequest } from "@/lib/api";
import { Button } from "@/components/ui/button";
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card";
import { Dialog, DialogContent, DialogDescription, DialogHeader, DialogTitle, DialogTrigger } from "@/components/ui/dialog";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Badge } from "@/components/ui/badge";
import { Tabs, TabsContent, TabsList, TabsTrigger } from "@/components/ui/tabs";
import { toast } from "sonner";
import { Users, Plus, Play, Clock, Trophy, GamepadIcon, LogOut, Crown } from "lucide-react";
import { format } from "date-fns";

export default function Dashboard() {
  const { user } = useUser();
  const router = useRouter();
  const queryClient = useQueryClient();
  const [gameName, setGameName] = useState("");
  const [startingLife, setStartingLife] = useState(20);
  const [isCreateDialogOpen, setIsCreateDialogOpen] = useState(false);

  // Fetch user's active games
  const { data: userGames, isLoading: gamesLoading } = useQuery({
    queryKey: ['user-games', user?.id],
    queryFn: () => userApi.getGames(user!.id),
    enabled: !!user,
    refetchInterval: 5000, // Refetch every 5 seconds
  });

  // Fetch available games to join
  const { data: availableGames, isLoading: availableGamesLoading } = useQuery({
    queryKey: ['available-games', user?.id],
    queryFn: () => userApi.getAvailableGames(user!.id),
    enabled: !!user,
    refetchInterval: 10000, // Refetch every 10 seconds
  });

  // Fetch user's game history
  const { data: gameHistory, isLoading: historyLoading } = useQuery({
    queryKey: ['user-history', user?.id],
    queryFn: () => userApi.getHistory(user!.id),
    enabled: !!user,
    refetchInterval: 30000, // Refetch every 30 seconds
  });

  // Create game mutation
  const createGameMutation = useMutation({
    mutationFn: async (data: CreateGameRequest) => {
      return gameApi.create(data);
    },
    onSuccess: (game) => {
      queryClient.invalidateQueries({ queryKey: ['user-games'] });
      queryClient.invalidateQueries({ queryKey: ['available-games'] });
      setIsCreateDialogOpen(false);
      setGameName("");
      setStartingLife(20);
      toast.success("Game created successfully!");
      router.push(`/live-games/${game.id}`);
    },
    onError: (error) => {
      toast.error((error as { response?: { data?: { error?: string } } }).response?.data?.error || "Failed to create game");
    },
  });

  // Join game mutation
  const joinGameMutation = useMutation({
    mutationFn: async ({ gameId, data }: { gameId: string; data: JoinGameRequest }) => {
      return gameApi.join(gameId, data);
    },
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['user-games'] });
      queryClient.invalidateQueries({ queryKey: ['available-games'] });
      toast.success("Joined game successfully!");
    },
    onError: (error) => {
      toast.error((error as { response?: { data?: { error?: string } } }).response?.data?.error || "Failed to join game");
    },
  });

  // Leave game mutation
  const leaveGameMutation = useMutation({
    mutationFn: async ({ gameId, data }: { gameId: string; data: JoinGameRequest }) => {
      return gameApi.leave(gameId, data);
    },
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['user-games'] });
      queryClient.invalidateQueries({ queryKey: ['available-games'] });
      toast.success("Left game successfully!");
    },
    onError: (error) => {
      toast.error((error as { response?: { data?: { error?: string } } }).response?.data?.error || "Failed to leave game");
    },
  });

  const handleCreateGame = () => {
    if (!user || !gameName.trim()) return;

    createGameMutation.mutate({
      name: gameName.trim(),
      startingLife: startingLife,
      clerkUserId: user.id,
    });
  };

  const handleJoinGame = (gameId: string) => {
    if (!user) return;

    joinGameMutation.mutate({
      gameId,
      data: {
        clerkUserId: user.id,
      },
    });
  };

  const handleLeaveGame = (gameId: string) => {
    if (!user) return;

    if (confirm("Are you sure you want to leave this game?")) {
      leaveGameMutation.mutate({
        gameId,
        data: {
          clerkUserId: user.id,
        },
      });
    }
  };

  const isUserInGame = (game: GameWithUsers) => {
    return game.users.some(u => u.clerkUserId === user?.id);
  };

  const getGameStatusBadge = (status: string) => {
    switch (status) {
      case 'active':
        return <Badge variant="default">Active</Badge>;
      case 'finished':
        return <Badge variant="outline">Finished</Badge>;
      default:
        return <Badge variant="outline">{status}</Badge>;
    }
  };

  if (!user) {
    return (
      <div className="container mx-auto p-8 text-center">
        <div className="max-w-2xl mx-auto">
          <h1 className="text-4xl font-bold mb-4">Welcome to Conclave</h1>
          <p className="text-xl text-muted-foreground mb-8">
            The ultimate Magic: The Gathering life tracker for multiplayer games
          </p>
          <div className="bg-card p-6 rounded-lg border">
            <h2 className="text-2xl font-semibold mb-4">Features</h2>
            <div className="grid md:grid-cols-2 gap-4 text-left">
              <div className="flex items-start gap-3">
                <Users className="h-5 w-5 mt-1 text-primary" />
                <div>
                  <h3 className="font-medium">Multiplayer Support</h3>
                  <p className="text-sm text-muted-foreground">Track life for up to 8 players</p>
                </div>
              </div>
              <div className="flex items-start gap-3">
                <Clock className="h-5 w-5 mt-1 text-primary" />
                <div>
                  <h3 className="font-medium">Real-time Updates</h3>
                  <p className="text-sm text-muted-foreground">See changes instantly across all devices</p>
                </div>
              </div>
              <div className="flex items-start gap-3">
                <Trophy className="h-5 w-5 mt-1 text-primary" />
                <div>
                  <h3 className="font-medium">Game History</h3>
                  <p className="text-sm text-muted-foreground">Track your wins and game statistics</p>
                </div>
              </div>
              <div className="flex items-start gap-3">
                <Play className="h-5 w-5 mt-1 text-primary" />
                <div>
                  <h3 className="font-medium">Instant Play</h3>
                  <p className="text-sm text-muted-foreground">Create games and start playing immediately</p>
                </div>
              </div>
            </div>
          </div>
        </div>
      </div>
    );
  }

  return (
    <div className="container mx-auto p-6">
      <div className="mb-8">
        <h1 className="text-3xl font-bold mb-2">Welcome back, {user.firstName || user.username}!</h1>
        <p className="text-muted-foreground">Manage your MTG games and track life totals</p>
      </div>

      <Tabs defaultValue="games" className="space-y-6">
        <TabsList>
          <TabsTrigger value="games">My Games</TabsTrigger>
          <TabsTrigger value="available">Available Games</TabsTrigger>
          <TabsTrigger value="history">Game History</TabsTrigger>
        </TabsList>

        <TabsContent value="games">
          <div className="flex justify-between items-center mb-6">
            <h2 className="text-2xl font-semibold">My Active Games</h2>
            <Dialog open={isCreateDialogOpen} onOpenChange={setIsCreateDialogOpen}>
              <DialogTrigger asChild>
                <Button>
                  <Plus className="h-4 w-4 mr-2" />
                  Create Game
                </Button>
              </DialogTrigger>
              <DialogContent>
                <DialogHeader>
                  <DialogTitle>Create New Game</DialogTitle>
                  <DialogDescription>
                    Create a new MTG life tracking game that starts immediately. Other players can join while you play.
                  </DialogDescription>
                </DialogHeader>
                <div className="space-y-4">
                  <div>
                    <Label htmlFor="gameName">Game Name</Label>
                    <Input
                      id="gameName"
                      placeholder="Enter game name..."
                      value={gameName}
                      onChange={(e) => setGameName(e.target.value)}
                    />
                  </div>
                  <div>
                    <Label htmlFor="startingLife">Starting Life Total</Label>
                    <Input
                      id="startingLife"
                      type="number"
                      min="1"
                      max="999"
                      value={startingLife}
                      onChange={(e) => setStartingLife(parseInt(e.target.value) || 20)}
                    />
                  </div>
                  <Button
                    onClick={handleCreateGame}
                    disabled={!gameName.trim() || createGameMutation.isPending}
                    className="w-full"
                  >
                    {createGameMutation.isPending ? "Creating..." : "Create & Play"}
                  </Button>
                </div>
              </DialogContent>
            </Dialog>
          </div>

          {gamesLoading ? (
            <div className="text-center py-8">
              <p className="text-muted-foreground">Loading your games...</p>
            </div>
          ) : userGames && userGames.length > 0 ? (
            <div className="grid gap-4 md:grid-cols-2 lg:grid-cols-3">
              {userGames.map((gameWithUsers) => {
                const game = gameWithUsers.game;
                const inGame = isUserInGame(gameWithUsers);

                return (
                  <Card key={game.id} className="hover:shadow-md transition-shadow">
                    <CardHeader>
                      <div className="flex justify-between items-start">
                        <div>
                          <CardTitle className="text-lg">{game.name}</CardTitle>
                          <CardDescription>
                            Created {format(new Date(game.createdAt), "MMM d, yyyy 'at' h:mm a")}
                          </CardDescription>
                        </div>
                        {getGameStatusBadge(game.status)}
                      </div>
                    </CardHeader>
                    <CardContent>
                      <div className="space-y-3">
                        <div className="flex items-center gap-2 text-sm text-muted-foreground">
                          <Users className="h-4 w-4" />
                          <span>{gameWithUsers.users.length} player{gameWithUsers.users.length !== 1 ? 's' : ''}</span>
                          <span>•</span>
                          <span>{game.startingLife} starting life</span>
                        </div>

                        <div className="flex gap-2">
                          {game.status === 'active' && (
                            <>
                              {inGame ? (
                                <>
                                  <Button
                                    size="sm"
                                    variant="default"
                                    onClick={() => router.push(`/live-games/${game.id}`)}
                                    className="flex-1"
                                  >
                                    <GamepadIcon className="h-4 w-4 mr-1" />
                                    Play Live
                                  </Button>
                                  <Button
                                    size="sm"
                                    variant="outline"
                                    onClick={() => handleLeaveGame(game.id)}
                                    disabled={leaveGameMutation.isPending}
                                  >
                                    <LogOut className="h-4 w-4" />
                                  </Button>
                                </>
                              ) : (
                                <Button
                                  size="sm"
                                  variant="default"
                                  onClick={() => handleJoinGame(game.id)}
                                  disabled={joinGameMutation.isPending}
                                  className="flex-1"
                                >
                                  <Users className="h-4 w-4 mr-1" />
                                  Join
                                </Button>
                              )}
                            </>
                          )}
                          {game.status === 'finished' && (
                            <Button
                              size="sm"
                              variant="outline"
                              onClick={() => router.push(`/finished-games/${game.id}`)}
                              className="flex-1"
                            >
                              <Trophy className="h-4 w-4 mr-1" />
                              View Results
                            </Button>
                          )}
                        </div>
                      </div>
                    </CardContent>
                  </Card>
                );
              })}
            </div>
          ) : (
            <div className="text-center py-12">
              <GamepadIcon className="h-12 w-12 mx-auto text-muted-foreground mb-4" />
              <h3 className="text-lg font-semibold mb-2">No active games</h3>
              <p className="text-muted-foreground mb-4">Create your first game to get started!</p>
              <Button onClick={() => setIsCreateDialogOpen(true)}>
                <Plus className="h-4 w-4 mr-2" />
                Create Game
              </Button>
            </div>
          )}
        </TabsContent>

        <TabsContent value="available">
          <div className="mb-6">
            <h2 className="text-2xl font-semibold mb-2">Available Games</h2>
            <p className="text-muted-foreground">Join active games created by other players</p>
          </div>

          {availableGamesLoading ? (
            <div className="text-center py-8">
              <p className="text-muted-foreground">Loading available games...</p>
            </div>
          ) : availableGames && availableGames.length > 0 ? (
            <div className="grid gap-4 md:grid-cols-2 lg:grid-cols-3">
              {availableGames.map((gameWithUsers) => {
                const game = gameWithUsers.game;

                return (
                  <Card key={game.id} className="hover:shadow-md transition-shadow">
                    <CardHeader>
                      <div className="flex justify-between items-start">
                        <div>
                          <CardTitle className="text-lg">{game.name}</CardTitle>
                          <CardDescription>
                            Created {format(new Date(game.createdAt), "MMM d, yyyy 'at' h:mm a")}
                          </CardDescription>
                        </div>
                        <Badge variant="default">Active</Badge>
                      </div>
                    </CardHeader>
                    <CardContent>
                      <div className="space-y-3">
                        <div className="flex items-center gap-2 text-sm text-muted-foreground">
                          <Users className="h-4 w-4" />
                          <span>{gameWithUsers.users.length}/8 players</span>
                          <span>•</span>
                          <span>{game.startingLife} starting life</span>
                        </div>

                        <Button
                          size="sm"
                          variant="default"
                          onClick={() => handleJoinGame(game.id)}
                          disabled={joinGameMutation.isPending}
                          className="w-full"
                        >
                          <Users className="h-4 w-4 mr-1" />
                          {joinGameMutation.isPending ? "Joining..." : "Join Game"}
                        </Button>
                      </div>
                    </CardContent>
                  </Card>
                );
              })}
            </div>
          ) : (
            <div className="text-center py-12">
              <Users className="h-12 w-12 mx-auto text-muted-foreground mb-4" />
              <h3 className="text-lg font-semibold mb-2">No available games</h3>
              <p className="text-muted-foreground mb-4">No games are currently looking for players. Create your own game!</p>
              <Button onClick={() => setIsCreateDialogOpen(true)}>
                <Plus className="h-4 w-4 mr-2" />
                Create Game
              </Button>
            </div>
          )}
        </TabsContent>

        <TabsContent value="history">
          <div className="mb-6">
            <h2 className="text-2xl font-semibold mb-2">Game History</h2>
            <p className="text-muted-foreground">Your completed games and results</p>
          </div>

          {historyLoading ? (
            <div className="text-center py-8">
              <p className="text-muted-foreground">Loading your game history...</p>
            </div>
          ) : gameHistory && gameHistory.games.length > 0 ? (
            <div className="space-y-4">
              {gameHistory.games.map((gameWithPlayers) => {
                const game = gameWithPlayers.game;
                const winner = gameWithPlayers.winner;
                const userWon = winner?.clerkUserId === user.id;

                return (
                  <Card key={game.id}>
                    <CardHeader>
                      <div className="flex justify-between items-start">
                        <div>
                          <CardTitle className="text-lg">{game.name}</CardTitle>
                          <CardDescription>
                            Finished {game.finishedAt ? format(new Date(game.finishedAt), "MMM d, yyyy 'at' h:mm a") : 'Recently'}
                          </CardDescription>
                        </div>
                        <div className="flex items-center gap-2">
                          {userWon && <Crown className="h-4 w-4 text-yellow-500" />}
                          <Badge variant={userWon ? "default" : "outline"}>
                            {userWon ? "Won" : "Participated"}
                          </Badge>
                        </div>
                      </div>
                    </CardHeader>
                    <CardContent>
                      <div className="space-y-3">
                        <div className="flex items-center gap-4 text-sm text-muted-foreground">
                          <span>{gameWithPlayers.players.length} players</span>
                          <span>•</span>
                          <span>{game.startingLife} starting life</span>
                          {winner && (
                            <>
                              <span>•</span>
                              <span>Winner: Player {winner.position}</span>
                            </>
                          )}
                        </div>
                        <Button
                          size="sm"
                          variant="outline"
                          onClick={() => router.push(`/finished-games/${game.id}`)}
                          className="w-full"
                        >
                          <Trophy className="h-4 w-4 mr-1" />
                          View Game Results
                        </Button>
                      </div>
                    </CardContent>
                  </Card>
                );
              })}
            </div>
          ) : (
            <div className="text-center py-12">
              <Trophy className="h-12 w-12 mx-auto text-muted-foreground mb-4" />
              <h3 className="text-lg font-semibold mb-2">No game history</h3>
              <p className="text-muted-foreground">Complete some games to see your history here!</p>
            </div>
          )}
        </TabsContent>
      </Tabs>
    </div>
  );
}
