import { SignInButton } from "@clerk/nextjs";
import { Button } from "@/components/ui/button";
import { Card } from "@/components/ui/card";
import { Users, Zap, Shield, Smartphone } from "lucide-react";

export function LandingPage() {
  return (
    <div className="min-h-screen bg-gradient-to-b from-background to-muted/20">
      <div className="container mx-auto px-4 py-16">
        <div className="text-center mb-16">
          <h1 className="text-5xl font-bold mb-4 bg-gradient-to-r from-primary to-primary/60 bg-clip-text text-transparent">
            Conclave
          </h1>
          <p className="text-xl text-muted-foreground mb-8 max-w-2xl mx-auto">
            The ultimate real-time multiplayer life tracker for Magic: The Gathering.
            Track life totals, manage games, and sync across all your devices.
          </p>
          <div className="flex gap-4 justify-center">
            <SignInButton>
              <Button size="lg" className="font-semibold">
                Get Started
              </Button>
            </SignInButton>
            <SignInButton>
              <Button size="lg" variant="outline">
                Sign In
              </Button>
            </SignInButton>
          </div>
        </div>

        <div className="grid md:grid-cols-2 lg:grid-cols-4 gap-6 mb-16">
          <Card className="p-6 text-center">
            <Users className="w-12 h-12 mx-auto mb-4 text-primary" />
            <h3 className="font-semibold mb-2">Multiplayer Support</h3>
            <p className="text-sm text-muted-foreground">
              Support for up to 8 players in a single game
            </p>
          </Card>
          <Card className="p-6 text-center">
            <Zap className="w-12 h-12 mx-auto mb-4 text-primary" />
            <h3 className="font-semibold mb-2">Real-time Sync</h3>
            <p className="text-sm text-muted-foreground">
              Instant updates across all connected devices
            </p>
          </Card>
          <Card className="p-6 text-center">
            <Shield className="w-12 h-12 mx-auto mb-4 text-primary" />
            <h3 className="font-semibold mb-2">Game History</h3>
            <p className="text-sm text-muted-foreground">
              Complete audit trail of all life changes
            </p>
          </Card>
          <Card className="p-6 text-center">
            <Smartphone className="w-12 h-12 mx-auto mb-4 text-primary" />
            <h3 className="font-semibold mb-2">Cross-Platform</h3>
            <p className="text-sm text-muted-foreground">
              Web, iOS, and mobile-responsive design
            </p>
          </Card>
        </div>

        <Card className="p-8 max-w-4xl mx-auto">
          <h2 className="text-2xl font-bold mb-4 text-center">How It Works</h2>
          <div className="space-y-4">
            <div className="flex items-start gap-4">
              <div className="w-8 h-8 rounded-full bg-primary/10 flex items-center justify-center flex-shrink-0">
                <span className="text-sm font-semibold text-primary">1</span>
              </div>
              <div>
                <h3 className="font-semibold mb-1">Create a Game</h3>
                <p className="text-sm text-muted-foreground">
                  Start a new game and get a unique game code to share with your friends
                </p>
              </div>
            </div>
            <div className="flex items-start gap-4">
              <div className="w-8 h-8 rounded-full bg-primary/10 flex items-center justify-center flex-shrink-0">
                <span className="text-sm font-semibold text-primary">2</span>
              </div>
              <div>
                <h3 className="font-semibold mb-1">Invite Players</h3>
                <p className="text-sm text-muted-foreground">
                  Players join using the game code or direct link
                </p>
              </div>
            </div>
            <div className="flex items-start gap-4">
              <div className="w-8 h-8 rounded-full bg-primary/10 flex items-center justify-center flex-shrink-0">
                <span className="text-sm font-semibold text-primary">3</span>
              </div>
              <div>
                <h3 className="font-semibold mb-1">Track Life Totals</h3>
                <p className="text-sm text-muted-foreground">
                  Update life totals in real-time, visible to all players instantly
                </p>
              </div>
            </div>
            <div className="flex items-start gap-4">
              <div className="w-8 h-8 rounded-full bg-primary/10 flex items-center justify-center flex-shrink-0">
                <span className="text-sm font-semibold text-primary">4</span>
              </div>
              <div>
                <h3 className="font-semibold mb-1">End Game & Review</h3>
                <p className="text-sm text-muted-foreground">
                  Automatic winner determination and full game history available
                </p>
              </div>
            </div>
          </div>
        </Card>
      </div>
    </div>
  );
}