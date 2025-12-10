"use client";

import { useState } from "react";
import Image from "next/image";
import { ChevronDown, ChevronUp, Crown } from "lucide-react";
import { cn } from "@/lib/utils";
import type { Player, CommanderDamage } from "@/lib/api";
import { PoisonTracker, PoisonBadge } from "./poison-tracker";
import { CommanderDamageTracker, CommanderDamageBadge, PartnerToggle } from "./commander-damage-tracker";

const PLAYER_COLORS = [
  { gradient: "from-violet-500/30 to-purple-600/10", border: "border-violet-500/30", accent: "text-violet-400" },
  { gradient: "from-blue-500/30 to-cyan-600/10", border: "border-blue-500/30", accent: "text-blue-400" },
  { gradient: "from-emerald-500/30 to-green-600/10", border: "border-emerald-500/30", accent: "text-emerald-400" },
  { gradient: "from-amber-500/30 to-orange-600/10", border: "border-amber-500/30", accent: "text-amber-400" },
  { gradient: "from-rose-500/30 to-red-600/10", border: "border-rose-500/30", accent: "text-rose-400" },
  { gradient: "from-pink-500/30 to-fuchsia-600/10", border: "border-pink-500/30", accent: "text-pink-400" },
  { gradient: "from-teal-500/30 to-cyan-600/10", border: "border-teal-500/30", accent: "text-teal-400" },
  { gradient: "from-indigo-500/30 to-blue-600/10", border: "border-indigo-500/30", accent: "text-indigo-400" },
];

interface PlayerPanelProps {
  player: Player;
  playerIndex: number;
  allPlayers: Player[];
  commanderDamage: CommanderDamage[];
  partnerEnabled: Record<string, boolean>;
  poisonCounters?: number;
  isWinner?: boolean;
  isConnected: boolean;
  isAnimating?: boolean;
  /** Number of players total - affects sizing */
  playerCount: number;
  onLifeChange: (delta: number) => void;
  onPoisonChange?: (delta: number) => void;
  onCommanderDamageChange: (fromId: string, toId: string, commanderNumber: number, delta: number) => void;
  onPartnerToggle: () => void;
}

