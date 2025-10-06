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

## Code Quality Assessment (2025-10-05)

### Architecture Overview

**Data Models** (Item.swift)
The app uses SwiftData with three core models:

1. **Player**: Simple entity (id, name)
2. **Match**: Contains two players, first server, points collection, weather data, location
   - Uses cascade delete for points relationship
   - Stores tiebreak server history as comma-separated string (converted to UUID array)
   - Has `sortedPoints` computed property (sorts by timestamp)
3. **Point**: Stores winner, loser, type, setNumber, gameNumber, timestamp
   - Types: `.ace`, `.winner`, `.doubleFault`, `.unforcedError`

**Key insight**: The "compute-don't-store" architecture—match state is derived from point sequence, not stored directly.

**Core Scoring Logic** (ScoreEngine.swift)
Pure functional engine with no dependencies:

- **`foldPoints()`**: Processes point timeline → returns `MatchState` (completed sets, current game score, tiebreak status)
- **Tennis rules**: Standard deuce/advantage, tiebreak at 6-6, win by 2
- **Server rotation**: Alternates per game, special tiebreak logic (first server serves 1 point, then alternates every 2)
- **`currentServerID()`**: Determines current server from point history
- **`currentGameNumber()`**: ⚠️ **DUPLICATE LOGIC** (documented bug—different from `foldPoints()`, causes game numbering bugs)

**State Management** (MatchViewModel)
ObservableObject with:
- `@Published cursor: Int` — index into points array for timeline navigation
- `@Published match: Match?`
- `derivedState` — computed property calling ScoreEngine with `points.prefix(cursor)`

**Critical**: Uses in-memory @Published state to avoid SwiftData persistence lag (documented in CLAUDE.md)

**Views**

**ContentView**: Root TabView with 3 tabs
- **Play tab**: Shows PlayView if active match exists, else FirstServerSelectionView
- **View tab**: StatsView with charts/analytics
- **Settings tab**: Sound toggle, placeholder for future settings
- Handles Live Activity button actions via NotificationCenter
- 50ms debounce to prevent accidental double-taps while allowing rapid catch-up entry

**PlayView**: 6-button input interface
- **UnifiedButtonsView**: Context-aware buttons (serve/rally/errors) arranged in 2x3 grid
- Shows current score, completed sets, timeline navigation
- 50ms debounce (same as ContentView for consistency)
- **GameProgressionView**: Shows point-by-point progression like "0-0 → Mark winner → 15-0"
- Haptic feedback (different patterns for Mark vs Jeff)
- Speech synthesis for point announcements

**StatsView**: Analytics with multiple view modes
- **Filter modes**: All sets, By set, By game (Points Won/Ended)
- **Charts**: Horizontal stacked bars, pyramid charts for per-game breakdown
- **⚠️ Game numbering workaround** (lines 1138-1153, 1332-1348): Recalculates game numbers to fix stored bug
- Match title editing, weather display, location map

**Live Activities**
- **LiveActivityManager**: Starts/updates/ends Live Activities
- **TennisTrackerApp**: Handles URL schemes from Live Activity buttons (but CLAUDE.md says this was replaced with AppIntents)
- **⚠️ Architecture mismatch**: Code shows URL handling, but docs say switched to AppIntent buttons

### Code Quality Issues & Recommendations

**🔴 Critical Issues**

1. **Duplicate Game Completion Logic** (ScoreEngine.swift:83-136)
   - `currentGameNumber()` duplicates `foldPoints()` logic but implementations differ
   - **Result**: Game numbers stored in DB are incorrect (skip values like 1,2,3,7,9)
   - **Evidence**: StatsView has workaround code to recalculate game numbers
   - **Fix**: Delete `currentGameNumber()`, extract from `foldPoints()` result instead

2. **Debouncing** (PlayView + ContentView) - ✅ FIXED 2025-10-05
   - Both now use consistent 50ms debounce
   - Prevents accidental double-taps while allowing rapid catch-up entry
   - Previous: 500ms (ContentView), 100ms (PlayView) - too slow for catching up on missed points

3. **SwiftData Race Condition Workarounds** (ContentView:266-305)
   - Manually includes uncommitted points in calculations
   - Increments cursor from known position instead of querying `.count`
   - **Why needed**: SwiftData persistence lags 2-5 seconds
   - **Better approach**: Consider using in-memory buffer + batch commits, or redesign to avoid querying SwiftData for real-time updates

