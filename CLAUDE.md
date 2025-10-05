# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Tennis Tracker is an iOS app for point-by-point tennis match tracking with timeline navigation. Given the fact that Deuce-Advantage-Deuce-Advantage sequences could in theory go on for a while, it implements a "compute-don't-store" architecture where **in-game** match state (scores like 15-30, deuce, advantage) is derived from the ordered sequence of points within the current game. Each point stores its gameNumber for efficient filtering, allowing game progression summaries to be computed on-demand from only the relevant game's points, not the entire match history.

Types of way a point can end: in this version, we divide the way a point can end into four main types:
"Ace" (a type of winner)
"Winner" (any other type of winner)
"Double fault" (a type of unforced error)
"Unforced error" (from play).

In any game, only one person is serving, so there are six different ways the point can end:
1. Server hits an ace
2. Server makes a double fault
3. Server hits a winner (during the rally)
4. Server makes an unforced error (not a double fault)
5. Receiver hits a winner
6. Receiver makes an unforced error.

Therefore, six large buttons will suffice on the main "input" screen.

## Changelog

### 2025-10-04

**Weather Integration:**
- Added WeatherKit integration to fetch weather data when matches start
- Extended Match model with `temperature`, `weatherCondition`, and `weatherSymbol` fields
- Created `WeatherService.swift` with async background weather fetching (non-blocking)
- Weather display shows temperature in both Celsius and Fahrenheit with SF Symbol icon
- Added WeatherKit entitlement to `TennisTracker.entitlements`
- Requires active Apple Developer Program membership ($99/year)
- Free tier: 500,000 API calls/month (we use 1 call per match)

**UI Improvements:**
- Fixed pyramid chart zero line centering in "By game" views (Points Won and Points Ended)
  - Previous: Asymmetric domains created off-center zero lines (e.g., -15 to 25)
  - Fixed: Implemented symmetric domains using `maxValue` computed property (e.g., -25 to 25)
- Action buttons (Add Note, Delete/End Match) now visible in all view modes (All sets, By set, By game)
  - Previous: Buttons only showed in default view mode
  - Fixed: Moved `MatchActionButtonsView` outside switch statement
- Match selector dropdown improvements:
  - Matches now sorted by most recent first
  - Shows match title (if set) instead of date in dropdown
  - Falls back to formatted date if no title exists

**Architecture:**
- Weather fetching uses Task-based concurrency with retry logic (up to 2 seconds) to wait for location
- Weather errors are logged but non-fatal (weather is nice-to-have, not critical)

## Build Commands

```bash
# Build the app for iOS simulator
cd TennisTracker && xcodebuild -scheme TennisTracker -destination 'platform=iOS Simulator,name=iPhone 17' build

# Find available simulators
xcrun simctl list devices

# Clean build
cd TennisTracker && xcodebuild clean
```

## Required Capabilities

### WeatherKit
The app uses Apple's WeatherKit framework to fetch weather data for each match. This requires:

1. **Enable WeatherKit in Xcode:**
   - Select the TennisTracker target
   - Go to "Signing & Capabilities"
   - Click "+ Capability"
   - Add "WeatherKit"

2. **What it does:**
   - Fetches weather conditions when a match starts (if location is available)
   - Stores temperature, condition, and SF Symbol name in the Match model
   - Displays weather info in the Stats view under the match date
   - Free tier: 500,000 API calls/month (we use 1 call per match)

## Core Architecture

### Data Models (SwiftData)
- **Player**: Simple entity with id and name
- **Match**: Contains two players, firstServerID, and ordered collection of Points
- **Point**: Links to match, winner/loser players, PointType enum, setNumber, timestamp

Key relationship: `Match.points` is an ordered array that forms the authoritative timeline. All scoring is computed from this sequence. (Or, at least all in-game scoring.)

### Tennis Scoring Engine (ScoreEngine.swift)
Pure functional scoring logic that computes match state from point sequences:

- **foldPoints()**: Processes point timeline to determine completed sets, current set games, and in-game scores
- **Tiebreak Logic**: Triggered at 6-6 in games, first to 7 points win by 2
- **Server Rotation**: Alternates each game, with special tiebreak rotation (every 2 points)
- **Match State**: Returns DerivedMatchState with current/final scores and leader determination

### Timeline Navigation Pattern
The app uses a cursor-based system for navigating match history:

