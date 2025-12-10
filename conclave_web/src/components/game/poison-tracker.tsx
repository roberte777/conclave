"use client";

import { Skull } from "lucide-react";
import { cn } from "@/lib/utils";
import { InlineLifeControls } from "./life-controls";

interface PoisonTrackerProps {
  value: number;
  onChange: (delta: number) => void;
  disabled?: boolean;
  compact?: boolean;
}

export function PoisonTracker({
  value,
  onChange,
  disabled = false,
  compact = false,
}: PoisonTrackerProps) {
  const isLethal = value >= 10;
  const isDangerous = value >= 7;

  if (compact) {
    // Pill display for compact mode (shown in player header)
    return (
      <button
        className={cn(
          "flex items-center gap-1 px-2 py-1 rounded-full text-xs font-medium",
          "transition-all duration-150",
          value === 0 && "bg-white/5 text-muted-foreground hover:bg-white/10",
          value > 0 && !isDangerous && "bg-purple-500/20 text-purple-400",
          isDangerous && !isLethal && "bg-orange-500/20 text-orange-400",
          isLethal && "bg-red-500/30 text-red-400 animate-pulse"
        )}
        aria-label={`Poison counters: ${value}`}
      >
        <Skull className="w-3 h-3" />
        <span className="tabular-nums">{value}</span>
      </button>
    );
  }

  // Full controls for expanded view
  return (
    <div className="flex items-center gap-3">
      <div className={cn(
        "flex items-center gap-1.5 px-2 py-1 rounded-lg",
        value === 0 && "bg-white/5",
        value > 0 && !isDangerous && "bg-purple-500/15",
        isDangerous && !isLethal && "bg-orange-500/15",
        isLethal && "bg-red-500/20"
      )}>
        <Skull className={cn(
          "w-4 h-4",
          value === 0 && "text-muted-foreground",
          value > 0 && !isDangerous && "text-purple-400",
          isDangerous && !isLethal && "text-orange-400",
          isLethal && "text-red-400"
        )} />
        <span className="text-xs font-medium text-muted-foreground">Poison</span>
      </div>
      <InlineLifeControls
        value={value}
        onChange={onChange}
        disabled={disabled}
        min={0}
        highlight
      />
    </div>
  );
}

// Inline poison badge for player header area
export function PoisonBadge({ count }: { count: number }) {
  if (count === 0) return null;
  
  const isLethal = count >= 10;
  const isDangerous = count >= 7;

  return (
    <div
      className={cn(
        "flex items-center gap-1 px-1.5 py-0.5 rounded-full text-[10px] font-semibold",
        !isDangerous && "bg-purple-500/20 text-purple-400",
        isDangerous && !isLethal && "bg-orange-500/20 text-orange-400",
        isLethal && "bg-red-500/30 text-red-400"
      )}
    >
      <Skull className="w-2.5 h-2.5" />
      <span className="tabular-nums">{count}</span>
    </div>
  );
}