4. **Tiebreak Storage Hack** (Match model lines 53-65)
   - UUIDs stored as comma-separated string, converted to array
   - **Why**: SwiftData doesn't support `[UUID]` arrays natively
   - **Better**: Use separate @Model for TiebreakServer with relationship, or use `@Attribute(.transformable)`

**🟡 Design Issues**

5. **Hardcoded Player Names**
   - "Mark" and "Jeff" scattered throughout (PlayView:618-694, ContentView:320-354)
   - **Fix**: Use match.playerOne/playerTwo consistently, eliminate hardcoded strings

6. **Massive View Files**
   - StatsView.swift: 1535 lines
   - PlayView.swift: 994 lines
   - **Fix**: Extract views into separate files (e.g., `ByGamePointsWonView` → own file)

7. **Commented-Out Code** (StatsView:627-640)
   - Dead code should be deleted, not commented
   - Use git for history

8. **Mixed Responsibilities in ContentView**
   - Handles URL schemes (lines 62-115) but docs say this was replaced
   - Widget action handling (lines 112-199)
   - Match creation, location, weather
   - **Fix**: Extract services (URLHandler, WidgetActionService, MatchFactory)

**🟢 Performance Issues**

9. **GameProgressionView Performance Logging**
   - Lines 848-926: Extensive performance logging on every render
   - **Impact**: Console spam, performance overhead in production
   - **Fix**: Wrap in `#if DEBUG` or remove entirely

10. **Excessive `match.sortedPoints` Calls**
    - Called repeatedly throughout views
    - Each call creates new sorted array
    - **Fix**: Cache sorted points in ViewModel, update only on point insertion

11. **Per-Game Chart Recalculation** (StatsView:1131-1187, 1326-1393)
    - Recalculates game numbers on every render
    - **Fix**: Compute once, cache in @State

**🔵 Architecture Suggestions**

12. **Missing Abstraction for Point Recording**
    - Logic duplicated in PlayView (lines 319-543) and ContentView (lines 201-308)
    - **Fix**: Extract `PointRecordingService` with single source of truth

13. **No Error Handling**
    - SwiftData operations have no try/catch
    - Weather fetch errors are logged but not surfaced
    - **Fix**: Add error boundaries, user-facing error messages

14. **Action ID Cleanup in Static Dict** (ContentView:51-52, 154-159)
    - Uses static mutable state for deduplication
    - **Issue**: Never garbage collected until cleanup runs
    - **Risk**: Memory leak on very long sessions
    - **Fix**: Use actor-based service with automatic cleanup

15. **Speech Synthesizer as Let Constant** (PlayView:306)
    - Created once but never reused across point recordings
    - Should be @StateObject or injected dependency

**🟣 Testing & Maintainability**

16. **Zero Test Coverage**
    - No unit tests for ScoreEngine (pure functions, perfect for testing!)
    - No tests for game completion logic
    - **Recommendation**: Start with ScoreEngine tests (tennis scoring rules are complex)

17. **Magic Numbers**
    - Chart heights (18, 200), widths (30, 80)
    - **Fix**: Extract to named constants
    - Note: Debounce time (0.05/50ms) is now consistent across the app

18. **Print Debugging Everywhere**
    - 50+ print statements for debugging
    - **Fix**: Use proper logging framework (OSLog), add log levels

**✅ Good Practices Found**

- Clean separation of scoring logic (ScoreEngine is stateless)
- Proper use of SwiftUI state management
- Documentation in CLAUDE.md of known bugs and fixes
- Cascade delete relationships
- Functional programming approach for game state

### Priority Recommendations

**High Priority** (blocking correctness):
1. Fix duplicate game number logic (delete `currentGameNumber()`)
2. Consolidate debouncing into single location
3. Remove hardcoded player names

**Medium Priority** (maintainability):
4. Extract point recording into service
5. Split massive view files
6. Add error handling
7. Cache sorted points

**Low Priority** (nice-to-have):
8. Add unit tests for ScoreEngine
9. Replace print debugging with OSLog
10. Clean up commented code

## Near Term Work (Post-2025-10-05 Fixes)

