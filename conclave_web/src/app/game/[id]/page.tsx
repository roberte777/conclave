import { auth } from "@clerk/nextjs/server";
import { redirect } from "next/navigation";
import { GamePageClient } from "@/components/game-page";

export default async function GamePage({ params }: { params: Promise<{ id: string }> }) {
  const { userId } = await auth();
  const { id } = await params;

  if (!userId) {
    redirect("/");
  }

  // clerkUserId is now obtained from JWT token in the client component
  return <GamePageClient gameId={id} />;
}