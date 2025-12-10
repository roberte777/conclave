"use client";

import { Swords, Shield, ChevronDown, ChevronRight } from "lucide-react";
import { cn } from "@/lib/utils";
import { InlineLifeControls } from "./life-controls";
import Image from "next/image";
import { useState } from "react";
import type { Player, CommanderDamage } from "@/lib/api";

interface CommanderDamageTrackerProps {
  /** The player receiving damage */
  targetPlayer: Player;
  /** All players in the game (to show damage sources) */
  allPlayers: Player[];
  /** All commander damage records */
  commanderDamage: CommanderDamage[];
  /** Map of player IDs to whether they have partner commanders */
  partnerEnabled: Record<string, boolean>;
  /** Callback when commander damage changes */
  onDamageChange: (fromId: string, toId: string, commanderNumber: number, delta: number) => void;
  disabled?: boolean;
  compact?: boolean;
}

interface DamageFromPlayerProps {
  fromPlayer: Player;
  targetPlayerId: string;
  commanderDamage: CommanderDamage[];
  hasPartner: boolean;
  onDamageChange: (commanderNumber: number, delta: number) => void;
  disabled?: boolean;
  compact?: boolean;
  colorIndex: number;
}

const PLAYER_COLORS = [
  "border-violet-500/30",
  "border-blue-500/30",
  "border-emerald-500/30",
  "border-amber-500/30",
  "border-rose-500/30",
  "border-pink-500/30",
  "border-teal-500/30",
  "border-indigo-500/30",
];

function DamageFromPlayer({
  fromPlayer,
  targetPlayerId,
  commanderDamage,
  hasPartner,
  onDamageChange,
  disabled,
  compact,
  colorIndex,
}: DamageFromPlayerProps) {
  const getDamage = (commanderNumber: number) => {
    return commanderDamage.find(
      (cd) =>
        cd.fromPlayerId === fromPlayer.id &&
        cd.toPlayerId === targetPlayerId &&
        cd.commanderNumber === commanderNumber
    )?.damage || 0;
  };

  const commander1Damage = getDamage(1);
  const commander2Damage = getDamage(2);
  const totalDamage = commander1Damage + (hasPartner ? commander2Damage : 0);
  const isLethal = totalDamage >= 21;
  const isDangerous = totalDamage >= 15;

  if (compact) {
    // Ultra compact display for mobile collapsed view
    return (
      <div className={cn(
        "flex items-center gap-2 px-2 py-1.5 rounded-lg bg-white/5",
        isLethal && "bg-red-500/15"
      )}>
        {fromPlayer.imageUrl ? (
          <Image
            src={fromPlayer.imageUrl}
            alt={fromPlayer.displayName}
            width={18}
            height={18}
            className="rounded-full"
          />
        ) : (
          <div className="w-[18px] h-[18px] rounded-full bg-white/10 flex items-center justify-center text-[10px] font-bold">
            {fromPlayer.displayName.charAt(0)}
          </div>
        )}
        <span className={cn(
          "text-sm font-bold tabular-nums",
          isLethal && "text-red-400",
          isDangerous && !isLethal && "text-orange-400"
        )}>
          {totalDamage}
        </span>
      </div>
    );
  }

  return (
    <div className={cn(
      "rounded-xl p-3 bg-white/5 border-l-2",
      PLAYER_COLORS[colorIndex % PLAYER_COLORS.length]
    )}>
      <div className="flex items-center gap-2 mb-2">
        {fromPlayer.imageUrl ? (
          <Image
            src={fromPlayer.imageUrl}
            alt={fromPlayer.displayName}
            width={24}
            height={24}
            className="rounded-full ring-1 ring-white/20"
          />
        ) : (
          <div className="w-6 h-6 rounded-full bg-white/10 flex items-center justify-center text-xs font-bold">
            {fromPlayer.displayName.charAt(0)}
          </div>
        )}
        <span className="text-sm font-medium truncate flex-1">
          {fromPlayer.displayName}
        </span>
        {totalDamage > 0 && (
          <span className={cn(
            "text-xs font-bold px-1.5 py-0.5 rounded",
            isLethal && "bg-red-500/20 text-red-400",
            isDangerous && !isLethal && "bg-orange-500/20 text-orange-400",
            !isDangerous && "bg-white/10 text-muted-foreground"
          )}>
            {totalDamage}
          </span>
        )}
      </div>
      
      <div className="space-y-2">
        <InlineLifeControls
          value={commander1Damage}
          onChange={(delta) => onDamageChange(1, delta)}
          disabled={disabled}
          label="Cmdr 1"
          highlight
        />
        {hasPartner && (
          <InlineLifeControls
            value={commander2Damage}
            onChange={(delta) => onDamageChange(2, delta)}
            disabled={disabled}
            label="Cmdr 2"
            highlight
          />
        )}
      </div>
    </div>
  );
}

