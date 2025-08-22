"use client";

import { useState, useEffect, useCallback } from "react";
import { useUser } from "@clerk/nextjs";
import { Button } from "@/components/ui/button";
import {
  Card,
  CardContent,
  CardDescription,
  CardHeader,
  CardTitle,
} from "@/components/ui/card";
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
import { Plus, Users, Trophy } from "lucide-react";
import { ConclaveAPI, type GameWithUsers, DEFAULT_STARTING_LIFE } from "@/lib/api";
import { useMemo } from "react";

export function UserDashboard() {
  const { user } = useUser();
  const [creatingGame, setCreatingGame] = useState(false);
  const [myActiveGames, setMyActiveGames] = useState<GameWithUsers[]>([]);
  const [availableGames, setAvailableGames] = useState<GameWithUsers[]>([]);
  const [loadingGames, setLoadingGames] = useState(true);
  const [showCreateDialog, setShowCreateDialog] = useState(false);
  const [gameName, setGameName] = useState("");
  const [startingLifeInput, setStartingLifeInput] = useState(String(DEFAULT_STARTING_LIFE));
  const [startingLifeError, setStartingLifeError] = useState<string | null>(null);
  const [leavingGameId, setLeavingGameId] = useState<string | null>(null);

  const api = useMemo(() => {
    const base = process.env.NEXT_PUBLIC_API_URL || "http://localhost:3001";
    return new ConclaveAPI({ httpUrl: `${base}/api/v1` });
  }, []);

  const refreshGames = useCallback(async () => {
    if (!user?.id) return;

    setLoadingGames(true);
    try {
      const [userGames, joinableGames] = await Promise.all([
        api.http.getUserGames(user.id),
        api.http.getAvailableGames(user.id),
      ]);
      setMyActiveGames(userGames.filter((g) => g.game.status === "active"));
      setAvailableGames(joinableGames);
    } catch (error) {
      console.error("Failed to fetch active games:", error);
    } finally {
      setLoadingGames(false);
    }
  }, [api, user?.id]);

  useEffect(() => {
    refreshGames();
  }, [refreshGames]);

  const handleCreateGame = async () => {
    if (!user?.id || !gameName.trim()) return;
    setStartingLifeError(null);

    const parsedLife = parseInt(startingLifeInput, 10);
    if (!Number.isFinite(parsedLife) || parsedLife < 1 || parsedLife > 999) {
      setStartingLifeError("Starting life must be a number between 1 and 999");
      return;
    }

    setCreatingGame(true);
    try {
      const game = await api.http.createGame({
        clerkUserId: user.id,
        name: gameName,
        startingLife: parsedLife,
      });

      setShowCreateDialog(false);
      setGameName("");
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
    setGameName(`${user?.firstName || user?.username || "Player"}'s Game`);
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
      await api.http.leaveGame(gameId, user.id);
      await refreshGames();
    } catch (error) {
      console.error("Failed to leave game:", error);
    } finally {
      setLeavingGameId(null);
    }
  };

  return (
    <div className="container mx-auto px-4 py-8 max-w-6xl">
      <div className="mb-8">
        <h1 className="text-3xl font-bold mb-2">
          Welcome back, {user?.firstName || user?.username || "Player"}!
        </h1>
      </div>

      <div className="mb-6">
        <Button
          className="mb-6"
          size="lg"
          onClick={openCreateDialog}
          disabled={myActiveGames.length > 0}
          title={myActiveGames.length > 0 ? "You already have an active game" : undefined}
        >
          <Plus className="w-4 h-4 mr-2" />
          {myActiveGames.length > 0 ? "Active Game In Progress" : "Create New Game"}
        </Button>
      </div>

      <Dialog open={showCreateDialog} onOpenChange={setShowCreateDialog}>
        <DialogContent className="sm:max-w-[425px]">
          <DialogHeader>
            <DialogTitle>Create New Game</DialogTitle>
            <DialogDescription>
              Set up your game settings. You can customize the game name and starting life total.
            </DialogDescription>
          </DialogHeader>
          <div className="grid gap-4 py-4">
            <div className="grid grid-cols-4 items-center gap-4">
              <Label htmlFor="name" className="text-right">
                Game Name
              </Label>
              <Input
                id="name"
                value={gameName}
                onChange={(e) => setGameName(e.target.value)}
                className="col-span-3"
                placeholder="Enter game name"
              />
            </div>
            <div className="grid grid-cols-4 items-center gap-4">
              <Label htmlFor="life" className="text-right">
                Starting Life
              </Label>
              <div className="col-span-3 space-y-2">
                <Input
                  id="life"
                  type="number"
                  value={startingLifeInput}
                  onChange={(e) => setStartingLifeInput(e.target.value)}
                  min={1}
                  max={999}
                />
                {startingLifeError ? (
                  <p className="text-sm text-red-500">{startingLifeError}</p>
                ) : null}
              </div>
            </div>
          </div>
          <DialogFooter>
            <Button
              variant="outline"
              onClick={() => setShowCreateDialog(false)}
              disabled={creatingGame}
            >
              Cancel
            </Button>
            <Button onClick={handleCreateGame} disabled={creatingGame || !gameName.trim()}>
              {creatingGame ? "Creating..." : "Create Game"}
            </Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>

      <div className="grid gap-6">
        <Card>
          <CardHeader>
            <CardTitle className="flex items-center gap-2">
              <Users className="w-5 h-5" />
              Your Active Games
            </CardTitle>
            <CardDescription>Games you are currently in</CardDescription>
          </CardHeader>
          <CardContent>
            {loadingGames ? (
              <div className="text-center py-8 text-muted-foreground">
                Loading games...
              </div>
            ) : myActiveGames.length === 0 ? (
              <div className="text-center py-8 text-muted-foreground">
                <Trophy className="w-12 h-12 mx-auto mb-4 opacity-50" />
                <p>You have no active games</p>
              </div>
            ) : (
              <div className="space-y-3">
                {myActiveGames.map((g) => (
                  <div
                    key={g.game.id}
                    className="flex items-center justify-between p-4 border rounded-lg hover:bg-accent/50 transition-colors"
                  >
                    <div>
                      <h3 className="font-medium">{g.game.name}</h3>
                      <p className="text-sm text-muted-foreground">
                        {g.users.length} {g.users.length === 1 ? "player" : "players"}
                      </p>
                    </div>
                    <div className="flex items-center gap-2">
                      <Button
                        onClick={() => handleJoinGame(g.game.id)}
                        variant="default"
                        size="sm"
                      >
                        Rejoin
                      </Button>
                      <Button
                        onClick={() => handleLeaveGame(g.game.id)}
                        variant="outline"
                        size="sm"
                        disabled={leavingGameId === g.game.id}
                      >
                        {leavingGameId === g.game.id ? "Leaving..." : "Leave"}
                      </Button>
                    </div>
                  </div>
                ))}
              </div>
            )}
          </CardContent>
        </Card>

        <Card>
          <CardHeader>
            <CardTitle className="flex items-center gap-2">
              <Users className="w-5 h-5" />
              Available Games
            </CardTitle>
            <CardDescription>Join an existing game</CardDescription>
          </CardHeader>
          <CardContent>
            {loadingGames ? (
              <div className="text-center py-8 text-muted-foreground">
                Loading games...
              </div>
            ) : availableGames.length === 0 ? (
              <div className="text-center py-8 text-muted-foreground">
                <Trophy className="w-12 h-12 mx-auto mb-4 opacity-50" />
                <p>No available games right now</p>
                <p className="text-sm mt-2">You can create a new game when you leave your current one.</p>
              </div>
            ) : (
              <div className="space-y-3">
                {availableGames.map((gameWithUsers) => (
                  <div
                    key={gameWithUsers.game.id}
                    className="flex items-center justify-between p-4 border rounded-lg hover:bg-accent/50 transition-colors"
                  >
                    <div>
                      <h3 className="font-medium">{gameWithUsers.game.name}</h3>
                      <p className="text-sm text-muted-foreground">
                        {gameWithUsers.users.length} {gameWithUsers.users.length === 1 ? "player" : "players"}
                      </p>
                    </div>
                    <Button
                      onClick={() => handleJoinGame(gameWithUsers.game.id)}
                      variant="outline"
                      size="sm"
                    >
                      Join
                    </Button>
                  </div>
                ))}
              </div>
            )}
          </CardContent>
        </Card>
      </div>
    </div>
  );
}

