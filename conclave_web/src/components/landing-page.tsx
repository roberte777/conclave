"use client";

import { useState, useEffect } from "react";
import { SignInButton } from "@clerk/nextjs";
import { Button } from "@/components/ui/button";
import {
  Users,
  Zap,
  Shield,
  Smartphone,
  Sparkles,
  Heart,
  Swords,
  Crown,
  ArrowRight,
  Github,
} from "lucide-react";

export function LandingPage() {
  const [mounted, setMounted] = useState(false);

  useEffect(() => {
    setMounted(true);
  }, []);

  return (
    <div className="min-h-screen bg-gradient-mesh overflow-hidden">
      {/* Hero Section */}
      <section className="relative pt-20 pb-32 px-4">
        {/* Animated background elements */}
        <div className="absolute inset-0 overflow-hidden pointer-events-none">
          <div className="absolute top-20 left-10 w-72 h-72 bg-violet-500/20 rounded-full blur-3xl animate-float" />
          <div className="absolute top-40 right-20 w-96 h-96 bg-blue-500/15 rounded-full blur-3xl animate-float" style={{ animationDelay: "2s" }} />
          <div className="absolute bottom-20 left-1/3 w-80 h-80 bg-pink-500/10 rounded-full blur-3xl animate-float" style={{ animationDelay: "4s" }} />
        </div>

        <div className="max-w-6xl mx-auto relative">
          {/* Badge */}
          <div className={`flex justify-center mb-8 transition-all duration-500 ${mounted ? "opacity-100 translate-y-0" : "opacity-0 translate-y-4"}`}>
            <div className="glass-card rounded-full px-4 py-2 flex items-center gap-2 text-sm">
              <Sparkles className="w-4 h-4 text-violet-400" />
              <span className="text-muted-foreground">Real-time multiplayer life tracking</span>
            </div>
          </div>

          {/* Main Headline */}
          <h1 className={`text-5xl md:text-7xl lg:text-8xl font-black text-center mb-6 transition-all duration-500 delay-100 ${mounted ? "opacity-100 translate-y-0" : "opacity-0 translate-y-4"}`}>
            <span className="bg-gradient-to-r from-violet-400 via-purple-400 to-pink-400 bg-clip-text text-transparent animate-gradient">
              Conclave
            </span>
          </h1>

          {/* Subheadline */}
          <p className={`text-xl md:text-2xl text-center text-muted-foreground max-w-3xl mx-auto mb-10 transition-all duration-500 delay-200 ${mounted ? "opacity-100 translate-y-0" : "opacity-0 translate-y-4"}`}>
            The ultimate life tracker for Magic: The Gathering.
            <span className="block mt-2 text-foreground/80">
              Track life, commander damage, and win in style.
            </span>
          </p>

          {/* CTA Buttons */}
          <div className={`flex flex-col sm:flex-row gap-4 justify-center items-center mb-20 transition-all duration-500 delay-300 ${mounted ? "opacity-100 translate-y-0" : "opacity-0 translate-y-4"}`}>
            <SignInButton mode="modal">
              <Button size="lg" className="h-14 px-8 text-lg font-semibold bg-gradient-to-r from-violet-600 to-purple-600 hover:from-violet-500 hover:to-purple-500 shadow-lg shadow-violet-500/25 transition-all hover:shadow-xl hover:shadow-violet-500/30 hover:scale-105">
                Get Started Free
                <ArrowRight className="w-5 h-5 ml-2" />
              </Button>
            </SignInButton>
            <SignInButton mode="modal">
              <Button size="lg" variant="outline" className="h-14 px-8 text-lg font-semibold glass-card hover:bg-white/10">
                Sign In
              </Button>
            </SignInButton>
          </div>

          {/* Hero Visual - Life Counter Preview */}
          <div className={`relative transition-all duration-500 delay-[400ms] ${mounted ? "opacity-100 translate-y-0" : "opacity-0 translate-y-4"}`}>
            <div className="absolute inset-0 bg-gradient-to-t from-background via-transparent to-transparent z-10 pointer-events-none" />
            <div className="glass-card rounded-3xl p-6 md:p-8 max-w-4xl mx-auto overflow-hidden">
              <div className="grid grid-cols-2 md:grid-cols-4 gap-4">
                {/* Sample Player Cards */}
                {[
                  { name: "Player 1", life: 40, color: "from-violet-500/30 to-purple-600/10 border-violet-500/30" },
                  { name: "Player 2", life: 38, color: "from-blue-500/30 to-cyan-600/10 border-blue-500/30" },
                  { name: "Player 3", life: 32, color: "from-emerald-500/30 to-green-600/10 border-emerald-500/30" },
                  { name: "Player 4", life: 25, color: "from-amber-500/30 to-orange-600/10 border-amber-500/30" },
                ].map((player, i) => (
                  <div
                    key={i}
                    className={`bg-gradient-to-br ${player.color} rounded-2xl border p-4 md:p-6 text-center backdrop-blur-xl transition-all duration-500`}
                    style={{
                      transitionDelay: `${500 + i * 100}ms`,
                      opacity: mounted ? 1 : 0,
                      transform: mounted ? "translateY(0)" : "translateY(16px)"
                    }}
                  >
                    <div className="text-sm text-muted-foreground mb-2">{player.name}</div>
                    <div className="text-4xl md:text-5xl font-black">{player.life}</div>
                    <div className="text-xs text-muted-foreground mt-1">Life</div>
                  </div>
                ))}
              </div>
            </div>
          </div>
        </div>
      </section>

      {/* Features Section */}
      <section className="py-24 px-4 relative">
        <div className="max-w-6xl mx-auto">
          <div className="text-center mb-16">
            <h2 className="text-3xl md:text-5xl font-bold mb-4">
              Everything you need to{" "}
              <span className="bg-gradient-to-r from-violet-400 to-pink-400 bg-clip-text text-transparent">
                track your games
              </span>
            </h2>
            <p className="text-lg text-muted-foreground max-w-2xl mx-auto">
              Built for Commander players who want a beautiful, fast, and reliable way to keep score.
            </p>
          </div>

          <div className="grid md:grid-cols-2 lg:grid-cols-4 gap-6">
            {[
              {
                icon: Users,
                title: "Up to 8 Players",
                description: "Perfect for Commander pods of any size",
                gradient: "from-violet-500 to-purple-500",
              },
              {
                icon: Zap,
                title: "Real-time Sync",
                description: "Changes appear instantly on all devices",
                gradient: "from-blue-500 to-cyan-500",
              },
              {
                icon: Swords,
                title: "Commander Damage",
                description: "Track damage from each commander with partners",
                gradient: "from-orange-500 to-red-500",
              },
              {
                icon: Smartphone,
                title: "Cross-Platform",
                description: "Works on web, iOS, and any device",
                gradient: "from-emerald-500 to-green-500",
              },
            ].map((feature, i) => (
              <div
                key={i}
                className="glass-card rounded-2xl p-6 group hover:scale-105 transition-all duration-300"
              >
                <div className={`w-14 h-14 rounded-xl bg-gradient-to-br ${feature.gradient} flex items-center justify-center mb-4 shadow-lg group-hover:shadow-xl transition-shadow`}>
                  <feature.icon className="w-7 h-7 text-white" />
                </div>
                <h3 className="text-lg font-semibold mb-2">{feature.title}</h3>
                <p className="text-sm text-muted-foreground">{feature.description}</p>
              </div>
            ))}
          </div>
        </div>
      </section>

      {/* How It Works Section */}
      <section className="py-24 px-4 relative">
        <div className="absolute inset-0 bg-gradient-to-b from-transparent via-violet-500/5 to-transparent pointer-events-none" />
        <div className="max-w-4xl mx-auto relative">
          <div className="text-center mb-16">
            <h2 className="text-3xl md:text-5xl font-bold mb-4">
              Start playing in{" "}
              <span className="bg-gradient-to-r from-violet-400 to-pink-400 bg-clip-text text-transparent">
                seconds
              </span>
            </h2>
          </div>

          <div className="space-y-8">
            {[
              {
                step: 1,
                icon: Heart,
                title: "Create a Game",
                description: "Set your starting life and share the link with your playgroup",
              },
              {
                step: 2,
                icon: Users,
                title: "Players Join",
                description: "Everyone connects and sees the same game state in real-time",
              },
              {
                step: 3,
                icon: Swords,
                title: "Track Everything",
                description: "Tap to adjust life, track commander damage, toggle partners",
              },
              {
                step: 4,
                icon: Crown,
                title: "Crown the Winner",
                description: "End the game and see who came out on top",
              },
            ].map((item, i) => (
              <div
                key={i}
                className="flex items-start gap-6 glass-card rounded-2xl p-6 hover:bg-white/5 transition-colors"
              >
                <div className="flex-shrink-0 w-12 h-12 rounded-xl bg-gradient-to-br from-violet-500 to-purple-500 flex items-center justify-center font-bold text-lg shadow-lg">
                  {item.step}
                </div>
                <div className="flex-1">
                  <div className="flex items-center gap-3 mb-2">
                    <item.icon className="w-5 h-5 text-violet-400" />
                    <h3 className="text-xl font-semibold">{item.title}</h3>
                  </div>
                  <p className="text-muted-foreground">{item.description}</p>
                </div>
              </div>
            ))}
          </div>
        </div>
      </section>

      {/* CTA Section */}
      <section className="py-24 px-4 relative">
        <div className="max-w-4xl mx-auto">
          <div className="glass-card rounded-3xl p-8 md:p-12 text-center relative overflow-hidden">
            {/* Background decoration */}
            <div className="absolute inset-0 bg-gradient-to-br from-violet-500/10 via-transparent to-pink-500/10 pointer-events-none" />

            <div className="relative">
              <Shield className="w-16 h-16 mx-auto mb-6 text-violet-400" />
              <h2 className="text-3xl md:text-4xl font-bold mb-4">
                Ready to elevate your games?
              </h2>
              <p className="text-lg text-muted-foreground mb-8 max-w-xl mx-auto">
                Join thousands of Commander players who use Conclave to track their games. Free forever.
              </p>
              <SignInButton mode="modal">
                <Button size="lg" className="h-14 px-10 text-lg font-semibold bg-gradient-to-r from-violet-600 to-purple-600 hover:from-violet-500 hover:to-purple-500 shadow-lg shadow-violet-500/25 transition-all hover:shadow-xl hover:shadow-violet-500/30 hover:scale-105">
                  Start Tracking Now
                  <Sparkles className="w-5 h-5 ml-2" />
                </Button>
              </SignInButton>
            </div>
          </div>
        </div>
      </section>

      {/* Footer */}
      <footer className="py-12 px-4 border-t border-white/10">
        <div className="max-w-6xl mx-auto flex flex-col md:flex-row items-center justify-between gap-4">
          <div className="flex items-center gap-2">
            <span className="text-xl font-bold bg-gradient-to-r from-violet-400 to-pink-400 bg-clip-text text-transparent">
              Conclave
            </span>
            <span className="text-muted-foreground text-sm">
              MTG Life Tracker
            </span>
          </div>
          <div className="flex items-center gap-6 text-sm text-muted-foreground">
            <a
              href="https://github.com"
              target="_blank"
              rel="noopener noreferrer"
              className="flex items-center gap-2 hover:text-foreground transition-colors"
            >
              <Github className="w-4 h-4" />
              Open Source
            </a>
            <span>Built with ❤️ for MTG players</span>
          </div>
        </div>
      </footer>
    </div>
  );
}