export function CommanderDamageTracker({
  targetPlayer,
  allPlayers,
  commanderDamage,
  partnerEnabled,
  onDamageChange,
  disabled = false,
  compact = false,
}: CommanderDamageTrackerProps) {
  const [isExpanded, setIsExpanded] = useState(!compact);
  
  const otherPlayers = allPlayers.filter((p) => p.id !== targetPlayer.id);
  
  // Calculate total commander damage received
  const totalDamageReceived = commanderDamage
    .filter((cd) => cd.toPlayerId === targetPlayer.id)
    .reduce((sum, cd) => sum + cd.damage, 0);

  if (otherPlayers.length === 0) {
    return null;
  }

  const CollapsedView = () => (
    <button
      onClick={() => setIsExpanded(true)}
      className="w-full flex items-center justify-between px-3 py-2 rounded-xl bg-white/5 hover:bg-white/10 transition-colors"
    >
      <div className="flex items-center gap-2">
        <Swords className="w-4 h-4 text-orange-400" />
        <span className="text-sm font-medium">Commander Damage</span>
      </div>
      <div className="flex items-center gap-2">
        {totalDamageReceived > 0 && (
          <span className={cn(
            "text-sm font-bold tabular-nums",
            totalDamageReceived >= 21 && "text-red-400"
          )}>
            {totalDamageReceived}
          </span>
        )}
        <ChevronRight className="w-4 h-4 text-muted-foreground" />
      </div>
    </button>
  );

  if (compact && !isExpanded) {
    return <CollapsedView />;
  }

  return (
    <div className="space-y-3">
      {compact && (
        <button
          onClick={() => setIsExpanded(false)}
          className="w-full flex items-center justify-between px-3 py-2 rounded-xl bg-white/5 hover:bg-white/10 transition-colors"
        >
          <div className="flex items-center gap-2">
            <Swords className="w-4 h-4 text-orange-400" />
            <span className="text-sm font-medium">Commander Damage</span>
          </div>
          <div className="flex items-center gap-2">
            <span className={cn(
              "text-sm font-bold tabular-nums",
              totalDamageReceived >= 21 && "text-red-400"
            )}>
              {totalDamageReceived}
            </span>
            <ChevronDown className="w-4 h-4 text-muted-foreground" />
          </div>
        </button>
      )}
      
      {!compact && (
        <div className="flex items-center gap-2 text-sm font-medium text-muted-foreground">
          <Swords className="w-4 h-4 text-orange-400" />
          <span>Incoming Commander Damage</span>
          {totalDamageReceived > 0 && (
            <span className={cn(
              "ml-auto font-bold tabular-nums",
              totalDamageReceived >= 21 && "text-red-400"
            )}>
              Total: {totalDamageReceived}
            </span>
          )}
        </div>
      )}
      
      <div className="grid gap-2 sm:grid-cols-2 lg:grid-cols-3">
        {otherPlayers.map((from, index) => (
          <DamageFromPlayer
            key={from.id}
            fromPlayer={from}
            targetPlayerId={targetPlayer.id}
            commanderDamage={commanderDamage}
            hasPartner={partnerEnabled[from.id] || false}
            onDamageChange={(commanderNumber, delta) =>
              onDamageChange(from.id, targetPlayer.id, commanderNumber, delta)
            }
            disabled={disabled}
            compact={false}
            colorIndex={index}
          />
        ))}
      </div>
    </div>
  );
}

// Compact summary badge for collapsed player panels
export function CommanderDamageBadge({ 
  totalDamage,
  onClick,
}: { 
  totalDamage: number;
  onClick?: () => void;
}) {
  if (totalDamage === 0) return null;
  
  const isLethal = totalDamage >= 21;
  const isDangerous = totalDamage >= 15;

  return (
    <button
      onClick={onClick}
      className={cn(
        "flex items-center gap-1 px-1.5 py-0.5 rounded-full text-[10px] font-semibold",
        "hover:opacity-80 transition-opacity",
        !isDangerous && "bg-orange-500/20 text-orange-400",
        isDangerous && !isLethal && "bg-orange-500/30 text-orange-400",
        isLethal && "bg-red-500/30 text-red-400"
      )}
    >
      <Swords className="w-2.5 h-2.5" />
      <span className="tabular-nums">{totalDamage}</span>
    </button>
  );
}

// Partner toggle button
export function PartnerToggle({
  enabled,
  onToggle,
  disabled = false,
}: {
  enabled: boolean;
  onToggle: () => void;
  disabled?: boolean;
}) {
  return (
    <button
      onClick={onToggle}
      disabled={disabled}
      className={cn(
        "p-2 rounded-lg transition-all",
        enabled
          ? "bg-primary/30 text-primary hover:bg-primary/40"
          : "bg-white/5 text-muted-foreground hover:bg-white/10 hover:text-foreground",
        disabled && "opacity-50 cursor-not-allowed"
      )}
      aria-label={enabled ? "Disable partner commander" : "Enable partner commander"}
      title={enabled ? "Partner enabled" : "Enable partner"}
    >
      <Shield className="w-4 h-4" />
    </button>
  );
}
