import type { Metadata } from "next";
import {
  ClerkProvider,
  SignInButton,
  SignUpButton,
  SignedIn,
  SignedOut,
  UserButton,
} from "@clerk/nextjs";
import { Geist, Geist_Mono } from "next/font/google";
import "./globals.css";
import { QueryProvider } from "@/components/providers/query-provider";
import { Toaster } from "@/components/ui/sonner";

const geistSans = Geist({
  variable: "--font-geist-sans",
  subsets: ["latin"],
});

const geistMono = Geist_Mono({
  variable: "--font-geist-mono",
  subsets: ["latin"],
});

export const metadata: Metadata = {
  title: "Conclave - MTG Life Tracker",
  description: "Track life totals and manage games for Magic: The Gathering multiplayer sessions",
  keywords: ["MTG", "Magic The Gathering", "life tracker", "multiplayer", "game tracker"],
};

export default function RootLayout({
  children,
}: Readonly<{
  children: React.ReactNode;
}>) {
  return (
    <ClerkProvider>
      <html lang="en">
        <body
          className={`${geistSans.variable} ${geistMono.variable} antialiased bg-background text-foreground`}
        >
          <QueryProvider>
            <header className="border-b border-border bg-card">
              <div className="container mx-auto flex justify-between items-center p-4 h-16">
                <div className="flex items-center gap-2">
                  <h1 className="text-xl font-bold text-primary">⚔️ Conclave</h1>
                  <span className="text-sm text-muted-foreground">MTG Life Tracker</span>
                </div>
                <div className="flex items-center gap-4">
                  <SignedOut>
                    <SignInButton mode="modal">
                      <button className="text-sm hover:text-primary transition-colors">
                        Sign In
                      </button>
                    </SignInButton>
                    <SignUpButton mode="modal">
                      <button className="bg-primary text-primary-foreground hover:bg-primary/90 rounded-md font-medium text-sm h-9 px-3 transition-colors">
                        Sign Up
                      </button>
                    </SignUpButton>
                  </SignedOut>
                  <SignedIn>
                    <UserButton
                      appearance={{
                        elements: {
                          avatarBox: "h-8 w-8",
                        },
                      }}
                    />
                  </SignedIn>
                </div>
              </div>
            </header>
            <main className="min-h-[calc(100vh-4rem)]">
              {children}
            </main>
            <Toaster />
          </QueryProvider>
        </body>
      </html>
    </ClerkProvider>
  );
}
