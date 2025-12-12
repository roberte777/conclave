"use client";

import { useEffect, useMemo, useState, useCallback } from "react";
import { useAuth } from "@clerk/nextjs";
import { Button } from "@/components/ui/button";
import {
    Dialog,
    DialogContent,
    DialogDescription,
    DialogFooter,
    DialogHeader,
    DialogTitle,
} from "@/components/ui/dialog";
import { ConclaveAPI, type GameState, type Player } from "@/lib/api";
import Image from "next/image";
import Link from "next/link";
import {
    Swords,
    ChevronUp,
    ChevronDown,
    Crown,
    Users,
    Wifi,
    WifiOff,
    Home,
    RefreshCw,
    Power,
    Shield,
    Sparkles,
    X,
    Settings,
} from "lucide-react";
import { cn } from "@/lib/utils";
import { Tooltip } from "@/components/ui/tooltip";

interface GamePageClientProps {
    gameId: string;
}

type PartnerState = Record<string, boolean>;

const PLAYER_COLORS = [
    "from-violet-500/30 to-purple-600/10 border-violet-500/30",
    "from-blue-500/30 to-cyan-600/10 border-blue-500/30",
    "from-emerald-500/30 to-green-600/10 border-emerald-500/30",
    "from-amber-500/30 to-orange-600/10 border-amber-500/30",
    "from-rose-500/30 to-red-600/10 border-rose-500/30",
    "from-pink-500/30 to-fuchsia-600/10 border-pink-500/30",
    "from-teal-500/30 to-cyan-600/10 border-teal-500/30",
    "from-indigo-500/30 to-blue-600/10 border-indigo-500/30",
];

const PLAYER_ACCENTS = [
    "text-violet-400",
    "text-blue-400",
    "text-emerald-400",
    "text-amber-400",
    "text-rose-400",
    "text-pink-400",
    "text-teal-400",
    "text-indigo-400",
];

