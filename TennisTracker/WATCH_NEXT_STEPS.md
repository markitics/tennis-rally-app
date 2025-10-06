# Apple Watch App - Ready to Build! 🎾⌚

## What's Done ✅

All code files are created and ready:

### Watch App Files (add to watch target):
- ✅ `WatchApp-ContentView.swift` - Main TabView with 2 screens
- ✅ `ScoreDisplayView.swift` - Screen 1 (score display)
- ✅ `PointEntryView.swift` - Screen 2 (2 big buttons)

### iPhone App Files (already in iOS target):
- ✅ `PhoneWatchConnectivity.swift` - iPhone-side connectivity
- ✅ `ContentView.swift` - Updated with watch handler

## What You Need to Do (5-10 minutes)

### Step 1: Add Watch App Files to Xcode Target

Once you've created the watchOS target in Xcode:

1. **In Xcode Navigator**, find these 3 files:
   - `WatchApp-ContentView.swift`
   - `ScoreDisplayView.swift`
   - `PointEntryView.swift`

2. **For each file**:
   - Click the file
   - Open File Inspector (right panel)
   - Under "Target Membership":
     - ✅ Check `TennisTracker Watch App`
     - ❌ Uncheck `TennisTracker` (iOS)

### Step 2: Update Watch App Entry Point

Your watch target has a main app file (probably `TennisTracker_Watch_AppApp.swift`).

**Replace its contents with:**

```swift
import SwiftUI

@main
struct TennisTracker_Watch_App: App {
    var body: some Scene {
        WindowGroup {
            WatchAppContentView()
        }
    }
}
```

### Step 3: Build & Run on Watch

1. **Connect iPhone** to Mac via USB
2. **Make sure** iPhone is paired with Apple Watch
3. **In Xcode**:
   - Select scheme: `TennisTracker Watch App`
   - Select destination: Your Apple Watch (should show via iPhone)
   - Press **Cmd+R**

Xcode will:
- Build watch app
- Install on watch via paired iPhone
- Launch automatically

### Step 4: Test!

1. **On iPhone**: Start a match (or use existing active match)
2. **On Watch**: Launch the Tennis Tracker app
3. **You'll see**:
   - Screen 2 (Point Entry) with 2 big buttons - default view
   - Swipe left → Screen 1 (Score Display)
4. **Press button** on watch → Score updates on both watch AND iPhone instantly!

## How It Works

### UI Flow:
- **Screen 2 (Point Entry)** - Default, where you spend 95% of time
  - 2 big buttons: Mark Winner, Jeff Winner
  - Score shown at top
- **Screen 1 (Score Display)** - One swipe away
  - BIG: Game score (e.g., "40-30")
  - Small: Set score (e.g., "2-1")
  - Small: Server ("Mark serving")

### Data Flow:
1. Watch button press → Send message to iPhone
2. iPhone records point → Returns new score in reply
3. Watch receives score → Updates UI
4. **Total time: ~100-200ms** ✨

### Navigation:
- **Horizontal swipe** between screens (like Workout app)
- **Dots at top** show which screen (1 of 2)
- **Haptic feedback** on button press

## Troubleshooting

**Watch not showing in destinations:**
- Make sure iPhone and Watch are paired (Watch app on iPhone)
- Make sure Watch is unlocked and on wrist
- Try: Xcode → Window → Devices → Check watch appears

**"iPhone not reachable" on watch:**
- Make sure iPhone app is running (background is fine)
- Try launching iPhone app first
- Check both on same WiFi

**Build errors:**
- Make sure files are in correct target (Step 1)
- Clean build folder: Cmd+Shift+K
- Restart Xcode if needed

## What's Next?

### Future Enhancements:
1. **More buttons** - Add 4 or 6 buttons (Winner/Error for each player)
2. **Digital Crown** - Scroll to see point progression on Screen 1
3. **Complications** - Add to watch face for instant launch
4. **Live Activity mode** - Auto-launch when match starts
5. **Timeline navigation** - Back/forward through match history

But start simple - get the 2-button MVP working first! 🚀

## Files Summary

```
TennisTracker/
├── TennisTracker/                    # iOS app
│   ├── ContentView.swift            # ✅ Updated with watch handler
│   ├── PhoneWatchConnectivity.swift # ✅ iPhone connectivity
│   └── ...
├── TennisTracker Watch App/          # Watch app (you'll create this)
│   ├── WatchApp-ContentView.swift   # ✅ Main TabView
│   ├── ScoreDisplayView.swift       # ✅ Screen 1
│   ├── PointEntryView.swift         # ✅ Screen 2
│   └── TennisTracker_Watch_AppApp.swift  # Update this @main
└── TennisTrackerWidget/              # Widget extension
    └── ...
```

Ready to build! 🎾
