import { auth } from "@clerk/nextjs/server";
import { LandingPage } from "@/components/landing-page";
import { UserDashboard } from "@/components/user-dashboard";

export default async function Home() {
  const { userId } = await auth();

  if (!userId) {
    return <LandingPage />;
  }

  return <UserDashboard />;
}