export function GamePageClient({ gameId }: GamePageClientProps) {
    const { getToken, userId } = useAuth();
    const api = useMemo(() => new ConclaveAPI({}), []);

    const [isConnected, setIsConnected] = useState(false);
    // Reserve the full-screen error UI for non-recoverable errors (e.g. auth failure).
    const [fatalError, setFatalError] = useState<string | null>(null);
    const [state, setState] = useState<GameState | null>(null);
    const [partnerEnabled, setPartnerEnabled] = useState<PartnerState>({});
    const [winner, setWinner] = useState<Player | null>(null);
    const [expandedPlayer, setExpandedPlayer] = useState<string | null>(null);
    const [animatingLife, setAnimatingLife] = useState<Record<string, boolean>>({});
    const [showEndGameDialog, setShowEndGameDialog] = useState(false);
    const [selectedWinnerId, setSelectedWinnerId] = useState<string | null>(null);

    // Sort players so the current user is first, then others by position
    const sortedPlayers = useMemo(() => {
        if (!state?.players) return [];
        const currentUserPlayer = state.players.find(p => p.clerkUserId === userId);
        const otherPlayers = state.players
            .filter(p => p.clerkUserId !== userId)
            .sort((a, b) => a.position - b.position);
        return currentUserPlayer ? [currentUserPlayer, ...otherPlayers] : otherPlayers;
    }, [state?.players, userId]);

    // Establish websocket connection and wire up handlers
    useEffect(() => {
        let ws: ReturnType<typeof api.connectWebSocket> | null = null;
        let cleanupFunctions: (() => void)[] = [];

        const isAuthErrorMessage = (message: string) =>
            /auth|unauthor|token/i.test(message);

        // Token getter function - called on each connection/reconnection attempt
        const fetchToken = async (): Promise<string> => {
            const token = await getToken({ template: "default" });
            if (!token) {
                throw new Error("Not authenticated");
            }
            return token;
        };

        const connect = () => {
            ws = api.connectWebSocket(gameId, fetchToken);

            const offConnect = ws.onConnect(() => {
                setIsConnected(true);
                setFatalError(null);
                ws?.getGameState();
            });

            const offDisconnect = ws.onDisconnect(() => {
                setIsConnected(false);
            });

            const offError = ws.onError((e) => {
                // Avoid kicking the user out to a full-screen error for transient socket issues.
                // If reconnection exhausts attempts, the client will emit a "Failed to reconnect"
                // error; still keep the UI in-place so users can recover by returning online.
                const message = e.message || "WebSocket error";
                if (isAuthErrorMessage(message)) {
                    setFatalError(message);
                } else {
                    console.warn("WebSocket error (non-fatal):", message);
                }
            });

            const offAll = ws.on("*", (message) => {
                switch (message.type) {
                    case "gameStarted": {
                        const next: GameState = {
                            game: message.game,
                            players: message.players,
                            recentChanges: message.recentChanges,
                            commanderDamage: message.commanderDamage,
                        };
                        setState(next);
                        break;
                    }
                    case "lifeUpdate": {
                        setState((prev) => {
                            if (!prev) return prev;
                            const players = prev.players.map((p) =>
                                p.id === message.playerId ? { ...p, currentLife: message.newLife } : p
                            );
                            return { ...prev, players };
                        });
                        // Trigger animation
                        setAnimatingLife((prev) => ({ ...prev, [message.playerId]: true }));
                        setTimeout(() => {
                            setAnimatingLife((prev) => ({ ...prev, [message.playerId]: false }));
                        }, 200);
                        break;
                    }
                    case "playerJoined": {
                        setState((prev) => {
                            if (!prev) return prev;
                            if (prev.players.some(p => p.id === message.player.id)) {
                                return prev;
                            }
                            return {
                                ...prev,
                                players: [...prev.players, message.player],
                            };
                        });
                        ws?.getGameState();
                        break;
                    }
                    case "playerLeft": {
                        setState((prev) => {
                            if (!prev) return prev;
                            const players = prev.players.filter((p) => p.id !== message.playerId);
                            const commanderDamage = prev.commanderDamage.filter(
                                (cd) => cd.fromPlayerId !== message.playerId && cd.toPlayerId !== message.playerId
                            );
                            return { ...prev, players, commanderDamage };
                        });
                        ws?.getGameState();
                        break;
                    }
                    case "commanderDamageUpdate": {
                        setState((prev) => {
                            if (!prev) return prev;
                            const idx = prev.commanderDamage.findIndex(
                                (cd) =>
                                    cd.fromPlayerId === message.fromPlayerId &&
                                    cd.toPlayerId === message.toPlayerId &&
                                    cd.commanderNumber === message.commanderNumber
                            );
                            if (idx >= 0) {
                                const next = [...prev.commanderDamage];
                                next[idx] = { ...next[idx], damage: message.newDamage };
                                return { ...prev, commanderDamage: next };
                            }
                            return {
                                ...prev,
                                commanderDamage: [
                                    ...prev.commanderDamage,
                                    {
                                        id: `${message.fromPlayerId}-${message.toPlayerId}-${message.commanderNumber}`,
                                        gameId: prev.game.id,
                                        fromPlayerId: message.fromPlayerId,
                                        toPlayerId: message.toPlayerId,
                                        commanderNumber: message.commanderNumber,
                                        damage: message.newDamage,
                                        createdAt: new Date().toISOString(),
                                        updatedAt: new Date().toISOString(),
                                    },
                                ],
                            };
                        });
                        break;
                    }
                    case "partnerToggled": {
                        setPartnerEnabled((prev) => ({ ...prev, [message.playerId]: message.hasPartner }));
                        break;
                    }
                    case "gameEnded": {
                        setWinner(message.winner || null);
                        break;
                    }
                    case "error": {
                        // Server-side errors might be actionable, but avoid a full-screen takeover
                        // for transient connectivity-related messages.
                        if (isAuthErrorMessage(message.message)) {
                            setFatalError(message.message);
                        } else {
                            console.warn("WebSocket server error (non-fatal):", message.message);
                        }
                        break;
                    }
                }
            });

            cleanupFunctions = [offConnect, offDisconnect, offError, offAll];
        };

        connect();

        return () => {
            cleanupFunctions.forEach(fn => fn());
            api.disconnectWebSocket();
        };
    }, [api, gameId, getToken]);

    const changeLife = useCallback(
        (playerId: string, delta: number) => {
            api.ws?.updateLife(playerId, delta);
        },
        [api]
    );

    const endGame = useCallback(() => {
        setShowEndGameDialog(true);
    }, []);

    const confirmEndGame = useCallback(() => {
        api.ws?.endGame(selectedWinnerId || undefined);
        setShowEndGameDialog(false);
        setSelectedWinnerId(null);
    }, [api, selectedWinnerId]);

    const getCommanderDamage = useCallback(
        (fromId: string, toId: string, commanderNumber: number) => {
            if (!state) return 0;
            return (
                state.commanderDamage.find(
                    (cd) =>
                        cd.fromPlayerId === fromId &&
                        cd.toPlayerId === toId &&
                        cd.commanderNumber === commanderNumber
                )?.damage || 0
            );
        },
        [state]
    );

    const changeCommanderDamage = useCallback(
        (fromId: string, toId: string, commanderNumber: number, delta: number) => {
            api.ws?.updateCommanderDamage(fromId, toId, commanderNumber, delta);
        },
        [api]
    );

    const togglePartner = useCallback(
        (playerId: string) => {
            const enabled = !!partnerEnabled[playerId];
            api.ws?.togglePartner(playerId, !enabled);
        },
        [api, partnerEnabled]
    );

    const getTotalCommanderDamage = useCallback(
        (toId: string) => {
            if (!state) return 0;
            return state.commanderDamage
                .filter((cd) => cd.toPlayerId === toId)
                .reduce((sum, cd) => sum + cd.damage, 0);
        },
        [state]
    );

    if (fatalError) {
        return (
            <div className="min-h-screen bg-gradient-mesh flex items-center justify-center p-4">
                <div className="glass-card rounded-2xl p-8 max-w-md w-full text-center animate-fade-in-up">
                    <div className="w-16 h-16 mx-auto mb-6 rounded-full bg-red-500/20 flex items-center justify-center">
                        <X className="w-8 h-8 text-red-400" />
                    </div>
                    <h2 className="text-2xl font-bold mb-3">Connection Error</h2>
                    <p className="text-muted-foreground mb-6">{fatalError}</p>
                    <div className="flex gap-3 justify-center">
                        <Button asChild variant="outline">
                            <Link href="/">
                                <Home className="w-4 h-4 mr-2" />
                                Go Home
                            </Link>
                        </Button>
                        <Button onClick={() => window.location.reload()}>
                            <RefreshCw className="w-4 h-4 mr-2" />
                            Retry
                        </Button>
                    </div>
                </div>
            </div>
        );
    }

    return (
        <div className="min-h-screen bg-gradient-mesh">
            {/* Header Bar */}
            <div className="glass border-b border-white/10 sticky top-0 z-50">
                <div className="max-w-7xl mx-auto px-4 py-3 flex items-center justify-between">
                    <div className="flex items-center gap-4">
                        <Link
                            href="/"
                            className="p-2 rounded-lg hover:bg-white/10 transition-colors"
                            title="Back to Dashboard"
                        >
                            <Home className="w-5 h-5" />
                        </Link>
                        <div>
                            <h1 className="text-lg font-bold flex items-center gap-2">
                                Game #{gameId.slice(0, 8)}
                                {winner && (
                                    <span className="text-xs px-2 py-1 rounded-full bg-amber-500/20 text-amber-400 font-medium">
                                        Finished
                                    </span>
                                )}
                            </h1>
                            <div className="flex items-center gap-3 text-xs text-muted-foreground">
                                <span className="flex items-center gap-1">
                                    {isConnected ? (
                                        <>
                                            <Wifi className="w-3 h-3 text-emerald-400" />
                                            <span className="text-emerald-400">Live</span>
                                        </>
                                    ) : (
                                        <>
                                            <WifiOff className="w-3 h-3 text-red-400" />
                                            <span className="text-red-400">Connecting...</span>
                                        </>
                                    )}
                                </span>
                                <span className="flex items-center gap-1">
                                    <Users className="w-3 h-3" />
                                    {state?.players.length || 0} players
                                </span>
                            </div>
                        </div>
                    </div>
                    <div className="flex items-center gap-2">
                        <Button
                            variant="ghost"
                            size="sm"
                            onClick={() => api.ws?.getGameState()}
                            disabled={!isConnected}
                            className="text-muted-foreground hover:text-foreground"
                        >
                            <RefreshCw className="w-4 h-4" />
                        </Button>
                        <Button
                            variant="ghost"
                            size="sm"
                            onClick={endGame}
                            disabled={!isConnected || !state || state.game.status === "finished"}
                            className="text-red-400 hover:text-red-300 hover:bg-red-500/10"
                        >
                            <Power className="w-4 h-4 mr-1" />
                            End
                        </Button>
                    </div>
                </div>
            </div>

            {/* Winner Banner */}
            {winner && (
                <div className="bg-gradient-to-r from-amber-500/20 via-yellow-500/20 to-amber-500/20 border-b border-amber-500/30 animate-fade-in-up">
                    <div className="max-w-7xl mx-auto px-4 py-4 flex items-center justify-center gap-4">
                        <Crown className="w-6 h-6 text-amber-400" />
                        <span className="text-lg font-semibold">
                            <span className="text-amber-400">{winner.displayName}</span> wins with{" "}
                            <span className="text-amber-400">{winner.currentLife}</span> life!
                        </span>
                        <Crown className="w-6 h-6 text-amber-400" />
                    </div>
                </div>
            )}

            {/* Main Content */}
            <div className="max-w-7xl mx-auto p-4 md:p-6">
                {!state ? (
                    <div className="flex items-center justify-center min-h-[60vh]">
                        <div className="text-center">
                            <div className="w-16 h-16 mx-auto mb-6 rounded-full bg-primary/20 animate-pulse flex items-center justify-center">
                                <Sparkles className="w-8 h-8 text-primary" />
                            </div>
                            <p className="text-lg text-muted-foreground">Loading game...</p>
                        </div>
                    </div>
                ) : (
                    <div className={cn(
                        "grid gap-4 md:gap-6",
                        // Always single column on mobile, then responsive grid on larger screens
                        "grid-cols-1",
                        sortedPlayers.length === 1 && "max-w-lg mx-auto",
                        sortedPlayers.length === 2 && "md:grid-cols-2 max-w-4xl mx-auto",
                        sortedPlayers.length === 3 && "md:grid-cols-2 lg:grid-cols-3",
                        sortedPlayers.length === 4 && "md:grid-cols-2 lg:grid-cols-4",
                        sortedPlayers.length >= 5 && "md:grid-cols-2 lg:grid-cols-3 xl:grid-cols-4"
                    )}>
                        {sortedPlayers.map((player, index) => {
                            const colorClass = PLAYER_COLORS[index % PLAYER_COLORS.length];
                            const accentClass = PLAYER_ACCENTS[index % PLAYER_ACCENTS.length];
                            const isExpanded = expandedPlayer === player.id;
                            const totalCmdDamage = getTotalCommanderDamage(player.id);
                            const isDanger = player.currentLife <= 10;
                            const isCritical = player.currentLife <= 5;
                            const isAnimating = animatingLife[player.id];

                            return (
                                <div
                                    key={player.id}
                                    className={cn(
                                        "life-counter relative rounded-2xl border overflow-hidden",
                                        "bg-gradient-to-br",
                                        colorClass,
                                        "backdrop-blur-xl transition-all duration-300",
                                        isExpanded && "col-span-full lg:col-span-2"
                                    )}
                                >
                                    {/* Player Header */}
                                    <div className="flex items-center justify-between px-4 py-3 border-b border-white/10">
                                        <div className="flex items-center gap-3 min-w-0">
                                            {player.imageUrl ? (
                                                <Image
                                                    src={player.imageUrl}
                                                    alt={player.displayName}
                                                    width={36}
                                                    height={36}
                                                    className="rounded-full ring-2 ring-white/20"
                                                />
                                            ) : (
                                                <div className={cn(
                                                    "w-9 h-9 rounded-full flex items-center justify-center font-bold text-sm",
                                                    "bg-white/10"
                                                )}>
                                                    {player.displayName.charAt(0).toUpperCase()}
                                                </div>
                                            )}
                                            <div className="min-w-0">
                                                <div className="font-semibold truncate">
                                                    {player.displayName}
                                                </div>
                                                <div className={cn("text-xs", accentClass)}>
                                                    Player {player.position}
                                                </div>
                                            </div>
                                        </div>
                                        <Tooltip content={isExpanded ? "Hide settings" : "Player settings"} side="bottom">
                                            <button
                                                onClick={() => setExpandedPlayer(isExpanded ? null : player.id)}
                                                className={cn(
                                                    "p-2 rounded-lg transition-all",
                                                    isExpanded
                                                        ? "bg-primary/30 text-primary hover:bg-primary/40"
                                                        : "bg-white/5 text-muted-foreground hover:bg-white/10 hover:text-foreground"
                                                )}
                                            >
                                                <Settings className="w-4 h-4" />
                                            </button>
                                        </Tooltip>
                                    </div>

                                    {/* Life Counter Section */}
                                    <div className="p-3 md:p-4 lg:p-6">
                                        <div className="flex items-center justify-between gap-2 md:gap-4">
                                            {/* Decrease Buttons */}
                                            <div className="flex flex-col gap-1.5 md:gap-2 shrink-0">
                                                <button
                                                    onClick={() => changeLife(player.id, -1)}
                                                    disabled={!isConnected}
                                                    className="life-button life-button-decrease w-10 h-10 md:w-12 md:h-12 lg:w-14 lg:h-14 rounded-xl bg-red-500/20 hover:bg-red-500/30 text-red-400 font-bold text-lg flex items-center justify-center disabled:opacity-50 transition-all"
                                                >
                                                    <ChevronDown className="w-5 h-5 md:w-6 md:h-6" />
                                                </button>
                                                <button
                                                    onClick={() => changeLife(player.id, -5)}
                                                    disabled={!isConnected}
                                                    className="life-button life-button-decrease w-10 h-10 md:w-12 md:h-12 lg:w-14 lg:h-14 rounded-xl bg-red-500/10 hover:bg-red-500/20 text-red-400/80 font-semibold text-sm md:text-base flex items-center justify-center disabled:opacity-50 transition-all"
                                                >
                                                    -5
                                                </button>
                                            </div>

                                            {/* Life Total */}
                                            <div className="flex-1 text-center min-w-0">
                                                <div
                                                    className={cn(
                                                        "text-5xl md:text-6xl lg:text-7xl font-black tabular-nums transition-all",
                                                        isAnimating && "animate-counter-bump",
                                                        isCritical && "text-red-400",
                                                        isDanger && !isCritical && "text-amber-400"
                                                    )}
                                                >
                                                    {player.currentLife}
                                                </div>
                                                <div className="text-xs md:text-sm text-muted-foreground mt-1 flex items-center justify-center gap-2 md:gap-3">
                                                    <span>Life</span>
                                                    {totalCmdDamage > 0 && (
                                                        <span className="flex items-center gap-1 text-orange-400">
                                                            <Swords className="w-3 h-3" />
                                                            {totalCmdDamage}
                                                        </span>
                                                    )}
                                                </div>
                                            </div>

                                            {/* Increase Buttons */}
                                            <div className="flex flex-col gap-1.5 md:gap-2 shrink-0">
                                                <button
                                                    onClick={() => changeLife(player.id, +1)}
                                                    disabled={!isConnected}
                                                    className="life-button life-button-increase w-10 h-10 md:w-12 md:h-12 lg:w-14 lg:h-14 rounded-xl bg-emerald-500/20 hover:bg-emerald-500/30 text-emerald-400 font-bold text-lg flex items-center justify-center disabled:opacity-50 transition-all"
                                                >
                                                    <ChevronUp className="w-5 h-5 md:w-6 md:h-6" />
                                                </button>
                                                <button
                                                    onClick={() => changeLife(player.id, +5)}
                                                    disabled={!isConnected}
                                                    className="life-button life-button-increase w-10 h-10 md:w-12 md:h-12 lg:w-14 lg:h-14 rounded-xl bg-emerald-500/10 hover:bg-emerald-500/20 text-emerald-400/80 font-semibold text-sm md:text-base flex items-center justify-center disabled:opacity-50 transition-all"
                                                >
                                                    +5
                                                </button>
                                            </div>
                                        </div>
                                    </div>

                                    {/* Player Settings Section (Expanded) */}
                                    {isExpanded && (
                                        <div className="px-4 pb-4 md:px-6 md:pb-6 border-t border-white/10 pt-4 animate-fade-in-up">
                                            {/* Partner Toggle */}
                                            <div className="flex items-center justify-between mb-4 p-3 glass-card rounded-xl">
                                                <div className="flex items-center gap-2">
                                                    <Shield className="w-4 h-4 text-primary" />
                                                    <span className="text-sm font-medium">Partner Commander</span>
                                                </div>
                                                <button
                                                    onClick={() => togglePartner(player.id)}
                                                    disabled={!isConnected}
                                                    className={cn(
                                                        "relative inline-flex h-6 w-11 items-center rounded-full transition-colors",
                                                        partnerEnabled[player.id]
                                                            ? "bg-primary"
                                                            : "bg-white/20",
                                                        !isConnected && "opacity-50 cursor-not-allowed"
                                                    )}
                                                >
                                                    <span
                                                        className={cn(
                                                            "inline-block h-4 w-4 transform rounded-full bg-white transition-transform",
                                                            partnerEnabled[player.id] ? "translate-x-6" : "translate-x-1"
                                                        )}
                                                    />
                                                </button>
                                            </div>

                                            {/* Commander Damage Section */}
                                            {sortedPlayers.length > 1 && (
                                                <>
                                                    <div className="text-sm font-medium mb-3 flex items-center gap-2">
                                                        <Swords className="w-4 h-4 text-orange-400" />
                                                        Incoming Commander Damage
                                                    </div>
                                                    <div className="grid gap-3 sm:grid-cols-2 lg:grid-cols-3">
                                                        {sortedPlayers
                                                            .filter((from) => from.id !== player.id)
                                                            .map((from, fromIndex) => (
                                                                <div
                                                                    key={from.id}
                                                                    className="glass-card rounded-xl p-3"
                                                                >
                                                                    <div className="flex items-center gap-2 mb-2">
                                                                        {from.imageUrl ? (
                                                                            <Image
                                                                                src={from.imageUrl}
                                                                                alt={from.displayName}
                                                                                width={20}
                                                                                height={20}
                                                                                className="rounded-full"
                                                                            />
                                                                        ) : (
                                                                            <div className={cn(
                                                                                "w-5 h-5 rounded-full flex items-center justify-center text-xs font-bold",
                                                                                PLAYER_ACCENTS[(index + fromIndex + 1) % PLAYER_ACCENTS.length]
                                                                            )}>
                                                                                {from.displayName.charAt(0)}
                                                                            </div>
                                                                        )}
                                                                        <span className="text-sm font-medium truncate">
                                                                            {from.displayName}
                                                                        </span>
                                                                    </div>
                                                                    <div className="space-y-2">
                                                                        {[1, ...(partnerEnabled[from.id] ? [2] : [])].map((cmd) => {
                                                                            const damage = getCommanderDamage(from.id, player.id, cmd);
                                                                            return (
                                                                                <div key={cmd} className="flex items-center justify-between">
                                                                                    <span className="text-xs text-muted-foreground">
                                                                                        Cmdr {cmd}
                                                                                    </span>
                                                                                    <div className="flex items-center gap-2">
                                                                                        <button
                                                                                            onClick={() => changeCommanderDamage(from.id, player.id, cmd, -1)}
                                                                                            disabled={!isConnected || damage === 0}
                                                                                            className="w-7 h-7 rounded-lg bg-white/5 hover:bg-white/10 text-sm font-medium disabled:opacity-30 transition-all"
                                                                                        >
                                                                                            -
                                                                                        </button>
                                                                                        <span className={cn(
                                                                                            "w-8 text-center font-bold tabular-nums",
                                                                                            damage >= 21 && "text-red-400",
                                                                                            damage >= 15 && damage < 21 && "text-orange-400"
                                                                                        )}>
                                                                                            {damage}
                                                                                        </span>
                                                                                        <button
                                                                                            onClick={() => changeCommanderDamage(from.id, player.id, cmd, +1)}
                                                                                            disabled={!isConnected}
                                                                                            className="w-7 h-7 rounded-lg bg-white/5 hover:bg-white/10 text-sm font-medium disabled:opacity-30 transition-all"
                                                                                        >
                                                                                            +
                                                                                        </button>
                                                                                    </div>
                                                                                </div>
                                                                            );
                                                                        })}
                                                                    </div>
                                                                </div>
                                                            ))}
                                                    </div>
                                                </>
                                            )}
                                        </div>
                                    )}
                                </div>
                            );
                        })}
                    </div>
                )}
            </div>

            {/* End Game Dialog */}
            <Dialog open={showEndGameDialog} onOpenChange={setShowEndGameDialog}>
                <DialogContent>
                    <DialogHeader>
                        <DialogTitle>End Game</DialogTitle>
                        <DialogDescription>
                            Select the winner of this game, or choose &quot;No winner&quot; if the game was not completed.
                        </DialogDescription>
                    </DialogHeader>
                    <div className="py-4">
                        <div className="space-y-2">
                            <Button
                                variant={selectedWinnerId === null ? "default" : "outline"}
                                className="w-full justify-start"
                                onClick={() => setSelectedWinnerId(null)}
                            >
                                No winner (game not completed)
                            </Button>
                            {(state?.players || []).map((player) => (
                                <Button
                                    key={player.id}
                                    variant={selectedWinnerId === player.id ? "default" : "outline"}
                                    className="w-full justify-start"
                                    onClick={() => setSelectedWinnerId(player.id)}
                                >
                                    <div className="flex items-center gap-2">
                                        {player.imageUrl && (
                                            <Image
                                                src={player.imageUrl}
                                                alt={player.displayName}
                                                width={20}
                                                height={20}
                                                className="rounded-full"
                                            />
                                        )}
                                        <span>
                                            P{player.position}: {player.displayName} ({player.currentLife} life)
                                        </span>
                                    </div>
                                </Button>
                            ))}
                        </div>
                    </div>
                    <DialogFooter>
                        <Button variant="outline" onClick={() => setShowEndGameDialog(false)}>
                            Cancel
                        </Button>
                        <Button variant="destructive" onClick={confirmEndGame}>
                            End Game
                        </Button>
                    </DialogFooter>
                </DialogContent>
            </Dialog>
        </div>
    );
}