- **Cursor**: Index into Match.points array (0 to points.count)
- **Back/Forward**: Move cursor to see historical match states
- **Rewrite-from-here**: When adding points while cursor < points.count, removes future points and inserts new point
- **Derived State**: ScoreEngine computes state from points.prefix(cursor)

### View Architecture
- **ContentView**: Root with segmented tab control (Play/View/Settings). 
- **PlayView**: A simple interface with:
  - 6 main large buttons for recording how each points ends, plus 
  - timeline navigation (back/forward to see how we got to this score). Pressing the 'back' button not only rewinds the score, but also rewinds the written sequence of steps. The "sequence of steps" might look like "0-0 -> Mark winner -> 15-0 -> Jeff error -> 30-0 -> Mark ace -> 40-0 -> Mark double fault -> 40-15" etc. We use the word "cursor" to mark the "point in time" we're viewing; it's always the latest score unless we've navigated "back".
- **StatsView**: Match/set filtering with point type breakdown. Key charts show, for each player, (i) the breakdown of the points they won (from hitting a winner vs. from their opponent making a mistake), and (ii) the breakdown of "all the points they ended" (that's winners they hit plus mistakes they made).
- Settings page (e.g., to turn on/off sound). This is mainly a placeholder for now, but we'll add more settings in future.
- **MatchViewModel**: ObservableObject managing cursor state and derived match state

## Tennis Rules Implementation
- **Games**: Standard 0/15/30/40 with deuce/advantage (win by 2)
- **Sets**: First to 6 games, win by 2, tiebreak at 6-6
- **Match**: Continuous play (no "best of" format)
- **Server Logic**: Tracked per set start, alternates each game, special tiebreak rotation
- **Current Winner**: Hierarchical comparison (sets → games → points)

## Key Implementation Notes
- Point input is gated by server status (only server can double fault or ace)
- All scoring computation happens in ScoreEngine static methods
- Timeline navigation preserves non-destructive match editing, so repeatedly pressing "forward" will bring us forward in time, one point at a time, to the latest score.
- SwiftData relationships use cascade delete rules
- Local-only storage (no cloud sync in current implementation)
- Player names hard-coded as "Mark" and "Jeff" for this first MVP version

## Design Principles & Style Guide

**CRITICAL: Always Use Latest iOS Design Patterns**

The user is obsessed with always using the latest default style guide recommendations, and wants this app to look beautiful in iOS 26 with "liquid glass" and other recommended best design practices.

**When implementing UI:**
- ✅ **DO**: Consult the latest Apple documentation and use modern iOS 26 patterns
- ✅ **DO**: Prioritize edge-to-edge content, translucent materials (`.ultraThinMaterial`), and liquid glass effects
- ✅ **DO**: Look at modern apps (X/Twitter, Slack) for reference on current iOS design patterns
- ❌ **DON'T**: Revert to reliable but potentially out-of-date coding patterns
- ❌ **DON'T**: Use opaque backgrounds or heavy UI elements when translucent materials are available

**Key Modern Patterns in This App:**
- TabView with `.toolbarBackground(.ultraThinMaterial, for: .tabBar)` for liquid glass effect
- Content that extends edge-to-edge using `.ignoresSafeArea(edges: .bottom)`
- ScrollViews with bottom padding to allow content to scroll under translucent tab bars
- Always follow Apple's Human Interface Guidelines: https://developer.apple.com/design/

**If in doubt about a design decision:** Consult the latest Apple documentation rather than falling back to older, more "reliable" patterns. Modern aesthetics and following current guidelines is a priority.

## Learnings & Architectural Gotchas

### SwiftData vs @Published Performance (Critical - discovered 2025-10-03)

When displaying derived data in SwiftUI views, there are TWO ways to access match data:

**1. @Published ViewModel state (FAST ✅)**
- Example: `viewModel.derivedState`
- Updates instantly when cursor changes
- Works with in-memory data
- Used by: Top score display, which updates immediately

**2. Direct SwiftData queries (SLOW ❌)**
- Example: `match.sortedPoints` directly in views
- Waits for SwiftData persistence to commit (can take seconds!)
- Blocks UI updates until database write completes
- Bug example: GameProgressionView initially queried SwiftData directly - caused 3-5 second lag

**The Bug:** GameProgressionView was querying `match.sortedPoints` directly while the top score used `viewModel.derivedState`. This caused:
- Top score: instant updates
- Progression text: 3-5 second lag
- Inconsistent UX where different parts of screen updated at different times

**The Fix:** Changed GameProgressionView to use `viewModel.cursor` and work with visible points from the ViewModel instead of querying SwiftData directly. Now both use the same fast in-memory path.

**Lesson:** Always use @Published ViewModel state for real-time UI updates. Only query SwiftData directly for background operations or initial loads.

### Game Completion Logic - Single Source of Truth

**Problem:** Had duplicate "is game complete?" logic in two places:
1. `buildProgression()` - calculated `gameWon` inline
2. `isCurrentScoreZeroZero` - checked if current game was empty

**Solution:** Extracted `isGameComplete(points:)` helper that uses the same logic as `buildProgression()`. Now there's one source of truth for "did this game end?" calculation.

**Lesson:** When you see the same conditional logic in multiple places, extract it into a reusable helper. Don't duplicate tennis scoring rules.

### Live Activity AppIntent Buttons - Lock Screen Execution (Critical - discovered 2025-10-04)

**Problem:** Live Activity buttons were using URL schemes (`Link` with `tennistracker://` URLs) which required:
- Phone to be unlocked
- App to open and come to foreground
- User to be on the Play screen

This defeated the purpose of Live Activity buttons - they should work from the lock screen without opening the app.

**Root Cause:** Using `Link(destination: URL(...))` instead of `Button(intent: ...)`
- URL schemes ALWAYS open the app
- Even with `?silent=true` parameter, iOS opens the app to handle the URL
- This is by design - URL handling requires the app to be active

**The Solution:** Use AppIntent buttons directly in Live Activity
```swift
// ❌ OLD WAY - Opens app, requires unlock
Link(destination: URL(string: "tennistracker://winner?silent=true")!) {
    VStack {
        Text("🏆")
        Text("Winner")
    }
}

// ✅ NEW WAY - Runs in background, works from lock screen
Button(intent: WinnerIntent()) {
    VStack {
        Text("🏆")
        Text("Winner")
    }
}
```

**How It Works:**
1. **AppIntent Definition** (`LiveActivityIntents.swift`):
   - `static var openAppWhenRun: Bool = false` - Critical flag!
   - Intent executes in the widget extension process (separate from main app)
   - Saves action to shared UserDefaults (App Group)
   - Sends Darwin notification to wake up main app

2. **Widget Extension Info.plist**:
   - `INIntentsSupported` lists the intent names
   - `INIntentsRestrictedWhileLocked` is EMPTY array (allows lock screen execution)

3. **Main App Listener** (`TennisTrackerApp.swift`):
   - Registers for Darwin notifications via `CFNotificationCenterGetDarwinNotifyCenter()`
   - Checks shared UserDefaults for pending actions
   - Posts local NotificationCenter event for PlayView to handle
   - All happens in background - no UI disruption!

**Key Requirements:**
- App Group configured (`group.com.markmoriarty.apps.TennisTracker`)
- Widget extension has App Group entitlement
- Main app has App Group entitlement
- AppIntents properly declared in Info.plist
- Darwin notification observer set up on app launch

**Result:** Buttons now work from:
- Lock screen ✅
- Home screen (when app backgrounded) ✅
- Any screen (not just Play view) ✅
- Without unlocking phone ✅
- Without opening app ✅

**Lesson:** For Live Activities that should work from lock screen, ALWAYS use `Button(intent:)` not `Link(destination:)`. URL schemes are for deep linking, not background actions.

## BugFixes

### Game Number Skipping Bug (Fixed 2025-10-04)

**Problem:** In the "By game" pyramid charts (Points Won and Points Ended), game numbers were skipping values. For example:
- Set 1: S1G1, S1G2, S1G3, S1G4, S1G5, S1G6, S1G7, S1G9 (skips G8)
- Set 2: S2G11 (skips G10)

The stored `gameNumber` values in the database were literally 1, 2, 3, 4, 5, 6, 7, 9, 11... with missing numbers.

**Root Cause:** `ScoreEngine.currentGameNumber()` (lines 83-135) duplicates the game completion logic from `foldPoints()`, but the two implementations can get out of sync. When sets end or during tiebreaks, the duplicate logic miscounts `gamesCompleted`, causing it to assign incorrect game numbers to new points.

**The Fix:** Instead of relying on the buggy stored `gameNumber` values, calculate the game-within-set number directly in the chart views (`ByGamePointsWonView` and `ByGamePointsEndedView` in `StatsView.swift`):

```swift
var gameNumberInSet = 0  // Calculate game number instead of using stored value
var currentSetNumber = 0

for (key, points) in groupedPoints.sorted(by: { $0.key < $1.key }) {
    guard let firstPoint = points.first else { continue }

    // Reset game count when entering new set
    if firstPoint.setNumber != currentSetNumber {
        currentSetNumber = firstPoint.setNumber
        gameNumberInSet = 0  // Reset for new set
    }

    gameNumberInSet += 1  // Increment for each game

    games.append(GameData(
        // ... other fields
        gameNumber: gameNumberInSet,  // Use calculated value instead of firstPoint.gameNumber
    ))
}
```

This workaround ignores the broken stored `gameNumber` and just counts 1, 2, 3... for each game in the set, ensuring consecutive numbering in the charts (S1G1-G8, S2G1-G7, etc.).

**Impact:** The chart views now show proper consecutive game numbers. The underlying `ScoreEngine.currentGameNumber()` bug still exists and could be fixed in the future, but this workaround makes the UI correct regardless of what's stored in the database.

**Lesson:** When you have duplicate logic in multiple places, they can drift out of sync. The proper fix would be to eliminate the duplicate `currentGameNumber()` function and calculate it from the authoritative `foldPoints()` result instead.

### Live Activity Cursor Lag Bug (Fixed 2025-10-04)

**Problem:** When rapidly pressing Live Activity buttons from lock screen, only the first button press would advance the cursor. Subsequent presses would create points in the database, but the cursor would stay stuck at the first point. Points became "invisible" until the user manually pressed the forward button to reveal them.

**Observed behavior:**
- Press button 1: Score updates correctly (e.g., 40-0 → 2-0) ✅
- Press button 2: Score updates correctly (e.g., 2-0 → 2-0, 15-0) ✅
- Press button 3: Live Activity shows no change ❌
- Press button 4: Live Activity shows no change ❌
- Unlock app: Cursor at 127, but forward button not greyed out
- Press forward twice: Reveals hidden points at 128, 129

**Root Cause:** SwiftData persistence lag. The line `matchViewModel.cursor = match.sortedPoints.count` in `ContentView.recordPoint()` was querying SwiftData directly. When points were inserted rapidly (< 2 seconds apart), SwiftData hadn't committed the previous point yet, so `.count` returned stale data.

Example timeline:
```
T=0s:   Insert point 127, set cursor = match.sortedPoints.count → 127 ✅
T=1s:   Insert point 128, set cursor = match.sortedPoints.count → 127 ❌ (SwiftData lag!)
T=2s:   Insert point 129, set cursor = match.sortedPoints.count → 127 ❌ (SwiftData lag!)
```

Points were successfully created, but cursor never advanced past 127.

**The Fix:** Two-part fix in `ContentView.recordPoint()`:

**Part 1 - Cursor increment:**
```swift
// OLD (broken):
matchViewModel.cursor = match.sortedPoints.count  // Reads stale SwiftData

// NEW (fixed):
matchViewModel.cursor = matchViewModel.cursor + 1  // Increment from known position
```

**Part 2 - Live Activity score computation:**
```swift
// OLD (broken):
let derivedState = matchViewModel.derivedState  // Uses match.sortedPoints (stale!)

// NEW (fixed):
// Manually include uncommitted point in calculation
let committedPoints = Array(match.sortedPoints)
let visiblePointsWithNew = committedPoints + [newPoint]

let derivedState = ScoreEngine.compute(
    visiblePoints: visiblePointsWithNew,
    fullPoints: visiblePointsWithNew,
    p1: match.playerOne.id,
    p2: match.playerTwo.id,
    firstServerID: match.firstServerID
)
```

The second fix was necessary because even though cursor advanced correctly, the Live Activity scoreboard would lag behind reality. Computing `derivedState` from `match.sortedPoints` would only include committed points, so rapid button presses showed stale scores on the lock screen.

This follows the critical architecture rule documented in "SwiftData vs @Published Performance": **Always use @Published ViewModel state for real-time UI updates. Never query SwiftData directly.**

**Impact:** Live Activity buttons now work perfectly from lock screen with rapid presses. Both cursor AND displayed score advance immediately with each press, keeping everything in sync regardless of SwiftData commit timing.

**Lesson:** The "SwiftData vs @Published Performance" rule isn't just for display optimization - it's critical for correctness. Any code path that needs immediate consistency (like Live Activity actions) MUST either use the ViewModel state OR manually include uncommitted data in calculations. SwiftData is asynchronous and can lag by several seconds.
