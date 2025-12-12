"use client";

import { useState, useEffect, useMemo } from "react";
import { useUser, useAuth } from "@clerk/nextjs";
import Link from "next/link";
import {
  Card,
  CardContent,
  CardDescription,
  CardHeader,
  CardTitle,
} from "@/components/ui/card";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { Tabs, TabsList, TabsTrigger, TabsContent } from "@/components/ui/tabs";
import { Avatar, AvatarImage, AvatarFallback } from "@/components/ui/avatar";
import {
  Trophy,
  Sword,
  Calendar,
  Users,
  TrendingUp,
  Clock,
  Sparkles,
  Medal,
  Target,
  ArrowRight,
  Heart,
  Crown,
} from "lucide-react";
import { ConclaveAPI, type GameHistory, type GameWithPlayers, type Player } from "@/lib/api";
import { PodFilter } from "@/components/pod-filter";

interface MatchStats {
  totalGames: number;
  wins: number;
  losses: number;
  winRate: number;
  avgLifeRemaining: number;
  bestWin: GameWithPlayers | null;
}

function calculateStats(history: GameHistory, clerkUserId: string): MatchStats {
  const games = history.games;
  const totalGames = games.length;

  let wins = 0;
  let totalLifeWhenWon = 0;
  let bestWin: GameWithPlayers | null = null;
  let bestWinLife = 0;

  games.forEach((game) => {
    if (game.winner?.clerkUserId === clerkUserId) {
      wins++;
      totalLifeWhenWon += game.winner.currentLife;
      if (game.winner.currentLife > bestWinLife) {
        bestWin = game;
        bestWinLife = game.winner.currentLife;
      }
    }
  });

  return {
    totalGames,
    wins,
    losses: totalGames - wins,
    winRate: totalGames > 0 ? Math.round((wins / totalGames) * 100) : 0,
    avgLifeRemaining: wins > 0 ? Math.round(totalLifeWhenWon / wins) : 0,
    bestWin,
  };
}

function getInitials(name: string): string {
  return name
    .split(" ")
    .map((n) => n[0])
    .join("")
    .toUpperCase()
    .slice(0, 2);
}

function formatDate(dateString: string): string {
  const date = new Date(dateString);
  const now = new Date();
  const diffMs = now.getTime() - date.getTime();
  const diffDays = Math.floor(diffMs / (1000 * 60 * 60 * 24));

  if (diffDays === 0) {
    return "Today";
  } else if (diffDays === 1) {
    return "Yesterday";
  } else if (diffDays < 7) {
    return `${diffDays} days ago`;
  } else {
    return date.toLocaleDateString("en-US", {
      month: "short",
      day: "numeric",
      year: date.getFullYear() !== now.getFullYear() ? "numeric" : undefined,
    });
  }
}

function formatDuration(startDate: string, endDate?: string): string {
  if (!endDate) return "In progress";
  const start = new Date(startDate);
  const end = new Date(endDate);
  const diffMs = end.getTime() - start.getTime();
  const diffMins = Math.floor(diffMs / (1000 * 60));

  if (diffMins < 1) return "< 1 min";
  if (diffMins < 60) return `${diffMins} min`;
  const hours = Math.floor(diffMins / 60);
  const mins = diffMins % 60;
  return `${hours}h ${mins}m`;
}

function StatCard({
  icon: Icon,
  label,
  value,
  subValue,
  gradient,
}: {
  icon: React.ElementType;
  label: string;
  value: string | number;
  subValue?: string;
  gradient: string;
}) {
  return (
    <div className="relative group overflow-hidden rounded-2xl p-[1px]">
      <div className={`absolute inset-0 ${gradient} opacity-75 group-hover:opacity-100 transition-opacity duration-300`} />
      <div className="relative bg-card/95 backdrop-blur-xl rounded-2xl p-6 h-full">
        <div className="flex items-center gap-4">
          <div className={`p-3 rounded-xl ${gradient}`}>
            <Icon className="w-6 h-6 text-white" />
          </div>
          <div className="flex-1 min-w-0">
            <p className="text-sm text-muted-foreground font-medium">{label}</p>
            <p className="text-3xl font-bold tracking-tight transition-all duration-300">{value}</p>
            {subValue && (
              <p className="text-xs text-muted-foreground mt-1 transition-all duration-300">{subValue}</p>
            )}
          </div>
        </div>
      </div>
    </div>
  );
}

