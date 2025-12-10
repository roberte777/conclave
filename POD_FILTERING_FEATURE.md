# Pod Filtering Feature

## Overview
This feature allows users to filter their match history by specific groups of players (called "pods"). For example, you can now see your win/loss record specifically when playing with Elijah, Adam, and Aaron.

## What Was Implemented

### Backend Changes (Rust API)

#### 1. New API Endpoint
- **Endpoint**: `GET /api/v1/users/me/history/pod/{pod_filter}`
- **Authentication**: Requires JWT token (Clerk)
- **Parameters**: `pod_filter` is a comma-separated list of clerk_user_ids
- **Example**: `/api/v1/users/me/history/pod/user_abc123,user_def456,user_ghi789`

#### 2. Database Query Enhancement
Updated `get_user_game_history()` in `database.rs` to accept an optional `pod_filter` parameter:
- When `pod_filter` is provided, it returns only games where ALL specified users participated
- Uses SQL `IN` clauses to ensure all pod members were present in the game
- Maintains backward compatibility - existing calls without pod filter work as before

#### 3. Handler Function
Added `get_user_history_with_pod()` in `handlers.rs`:
- Parses comma-separated user IDs
- Automatically includes the authenticated user in the pod
- Validates that the pod filter is not empty

### Frontend Changes (Next.js + React)

#### 1. New UI Components

**Command Component** (`src/components/ui/command.tsx`)
- Added shadcn/ui Command component for searchable dropdowns
- Provides keyboard navigation and search functionality

**Popover Component** (`src/components/ui/popover.tsx`)
- Added shadcn/ui Popover component for dropdown overlays
- Used to display the player selection interface

**PodFilter Component** (`src/components/pod-filter.tsx`)
- Multi-select player picker with search
- Shows player avatars and display names
- Visual badges for selected players
- Remove individual players or clear all
- Filters out the current user (you can't play against yourself!)
- Deduplicates players by clerk_user_id

#### 2. API Client Updates
Enhanced `HttpClient` in `http-client.ts`:
- Added `getUserHistoryWithPod(podUserIds: string[])` method
- Handles URL encoding and comma-separated formatting

#### 3. Match History Component Enhancements
Updated `match-history.tsx`:
- Added pod filter state management
- Collapsible "Pod Filter" section with toggle
- Automatically fetches all unique players from match history
- Re-fetches games when pod selection changes
- Shows informative message when pod filter is active
- Stats (win rate, total games, etc.) automatically update based on filtered results

## How It Works

### User Flow
1. User navigates to Match History page
2. Clicks "Show" on the Pod Filter section
3. Clicks the player selection dropdown
4. Searches and selects players they want to filter by
5. Selected players appear as badges below the dropdown
6. Match history automatically updates to show only games with those players
7. Stats update to reflect performance in those specific games

### Technical Flow
1. Frontend loads all match history initially
2. Extracts unique players from all games
3. When user selects pod members, frontend calls `getUserHistoryWithPod()`
4. Backend query ensures ALL selected players were in each returned game
5. Frontend re-renders with filtered results
6. Stats are recalculated based on filtered games

## Example Usage

### Scenario
You want to see your performance when playing with your regular pod: Elijah, Adam, and Aaron.

### Steps
1. Open Match History
2. Show Pod Filter
3. Select "Elijah" from the dropdown
4. Select "Adam" from the dropdown
5. Select "Aaron" from the dropdown
6. View your wins/losses/stats for games with all three players

### What You'll See
- Only games where you AND Elijah AND Adam AND Aaron all participated
- Win rate specifically for this pod configuration
- Average life remaining when you win in this pod
- Total number of games with this exact group

## Benefits

1. **Track Competitive Dynamics**: See who tends to win when playing with specific groups
2. **Identify Pod Synergies**: Understand which player combinations work well together
3. **Personal Performance Analysis**: Track improvement with your regular playgroup
4. **Flexible Filtering**: Can filter by any combination of players you've played with
5. **Beautiful UI**: Modern, intuitive interface with avatars and searchable selection

## Technical Details

### Database Query Strategy
The backend uses SQL subqueries to ensure ALL pod members participated:
```sql
SELECT DISTINCT g.*
FROM games g
INNER JOIN players p ON g.id = p.game_id
WHERE p.clerk_user_id = ?  -- authenticated user
AND g.id IN (SELECT game_id FROM players WHERE clerk_user_id = ?)  -- first pod member
AND g.id IN (SELECT game_id FROM players WHERE clerk_user_id = ?)  -- second pod member
-- ... for each pod member
AND g.status = 'finished'
ORDER BY g.finished_at DESC
```

### Performance Considerations
- Player list is extracted from existing match history (no additional API call)
- Pod filter request is only made when actually filtering (not on initial load)
- Results are cached in React state until pod selection changes

### Future Enhancements (Not Yet Implemented)
- Save favorite pods for quick access
- Pod-based leaderboards
- Compare stats across different pod configurations
- Export pod statistics
- Share pod stats with friends

## Testing

To test this feature:
1. Ensure you have multiple finished games with different players
2. Navigate to `/history` page
3. Toggle the Pod Filter section
4. Select one or more players
5. Verify the game list updates to show only relevant games
6. Check that stats reflect the filtered results
7. Remove players and verify the filter updates accordingly

## Dependencies Added
- `cmdk` - Command menu component for searchable dropdowns
- `@radix-ui/react-popover` - Popover primitive for dropdown overlays
