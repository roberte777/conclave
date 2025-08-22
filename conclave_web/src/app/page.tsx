import { SignedIn, SignedOut } from "@clerk/nextjs";
import { LandingPage } from "@/components/landing-page";
import { UserDashboard } from "@/components/user-dashboard";

export default function Home() {
  return (
    <>
      <SignedOut>
        <LandingPage />
      </SignedOut>
      <SignedIn>
        <UserDashboard />
      </SignedIn>
    </>
  );
}