function GameCard({
  game,
  clerkUserId,
}: {
  game: GameWithPlayers;
  clerkUserId: string;
}) {
  const isWin = game.winner?.clerkUserId === clerkUserId;
  const userPlayer = game.players.find((p) => p.clerkUserId === clerkUserId);
  const otherPlayers = game.players.filter((p) => p.clerkUserId !== clerkUserId);

  return (
    <div className="group">
      <Card className="relative overflow-hidden border-0 shadow-lg hover:shadow-xl transition-all duration-300 hover:-translate-y-1">
        {/* Gradient accent bar */}
        <div
          className={`absolute top-0 left-0 right-0 h-1 ${isWin
            ? "bg-gradient-to-r from-emerald-500 via-green-500 to-teal-500"
            : "bg-gradient-to-r from-rose-500 via-red-500 to-pink-500"
            }`}
        />

        {/* Win/Loss Badge */}
        <div className="absolute top-4 right-4">
          {isWin ? (
            <Badge className="bg-emerald-500/10 text-emerald-600 border-emerald-500/20 px-3 py-1 gap-1.5">
              <Trophy className="w-3.5 h-3.5" />
              Victory
            </Badge>
          ) : (
            <Badge variant="secondary" className="bg-rose-500/10 text-rose-600 border-rose-500/20 px-3 py-1 gap-1.5">
              <Sword className="w-3.5 h-3.5" />
              Defeat
            </Badge>
          )}
        </div>

        <CardHeader className="pb-3">
          <CardTitle className="text-xl pr-24">
            Game {game.game.id.slice(0, 8)}
          </CardTitle>
          <CardDescription className="flex items-center gap-4 text-xs">
            <span className="flex items-center gap-1.5">
              <Calendar className="w-3.5 h-3.5" />
              {formatDate(game.game.createdAt)}
            </span>
            <span className="flex items-center gap-1.5">
              <Clock className="w-3.5 h-3.5" />
              {formatDuration(game.game.createdAt, game.game.finishedAt)}
            </span>
            <span className="flex items-center gap-1.5">
              <Users className="w-3.5 h-3.5" />
              {game.players.length} players
            </span>
          </CardDescription>
        </CardHeader>

        <CardContent className="pt-0">
          {/* Your Result */}
          {userPlayer && (
            <div className={`mb-4 p-4 rounded-xl ${isWin ? "bg-emerald-500/5" : "bg-muted/50"}`}>
              <div className="flex items-center justify-between">
                <div className="flex items-center gap-3">
                  <div className={`relative ${isWin ? "ring-2 ring-emerald-500 ring-offset-2 ring-offset-background rounded-full" : ""}`}>
                    <Avatar className="h-12 w-12">
                      <AvatarImage src={userPlayer.imageUrl} alt={userPlayer.displayName} />
                      <AvatarFallback className="bg-primary/10 text-primary font-semibold">
                        {getInitials(userPlayer.displayName)}
                      </AvatarFallback>
                    </Avatar>
                    {isWin && (
                      <div className="absolute -top-1 -right-1 w-5 h-5 bg-yellow-500 rounded-full flex items-center justify-center shadow-lg">
                        <Crown className="w-3 h-3 text-white" />
                      </div>
                    )}
                  </div>
                  <div>
                    <p className="font-semibold">You</p>
                    <p className="text-sm text-muted-foreground">
                      Position {userPlayer.position}
                    </p>
                  </div>
                </div>
                <div className="text-right">
                  <div className="flex items-center gap-1.5 justify-end">
                    <Heart className={`w-4 h-4 ${userPlayer.currentLife > 0 ? "text-rose-500" : "text-muted-foreground"}`} />
                    <span className="text-2xl font-bold tabular-nums">{userPlayer.currentLife}</span>
                  </div>
                  <p className="text-xs text-muted-foreground">
                    Started at {game.game.startingLife}
                  </p>
                </div>
              </div>
            </div>
          )}

          {/* Other Players */}
          <div className="space-y-2">
            <p className="text-xs font-medium text-muted-foreground uppercase tracking-wider mb-3">
              Opponents
            </p>
            <div className="grid gap-2">
              {otherPlayers.map((player) => {
                const isWinner = game.winner?.id === player.id;
                return (
                  <div
                    key={player.id}
                    className={`flex items-center justify-between p-3 rounded-lg transition-colors ${isWinner
                      ? "bg-emerald-500/5 border border-emerald-500/20"
                      : "bg-muted/30 hover:bg-muted/50"
                      }`}
                  >
                    <div className="flex items-center gap-3">
                      <div className="relative">
                        <Avatar className="h-8 w-8">
                          <AvatarImage src={player.imageUrl} alt={player.displayName} />
                          <AvatarFallback className="text-xs bg-secondary">
                            {getInitials(player.displayName)}
                          </AvatarFallback>
                        </Avatar>
                        {isWinner && (
                          <div className="absolute -top-0.5 -right-0.5 w-4 h-4 bg-yellow-500 rounded-full flex items-center justify-center shadow">
                            <Crown className="w-2.5 h-2.5 text-white" />
                          </div>
                        )}
                      </div>
                      <div>
                        <p className="font-medium text-sm">{player.displayName}</p>
                        {player.username && (
                          <p className="text-xs text-muted-foreground">@{player.username}</p>
                        )}
                      </div>
                    </div>
                    <div className="flex items-center gap-1.5">
                      <Heart className={`w-3.5 h-3.5 ${player.currentLife > 0 ? "text-rose-500" : "text-muted-foreground"}`} />
                      <span className={`font-semibold tabular-nums ${player.currentLife <= 0 ? "text-muted-foreground" : ""}`}>
                        {player.currentLife}
                      </span>
                    </div>
                  </div>
                );
              })}
            </div>
          </div>
        </CardContent>
      </Card>
    </div>
  );
}

