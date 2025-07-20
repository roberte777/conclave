"use client";

import { useState } from "react";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { Button } from "@/components/ui/button";
import { Badge } from "@/components/ui/badge";
import { Tabs, TabsContent, TabsList, TabsTrigger } from "@/components/ui/tabs";
import { CommanderDamageMatrix } from "./CommanderDamageMatrix";
import { Eye, EyeOff, Sword, TrendingUp } from "lucide-react";
import { type Player, type CommanderDamage } from "@/lib/api";

interface CommanderDamageTrackerProps {
    gameId: string;
    players: Player[];
    commanderDamage: CommanderDamage[];
    currentUserId: string;
    onUpdateDamage: (fromPlayerId: string, toPlayerId: string, commanderNumber: 1 | 2, damageAmount: number) => void;
    onTogglePartner: (playerId: string, enablePartner: boolean) => void;
    isConnected: boolean;
}

export function CommanderDamageTracker({
    players,
    commanderDamage,
    currentUserId,
    onUpdateDamage,
    onTogglePartner,
    isConnected
}: CommanderDamageTrackerProps) {
    const [isVisible, setIsVisible] = useState(true);

    // Helper function to get total damage dealt by a player
    const getTotalDamageDealt = (playerId: string): number => {
        return commanderDamage
            .filter(cd => cd.fromPlayerId === playerId)
            .reduce((total, cd) => total + cd.damage, 0);
    };

    // Helper function to get total damage received by a player
    const getTotalDamageReceived = (playerId: string): number => {
        return commanderDamage
            .filter(cd => cd.toPlayerId === playerId)
            .reduce((total, cd) => total + cd.damage, 0);
    };

    // Helper function to get highest damage received from any single commander
    const getHighestDamageReceived = (playerId: string): number => {
        const damageFromCommanders = commanderDamage
            .filter(cd => cd.toPlayerId === playerId)
            .map(cd => cd.damage);
        
        return damageFromCommanders.length > 0 ? Math.max(...damageFromCommanders) : 0;
    };

    // Helper function to check if player is in lethal range
    const isInLethalRange = (playerId: string): boolean => {
        return getHighestDamageReceived(playerId) >= 21;
    };

    // Helper function to get players sorted by threat level (highest damage received)
    const getPlayersByThreatLevel = () => {
        return [...players].sort((a, b) => {
            const aThreat = getHighestDamageReceived(a.id);
            const bThreat = getHighestDamageReceived(b.id);
            return bThreat - aThreat;
        });
    };

    if (players.length === 0) {
        return null;
    }

    return (
        <div className="space-y-4">
            {/* Header with toggle */}
            <Card>
                <CardHeader className="pb-3">
                    <div className="flex items-center justify-between">
                        <div className="flex items-center gap-2">
                            <Sword className="h-5 w-5" />
                            <CardTitle>Commander Damage</CardTitle>
                            <Badge variant="secondary">
                                {players.length} Players
                            </Badge>
                        </div>
                        <Button
                            variant="outline"
                            size="sm"
                            onClick={() => setIsVisible(!isVisible)}
                        >
                            {isVisible ? (
                                <>
                                    <EyeOff className="h-4 w-4 mr-2" />
                                    Hide
                                </>
                            ) : (
                                <>
                                    <Eye className="h-4 w-4 mr-2" />
                                    Show
                                </>
                            )}
                        </Button>
                    </div>
                    
                    {isVisible && (
                        <div className="text-sm text-muted-foreground">
                            Track commander damage between players. 21+ damage from any single commander eliminates a player.
                        </div>
                    )}
                </CardHeader>
            </Card>

            {isVisible && (
                <Tabs defaultValue="matrix" className="space-y-4">
                    <TabsList className="grid w-full grid-cols-2">
                        <TabsTrigger value="matrix">Damage Matrix</TabsTrigger>
                        <TabsTrigger value="summary">Summary</TabsTrigger>
                    </TabsList>

                    <TabsContent value="matrix" className="space-y-4">
                        <CommanderDamageMatrix
                            players={players}
                            commanderDamage={commanderDamage}
                            currentUserId={currentUserId}
                            onUpdateDamage={onUpdateDamage}
                            onTogglePartner={onTogglePartner}
                            isConnected={isConnected}
                        />
                    </TabsContent>

                    <TabsContent value="summary" className="space-y-4">
                        {/* Summary Cards */}
                        <div className="grid gap-4 md:grid-cols-2">
                            {/* Threat Level Summary */}
                            <Card>
                                <CardHeader>
                                    <CardTitle className="text-lg flex items-center gap-2">
                                        <TrendingUp className="h-4 w-4" />
                                        Elimination Threats
                                    </CardTitle>
                                </CardHeader>
                                <CardContent className="space-y-3">
                                    {getPlayersByThreatLevel().map((player) => {
                                        const highestDamage = getHighestDamageReceived(player.id);
                                        const isLethal = isInLethalRange(player.id);
                                        const isCurrentUser = player.clerkUserId === currentUserId;
                                        
                                        return (
                                            <div 
                                                key={player.id} 
                                                className={`
                                                    flex items-center justify-between p-2 rounded border
                                                    ${isLethal ? 'bg-red-50 border-red-200' : ''}
                                                    ${isCurrentUser ? 'ring-1 ring-blue-300' : ''}
                                                `}
                                            >
                                                <div className="flex items-center gap-2">
                                                    <span className="font-medium">
                                                        Player {player.position}
                                                        {isCurrentUser && (
                                                            <span className="text-xs text-muted-foreground ml-1">
                                                                (You)
                                                            </span>
                                                        )}
                                                    </span>
                                                    {isLethal && (
                                                        <Badge variant="destructive" className="text-xs">
                                                            ELIMINATED
                                                        </Badge>
                                                    )}
                                                </div>
                                                <div className="text-right">
                                                    <div className={`font-bold ${
                                                        highestDamage >= 21 ? 'text-red-600' :
                                                        highestDamage >= 15 ? 'text-orange-600' :
                                                        highestDamage >= 10 ? 'text-yellow-600' :
                                                        'text-green-600'
                                                    }`}>
                                                        {highestDamage}
                                                    </div>
                                                    <div className="text-xs text-muted-foreground">
                                                        max damage
                                                    </div>
                                                </div>
                                            </div>
                                        );
                                    })}
                                </CardContent>
                            </Card>

                            {/* Player Statistics */}
                            <Card>
                                <CardHeader>
                                    <CardTitle className="text-lg">Player Statistics</CardTitle>
                                </CardHeader>
                                <CardContent className="space-y-3">
                                    {players.map((player) => {
                                        const damageDealt = getTotalDamageDealt(player.id);
                                        const damageReceived = getTotalDamageReceived(player.id);
                                        const isCurrentUser = player.clerkUserId === currentUserId;
                                        
                                        return (
                                            <div 
                                                key={player.id} 
                                                className={`
                                                    p-2 rounded border space-y-1
                                                    ${isCurrentUser ? 'ring-1 ring-blue-300' : ''}
                                                `}
                                            >
                                                <div className="flex items-center justify-between">
                                                    <span className="font-medium">
                                                        Player {player.position}
                                                        {isCurrentUser && (
                                                            <span className="text-xs text-muted-foreground ml-1">
                                                                (You)
                                                            </span>
                                                        )}
                                                    </span>
                                                </div>
                                                <div className="flex justify-between text-sm">
                                                    <span className="text-muted-foreground">
                                                        Dealt: <span className="font-medium text-red-600">{damageDealt}</span>
                                                    </span>
                                                    <span className="text-muted-foreground">
                                                        Received: <span className="font-medium text-blue-600">{damageReceived}</span>
                                                    </span>
                                                </div>
                                            </div>
                                        );
                                    })}
                                </CardContent>
                            </Card>
                        </div>

                        {/* Game State Summary */}
                        <Card>
                            <CardHeader>
                                <CardTitle className="text-lg">Game Overview</CardTitle>
                            </CardHeader>
                            <CardContent>
                                <div className="grid gap-4 md:grid-cols-3">
                                    <div className="text-center">
                                        <div className="text-2xl font-bold text-muted-foreground">
                                            {commanderDamage.length}
                                        </div>
                                        <div className="text-sm text-muted-foreground">
                                            Total Damage Entries
                                        </div>
                                    </div>
                                    <div className="text-center">
                                        <div className="text-2xl font-bold text-red-600">
                                            {players.filter(p => isInLethalRange(p.id)).length}
                                        </div>
                                        <div className="text-sm text-muted-foreground">
                                            Players Eliminated
                                        </div>
                                    </div>
                                    <div className="text-center">
                                        <div className="text-2xl font-bold text-green-600">
                                            {players.filter(p => !isInLethalRange(p.id)).length}
                                        </div>
                                        <div className="text-sm text-muted-foreground">
                                            Players Remaining
                                        </div>
                                    </div>
                                </div>
                            </CardContent>
                        </Card>
                    </TabsContent>
                </Tabs>
            )}
        </div>
    );
}