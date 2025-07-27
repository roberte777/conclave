"use client";

import { useState } from "react";
import { Button } from "@/components/ui/button";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { Badge } from "@/components/ui/badge";
import { Separator } from "@/components/ui/separator";
import { Minus, Plus, Sword, Users } from "lucide-react";
import { type Player, type CommanderDamage } from "@/lib/api";

interface CommanderDamageMatrixProps {
    players: Player[];
    commanderDamage: CommanderDamage[];
    currentUserId: string;
    onUpdateDamage: (fromPlayerId: string, toPlayerId: string, commanderNumber: 1 | 2, damageAmount: number) => void;
    onTogglePartner: (playerId: string, enablePartner: boolean) => void;
    isConnected: boolean;
}

export function CommanderDamageMatrix({
    players,
    commanderDamage,
    onUpdateDamage,
    onTogglePartner,
    isConnected
}: CommanderDamageMatrixProps) {
    const [selectedCommander, setSelectedCommander] = useState<1 | 2>(1);

    // Helper function to get damage value between two players for a specific commander
    const getDamage = (fromPlayerId: string, toPlayerId: string, commanderNumber: 1 | 2): number => {
        const damageEntry = commanderDamage.find(
            cd => cd.fromPlayerId === fromPlayerId && 
                  cd.toPlayerId === toPlayerId && 
                  cd.commanderNumber === commanderNumber
        );
        return damageEntry?.damage || 0;
    };

    // Helper function to check if a player has partner enabled
    const hasPartner = (playerId: string): boolean => {
        return commanderDamage.some(cd => cd.fromPlayerId === playerId && cd.commanderNumber === 2);
    };

    // Helper function to get damage color class based on value
    const getDamageColorClass = (damage: number): string => {
        if (damage === 0) return "text-muted-foreground";
        if (damage >= 21) return "text-red-600 font-bold";
        if (damage >= 15) return "text-orange-600 font-semibold";
        if (damage >= 10) return "text-yellow-600 font-medium";
        return "text-green-600";
    };

    // Helper function to get background color class based on damage value
    const getDamageBackgroundClass = (damage: number): string => {
        if (damage >= 21) return "bg-red-50 border-red-200";
        if (damage >= 15) return "bg-orange-50 border-orange-200";
        if (damage >= 10) return "bg-yellow-50 border-yellow-200";
        return "";
    };

    if (players.length === 0) {
        return (
            <Card>
                <CardContent className="p-6 text-center text-muted-foreground">
                    No players in game
                </CardContent>
            </Card>
        );
    }

    return (
        <Card>
            <CardHeader>
                <div className="flex items-center justify-between">
                    <CardTitle className="flex items-center gap-2">
                        <Sword className="h-5 w-5" />
                        Commander Damage Tracking
                    </CardTitle>
                    <div className="flex items-center gap-2">
                        <Button
                            variant={selectedCommander === 1 ? "default" : "outline"}
                            size="sm"
                            onClick={() => setSelectedCommander(1)}
                        >
                            Commander 1
                        </Button>
                        <Button
                            variant={selectedCommander === 2 ? "default" : "outline"}
                            size="sm"
                            onClick={() => setSelectedCommander(2)}
                        >
                            Commander 2
                        </Button>
                    </div>
                </div>
            </CardHeader>
            <CardContent className="space-y-6">
                {/* Partner Toggle Section */}
                <div className="space-y-2">
                    <h4 className="text-sm font-medium">Partner Status</h4>
                    <div className="flex flex-wrap gap-2">
                        {players.map((player) => {
                            const playerHasPartner = hasPartner(player.id);
                            
                            return (
                                <div key={player.id} className="flex items-center gap-2">
                                    <span className="text-sm">Player {player.position}:</span>
                                    <Button
                                        variant={playerHasPartner ? "default" : "outline"}
                                        size="sm"
                                        onClick={() => onTogglePartner(player.id, !playerHasPartner)}
                                        disabled={!isConnected}
                                        className="h-7"
                                    >
                                        <Users className="h-3 w-3 mr-1" />
                                        {playerHasPartner ? "Partner On" : "Partner Off"}
                                    </Button>
                                </div>
                            );
                        })}
                    </div>
                </div>

                <Separator />

                {/* Damage Matrix */}
                <div className="space-y-4">
                    <div className="flex items-center justify-between">
                        <h4 className="text-sm font-medium">
                            Commander {selectedCommander} Damage Matrix
                        </h4>
                        <Badge variant="secondary">
                            {players.length} Players
                        </Badge>
                    </div>

                    <div className="space-y-3">
                        {players.map((fromPlayer) => (
                            <Card key={fromPlayer.id} className="p-3">
                                <div className="space-y-3">
                                    <div className="flex items-center gap-2">
                                        <Badge variant="outline">
                                            Player {fromPlayer.position}
                                        </Badge>
                                        <span className="text-sm text-muted-foreground">
                                            dealing damage to:
                                        </span>
                                    </div>
                                    
                                    <div className="grid gap-2" style={{
                                        gridTemplateColumns: `repeat(${Math.min(players.length - 1, 4)}, 1fr)`
                                    }}>
                                        {players
                                            .filter(toPlayer => toPlayer.id !== fromPlayer.id)
                                            .map((toPlayer) => {
                                                const damage = getDamage(fromPlayer.id, toPlayer.id, selectedCommander);
                                                const isLethal = damage >= 21;
                                                
                                                // Only show Commander 2 damage if the fromPlayer has partner enabled
                                                if (selectedCommander === 2 && !hasPartner(fromPlayer.id)) {
                                                    return (
                                                        <div key={toPlayer.id} className="text-center p-2 rounded border border-dashed border-muted-foreground/30">
                                                            <div className="text-xs text-muted-foreground mb-1">
                                                                → P{toPlayer.position}
                                                            </div>
                                                            <div className="text-xs text-muted-foreground">
                                                                No Partner
                                                            </div>
                                                        </div>
                                                    );
                                                }

                                                return (
                                                    <div 
                                                        key={toPlayer.id} 
                                                        className={`
                                                            text-center p-2 rounded border space-y-2
                                                            ${getDamageBackgroundClass(damage)}
                                                            ${isLethal ? 'ring-2 ring-red-500' : ''}
                                                        `}
                                                    >
                                                        <div className="text-xs text-muted-foreground">
                                                            → Player {toPlayer.position}
                                                        </div>
                                                        
                                                        <div className={`text-lg font-bold ${getDamageColorClass(damage)}`}>
                                                            {damage}
                                                            {isLethal && (
                                                                <Badge variant="destructive" className="ml-1 text-xs">
                                                                    LETHAL
                                                                </Badge>
                                                            )}
                                                        </div>
                                                        
                                                        <div className="flex gap-1">
                                                            <Button
                                                                variant="outline"
                                                                size="sm"
                                                                onClick={() => onUpdateDamage(fromPlayer.id, toPlayer.id, selectedCommander, -1)}
                                                                disabled={!isConnected || damage === 0}
                                                                className="h-6 w-6 p-0"
                                                            >
                                                                <Minus className="h-3 w-3" />
                                                            </Button>
                                                            <Button
                                                                variant="outline"
                                                                size="sm"
                                                                onClick={() => onUpdateDamage(fromPlayer.id, toPlayer.id, selectedCommander, 1)}
                                                                disabled={!isConnected}
                                                                className="h-6 w-6 p-0"
                                                            >
                                                                <Plus className="h-3 w-3" />
                                                            </Button>
                                                        </div>
                                                        
                                                        <div className="flex gap-1">
                                                            <Button
                                                                variant="outline"
                                                                size="sm"
                                                                onClick={() => onUpdateDamage(fromPlayer.id, toPlayer.id, selectedCommander, -5)}
                                                                disabled={!isConnected || damage === 0}
                                                                className="h-6 px-2 text-xs"
                                                            >
                                                                -5
                                                            </Button>
                                                            <Button
                                                                variant="outline"
                                                                size="sm"
                                                                onClick={() => onUpdateDamage(fromPlayer.id, toPlayer.id, selectedCommander, 5)}
                                                                disabled={!isConnected}
                                                                className="h-6 px-2 text-xs"
                                                            >
                                                                +5
                                                            </Button>
                                                        </div>
                                                    </div>
                                                );
                                            })}
                                    </div>
                                </div>
                            </Card>
                        ))}
                    </div>
                </div>

                {/* Legend */}
                <div className="mt-4 p-3 bg-muted rounded-lg">
                    <h5 className="text-xs font-medium mb-2">Damage Levels:</h5>
                    <div className="flex flex-wrap gap-3 text-xs">
                        <span className="text-green-600">0-9: Safe</span>
                        <span className="text-yellow-600">10-14: Warning</span>
                        <span className="text-orange-600">15-20: Danger</span>
                        <span className="text-red-600">21+: Lethal</span>
                    </div>
                </div>
            </CardContent>
        </Card>
    );
}