function EmptyState({ filter }: { filter: string }) {
  const messages = {
    all: {
      title: "No matches yet",
      description: "Your match history will appear here once you complete your first game.",
      icon: Sword,
    },
    wins: {
      title: "No victories yet",
      description: "Keep playing! Your first win is just around the corner.",
      icon: Trophy,
    },
    losses: {
      title: "No defeats recorded",
      description: "Impressive! You haven't lost a single game yet.",
      icon: Medal,
    },
  };

  const { title, description, icon: Icon } = messages[filter as keyof typeof messages] || messages.all;

  return (
    <div className="flex flex-col items-center justify-center py-20 animate-in fade-in duration-500">
      <div className="relative mb-6">
        <div className="absolute inset-0 bg-gradient-to-r from-primary/20 via-purple-500/20 to-pink-500/20 rounded-full blur-2xl" />
        <div className="relative p-6 rounded-full bg-muted/50 backdrop-blur-sm">
          <Icon className="w-12 h-12 text-muted-foreground" />
        </div>
      </div>
      <h3 className="text-xl font-semibold mb-2">{title}</h3>
      <p className="text-muted-foreground text-center max-w-sm mb-6">{description}</p>
      <Link href="/">
        <Button className="gap-2">
          <Sparkles className="w-4 h-4" />
          Start a New Game
          <ArrowRight className="w-4 h-4" />
        </Button>
      </Link>
    </div>
  );
}

