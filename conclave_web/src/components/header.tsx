"use client";

import {
  SignInButton,
  SignUpButton,
  SignedIn,
  SignedOut,
  UserButton,
} from "@clerk/nextjs";
import Link from "next/link";
import { usePathname } from "next/navigation";
import { Sparkles, Trophy, Home } from "lucide-react";

export function Header() {
  const pathname = usePathname();

  return (
    <header className="glass border-b border-white/10">
      <div className="max-w-7xl mx-auto px-4 h-16 flex items-center justify-between">
        {/* Logo & Navigation */}
        <div className="flex items-center gap-6">
          <Link href="/" className="flex items-center gap-2 group">
            <div className="w-8 h-8 rounded-lg bg-gradient-to-br from-violet-500 to-purple-500 flex items-center justify-center shadow-lg group-hover:shadow-violet-500/30 transition-shadow">
              <Sparkles className="w-4 h-4 text-white" />
            </div>
            <span className="text-xl font-bold bg-gradient-to-r from-violet-400 via-purple-400 to-pink-400 bg-clip-text text-transparent">
              Conclave
            </span>
          </Link>

          <SignedIn>
            <nav className="hidden sm:flex items-center gap-1">
              <Link
                href="/"
                className={`flex items-center gap-2 px-3 py-2 text-sm font-medium rounded-lg transition-all ${pathname === "/"
                  ? "bg-violet-500/20 text-violet-300"
                  : "text-muted-foreground hover:text-foreground hover:bg-white/5"
                  }`}
              >
                <Home className="w-4 h-4" />
                Dashboard
              </Link>
              <Link
                href="/history"
                className={`flex items-center gap-2 px-3 py-2 text-sm font-medium rounded-lg transition-all ${pathname === "/history"
                  ? "bg-violet-500/20 text-violet-300"
                  : "text-muted-foreground hover:text-foreground hover:bg-white/5"
                  }`}
              >
                <Trophy className="w-4 h-4" />
                Match History
              </Link>
            </nav>
          </SignedIn>
        </div>

        {/* Auth Buttons */}
        <div className="flex items-center gap-3">
          <SignedOut>
            <SignInButton mode="modal">
              <button className="px-4 py-2 text-sm font-medium text-muted-foreground hover:text-foreground transition-colors">
                Sign In
              </button>
            </SignInButton>
            <SignUpButton mode="modal">
              <button className="px-4 py-2 text-sm font-semibold rounded-lg bg-gradient-to-r from-violet-600 to-purple-600 hover:from-violet-500 hover:to-purple-500 text-white shadow-lg shadow-violet-500/20 hover:shadow-violet-500/30 transition-all hover:scale-105">
                Get Started
              </button>
            </SignUpButton>
          </SignedOut>
          <SignedIn>
            {/* Mobile navigation */}
            <nav className="flex sm:hidden items-center gap-1 mr-2">
              <Link
                href="/"
                className={`p-2 rounded-lg transition-all ${pathname === "/"
                  ? "bg-violet-500/20 text-violet-300"
                  : "text-muted-foreground hover:text-foreground hover:bg-white/5"
                  }`}
                title="Dashboard"
              >
                <Home className="w-5 h-5" />
              </Link>
              <Link
                href="/history"
                className={`p-2 rounded-lg transition-all ${pathname === "/history"
                  ? "bg-violet-500/20 text-violet-300"
                  : "text-muted-foreground hover:text-foreground hover:bg-white/5"
                  }`}
                title="Match History"
              >
                <Trophy className="w-5 h-5" />
              </Link>
            </nav>
            <UserButton
              afterSignOutUrl="/"
              appearance={{
                elements: {
                  avatarBox:
                    "h-9 w-9 ring-2 ring-violet-500/30 hover:ring-violet-500/50 transition-all",
                },
              }}
            />
          </SignedIn>
        </div>
      </div>
    </header>
  );
}
