"use client";

import { cn } from "@/lib/utils";
import type { ReactNode } from "react";

interface GameLayoutProps {
  playerCount: number;
  children: ReactNode;
}

/**
 * Responsive game layout grid that fits all players without scrolling.
 * 
 * Mobile layouts (portrait):
 * - 1 player:  1x1
 * - 2 players: 2x1 (stacked vertically)
 * - 3 players: 2 top + 1 bottom
 * - 4 players: 2x2
 * - 5 players: 2x2 + 1 bottom
 * - 6 players: 2x3
 * - 7 players: 2x3 + 1 bottom
 * - 8 players: 2x4
 * 
 * Desktop layouts:
 * - 1-2 players: centered with max-width
 * - 3-4 players: 2x2 or flexible
 * - 5-6 players: 2x3 or 3x2
 * - 7-8 players: 2x4 or 4x2
 */
export function GameLayout({ playerCount, children }: GameLayoutProps) {
  const getGridClasses = () => {
    // Base mobile classes - always 2 columns for multi-player
    const baseClasses = "grid gap-2 md:gap-4 w-full h-full";
    
    switch (playerCount) {
      case 1:
        return cn(baseClasses, "grid-cols-1 max-w-lg mx-auto");
      
      case 2:
        // Mobile: stacked, Desktop: side by side
        return cn(baseClasses, "grid-cols-1 md:grid-cols-2 max-w-4xl mx-auto");
      
      case 3:
        // Mobile: 2 top, 1 bottom centered
        // Desktop: 3 columns
        return cn(
          baseClasses,
          "grid-cols-2 md:grid-cols-3",
          "[&>*:last-child]:col-span-2 md:[&>*:last-child]:col-span-1"
        );
      
      case 4:
        // 2x2 on both mobile and desktop
        return cn(baseClasses, "grid-cols-2");
      
      case 5:
        // Mobile: 2x2 + 1 centered bottom
        // Desktop: better arrangement
        return cn(
          baseClasses,
          "grid-cols-2 lg:grid-cols-3",
          "[&>*:last-child]:col-span-2 lg:[&>*:last-child]:col-span-1"
        );
      
      case 6:
        // 2x3 on mobile, 3x2 on desktop
        return cn(baseClasses, "grid-cols-2 lg:grid-cols-3");
      
      case 7:
        // Mobile: 2x3 + 1 centered
        // Desktop: more flexible
        return cn(
          baseClasses,
          "grid-cols-2 lg:grid-cols-4",
          "[&>*:last-child]:col-span-2 lg:[&>*:last-child]:col-span-1"
        );
      
      case 8:
        // 2x4 on mobile, 4x2 on desktop
        return cn(baseClasses, "grid-cols-2 lg:grid-cols-4");
      
      default:
        return cn(baseClasses, "grid-cols-2 lg:grid-cols-4");
    }
  };

  return (
    <div className={getGridClasses()}>
      {children}
    </div>
  );
}

/**
 * Full-screen game container that ensures no scrolling on main game view.
 * Uses viewport height minus header to fit content.
 */
export function GameContainer({ children, hasWinnerBanner = false }: { children: ReactNode; hasWinnerBanner?: boolean }) {
  return (
    <div
      className={cn(
        "flex flex-col",
        // Account for header height and optional winner banner
        hasWinnerBanner
          ? "min-h-[calc(100vh-112px)] md:min-h-[calc(100vh-120px)]"
          : "min-h-[calc(100vh-56px)] md:min-h-[calc(100vh-64px)]"
      )}
    >
      <div className="flex-1 p-2 md:p-4 lg:p-6">
        {children}
      </div>
    </div>
  );
}