export function MatchHistory() {
  const { user } = useUser();
  const { getToken } = useAuth();
  const [history, setHistory] = useState<GameHistory | null>(null);
  const [allPlayersCache, setAllPlayersCache] = useState<Player[]>([]); // Cache all players from initial load
  const [initialLoading, setInitialLoading] = useState(true);
  const [isRefreshing, setIsRefreshing] = useState(false);
  const [filter, setFilter] = useState("all");
  const [selectedPodPlayerIds, setSelectedPodPlayerIds] = useState<string[]>([]);

  const api = useMemo(() => {
    const base = process.env.NEXT_PUBLIC_API_URL || "http://localhost:3001";
    return new ConclaveAPI({
      httpUrl: `${base}/api/v1`,
      getAuthToken: () => getToken({ template: "default" }),
    });
  }, [getToken]);

  // Initial fetch - get all history and cache players
  useEffect(() => {
    const fetchInitialHistory = async () => {
      if (!user?.id) return;

      setInitialLoading(true);
      try {
        const data = await api.http.getUserHistory();
        setHistory(data);

        // Cache all unique players from the full history
        const playerMap = new Map<string, Player>();
        data.games.forEach((game) => {
          game.players.forEach((player) => {
            if (!playerMap.has(player.clerkUserId)) {
              playerMap.set(player.clerkUserId, player);
            }
          });
        });
        setAllPlayersCache(Array.from(playerMap.values()));
      } catch (error) {
        console.error("Failed to fetch match history:", error);
      } finally {
        setInitialLoading(false);
      }
    };

    fetchInitialHistory();
  }, [api, user?.id]);

  // Fetch filtered history when pod selection changes (not on initial load)
  useEffect(() => {
    const fetchFilteredHistory = async () => {
      if (!user?.id || initialLoading) return;

      setIsRefreshing(true);
      try {
        let data: GameHistory;
        if (selectedPodPlayerIds.length > 0) {
          data = await api.http.getUserHistoryWithPod(selectedPodPlayerIds);
        } else {
          data = await api.http.getUserHistory();
        }
        setHistory(data);
      } catch (error) {
        console.error("Failed to fetch filtered history:", error);
      } finally {
        setIsRefreshing(false);
      }
    };

    fetchFilteredHistory();
  }, [api, user?.id, selectedPodPlayerIds, initialLoading]);

  // Use cached players for the filter (so they don't disappear when filtering)
  const allPlayers = allPlayersCache;

  const stats = useMemo(() => {
    if (!history || !user?.id) return null;
    return calculateStats(history, user.id);
  }, [history, user?.id]);

  const filteredGames = useMemo(() => {
    if (!history || !user?.id) return [];

    switch (filter) {
      case "wins":
        return history.games.filter((g) => g.winner?.clerkUserId === user.id);
      case "losses":
        return history.games.filter((g) => g.winner?.clerkUserId !== user.id);
      default:
        return history.games;
    }
  }, [history, user?.id, filter]);

  if (initialLoading) {
    return (
      <div className="min-h-[60vh] flex items-center justify-center">
        <div className="flex flex-col items-center gap-4 animate-pulse">
          <div className="relative">
            <div className="absolute inset-0 bg-gradient-to-r from-primary/30 via-purple-500/30 to-pink-500/30 rounded-full blur-xl animate-pulse" />
            <div className="relative p-4 rounded-full bg-muted">
              <Trophy className="w-8 h-8 text-muted-foreground" />
            </div>
          </div>
          <p className="text-muted-foreground">Loading match history...</p>
        </div>
      </div>
    );
  }

  return (
    <div className="min-h-screen bg-gradient-to-b from-background via-background to-muted/20">
      <div className="container mx-auto px-4 py-8 max-w-6xl">
        {/* Header */}
        <div className="mb-8">
          <div className="flex items-center gap-3 mb-2">
            <div className="p-2 rounded-lg bg-gradient-to-br from-primary/20 to-purple-500/20">
              <Trophy className="w-6 h-6 text-primary" />
            </div>
            <h1 className="text-3xl font-bold">Match History</h1>
          </div>
          <p className="text-muted-foreground">
            Track your victories, analyze your performance, and relive your epic battles.
          </p>
        </div>

        {/* Pod Filter Section */}
        <div className="mb-8">
          <div className="relative overflow-hidden rounded-2xl border bg-card/50 backdrop-blur-sm">
            {/* Subtle gradient accent */}
            <div className="absolute inset-0 bg-gradient-to-br from-primary/5 via-transparent to-purple-500/5 pointer-events-none" />

            <div className="relative p-5">
              <div className="flex items-center gap-3 mb-4">
                <div className="p-2 rounded-lg bg-gradient-to-br from-primary/20 to-purple-500/20">
                  <Users className="w-4 h-4 text-primary" />
                </div>
                <div>
                  <h3 className="font-semibold">Pod Stats</h3>
                  <p className="text-xs text-muted-foreground">
                    See your record against specific player groups
                  </p>
                </div>
              </div>

              <PodFilter
                availablePlayers={allPlayers}
                selectedPlayerIds={selectedPodPlayerIds}
                onSelectionChange={setSelectedPodPlayerIds}
                currentUserId={user?.id || ""}
              />
            </div>
          </div>
        </div>

        {/* Stats Grid */}
        {stats && stats.totalGames > 0 && (
          <div className={`grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-4 mb-8 transition-opacity duration-300 ${!initialLoading ? "animate-in fade-in slide-in-from-bottom-4 duration-500" : ""} ${isRefreshing ? "opacity-50" : "opacity-100"}`}>
            <StatCard
              icon={Target}
              label="Total Matches"
              value={stats.totalGames}
              subValue={`${stats.wins}W - ${stats.losses}L`}
              gradient="bg-gradient-to-br from-blue-500 to-cyan-500"
            />
            <StatCard
              icon={Trophy}
              label="Victories"
              value={stats.wins}
              subValue={stats.wins === 1 ? "1 win" : `${stats.wins} wins`}
              gradient="bg-gradient-to-br from-emerald-500 to-green-500"
            />
            <StatCard
              icon={TrendingUp}
              label="Win Rate"
              value={`${stats.winRate}%`}
              subValue={stats.winRate >= 50 ? "Above average!" : "Keep going!"}
              gradient="bg-gradient-to-br from-purple-500 to-pink-500"
            />
            <StatCard
              icon={Heart}
              label="Avg Life on Win"
              value={stats.avgLifeRemaining}
              subValue="Life remaining"
              gradient="bg-gradient-to-br from-rose-500 to-orange-500"
            />
          </div>
        )}

        {/* Filter Tabs */}
        <div className={`mb-6 transition-opacity duration-300 ${!initialLoading ? "animate-in fade-in slide-in-from-bottom-4 duration-500" : ""} ${isRefreshing ? "opacity-50" : "opacity-100"}`}>
          <Tabs value={filter} onValueChange={setFilter}>
            <TabsList className="bg-muted/50 backdrop-blur-sm">
              <TabsTrigger value="all" className="gap-2">
                <Sword className="w-4 h-4" />
                All Matches
              </TabsTrigger>
              <TabsTrigger value="wins" className="gap-2">
                <Trophy className="w-4 h-4" />
                Victories
              </TabsTrigger>
              <TabsTrigger value="losses" className="gap-2">
                <Target className="w-4 h-4" />
                Defeats
              </TabsTrigger>
            </TabsList>

            <TabsContent value="all" className="mt-6">
              {filteredGames.length === 0 ? (
                <EmptyState filter="all" />
              ) : (
                <div className="grid gap-4">
                  {filteredGames.map((game) => (
                    <GameCard
                      key={game.game.id}
                      game={game}
                      clerkUserId={user?.id || ""}
                    />
                  ))}
                </div>
              )}
            </TabsContent>

            <TabsContent value="wins" className="mt-6">
              {filteredGames.length === 0 ? (
                <EmptyState filter="wins" />
              ) : (
                <div className="grid gap-4">
                  {filteredGames.map((game) => (
                    <GameCard
                      key={game.game.id}
                      game={game}
                      clerkUserId={user?.id || ""}
                    />
                  ))}
                </div>
              )}
            </TabsContent>

            <TabsContent value="losses" className="mt-6">
              {filteredGames.length === 0 ? (
                <EmptyState filter="losses" />
              ) : (
                <div className="grid gap-4">
                  {filteredGames.map((game) => (
                    <GameCard
                      key={game.game.id}
                      game={game}
                      clerkUserId={user?.id || ""}
                    />
                  ))}
                </div>
              )}
            </TabsContent>
          </Tabs>
        </div>
      </div>
    </div>
  );
}