export function PlayerPanel({
  player,
  playerIndex,
  allPlayers,
  commanderDamage,
  partnerEnabled,
  poisonCounters = 0,
  isWinner = false,
  isConnected,
  isAnimating = false,
  playerCount,
  onLifeChange,
  onPoisonChange,
  onCommanderDamageChange,
  onPartnerToggle,
}: PlayerPanelProps) {
  const [isExpanded, setIsExpanded] = useState(false);
  
  const colors = PLAYER_COLORS[playerIndex % PLAYER_COLORS.length];
  const isDanger = player.currentLife <= 10;
  const isCritical = player.currentLife <= 5;
  
  // Calculate total commander damage received
  const totalCmdDamage = commanderDamage
    .filter((cd) => cd.toPlayerId === player.id)
    .reduce((sum, cd) => sum + cd.damage, 0);

  // Determine size based on player count
  // More players = smaller panels
  const getSizeClass = () => {
    if (playerCount <= 2) return "life-text-xl";
    if (playerCount <= 4) return "life-text-lg";
    if (playerCount <= 6) return "life-text-md";
    return "life-text-sm";
  };

  return (
    <div
      className={cn(
        "player-panel relative rounded-2xl border overflow-hidden",
        "bg-gradient-to-br backdrop-blur-xl",
        colors.gradient,
        colors.border,
        "transition-all duration-300",
        isExpanded && "row-span-2",
        isWinner && "ring-2 ring-amber-400/50"
      )}
    >
      {/* Winner Crown */}
      {isWinner && (
        <div className="absolute -top-1 -right-1 z-10">
          <div className="bg-amber-500/90 rounded-full p-1.5 shadow-lg shadow-amber-500/30">
            <Crown className="w-4 h-4 text-white" />
          </div>
        </div>
      )}

      {/* Player Header - Always visible */}
      <div className="flex items-center justify-between px-3 py-2 border-b border-white/10 bg-black/10">
        <div className="flex items-center gap-2 min-w-0 flex-1">
          {player.imageUrl ? (
            <Image
              src={player.imageUrl}
              alt={player.displayName}
              width={28}
              height={28}
              className="rounded-full ring-2 ring-white/20 shrink-0"
            />
          ) : (
            <div className={cn(
              "w-7 h-7 rounded-full flex items-center justify-center font-bold text-xs shrink-0",
              "bg-white/10"
            )}>
              {player.displayName.charAt(0).toUpperCase()}
            </div>
          )}
          <div className="min-w-0 flex-1">
            <div className="font-semibold text-sm truncate">
              {player.displayName}
            </div>
            <div className={cn("text-[10px] leading-tight", colors.accent)}>
              P{player.position}
            </div>
          </div>
        </div>
        
        {/* Compact badges and controls */}
        <div className="flex items-center gap-1.5 shrink-0">
          {/* Poison badge (when collapsed and has poison) */}
          {!isExpanded && poisonCounters > 0 && (
            <PoisonBadge count={poisonCounters} />
          )}
          
          {/* Commander damage badge (when collapsed) */}
          {!isExpanded && totalCmdDamage > 0 && (
            <CommanderDamageBadge 
              totalDamage={totalCmdDamage} 
              onClick={() => setIsExpanded(true)}
            />
          )}
          
          {/* Partner toggle */}
          <PartnerToggle
            enabled={partnerEnabled[player.id] || false}
            onToggle={onPartnerToggle}
            disabled={!isConnected}
          />
          
          {/* Expand/collapse button */}
          <button
            onClick={() => setIsExpanded(!isExpanded)}
            className={cn(
              "p-1.5 rounded-lg transition-all",
              isExpanded
                ? "bg-primary/30 text-primary"
                : "bg-white/5 text-muted-foreground hover:bg-white/10"
            )}
            aria-label={isExpanded ? "Collapse details" : "Expand details"}
          >
            {isExpanded ? (
              <ChevronUp className="w-4 h-4" />
            ) : (
              <ChevronDown className="w-4 h-4" />
            )}
          </button>
        </div>
      </div>

      {/* Life Counter - Main area */}
      <div className={cn(
        "flex items-center justify-center gap-4 px-3",
        playerCount <= 4 ? "py-4 md:py-6" : "py-2 md:py-4"
      )}>
        {/* Decrease button */}
        <div className="flex flex-col items-center gap-1 md:gap-2">
          <button
            onClick={() => onLifeChange(-1)}
            onTouchStart={(e) => {
              e.currentTarget.dataset.touchStart = Date.now().toString();
            }}
            onTouchEnd={(e) => {
              const start = parseInt(e.currentTarget.dataset.touchStart || "0");
              if (Date.now() - start > 400) {
                onLifeChange(-10);
              }
            }}
            disabled={!isConnected}
            className={cn(
              "life-button life-button-decrease rounded-xl bg-red-500/20 hover:bg-red-500/30 active:bg-red-500/40 text-red-400",
              "font-bold flex items-center justify-center disabled:opacity-40 transition-all",
              playerCount <= 4 ? "w-12 h-12 md:w-14 md:h-14" : "w-10 h-10 md:w-12 md:h-12"
            )}
            aria-label="Decrease life"
          >
            <span className={playerCount <= 4 ? "text-2xl" : "text-xl"}>−</span>
          </button>
          {/* Desktop -10 button */}
          <button
            onClick={() => onLifeChange(-10)}
            disabled={!isConnected}
            className={cn(
              "hidden md:flex life-button life-button-decrease rounded-lg bg-red-500/10 hover:bg-red-500/20 text-red-400/80",
              "font-semibold items-center justify-center disabled:opacity-40 transition-all",
              "h-7 px-2 text-xs"
            )}
          >
            −10
          </button>
        </div>

        {/* Life Total */}
        <div className="flex-1 text-center min-w-0">
          <div
            className={cn(
              "font-black tabular-nums transition-all leading-none",
              getSizeClass(),
              isAnimating && "animate-counter-bump",
              isCritical && "text-red-400",
              isDanger && !isCritical && "text-amber-400"
            )}
          >
            {player.currentLife}
          </div>
          <div className="text-[10px] text-muted-foreground mt-0.5 uppercase tracking-wide">
            Life
          </div>
        </div>

        {/* Increase button */}
        <div className="flex flex-col items-center gap-1 md:gap-2">
          <button
            onClick={() => onLifeChange(1)}
            onTouchStart={(e) => {
              e.currentTarget.dataset.touchStart = Date.now().toString();
            }}
            onTouchEnd={(e) => {
              const start = parseInt(e.currentTarget.dataset.touchStart || "0");
              if (Date.now() - start > 400) {
                onLifeChange(10);
              }
            }}
            disabled={!isConnected}
            className={cn(
              "life-button life-button-increase rounded-xl bg-emerald-500/20 hover:bg-emerald-500/30 active:bg-emerald-500/40 text-emerald-400",
              "font-bold flex items-center justify-center disabled:opacity-40 transition-all",
              playerCount <= 4 ? "w-12 h-12 md:w-14 md:h-14" : "w-10 h-10 md:w-12 md:h-12"
            )}
            aria-label="Increase life"
          >
            <span className={playerCount <= 4 ? "text-2xl" : "text-xl"}>+</span>
          </button>
          {/* Desktop +10 button */}
          <button
            onClick={() => onLifeChange(10)}
            disabled={!isConnected}
            className={cn(
              "hidden md:flex life-button life-button-increase rounded-lg bg-emerald-500/10 hover:bg-emerald-500/20 text-emerald-400/80",
              "font-semibold items-center justify-center disabled:opacity-40 transition-all",
              "h-7 px-2 text-xs"
            )}
          >
            +10
          </button>
        </div>
      </div>

      {/* Expanded Section - Secondary trackers */}
      {isExpanded && (
        <div className="px-3 pb-3 space-y-3 border-t border-white/10 pt-3 animate-fade-in-up">
          {/* Poison Tracker */}
          {onPoisonChange && (
            <PoisonTracker
              value={poisonCounters}
              onChange={onPoisonChange}
              disabled={!isConnected}
            />
          )}
          
          {/* Commander Damage Tracker */}
          {allPlayers.length > 1 && (
            <CommanderDamageTracker
              targetPlayer={player}
              allPlayers={allPlayers}
              commanderDamage={commanderDamage}
              partnerEnabled={partnerEnabled}
              onDamageChange={onCommanderDamageChange}
              disabled={!isConnected}
            />
          )}
        </div>
      )}

      {/* Mobile hint for long-press */}
      <div className="absolute bottom-1 left-0 right-0 text-center md:hidden">
        <span className="text-[8px] text-muted-foreground/50">
          Hold buttons for ±10
        </span>
      </div>
    </div>
  );
}
