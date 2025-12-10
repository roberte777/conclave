"use client";

import { useCallback, useRef, useState } from "react";

interface UseLongPressOptions {
  onPress: () => void;
  onLongPress: () => void;
  longPressDelay?: number;
  repeatInterval?: number;
}

export function useLongPress({
  onPress,
  onLongPress,
  longPressDelay = 400,
  repeatInterval = 100,
}: UseLongPressOptions) {
  const [isPressed, setIsPressed] = useState(false);
  const timeoutRef = useRef<ReturnType<typeof setTimeout> | null>(null);
  const intervalRef = useRef<ReturnType<typeof setInterval> | null>(null);
  const isLongPressRef = useRef(false);

  const clearTimers = useCallback(() => {
    if (timeoutRef.current) {
      clearTimeout(timeoutRef.current);
      timeoutRef.current = null;
    }
    if (intervalRef.current) {
      clearInterval(intervalRef.current);
      intervalRef.current = null;
    }
  }, []);

  const handleStart = useCallback(() => {
    setIsPressed(true);
    isLongPressRef.current = false;

    // Start long press timer
    timeoutRef.current = setTimeout(() => {
      isLongPressRef.current = true;
      onLongPress();
      
      // Start repeating
      intervalRef.current = setInterval(() => {
        onLongPress();
      }, repeatInterval);
    }, longPressDelay);
  }, [longPressDelay, onLongPress, repeatInterval]);

  const handleEnd = useCallback(() => {
    setIsPressed(false);
    clearTimers();
    
    // If it wasn't a long press, trigger the regular press
    if (!isLongPressRef.current) {
      onPress();
    }
    isLongPressRef.current = false;
  }, [clearTimers, onPress]);

  const handleCancel = useCallback(() => {
    setIsPressed(false);
    clearTimers();
    isLongPressRef.current = false;
  }, [clearTimers]);

  return {
    isPressed,
    handlers: {
      onMouseDown: handleStart,
      onMouseUp: handleEnd,
      onMouseLeave: handleCancel,
      onTouchStart: handleStart,
      onTouchEnd: handleEnd,
      onTouchCancel: handleCancel,
    },
  };
}
