import { auth } from "@clerk/nextjs/server";
import { LandingPage } from "@/components/landing-page";
import { UserDashboard } from "@/components/user-dashboard";
import { AuthRedirectHandler } from "@/components/auth-redirect-handler";

export default async function Home() {
  const { userId } = await auth();

  if (!userId) {
    return <LandingPage />;
  }

  return (
    <>
      <AuthRedirectHandler />
      <UserDashboard />
    </>
  );
}