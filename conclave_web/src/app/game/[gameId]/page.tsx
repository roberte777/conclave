"use client";

import { useState, useEffect } from "react";
import { useParams, useRouter } from "next/navigation";
import { gameApi } from "@/lib/api";
import { Button } from "@/components/ui/button";
import { ArrowLeft } from "lucide-react";

export default function GameRedirectPage() {
  const params = useParams();
  const router = useRouter();
  const gameId = params.gameId as string;
  const [isLoading, setIsLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    const redirectToCorrectPage = async () => {
      if (!gameId) {
        setError("No game ID provided");
        setIsLoading(false);
        return;
      }

      try {
        const gameState = await gameApi.getState(gameId);

        if (gameState.game.status === 'active') {
          router.replace(`/live-games/${gameId}`);
        } else if (gameState.game.status === 'finished') {
          router.replace(`/finished-games/${gameId}`);
        } else {
          setError(`Unknown game status: ${gameState.game.status}`);
          setIsLoading(false);
        }
      } catch (error) {
        console.error("Failed to fetch game state:", error);
        setError("Failed to load game");
        setIsLoading(false);
      }
    };

    redirectToCorrectPage();
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

  if (error) {
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

  // This should not render as we redirect above, but just in case
  return (
    <div className="container mx-auto p-6">
      <div className="text-center py-12">
        <p className="text-muted-foreground">Redirecting...</p>
      </div>
    </div>
  );
}
