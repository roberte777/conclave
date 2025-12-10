"use client";

import { ChevronUp, ChevronDown, Minus, Plus } from "lucide-react";
import { cn } from "@/lib/utils";
import { useLongPress } from "./use-long-press";
import { useCallback } from "react";

interface LifeControlsProps {
  onIncrement: (amount: number) => void;
  onDecrement: (amount: number) => void;
  disabled?: boolean;
  size?: "sm" | "md" | "lg";
  layout?: "vertical" | "horizontal";
}

interface LifeButtonProps {
  type: "increment" | "decrement";
  amount: number;
  onPress: (amount: number) => void;
  disabled?: boolean;
  size?: "sm" | "md" | "lg";
  showLongPressHint?: boolean;
}

function LifeButton({
  type,
  amount,
  onPress,
  disabled,
  size = "md",
  showLongPressHint = false,
}: LifeButtonProps) {
  const handlePress = useCallback(() => {
    onPress(amount);
  }, [onPress, amount]);

  const handleLongPress = useCallback(() => {
    onPress(amount * 10);
  }, [onPress, amount]);

  const { isPressed, handlers } = useLongPress({
    onPress: handlePress,
    onLongPress: handleLongPress,
  });

  const isIncrement = type === "increment";
  const Icon = isIncrement ? ChevronUp : ChevronDown;

  const sizeClasses = {
    sm: "w-10 h-10 md:w-12 md:h-12",
    md: "w-14 h-14 md:w-16 md:h-16",
    lg: "w-16 h-16 md:w-20 md:h-20",
  };

  const iconSizes = {
    sm: "w-5 h-5",
    md: "w-6 h-6 md:w-7 md:h-7",
    lg: "w-8 h-8",
  };

  return (
    <button
      {...handlers}
      disabled={disabled}
      className={cn(
        "life-button relative rounded-2xl font-bold flex items-center justify-center",
        "transition-all duration-150 select-none touch-manipulation",
        "disabled:opacity-40 disabled:cursor-not-allowed",
        sizeClasses[size],
        isIncrement
          ? "life-button-increase bg-emerald-500/20 hover:bg-emerald-500/30 active:bg-emerald-500/40 text-emerald-400"
          : "life-button-decrease bg-red-500/20 hover:bg-red-500/30 active:bg-red-500/40 text-red-400",
        isPressed && (isIncrement ? "bg-emerald-500/40 scale-95" : "bg-red-500/40 scale-95")
      )}
      aria-label={`${isIncrement ? "Increase" : "Decrease"} life by ${amount}`}
    >
      <Icon className={iconSizes[size]} />
      {showLongPressHint && (
        <span className="absolute -bottom-5 text-[10px] text-muted-foreground whitespace-nowrap md:hidden">
          Hold for ±10
        </span>
      )}
    </button>
  );
}

// Desktop-only button with explicit amount
function ExplicitLifeButton({
  type,
  amount,
  onPress,
  disabled,
  size = "md",
}: LifeButtonProps) {
  const isIncrement = type === "increment";
  
  const sizeClasses = {
    sm: "h-8 px-2 text-xs",
    md: "h-10 px-3 text-sm",
    lg: "h-12 px-4 text-base",
  };

  return (
    <button
      onClick={() => onPress(amount)}
      disabled={disabled}
      className={cn(
        "life-button rounded-xl font-semibold flex items-center justify-center gap-1",
        "transition-all duration-150 select-none",
        "disabled:opacity-40 disabled:cursor-not-allowed",
        sizeClasses[size],
        isIncrement
          ? "life-button-increase bg-emerald-500/15 hover:bg-emerald-500/25 active:bg-emerald-500/35 text-emerald-400"
          : "life-button-decrease bg-red-500/15 hover:bg-red-500/25 active:bg-red-500/35 text-red-400"
      )}
      aria-label={`${isIncrement ? "Increase" : "Decrease"} life by ${amount}`}
    >
      {isIncrement ? <Plus className="w-3 h-3" /> : <Minus className="w-3 h-3" />}
      {amount}
    </button>
  );
}

export function LifeControls({
  onIncrement,
  onDecrement,
  disabled = false,
  size = "md",
  layout = "vertical",
}: LifeControlsProps) {
  return (
    <div className={cn(
      "flex items-center gap-3",
      layout === "vertical" ? "flex-row" : "flex-col"
    )}>
      {/* Decrease side */}
      <div className="flex flex-col items-center gap-2">
        {/* Mobile: single button with long-press */}
        <div className="md:hidden">
          <LifeButton
            type="decrement"
            amount={1}
            onPress={onDecrement}
            disabled={disabled}
            size={size}
            showLongPressHint
          />
        </div>
        
        {/* Desktop: explicit buttons */}
        <div className="hidden md:flex flex-col gap-1.5">
          <LifeButton
            type="decrement"
            amount={1}
            onPress={onDecrement}
            disabled={disabled}
            size={size}
          />
          <ExplicitLifeButton
            type="decrement"
            amount={10}
            onPress={onDecrement}
            disabled={disabled}
            size="sm"
          />
        </div>
      </div>

      {/* Increment side */}
      <div className="flex flex-col items-center gap-2">
        {/* Mobile: single button with long-press */}
        <div className="md:hidden">
          <LifeButton
            type="increment"
            amount={1}
            onPress={onIncrement}
            disabled={disabled}
            size={size}
          />
        </div>
        
        {/* Desktop: explicit buttons */}
        <div className="hidden md:flex flex-col gap-1.5">
          <LifeButton
            type="increment"
            amount={1}
            onPress={onIncrement}
            disabled={disabled}
            size={size}
          />
          <ExplicitLifeButton
            type="increment"
            amount={10}
            onPress={onIncrement}
            disabled={disabled}
            size="sm"
          />
        </div>
      </div>
    </div>
  );
}

// Simpler inline controls for secondary uses
export function InlineLifeControls({
  value,
  onChange,
  disabled = false,
  min = 0,
  label,
  highlight = false,
}: {
  value: number;
  onChange: (delta: number) => void;
  disabled?: boolean;
  min?: number;
  label?: string;
  highlight?: boolean;
}) {
  return (
    <div className="flex items-center gap-2">
      {label && (
        <span className="text-xs text-muted-foreground min-w-[40px]">{label}</span>
      )}
      <div className="flex items-center gap-1.5">
        <button
          onClick={() => onChange(-1)}
          disabled={disabled || value <= min}
          className={cn(
            "w-7 h-7 rounded-lg text-sm font-medium",
            "bg-white/5 hover:bg-white/10 active:bg-white/15",
            "disabled:opacity-30 disabled:cursor-not-allowed",
            "transition-all duration-100"
          )}
          aria-label="Decrease"
        >
          −
        </button>
        <span
          className={cn(
            "w-8 text-center font-bold tabular-nums text-sm",
            highlight && value >= 21 && "text-red-400",
            highlight && value >= 10 && value < 21 && "text-orange-400"
          )}
        >
          {value}
        </span>
        <button
          onClick={() => onChange(1)}
          disabled={disabled}
          className={cn(
            "w-7 h-7 rounded-lg text-sm font-medium",
            "bg-white/5 hover:bg-white/10 active:bg-white/15",
            "disabled:opacity-30 disabled:cursor-not-allowed",
            "transition-all duration-100"
          )}
          aria-label="Increase"
        >
          +
        </button>
      </div>
    </div>
  );
}
