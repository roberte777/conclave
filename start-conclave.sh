#!/bin/bash

# Conclave MTG Life Tracker - Tmux Start Script (Root Level)
# This script starts both the Rust backend and Next.js frontend in a tmux session

SESSION_NAME="conclave"
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "🎯 Starting Conclave MTG Life Tracker..."
echo "📁 Project root: $PROJECT_ROOT"

# Function to check if we're currently in a tmux session
in_tmux() {
    [ -n "$TMUX" ]
}

# Check if session already exists and kill it
if tmux has-session -t "$SESSION_NAME" 2>/dev/null; then
    echo "🔄 Existing session '$SESSION_NAME' found. Killing it..."
    tmux kill-session -t "$SESSION_NAME"
fi

# Create new detached session
echo "🚀 Creating new tmux session '$SESSION_NAME'..."
tmux new-session -d -s "$SESSION_NAME" -c "$PROJECT_ROOT"

# Rename the first window
tmux rename-window -t "$SESSION_NAME:0" "backend"

# Set up the backend pane (Rust API)
echo "🦀 Setting up Rust backend..."
tmux send-keys -t "$SESSION_NAME:backend" "cd conclave_api" Enter
tmux send-keys -t "$SESSION_NAME:backend" "echo '🦀 Starting Rust backend on http://localhost:3001...'" Enter
tmux send-keys -t "$SESSION_NAME:backend" "cargo run" Enter

# Create a new window for the frontend
echo "⚛️  Setting up Next.js frontend..."
tmux new-window -t "$SESSION_NAME" -n "frontend" -c "$PROJECT_ROOT/conclave_web"
tmux send-keys -t "$SESSION_NAME:frontend" "echo '⚛️  Starting Next.js frontend...'" Enter
tmux send-keys -t "$SESSION_NAME:frontend" "echo '📝 Make sure to set up your .env.local with Clerk keys!'" Enter
tmux send-keys -t "$SESSION_NAME:frontend" "echo '🔗 Frontend will be available at http://localhost:3000 (or next available port)'" Enter
tmux send-keys -t "$SESSION_NAME:frontend" "bun run dev" Enter

# Create a new window for general commands/logs
tmux new-window -t "$SESSION_NAME" -n "commands" -c "$PROJECT_ROOT"
tmux send-keys -t "$SESSION_NAME:commands" "echo '📊 Conclave Project Logs & Commands'" Enter
tmux send-keys -t "$SESSION_NAME:commands" "echo '💡 Useful commands:'" Enter
tmux send-keys -t "$SESSION_NAME:commands" "echo '   - Backend: cargo run (in conclave_api/)'" Enter
tmux send-keys -t "$SESSION_NAME:commands" "echo '   - Frontend: bun run dev (in conclave_web/)'" Enter
tmux send-keys -t "$SESSION_NAME:commands" "echo '   - Backend tests: cargo test'" Enter
tmux send-keys -t "$SESSION_NAME:commands" "echo '   - Backend check: cargo check'" Enter
tmux send-keys -t "$SESSION_NAME:commands" "echo '🔧 Setup: Edit conclave_web/.env.local with your Clerk keys'" Enter
tmux send-keys -t "$SESSION_NAME:commands" "echo '📚 Docs: See README.md for full setup instructions'" Enter
tmux send-keys -t "$SESSION_NAME:commands" "" Enter

# Set the default window to backend
tmux select-window -t "$SESSION_NAME:backend"

# Attach or switch to the session
if in_tmux; then
    echo "🔄 Switching to session '$SESSION_NAME'..."
    tmux switch-client -t "$SESSION_NAME"
else
    echo "🔗 Attaching to session '$SESSION_NAME'..."
    tmux attach-session -t "$SESSION_NAME"
fi

echo "✅ Conclave session started!"
echo "📖 Use 'tmux detach' (Ctrl+b d) to detach from session"
echo "🔄 Use 'tmux attach-session -t $SESSION_NAME' to reattach later" 
