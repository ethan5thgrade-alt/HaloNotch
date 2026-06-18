# HaloNotch

A full-scale **Dynamic Island for your MacBook** — a native SwiftUI menu-bar app
that turns the notch (or, on non-notch Macs, a floating top-center pill) into a
live, interactive island: hover to expand, drop down a glass tray with Now
Playing, battery, clock/calendar, and a Pomodoro timer.

Built and researched against the leading apps in this space — NotchNook,
[Boring Notch](https://github.com/TheBoredTeam/boring.notch) (the open-source
reference), Alcove, and Notchy.

## What it does

- **Three states like iOS:** idle (black notch) → compact "live activity" flanks
  (album art + visualizer / timer) → expanded glass tray on hover.
- **Now Playing** — album art, scrubber, transport controls, and a live audio
  visualizer. Layered backend (see below) so it works out of the box.
- **Battery & charging** — fill + percentage + time-to-full/empty, instant
  updates via IOKit power-source notifications.
- **Clock & calendar** — live time/date and your next EventKit events.
- **Timer / Pomodoro** — quick-pick lengths; runs as a compact live activity in
  the closed notch.
- **Apple glass that matches your system** — the tray uses the real macOS 26
  **Liquid Glass** material (`.glassEffect`), falling back to `NSVisualEffectView`
  vibrancy on macOS 14–15. The strip hugging the notch stays opaque black so it
  merges with the hardware. Switchable: Glass / Black / Auto.

## Build & run

Requires macOS 14+, Xcode 26, and [XcodeGen](https://github.com/yonaskolb/XcodeGen).

```sh
cd ~/code/HaloNotch
xcodegen generate          # creates HaloNotch.xcodeproj (git-ignored)
open HaloNotch.xcodeproj    # then ⌘R in Xcode
# …or headless:
xcodebuild -project HaloNotch.xcodeproj -scheme HaloNotch -configuration Debug build
```

The app has no Dock icon — it lives in the menu bar (the rectangle icon). The
notch panel appears on the screen that has a notch (or the main screen).

### Permissions you'll be asked for

- **Automation** (Spotify / Music) — the first time media controls run, for the
  AppleScript now-playing source.
- **Calendar** — the first time the clock module appears, if you use it.

## The Now Playing backend (the interesting part)

macOS gives apps no public API for *other* apps' now-playing info. Two paths,
layered automatically:

1. **AppleScript source** (always on) — drives **Spotify + Apple Music**.
   Public, no entitlements, never breaks. This is why media works immediately.
2. **Universal MediaRemote adapter** (opt-in) — reads **every** app. Since
   macOS 15.4 the private `MediaRemote` framework is entitlement-gated, so the
   app bundle gets `nil`. The
   [`ungive/mediaremote-adapter`](https://github.com/ungive/mediaremote-adapter)
   trick runs the framework through the system `/usr/bin/perl` (which reports a
   `com.apple.*` bundle id and *is* allowed). Install it with:

   ```sh
   ./scripts/install-mediaremote-adapter.sh
   ```

   It installs to `~/Library/Application Support/HaloNotch/` and HaloNotch picks
   it up on next launch. Until then, you still have Spotify/Music via path 1.

The controller merges both sources (prefers whatever is *playing*) and routes
transport controls to whichever backend can drive the active app.

## Architecture

```
Sources/
  App/           HaloNotchApp (@main + AppDelegate), Preferences, NotchState,
                 SettingsView, MenuBarMenu
  Window/        ScreenGeometry (notch detection), NotchPanel (borderless
                 non-activating NSPanel), HoverMonitor (global cursor tracking),
                 NotchWindowController (positioning + open/close state machine)
  Views/         NotchRootView (3-layer morph), NotchShape (notch silhouette),
                 GlassMaterial (Liquid Glass / vibrancy), ExpandedView
  Views/Modules/ NowPlaying/ (model, AppleScript + adapter sources, controller,
                 view, visualizer), Battery/, Clock/, Timer/
```

- **Window:** a `.borderless`/`.nonactivatingPanel` `NSPanel` at `.statusBar`
  level, pinned top-center, hosting the SwiftUI tree via `NSHostingView`. It's
  click-through (`ignoresMouseEvents`) when closed and only captures clicks
  while expanded.
- **Notch detection:** `NSScreen.safeAreaInsets.top` + `auxiliaryTopLeftArea` /
  `auxiliaryTopRightArea` give the exact notch rect; falls back to a synthesized
  pill on non-notch Macs.
- **Hover:** a global + local `NSEvent` mouse-move monitor (no accessibility
  permission needed) compares the cursor against the notch / panel rects.
- **Animation:** one interruptible `spring` drives a continuous scale/opacity
  morph (no window resizing → no jank).

## Settings

Menu-bar → **HaloNotch Settings…**: launch at login, hover-vs-click, animation
speed, tray material, now-playing source + visualizer, and per-module toggles.

## Notes / honesty

- The AppleScript path and all four modules are fully implemented and working.
- The universal-adapter **read** path is fully wired; the installer script is
  best-effort against a third-party repo whose layout may change. If it fails,
  build the adapter per its README and drop the two files into the Application
  Support folder.
- Adapter **transport control** for non-Spotify/Music apps is best-effort
  (`send togglePlayPause/nextTrack/previousTrack`); Spotify/Music controls always
  go through reliable AppleScript.
