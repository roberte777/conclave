"use client";

import { useEffect, useMemo, useState } from "react";
import { useUser, SignedIn, SignedOut, SignInButton } from "@clerk/nextjs";
import { ConclaveAPI, type GameHistory, type GameWithPlayers } from "@/lib/api";
import Link from "next/link";

export default function HistoryPage() {
  const { user, isLoaded } = useUser();
  const [history, setHistory] = useState<GameHistory | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  const api = useMemo(() => {
    const base = process.env.NEXT_PUBLIC_API_URL || "http://localhost:3001";
    return new ConclaveAPI({ httpUrl: `${base}/api/v1` });
  }, []);

  useEffect(() => {
    const fetchHistory = async () => {
      if (!user?.id) return;
      setLoading(true);
      setError(null);
      try {
        const h = await api.http.getUserHistory(user.id);
        setHistory(h);
      } catch (e) {
        setError((e as Error).message || "Failed to load history");
      } finally {
        setLoading(false);
      }
    };
    if (isLoaded && user?.id) {
      fetchHistory();
    }
  }, [api, isLoaded, user?.id]);

  const renderGameRow = (g: GameWithPlayers) => {
    const finishedAt = g.game.finishedAt ? new Date(g.game.finishedAt).toLocaleString() : "";
    const winner = g.winner ? g.winner.clerkUserId : null;
    return (
      <div key={g.game.id} className="flex items-center justify-between p-4 border rounded-lg hover:bg-accent/50 transition-colors">
        <div className="min-w-0">
          <div className="font-medium truncate">{g.game.name}</div>
          <div className="text-sm text-muted-foreground">
            {g.players.length} {g.players.length === 1 ? "player" : "players"}
            {finishedAt ? ` • Finished ${finishedAt}` : null}
            {winner ? ` • Winner: ${winner}` : null}
          </div>
        </div>
        <div className="flex items-center gap-2">
          <Link href={`/game/${g.game.id}`} className="text-sm underline">
            View
          </Link>
        </div>
      </div>
    );
  };

  return (
    <div className="container mx-auto px-4 py-8 max-w-4xl">
      <h1 className="text-3xl font-bold mb-6">Match History</h1>

      <SignedOut>
        <div className="p-6 border rounded-lg">
          <p className="mb-4">Please sign in to view your match history.</p>
          <SignInButton mode="modal">
            <button className="bg-primary text-primary-foreground rounded-md font-medium text-sm h-9 px-4 hover:bg-primary/90 transition-colors">
              Sign In
            </button>
          </SignInButton>
        </div>
      </SignedOut>

      <SignedIn>
        {loading ? (
          <div className="text-muted-foreground">Loading…</div>
        ) : error ? (
          <div className="text-red-600">{error}</div>
        ) : !history || history.games.length === 0 ? (
          <div className="text-muted-foreground">No finished games yet.</div>
        ) : (
          <div className="space-y-3">
            {history.games.map(renderGameRow)}
          </div>
        )}
      </SignedIn>
    </div>
  );
}