### ✅ Recently Completed (2025-10-05)

**Live Activity Performance & Reliability Fixes:**
1. ✅ Fixed Info.plist - Added 4 missing AppIntent declarations
   - Added: `AceIntent`, `DoubleFaultIntent`, `JeffWinnerIntent`, `JeffErrorIntent`
   - Impact: All 6 Live Activity buttons now work reliably from lock screen

2. ✅ Implemented in-memory cache to eliminate SwiftData lag
   - Added `cachedPoints` array to `MatchViewModel`
   - Points added to cache instantly (< 10ms vs 2-5 second SwiftData lag)
   - All score calculations now use fresh cached data
   - Impact: Score updates are instant, no more "time travel" bugs

3. ✅ Updated all code paths to use cached points
   - Replaced every `match.sortedPoints` call with `viewModel.cachedPoints`
   - Updated: MatchViewModel, ContentView, PlayView, GameProgressionView
   - Impact: Consistent, instant data everywhere

4. ✅ Removed dead URL handling code
   - Deleted unused URL scheme handling from `TennisTrackerApp.swift` (54 lines)
   - Cleaned up architecture mismatch (AppIntents were already in use)
   - Impact: Cleaner codebase, less confusion

5. ✅ Fixed duplicate point bug
   - Replaced static dictionary with Actor-based `ActionIDStore` for thread-safe deduplication
   - Prevents race conditions from simultaneous button presses
   - Impact: No more "first press awards TWO points" bug

**Result**: Live Activity now works perfectly with instant score updates from lock screen! 🎾

### 🔴 High Priority Next Steps (Blocking Correctness)

1. **Fix duplicate game number logic** (ScoreEngine.swift:83-136)
   - **Problem**: `currentGameNumber()` duplicates `foldPoints()` logic but implementations differ
   - **Result**: Game numbers stored as 1,2,3,7,9 (skipping values like 4,5,6,8,10)
   - **Evidence**: StatsView has workaround code (lines 1138-1153, 1332-1348) that recalculates game numbers
   - **Fix**: Delete `currentGameNumber()` function entirely, derive game numbers from `foldPoints()` result
   - **Impact**: Correct game numbers in database and "By game" charts
   - **Estimated effort**: 2-3 hours (requires careful refactoring)

2. **Consolidate debouncing into single location**
   - **Problem**: Duplicate debouncing in PlayView (100ms) and ContentView (500ms)
   - **Issue**: Inconsistent timing, double processing guards
   - **Fix**: Move all debouncing to ContentView (handles both UI and Live Activity)
   - **Impact**: Consistent timing, simpler code
   - **Estimated effort**: 30 minutes

3. **Remove hardcoded player names**
   - **Problem**: "Mark" and "Jeff" scattered throughout (PlayView:618-694, ContentView:320-354)
   - **Fix**: Use `match.playerOne.name` and `match.playerTwo.name` consistently
   - **Impact**: App works with any player names (future-proof for settings)
   - **Estimated effort**: 1 hour

### 🟡 Medium Priority (Maintainability)

4. **Extract point recording into shared service**
   - **Problem**: Point recording logic duplicated in PlayView (lines 319-543) and ContentView (lines 201-308)
   - **Fix**: Create `PointRecordingService` class with single implementation
   - **Impact**: No duplicate code, single source of truth, easier to maintain
   - **Estimated effort**: 2 hours

5. **Split massive view files**
   - **Problem**: StatsView.swift (1535 lines), PlayView.swift (994 lines)
   - **Fix**: Extract into separate files:
     - `ByGamePointsWonView.swift`
     - `ByGamePointsEndedView.swift`
     - `GameProgressionView.swift`
     - `PointInputView.swift`
   - **Impact**: Easier navigation, faster compile times
   - **Estimated effort**: 1-2 hours

6. **Add error handling**
   - **Problem**: SwiftData operations have no try/catch, weather fetch errors only logged
   - **Fix**: Add error boundaries, show user-facing error messages
   - **Impact**: Better UX when things go wrong
   - **Estimated effort**: 3 hours

7. **Cache per-game chart calculations**
   - **Problem**: StatsView recalculates game numbers on every render (lines 1131-1187, 1326-1393)
   - **Fix**: Compute once, cache in @State
   - **Impact**: Better chart rendering performance
   - **Estimated effort**: 1 hour

