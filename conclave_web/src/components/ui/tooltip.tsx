"use client"

import * as React from "react"
import { createPortal } from "react-dom"
import { cn } from "@/lib/utils"

interface TooltipProps {
  children: React.ReactNode
  content: string
  side?: "top" | "bottom" | "left" | "right"
}

export function Tooltip({ children, content, side = "top" }: TooltipProps) {
  const [isVisible, setIsVisible] = React.useState(false)
  const [position, setPosition] = React.useState({ top: 0, left: 0 })
  const triggerRef = React.useRef<HTMLDivElement>(null)
  const tooltipRef = React.useRef<HTMLDivElement>(null)
  const [mounted, setMounted] = React.useState(false)

  React.useEffect(() => {
    setMounted(true)
  }, [])

  React.useEffect(() => {
    if (isVisible && triggerRef.current) {
      const rect = triggerRef.current.getBoundingClientRect()
      const tooltipEl = tooltipRef.current
      const tooltipWidth = tooltipEl?.offsetWidth || 100
      const tooltipHeight = tooltipEl?.offsetHeight || 32

      let top = 0
      let left = 0

      switch (side) {
        case "top":
          top = rect.top - tooltipHeight - 8
          left = rect.left + rect.width / 2 - tooltipWidth / 2
          break
        case "bottom":
          top = rect.bottom + 8
          left = rect.left + rect.width / 2 - tooltipWidth / 2
          break
        case "left":
          top = rect.top + rect.height / 2 - tooltipHeight / 2
          left = rect.left - tooltipWidth - 8
          break
        case "right":
          top = rect.top + rect.height / 2 - tooltipHeight / 2
          left = rect.right + 8
          break
      }

      // Keep tooltip within viewport
      const padding = 8
      if (left < padding) left = padding
      if (left + tooltipWidth > window.innerWidth - padding) {
        left = window.innerWidth - tooltipWidth - padding
      }
      if (top < padding) top = padding
      if (top + tooltipHeight > window.innerHeight - padding) {
        top = window.innerHeight - tooltipHeight - padding
      }

      setPosition({ top, left })
    }
  }, [isVisible, side])

  const tooltipElement = mounted && isVisible ? createPortal(
    <div
      ref={tooltipRef}
      className={cn(
        "fixed z-[9999] pointer-events-none",
        "px-2.5 py-1.5 text-xs font-medium whitespace-nowrap",
        "bg-card text-card-foreground rounded-lg shadow-lg shadow-black/30",
        "border border-white/10",
        "transition-opacity duration-150",
        isVisible ? "opacity-100" : "opacity-0"
      )}
      style={{ top: position.top, left: position.left }}
      role="tooltip"
    >
      {content}
    </div>,
    document.body
  ) : null

  return (
    <>
      <div
        ref={triggerRef}
        className="inline-flex"
        onMouseEnter={() => setIsVisible(true)}
        onMouseLeave={() => setIsVisible(false)}
        onFocus={() => setIsVisible(true)}
        onBlur={() => setIsVisible(false)}
      >
        {children}
      </div>
      {tooltipElement}
    </>
  )
}
