import { auth } from "@clerk/nextjs/server";
import { redirect } from "next/navigation";
import { MatchHistory } from "@/components/match-history";

export default async function HistoryPage() {
  const { userId } = await auth();

  if (!userId) {
    redirect("/");
  }

  return <MatchHistory />;
}
