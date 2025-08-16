import { auth } from "@clerk/nextjs/server";
import { redirect } from "next/navigation";
import { GamePageClient } from "@/components/game-page";

export default async function GamePage({ params }: { params: Promise<{ id: string }> }) {
  const { userId } = await auth();
  const { id } = await params;

  if (!userId) {
    redirect("/");
  }

  return <GamePageClient gameId={id} clerkUserId={userId!} />;
}