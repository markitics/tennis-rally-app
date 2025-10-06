# Apple Watch Setup - Quick Start Guide

## Step 1: Add watchOS Target (30 seconds in Xcode)

1. Open `TennisTracker.xcodeproj` in Xcode
2. File → New → Target
3. Choose **watchOS** → **Watch App**
4. Name: `TennisTracker Watch App`
5. Uncheck "Include Notification Scene"
6. Click Finish

## Step 2: Add Watch Files to Target

The code files are already created! Just need to add them to the right targets:

### For Watch App Target:
1. Drag `WatchApp-ContentView.swift` into the Watch App target folder
2. In Xcode, right-click → "Move to..." → select Watch App folder
3. Make sure it's checked for "TennisTracker Watch App" target only

### For iOS App Target:
1. `PhoneWatchConnectivity.swift` is already in the iOS target
2. Make sure it's checked for "TennisTracker" target only

## Step 3: Update Watch App Entry Point

In your Watch App target, find the `@main` app file (probably `TennisTracker_Watch_AppApp.swift`).

Replace its contents with:

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

## Step 4: Build & Run

1. Make sure your iPhone is paired with your Apple Watch
2. Connect iPhone to Mac via USB
3. In Xcode, select the scheme: **TennisTracker Watch App**
4. Select destination: Your Apple Watch (via paired iPhone)
5. Press **Cmd+R**

Xcode will:
- Build the watch app
- Install it on your watch via the paired iPhone
- Launch it automatically

## Testing

1. Start a match on your iPhone
2. Look at your watch - you should see:
   - Current score (0-0)
   - "Mark Winner" button (blue)
   - "Jeff Winner" button (green)
3. Press a button on your watch
4. Score should update on both watch AND iPhone instantly!

## Troubleshooting

**"Build failed" or can't find watch target:**
- Make sure you selected "Watch App" (not "Watch App for iOS App")
- Check that deployment target is watchOS 9.0 or later

**Watch not showing up as destination:**
- Make sure iPhone and Watch are paired (open Watch app on iPhone)
- Make sure Watch is unlocked and on wrist
- Try: Xcode → Window → Devices and Simulators → check watch is listed

**"iPhone not reachable" error on watch:**
- Make sure iPhone app is running (doesn't need to be in foreground)
- Try launching iPhone app first, then watch app
- Check that both devices are on same WiFi

## What's Next?

This MVP has just 2 buttons. Easy to add more:

- **4 buttons:** Mark Winner/Error, Jeff Winner/Error
- **6 buttons:** Add Ace and Double Fault
- **Timeline navigation:** Use Digital Crown for back/forward
- **Complications:** Quick launch from watch face

But start with 2 buttons - get it working first! 🎾⌚
