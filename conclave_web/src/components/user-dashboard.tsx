"use client";

import { useState, useEffect, useCallback, useMemo } from "react";
import { useUser, useAuth } from "@clerk/nextjs";
import { Button } from "@/components/ui/button";
import {
  Dialog,
  DialogContent,
  DialogDescription,
  DialogFooter,
  DialogHeader,
  DialogTitle,
} from "@/components/ui/dialog";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import {
  Plus,
  Users,
  Sparkles,
  ArrowRight,
  LogOut,
  RefreshCw,
  Gamepad2,
  Heart,
  Clock,
  Crown,
  AlertCircle,
} from "lucide-react";
import { ConclaveAPI, type GameWithUsers, DEFAULT_STARTING_LIFE } from "@/lib/api";
import { cn } from "@/lib/utils";

export function UserDashboard() {
  const { user } = useUser();
  const { getToken } = useAuth();
  const [creatingGame, setCreatingGame] = useState(false);
  const [myActiveGames, setMyActiveGames] = useState<GameWithUsers[]>([]);
  const [availableGames, setAvailableGames] = useState<GameWithUsers[]>([]);
  const [loadingGames, setLoadingGames] = useState(true);
  const [showCreateDialog, setShowCreateDialog] = useState(false);
  const [startingLifeInput, setStartingLifeInput] = useState(String(DEFAULT_STARTING_LIFE));
  const [startingLifeError, setStartingLifeError] = useState<string | null>(null);
  const [leavingGameId, setLeavingGameId] = useState<string | null>(null);
  const [refreshing, setRefreshing] = useState(false);

  const api = useMemo(() => {
    const base = process.env.NEXT_PUBLIC_API_URL || "http://localhost:3001";
    return new ConclaveAPI({
      httpUrl: `${base}/api/v1`,
      getAuthToken: () => getToken({ template: "default" }),
    });
  }, [getToken]);

  const refreshGames = useCallback(async () => {
    if (!user?.id) return;

    setRefreshing(true);
    setLoadingGames(true);
    try {
      const [userGames, joinableGames] = await Promise.all([
        api.http.getUserGames(),
        api.http.getAvailableGames(),
      ]);
      setMyActiveGames(userGames.filter((g) => g.game.status === "active"));
      setAvailableGames(joinableGames);
    } catch (error) {
      console.error("Failed to fetch active games:", error);
    } finally {
      setLoadingGames(false);
      setRefreshing(false);
    }
  }, [api, user?.id]);

  useEffect(() => {
    refreshGames();
  }, [refreshGames]);

  const handleCreateGame = async () => {
    if (!user?.id) return;
    setStartingLifeError(null);

    const parsedLife = parseInt(startingLifeInput, 10);
    if (!Number.isFinite(parsedLife) || parsedLife < 1 || parsedLife > 999) {
      setStartingLifeError("Starting life must be a number between 1 and 999");
      return;
    }

    setCreatingGame(true);
    try {
      const game = await api.http.createGame({
        startingLife: parsedLife,
      });

      setShowCreateDialog(false);
      setStartingLifeInput(String(DEFAULT_STARTING_LIFE));
      setStartingLifeError(null);
      window.location.href = `/game/${game.id}`;
    } catch (error) {
      console.error("Failed to create game:", error);
    } finally {
      setCreatingGame(false);
    }
  };

  const openCreateDialog = () => {
    setStartingLifeInput(String(DEFAULT_STARTING_LIFE));
    setStartingLifeError(null);
    setShowCreateDialog(true);
  };

  const handleJoinGame = (gameId: string) => {
    window.location.href = `/game/${gameId}`;
  };

  const handleLeaveGame = async (gameId: string) => {
    if (!user?.id) return;
    setLeavingGameId(gameId);
    try {
      await api.http.leaveGame(gameId);
      await refreshGames();
    } catch (error) {
      console.error("Failed to leave game:", error);
    } finally {
      setLeavingGameId(null);
    }
  };

  const timeAgo = (dateString: string) => {
    const date = new Date(dateString);
    const now = new Date();
    const seconds = Math.floor((now.getTime() - date.getTime()) / 1000);

    if (seconds < 60) return "just now";
    if (seconds < 3600) return `${Math.floor(seconds / 60)}m ago`;
    if (seconds < 86400) return `${Math.floor(seconds / 3600)}h ago`;
    return `${Math.floor(seconds / 86400)}d ago`;
  };

  return (
    <div className="min-h-screen bg-gradient-mesh">
      <div className="max-w-6xl mx-auto px-4 py-8 md:py-12">
        {/* Welcome Header */}
        <div className="mb-10">
          <div className="flex items-start justify-between gap-4 flex-wrap">
            <div>
              <h1 className="text-3xl md:text-4xl font-bold mb-2">
                Welcome back,{" "}
                <span className="bg-gradient-to-r from-violet-400 to-pink-400 bg-clip-text text-transparent">
                  {user?.firstName || user?.username || "Player"}
                </span>
              </h1>
              <p className="text-muted-foreground">
                Ready for another game? Create or join a session below.
              </p>
            </div>
            <Button
              variant="ghost"
              size="sm"
              onClick={refreshGames}
              disabled={refreshing}
              className="text-muted-foreground hover:text-foreground"
            >
              <RefreshCw className={cn("w-4 h-4 mr-2", refreshing && "animate-spin")} />
              Refresh
            </Button>
          </div>
        </div>

        {/* Quick Action - Create Game */}
        <div className="mb-10">
          <button
            onClick={openCreateDialog}
            disabled={myActiveGames.length > 0}
            className={cn(
              "w-full glass-card rounded-2xl p-6 text-left transition-all duration-300 group",
              myActiveGames.length > 0
                ? "opacity-60 cursor-not-allowed"
                : "hover:scale-[1.01] hover:bg-white/10"
            )}
          >
            <div className="flex items-start gap-4">
              <div className="w-14 h-14 rounded-xl bg-gradient-to-br from-violet-500 to-purple-500 flex items-center justify-center shadow-lg group-hover:shadow-xl transition-shadow">
                <Plus className="w-7 h-7 text-white" />
              </div>
              <div className="flex-1">
                <h3 className="text-xl font-semibold mb-1">Create New Game</h3>
                <p className="text-sm text-muted-foreground">
                  {myActiveGames.length > 0
                    ? "You can only be in one game at a time. Leave your current game to create a new one."
                    : "Start a new Commander session and invite your friends"}
                </p>
              </div>
              {myActiveGames.length === 0 && (
                <ArrowRight className="w-5 h-5 text-muted-foreground group-hover:text-foreground group-hover:translate-x-1 transition-all" />
              )}
            </div>
          </button>
        </div>

        {/* Your Active Games */}
        <section className={cn("mb-10 transition-opacity duration-300", refreshing && "opacity-50")}>
          <div className="flex items-center gap-3 mb-4">
            <div className="w-10 h-10 rounded-lg bg-gradient-to-br from-emerald-500 to-green-500 flex items-center justify-center">
              <Crown className="w-5 h-5 text-white" />
            </div>
            <div>
              <h2 className="text-xl font-semibold">Your Active Games</h2>
              <p className="text-sm text-muted-foreground">Games you&apos;re currently playing</p>
            </div>
          </div>

          {loadingGames ? (
            <div className="glass-card rounded-2xl p-12 text-center">
              <div className="w-12 h-12 mx-auto mb-4 rounded-full bg-primary/20 animate-pulse flex items-center justify-center">
                <Sparkles className="w-6 h-6 text-primary" />
              </div>
              <p className="text-muted-foreground">Loading your games...</p>
            </div>
          ) : myActiveGames.length === 0 ? (
            <div className="glass-card rounded-2xl p-12 text-center">
              <div className="w-16 h-16 mx-auto mb-4 rounded-full bg-violet-500/10 flex items-center justify-center">
                <Gamepad2 className="w-8 h-8 text-violet-400" />
              </div>
              <p className="text-lg font-medium mb-2">No active games</p>
              <p className="text-sm text-muted-foreground mb-6">
                Create a new game or join one from below
              </p>
              <Button onClick={openCreateDialog} className="bg-gradient-to-r from-violet-600 to-purple-600">
                <Plus className="w-4 h-4 mr-2" />
                Create Your First Game
              </Button>
            </div>
          ) : (
            <div className="grid gap-4 md:grid-cols-2">
              {myActiveGames.map((g) => (
                <div
                  key={g.game.id}
                  className="glass-card rounded-2xl p-5 hover:bg-white/5 transition-all"
                >
                  <div className="flex items-start justify-between gap-4 mb-4">
                    <div>
                      <h3 className="text-lg font-semibold mb-1">Game #{g.game.id.slice(0, 8)}</h3>
                      <div className="flex items-center gap-3 text-sm text-muted-foreground">
                        <span className="flex items-center gap-1">
                          <Users className="w-4 h-4" />
                          {g.users.length} player{g.users.length !== 1 && "s"}
                        </span>
                        <span className="flex items-center gap-1">
                          <Heart className="w-4 h-4" />
                          {g.game.startingLife} life
                        </span>
                        <span className="flex items-center gap-1">
                          <Clock className="w-4 h-4" />
                          {timeAgo(g.game.createdAt)}
                        </span>
                      </div>
                    </div>
                    <span className="px-2 py-1 rounded-full text-xs font-medium bg-emerald-500/20 text-emerald-400">
                      Active
                    </span>
                  </div>

                  {/* Player Avatars */}
                  <div className="flex items-center gap-2 mb-4">
                    <div className="flex -space-x-2">
                      {g.users.slice(0, 4).map((u, idx) => (
                        <div
                          key={u.clerkUserId}
                          className="w-8 h-8 rounded-full bg-gradient-to-br from-violet-500 to-purple-500 flex items-center justify-center text-xs font-bold ring-2 ring-background"
                          title={`Player ${idx + 1}`}
                        >
                          P{idx + 1}
                        </div>
                      ))}
                      {g.users.length > 4 && (
                        <div className="w-8 h-8 rounded-full bg-muted flex items-center justify-center text-xs font-medium ring-2 ring-background">
                          +{g.users.length - 4}
                        </div>
                      )}
                    </div>
                  </div>

                  <div className="flex items-center gap-2">
                    <Button
                      onClick={() => handleJoinGame(g.game.id)}
                      className="flex-1 bg-gradient-to-r from-violet-600 to-purple-600"
                    >
                      Rejoin Game
                      <ArrowRight className="w-4 h-4 ml-2" />
                    </Button>
                    <Button
                      onClick={() => handleLeaveGame(g.game.id)}
                      variant="ghost"
                      size="icon"
                      disabled={leavingGameId === g.game.id}
                      className="text-red-400 hover:text-red-300 hover:bg-red-500/10"
                      title="Leave game"
                    >
                      {leavingGameId === g.game.id ? (
                        <RefreshCw className="w-4 h-4 animate-spin" />
                      ) : (
                        <LogOut className="w-4 h-4" />
                      )}
                    </Button>
                  </div>
                </div>
              ))}
            </div>
          )}
        </section>

        {/* Available Games */}
        <section className={cn("transition-opacity duration-300", refreshing && "opacity-50")}>
          <div className="flex items-center justify-between gap-3 mb-4">
            <div className="flex items-center gap-3">
              <div className="w-10 h-10 rounded-lg bg-gradient-to-br from-blue-500 to-cyan-500 flex items-center justify-center">
                <Users className="w-5 h-5 text-white" />
              </div>
              <div>
                <h2 className="text-xl font-semibold">Available Games</h2>
                <p className="text-sm text-muted-foreground">Join an existing session</p>
              </div>
            </div>
            {myActiveGames.length > 0 && (
              <div className="flex items-center gap-2 px-3 py-1.5 rounded-lg bg-amber-500/10 border border-amber-500/20">
                <AlertCircle className="w-4 h-4 text-amber-400" />
                <span className="text-xs text-amber-400 font-medium">Leave your game to join another</span>
              </div>
            )}
          </div>

          {loadingGames ? (
            <div className="glass-card rounded-2xl p-12 text-center">
              <div className="w-12 h-12 mx-auto mb-4 rounded-full bg-primary/20 animate-pulse flex items-center justify-center">
                <Sparkles className="w-6 h-6 text-primary" />
              </div>
              <p className="text-muted-foreground">Looking for games...</p>
            </div>
          ) : availableGames.length === 0 ? (
            <div className="glass-card rounded-2xl p-12 text-center">
              <div className="w-16 h-16 mx-auto mb-4 rounded-full bg-blue-500/10 flex items-center justify-center">
                <Users className="w-8 h-8 text-blue-400" />
              </div>
              <p className="text-lg font-medium mb-2">No games available</p>
              <p className="text-sm text-muted-foreground">
                Be the first to create a game for others to join!
              </p>
            </div>
          ) : (
            <div className="grid gap-4 md:grid-cols-2 lg:grid-cols-3">
              {availableGames.map((gameWithUsers) => (
                <div
                  key={gameWithUsers.game.id}
                  className="glass-card rounded-2xl p-5 hover:bg-white/5 transition-all"
                >
                  <div className={myActiveGames.length > 0 ? "" : "mb-4"}>
                    <h3 className="text-lg font-semibold mb-1">Game #{gameWithUsers.game.id.slice(0, 8)}</h3>
                    <div className="flex items-center gap-3 text-sm text-muted-foreground">
                      <span className="flex items-center gap-1">
                        <Users className="w-4 h-4" />
                        {gameWithUsers.users.length} player{gameWithUsers.users.length !== 1 && "s"}
                      </span>
                      <span className="flex items-center gap-1">
                        <Heart className="w-4 h-4" />
                        {gameWithUsers.game.startingLife} life
                      </span>
                    </div>
                  </div>

                  {/* Player Avatars - only show when join button is visible */}
                  {myActiveGames.length === 0 && (
                    <div className="flex items-center gap-2 mb-4">
                      <div className="flex -space-x-2">
                        {gameWithUsers.users.slice(0, 3).map((u, idx) => (
                          <div
                            key={u.clerkUserId}
                            className="w-7 h-7 rounded-full bg-gradient-to-br from-blue-500 to-cyan-500 flex items-center justify-center text-xs font-bold ring-2 ring-background"
                            title={`Player ${idx + 1}`}
                          >
                            P{idx + 1}
                          </div>
                        ))}
                        {gameWithUsers.users.length > 3 && (
                          <div className="w-7 h-7 rounded-full bg-muted flex items-center justify-center text-xs font-medium ring-2 ring-background">
                            +{gameWithUsers.users.length - 3}
                          </div>
                        )}
                      </div>
                    </div>
                  )}

                  {myActiveGames.length === 0 && (
                    <Button
                      onClick={() => handleJoinGame(gameWithUsers.game.id)}
                      variant="outline"
                      className="w-full glass hover:bg-white/10"
                    >
                      Join Game
                      <ArrowRight className="w-4 h-4 ml-2" />
                    </Button>
                  )}
                </div>
              ))}
            </div>
          )}
        </section>
      </div>

      {/* Create Game Dialog */}
      <Dialog open={showCreateDialog} onOpenChange={setShowCreateDialog}>
        <DialogContent className="sm:max-w-[425px]">
          <DialogHeader>
            <DialogTitle className="text-xl">Create New Game</DialogTitle>
            <DialogDescription>
              Set up your Commander session with your preferred starting life total.
            </DialogDescription>
          </DialogHeader>
          <div className="space-y-6 py-4">
            <div className="space-y-2">
              <Label htmlFor="life" className="text-sm font-medium">
                Starting Life
              </Label>
              <Input
                id="life"
                type="number"
                value={startingLifeInput}
                onChange={(e) => setStartingLifeInput(e.target.value)}
                min={1}
                max={999}
              />
              {startingLifeError && (
                <p className="text-sm text-red-400">{startingLifeError}</p>
              )}
              <p className="text-xs text-muted-foreground">
                Standard Commander uses 40 life
              </p>
            </div>
          </div>
          <DialogFooter className="gap-2">
            <Button
              variant="ghost"
              onClick={() => setShowCreateDialog(false)}
              disabled={creatingGame}
            >
              Cancel
            </Button>
            <Button
              onClick={handleCreateGame}
              disabled={creatingGame}
              className="bg-gradient-to-r from-violet-600 to-purple-600"
            >
              {creatingGame ? (
                <>
                  <RefreshCw className="w-4 h-4 mr-2 animate-spin" />
                  Creating...
                </>
              ) : (
                <>
                  <Plus className="w-4 h-4 mr-2" />
                  Create Game
                </>
              )}
            </Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>
    </div>
  );
}
