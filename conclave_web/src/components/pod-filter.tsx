"use client";

import * as React from "react";
import { Check, Search, X, Users, ChevronDown } from "lucide-react";
import { cn } from "@/lib/utils";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Avatar, AvatarImage, AvatarFallback } from "@/components/ui/avatar";
import type { Player } from "@/lib/api";

interface PodFilterProps {
  availablePlayers: Player[];
  selectedPlayerIds: string[];
  onSelectionChange: (playerIds: string[]) => void;
  currentUserId: string;
}

function getInitials(name: string): string {
  return name
    .split(" ")
    .map((n) => n[0])
    .join("")
    .toUpperCase()
    .slice(0, 2);
}

export function PodFilter({
  availablePlayers,
  selectedPlayerIds,
  onSelectionChange,
  currentUserId,
}: PodFilterProps) {
  const [searchValue, setSearchValue] = React.useState("");
  const [isExpanded, setIsExpanded] = React.useState(false);

  // Filter out current user from available players
  const otherPlayers = availablePlayers.filter(
    (p) => p.clerkUserId !== currentUserId
  );

  // Get unique players by clerk user ID
  const uniquePlayers = React.useMemo(() => {
    const seen = new Map<string, Player>();
    for (const player of otherPlayers) {
      if (!seen.has(player.clerkUserId)) {
        seen.set(player.clerkUserId, player);
      }
    }
    return Array.from(seen.values());
  }, [otherPlayers]);

  // Filter players based on search
  const filteredPlayers = React.useMemo(() => {
    if (!searchValue.trim()) return uniquePlayers;
    const search = searchValue.toLowerCase();
    return uniquePlayers.filter(
      (p) =>
        p.displayName.toLowerCase().includes(search) ||
        (p.username && p.username.toLowerCase().includes(search))
    );
  }, [uniquePlayers, searchValue]);

  const selectedPlayers = uniquePlayers.filter((p) =>
    selectedPlayerIds.includes(p.clerkUserId)
  );

  const unselectedPlayers = filteredPlayers.filter(
    (p) => !selectedPlayerIds.includes(p.clerkUserId)
  );

  const handleTogglePlayer = (clerkUserId: string) => {
    if (selectedPlayerIds.includes(clerkUserId)) {
      onSelectionChange(selectedPlayerIds.filter((id) => id !== clerkUserId));
    } else {
      onSelectionChange([...selectedPlayerIds, clerkUserId]);
    }
  };

  const handleClearAll = () => {
    onSelectionChange([]);
    setSearchValue("");
  };

  if (uniquePlayers.length === 0) {
    return (
      <div className="flex items-center justify-center p-6 text-muted-foreground text-sm">
        <Users className="w-4 h-4 mr-2" />
        Play some games to see players you can filter by
      </div>
    );
  }

  return (
    <div className="space-y-4">
      {/* Selected Players - Always visible when there are selections */}
      {selectedPlayers.length > 0 && (
        <div className="space-y-2">
          <div className="flex items-center justify-between">
            <span className="text-xs font-medium text-muted-foreground uppercase tracking-wider">
              Your Pod
            </span>
            <Button
              variant="ghost"
              size="sm"
              onClick={handleClearAll}
              className="h-6 px-2 text-xs text-muted-foreground hover:text-foreground"
            >
              Clear all
            </Button>
          </div>
          <div className="flex flex-wrap gap-2">
            {selectedPlayers.map((player) => (
              <button
                key={player.clerkUserId}
                onClick={() => handleTogglePlayer(player.clerkUserId)}
                className="group flex items-center gap-2 px-3 py-1.5 rounded-full bg-primary/10 border border-primary/20 hover:bg-primary/20 hover:border-primary/30 transition-all duration-200"
              >
                <Avatar className="h-5 w-5 ring-2 ring-primary/20">
                  <AvatarImage src={player.imageUrl} alt={player.displayName} />
                  <AvatarFallback className="text-[10px] bg-primary/20 text-primary">
                    {getInitials(player.displayName)}
                  </AvatarFallback>
                </Avatar>
                <span className="text-sm font-medium">{player.displayName}</span>
                <X className="w-3.5 h-3.5 text-muted-foreground group-hover:text-foreground transition-colors" />
              </button>
            ))}
          </div>
        </div>
      )}

      {/* Add Players Section */}
      <div className="space-y-3">
        <button
          onClick={() => setIsExpanded(!isExpanded)}
          className="flex items-center gap-2 text-sm text-muted-foreground hover:text-foreground transition-colors"
        >
          <ChevronDown
            className={cn(
              "w-4 h-4 transition-transform duration-200",
              isExpanded && "rotate-180"
            )}
          />
          <span>
            {selectedPlayers.length === 0
              ? "Select players to filter by"
              : "Add more players"}
          </span>
        </button>

        {isExpanded && (
          <div className="space-y-3 animate-in fade-in slide-in-from-top-2 duration-200">
            {/* Search Input */}
            <div className="relative">
              <Search className="absolute left-3 top-1/2 -translate-y-1/2 w-4 h-4 text-muted-foreground" />
              <Input
                type="text"
                placeholder="Search players..."
                value={searchValue}
                onChange={(e) => setSearchValue(e.target.value)}
                className="pl-9 h-9"
              />
              {searchValue && (
                <button
                  onClick={() => setSearchValue("")}
                  className="absolute right-3 top-1/2 -translate-y-1/2 text-muted-foreground hover:text-foreground"
                >
                  <X className="w-4 h-4" />
                </button>
              )}
            </div>

            {/* Player Grid */}
            <div className="grid grid-cols-1 sm:grid-cols-2 gap-2 max-h-[240px] overflow-y-auto pr-1">
              {unselectedPlayers.map((player) => (
                <button
                  key={player.clerkUserId}
                  onClick={() => handleTogglePlayer(player.clerkUserId)}
                  className="flex items-center gap-3 p-2.5 rounded-lg border border-transparent bg-muted/50 hover:bg-muted hover:border-border transition-all duration-200 text-left"
                >
                  <Avatar className="h-8 w-8">
                    <AvatarImage src={player.imageUrl} alt={player.displayName} />
                    <AvatarFallback className="text-xs">
                      {getInitials(player.displayName)}
                    </AvatarFallback>
                  </Avatar>
                  <div className="flex-1 min-w-0">
                    <p className="text-sm font-medium truncate">
                      {player.displayName}
                    </p>
                    {player.username && (
                      <p className="text-xs text-muted-foreground truncate">
                        @{player.username}
                      </p>
                    )}
                  </div>
                  <div className="w-5 h-5 rounded-full border-2 border-muted-foreground/30 flex items-center justify-center shrink-0">
                    <Check className="w-3 h-3 text-transparent" />
                  </div>
                </button>
              ))}

              {/* Selected players in the grid (shown with check) */}
              {filteredPlayers
                .filter((p) => selectedPlayerIds.includes(p.clerkUserId))
                .map((player) => (
                  <button
                    key={player.clerkUserId}
                    onClick={() => handleTogglePlayer(player.clerkUserId)}
                    className="flex items-center gap-3 p-2.5 rounded-lg border border-primary/30 bg-primary/5 hover:bg-primary/10 transition-all duration-200 text-left"
                  >
                    <Avatar className="h-8 w-8 ring-2 ring-primary/30">
                      <AvatarImage src={player.imageUrl} alt={player.displayName} />
                      <AvatarFallback className="text-xs bg-primary/20 text-primary">
                        {getInitials(player.displayName)}
                      </AvatarFallback>
                    </Avatar>
                    <div className="flex-1 min-w-0">
                      <p className="text-sm font-medium truncate">
                        {player.displayName}
                      </p>
                      {player.username && (
                        <p className="text-xs text-muted-foreground truncate">
                          @{player.username}
                        </p>
                      )}
                    </div>
                    <div className="w-5 h-5 rounded-full bg-primary flex items-center justify-center shrink-0">
                      <Check className="w-3 h-3 text-primary-foreground" />
                    </div>
                  </button>
                ))}
            </div>

            {filteredPlayers.length === 0 && searchValue && (
              <p className="text-sm text-muted-foreground text-center py-4">
                No players found matching &quot;{searchValue}&quot;
              </p>
            )}
          </div>
        )}
      </div>
    </div>
  );
}