### 🟢 Low Priority (Nice-to-Have)

8. **Add unit tests for ScoreEngine**
   - **Why**: Pure functions, complex tennis rules (deuce, tiebreaks, server rotation)
   - **Impact**: Confidence in scoring logic, catch regressions
   - **Estimated effort**: 4-6 hours

9. **Replace print debugging with OSLog**
   - **Problem**: 50+ print statements for debugging
   - **Fix**: Use OSLog with log levels (debug, info, error)
   - **Impact**: Production-ready logging, better performance
   - **Estimated effort**: 2 hours

10. **Clean up commented code**
    - **Problem**: Dead code in StatsView:627-640
    - **Fix**: Delete commented sections, use git for history
    - **Impact**: Cleaner codebase
    - **Estimated effort**: 15 minutes

## Changelog

### 2025-10-05

**Live Activity Performance & Reliability Fixes:**

The Live Activity feature was experiencing severe performance issues and bugs:
- Score updates had 2-5 second lag from lock screen button presses
- First button press would sometimes award TWO points (race condition)
- Scores would "time travel" backwards (e.g., "1-3 30-0" → "1-2 40-Ad")
- Only 2 of 6 buttons worked reliably from lock screen

**Root Causes Identified:**
1. SwiftData persistence lag (2-5 seconds) caused stale data reads
2. Missing AppIntent declarations in widget Info.plist
3. Race conditions in action ID deduplication (static dictionary)
4. All code paths queried SwiftData directly instead of using cache

**Fixes Implemented:**
- **In-Memory Cache Architecture** (`MatchViewModel.swift`)
  - Added `cachedPoints` array for instant reads (<10ms vs 2-5s SwiftData lag)
  - Points added to cache immediately on button press
  - SwiftData writes happen in background (async, we don't care about lag)
  - All score calculations now use fresh cached data

- **Widget Configuration** (`TennisTrackerWidget/Info.plist`)
  - Added 4 missing AppIntent declarations: `AceIntent`, `DoubleFaultIntent`, `JeffWinnerIntent`, `JeffErrorIntent`
  - Result: All 6 Live Activity buttons now work from lock screen

- **Thread-Safe Deduplication** (`ContentView.swift`)
  - Replaced static dictionary with Actor-based `ActionIDStore`
  - Prevents race conditions from simultaneous button presses
  - Automatic cleanup of old action IDs (5 second window)

- **Cache-First Code Paths** (All files)
  - Replaced every `match.sortedPoints` call with `viewModel.cachedPoints`
  - Updated: `ContentView`, `PlayView`, `GameProgressionView`, `MatchViewModel`
  - Consistent, instant data everywhere

- **Code Cleanup** (`TennisTrackerApp.swift`)
  - Removed 54 lines of dead URL handling code (leftover from pre-AppIntent architecture)
  - Cleaned up confusing architecture mismatch

**Impact:**
- ✅ Live Activity score updates are now instant (<10ms response time)
- ✅ No more duplicate points on first press
- ✅ No more "time travel" score bugs
- ✅ All 6 buttons work reliably from lock screen
- ✅ Consistent point ordering (no random re-sorting)

**Performance Improvement:**
- Before: 2-5 second lag per button press (SwiftData query on every render)
- After: <10ms per button press (in-memory cache, SwiftData in background)
- 200-500x performance improvement!

**Files Changed:**
- `TennisTracker/TennisTracker/MatchViewModel.swift` - Added cache infrastructure
- `TennisTracker/TennisTracker/ContentView.swift` - Cache usage + Actor deduplication
- `TennisTracker/TennisTracker/PlayView.swift` - Updated to use cachedPoints
- `TennisTracker/TennisTracker/TennisTrackerApp.swift` - Removed dead URL code
- `TennisTracker/TennisTrackerWidget/Info.plist` - Added missing intents
- `CLAUDE.md` - Added "Near Term Work" section documenting fixes and future work

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

## When writing commit messages
This whole app is being vibe-coded by Claude, which we'll celebrate in the README.md.
Therefore, do not include extraneous mentions like this in commit messages: "written by claude code" or similar; never write "Co-Authored-By: Claude <noreply@anthropic.com>" (or similar) in a commit message

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
