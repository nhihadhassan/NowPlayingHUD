# NowPlayingHUD

A tiny, native macOS menu-bar utility that shows a brief, polished Now Playing popup whenever
your Spotify (or Apple Music) track changes — the Mac equivalent of the media popup Windows
shows, but built to feel like something Apple could have shipped.

No Electron, no webview, no local web server, no backend, no Spotify Web API account. Everything
runs locally against the Spotify/Apple Music apps already installed on your Mac, driven by their
own AppleScript scripting interfaces and distributed notifications.

> **Naming.** "NowPlayingHUD" is a placeholder project name — see [Renaming](#renaming) to change
> it before you ship it under your own name.

## Contents

- [What it does](#what-it-does)
- [Screenshots](#screenshots)
- [System requirements](#system-requirements)
- [Building](#building)
- [Installing and running](#installing-and-running)
- [Spotify Automation permission](#spotify-automation-permission)
- [Launch at Login](#launch-at-login)
- [Settings](#settings)
- [Keyboard shortcuts](#keyboard-shortcuts)
- [Apple Music support](#apple-music-support)
- [Architecture](#architecture)
- [Privacy](#privacy)
- [Performance](#performance)
- [Troubleshooting](#troubleshooting)
- [Known limitations](#known-limitations)
- [Testing](#testing)
- [Uninstalling completely](#uninstalling-completely)
- [Renaming](#renaming)

## What it does

- Watches Spotify's `com.spotify.client.PlaybackStateChanged` distributed notification (and
  Apple Music's `com.apple.Music.playerInfo`) — event-driven, never a polling loop.
- Shows a floating HUD near the top of your screen: artwork, title, artist, and a subtle progress
  bar. It fades/scales in, sits for a few seconds, and fades away — no window ever steals your
  keyboard focus or the currently-active app.
- Hovering it reveals transport controls, a seek scrubber, elapsed/remaining time, volume, and
  shuffle/repeat — a compact notification by default, a full player when you actually want one.
- Skip through five songs in a row and you still get exactly one HUD, updated in place each time.
- Lives in the menu bar (no Dock icon) with a full mini player in its popover, and a right-click
  menu for quick actions.
- Understands MacBook notches: on a notched display, "Smart Top Center" tucks the HUD just below
  the camera housing instead of under it, using only the public `NSScreen` safe-area APIs — no
  hardcoded model list.
- Works across multiple displays, Spaces, Stage Manager, and full-screen apps.

## Screenshots

_Add screenshots here after building and running the app — e.g. the compact HUD, the hover-expanded
HUD, the menu bar popover, and the Settings window. (`Cmd-Shift-4` to capture a region.)_

```
docs/screenshot-hud-compact.png
docs/screenshot-hud-expanded.png
docs/screenshot-menubar-popover.png
docs/screenshot-settings.png
```

## System requirements

- **macOS 14.0 (Sonoma) or later.** See [why macOS 14](#why-macos-14) below.
- Apple Silicon or Intel Mac.
- [Spotify for macOS](https://www.spotify.com/download/mac/) and/or Apple Music (built into
  macOS) — at least one installed to have anything to control.
- Xcode **or** just the free Command Line Tools (`xcode-select --install`) — see
  [Building](#building).

### Why macOS 14

Real [Liquid Glass](#liquid-glass) needs macOS 26; everything else in this app — Swift
Observation (`@Observable`), `SMAppService`, `NSGlassEffectView`'s vibrancy-material predecessor,
and the notch-safe-area `NSScreen` APIs — is available from macOS 12–14. macOS 14 was chosen as
the floor because `@Observable` (used throughout for reactive state) requires it, and going lower
would mean reintroducing Combine/`ObservableObject` boilerplate for no real benefit, since Liquid
Glass itself is already behind its own `#available(macOS 26.0, *)` check regardless of the floor.

## Building

**This was built and verified on a Mac with only Xcode's Command Line Tools installed — no full
Xcode.app.** Swift Package Manager is the actual source of truth; a `Makefile` does what Xcode
would otherwise do for you (assembling a real `.app`, generating the icon, code-signing).

```bash
# One-time, if you don't already have the Command Line Tools:
xcode-select --install

git clone <this-repo>
cd NowPlayingHUD   # or wherever you cloned it

make app           # builds + assembles + ad-hoc signs build/NowPlayingHUD.app
make run           # builds (if needed) and launches it, same as double-clicking in Finder
```

Other useful targets:

```bash
make build   # swift build only — no .app bundle, fastest inner loop while iterating
make test    # runs the test suite (see "Testing" for why this isn't `swift test`)
make icon    # regenerates Resources/AppIcon.icns from Tools/GenerateIcon.swift
make install # copies build/NowPlayingHUD.app into /Applications
make clean   # removes all build output
```

### If you have full Xcode installed

A `project.yml` is included for [XcodeGen](https://github.com/yonaskolb/XcodeGen):

```bash
brew install xcodegen
xcodegen generate
open NowPlayingHUD.xcodeproj
```

This generates a conventional `.xcodeproj` mirroring the SwiftPM module layout (an app target
plus a `NowPlayingHUDKit` framework). **This path was not build-verified in this environment**
(no Xcode was available to test it against) — the SwiftPM + Makefile path above is the one
actually built, run, and tested. If something's off in the generated project, the SwiftPM
manifest (`Package.swift`) is the ground truth for what should compile.

### Gatekeeper and signing

`make app` code-signs the bundle **ad-hoc** (`codesign --sign -`), which is all you need to run
your own local build — no Apple Developer Program membership and no notarization required.

Two things worth knowing:

1. **Gatekeeper**: since the app isn't notarized, first launch via double-click may show an
   "unidentified developer" warning. Right-click → Open (once) bypasses this, or just use
   `make run` / `make install`, which launch it directly.
2. **Automation permission resets on rebuild**: an ad-hoc signature's identity is derived from
   the binary's hash, which changes on every rebuild. macOS's Automation permission (see below)
   is tied to that identity, so **you may be asked to re-grant Spotify automation access after
   rebuilding**. If macOS seems stuck remembering a stale decision, reset it:
   ```bash
   tccutil reset AppleEvents com.nowplayinghud.app
   ```
   If you want a signing identity that survives rebuilds, create a free self-signed certificate
   in Keychain Access (Certificate Assistant → Create a Certificate → Code Signing) and set
   `codesign --sign "Your Certificate Name"` in the Makefile instead of `-`.

The app is **not sandboxed** — a deliberate choice for a personal local utility that needs to
send Apple Events to two specific other apps; sandboxing would add complexity (an Automation
entitlement is still declared in `Resources/NowPlayingHUD.entitlements` for when/if that changes)
without a meaningful security benefit here.

## Installing and running

```bash
make install                          # copies to /Applications
open /Applications/NowPlayingHUD.app  # or just find it in Spotlight/Launchpad
```

Or skip installing and just run it from `build/`:

```bash
make run
```

There's no installer package — this is a personal utility you build yourself, not something
distributed to other people's Macs.

## Spotify Automation permission

The first time NowPlayingHUD needs to actually talk to Spotify (reading the current track,
pressing play/pause, etc.), macOS shows its own system dialog asking whether NowPlayingHUD may
control Spotify. This is the **Automation** permission — click **OK**.

If you accidentally click **Don't Allow**, or want to check/change it later:

**System Settings → Privacy & Security → Automation → NowPlayingHUD** → enable **Spotify**
(and **Music**, if you use Apple Music).

Settings → Advanced shows the live status of this permission for each player, and a
**Test Spotify Connection** button. NowPlayingHUD never repeatedly re-prompts you if you deny
it — see [Troubleshooting](#troubleshooting) for what happens instead.

## Launch at Login

Settings → General → **Launch at Login**, implemented with Apple's modern `SMAppService` API (no
legacy login-item helper app). If macOS shows a "requires approval" state, Settings links
directly to **System Settings → General → Login Items**.

## Settings

Open via the menu bar icon's popover ("Settings…") or its right-click menu, or `Cmd-,` while the
Settings window is focused.

| Pane | Covers |
|---|---|
| **General** | Automatic HUD on/off, player source (Automatic/Spotify/Apple Music), menu bar item + display mode, full-screen behavior, hide-when-frontmost, Launch at Login |
| **HUD** | Position (including notch-aware Smart Top Center), which display, edge offset, display duration, hover-to-expand, hover dismissal delay, show-on-track-change/play/pause/manual-control |
| **Content** | Which fields appear: art, title, artist, album, progress, time, controls |
| **Appearance** | Style (Glass / Compact / Minimal), size (Small/Medium/Large), light/dark/automatic, artwork accent tint, animation preference |
| **Controls** | What clicking the HUD's artwork/text does |
| **Shortcuts** | Global keyboard shortcuts (nothing bound by default) |
| **Advanced** | Automation permission status + connection test, developer mode note |
| **About** | Version, privacy statement |

A live preview (with a sample track) sits under the HUD/Content/Appearance/Controls panes and
updates instantly as you change settings.

## Keyboard shortcuts

Settings → Shortcuts. **Nothing is bound by default** — pick your own combinations; existing
shortcuts elsewhere on your Mac are never overridden. Click a shortcut field and press your
desired combination (must include at least one modifier key); click the **×** to clear it.

Available actions: Show/Hide HUD, Play/Pause, Next, Previous, Volume Up, Volume Down, Seek
Forward, Seek Backward.

These use Carbon's `RegisterEventHotKey` (the same public API macOS itself has used for global
shortcuts for decades) rather than a `CGEventTap`, so **no Accessibility permission is needed**.
Media keys on your keyboard continue to control Spotify/Apple Music directly and normally —
NowPlayingHUD doesn't intercept them; it just reacts to the resulting playback change like any
other one.

## Apple Music support

NowPlayingHUD is Spotify-first but treats players through one `PlaybackProvider` abstraction, so
Apple Music works too, driven by `com.apple.Music.playerInfo`. Set **Player** to "Apple Music" or
leave it on "Automatic" (prefers whichever player is actually playing; ties go to whichever most
recently changed; see [Architecture](#architecture)).

Apple Music actually has a **richer** scripting interface than Spotify in one respect: it exposes
a genuine three-state repeat (off/one/all), so "Repeat One" is available there but not for
Spotify (see [Known limitations](#known-limitations)). Its artwork comes across as raw image
bytes over Apple Events rather than a URL, which makes it slightly slower to appear than
Spotify's directly-fetched artwork.

## Architecture

```
Playback (event-driven, no polling)
  PlaybackProvider (protocol)
    SpotifyPlaybackProvider     — DistributedNotificationCenter + AppleEventBridge
    AppleMusicPlaybackProvider  — same shape, com.apple.Music.playerInfo
    MockPlaybackProvider        — scripted scenarios for debug/testing
  PlaybackCoordinator           — provider selection, dedup, Automatic-mode arbitration

Automation
  AppleEventBridge              — in-process NSAppleScript execution, own timeout
  AutomationPermissionService   — non-prompting permission reads

Artwork
  ArtworkCache (actor)          — memory (NSCache) + bounded disk (LRU), two tiers
  ArtworkService (actor)        — fetch + in-flight coalescing
  AccentExtractor               — Core Image CIAreaAverage → subtle tint

HUD
  ScreenSnapshot / ScreenPositioningService / ScreenSelection  — pure geometry
  HUDStateMachine                — pure presentation-lifecycle state machine
  HUDPresentationPolicy          — pure "should this present" decision logic
  HUDPanel                       — the NSPanel itself
  HUDHoverTracker                — click-through hover entry detection
  HUDPresentationCoordinator     — ties the above together with real AppKit/timers

UI (SwiftUI)                     — HUDRootView, MiniPlayerView, and shared subviews

MenuBar     — NSStatusItem + NSPopover
Settings    — NSWindow + SwiftUI NavigationSplitView, 8 panes
Preferences — PreferencesStore, @Observable over UserDefaults
Shortcuts   — GlobalShortcutController (Carbon), KeyCombo, ShortcutRecorderView
App         — AppEnvironment (composition root), AppDelegate
```

Playback logic, positioning math, artwork caching, and the presentation state machine are all
pure Swift with no AppKit dependency, which is what makes them unit-testable (see
[Testing](#testing)) without a real screen, window, or running Spotify.

### Automatic player-selection rule

When **Player** is set to Automatic: whichever player is currently playing wins; if both are
playing, whichever most recently reported a change wins; if neither is playing, the previously
active player is kept (so a pause doesn't cause a flicker to the other app); with no prior choice,
Spotify is preferred. See `ProviderArbitration.swift` and its tests.

### The HUD window itself

`HUDPanel` is a borderless, non-activating `NSPanel` at `.statusBar` level (not the maximum
possible level — it's meant to behave like a system HUD, not sit above everything). It's
click-through (`ignoresMouseEvents = true`) until hovered, ordered on screen with
`orderFrontRegardless()` (never `makeKey`), and its `collectionBehavior` combines
`canJoinAllSpaces` + `fullScreenAuxiliary` + `transient` + `ignoresCycle`, with an opt-in
`canJoinAllApplications` for showing over another app's full-screen window. Detecting a hover on
a click-through window needs a `.mouseMoved` global monitor (which doesn't require Accessibility
permission) purely to catch the *first* entry; the exit is handled by ordinary AppKit events once
the panel becomes interactive. See `HUDPanel.swift` and `HUDHoverTracker.swift` for the full
reasoning.

### Liquid Glass

Where the SDK supports it (macOS 26+), `HUDBackground` uses real `GlassEffectContainer`/
`glassEffect` (SwiftUI) — gated behind `#available(macOS 26.0, *)` — falling back to
`NSVisualEffectView`'s `.hudWindow` material on macOS 14/15, or a flat fill under Reduce
Transparency. Glass is applied once, to the container behind everything, not sprinkled onto
individual controls.

## Privacy

This is a personal, local utility. There is no analytics, telemetry, crash reporting, ads,
tracking, account, or remote database of any kind. The only network traffic NowPlayingHUD ever
makes is fetching album artwork directly from Spotify's own CDN (`i.scdn.co`) — the same place
Spotify itself would show it to you. Apple Music artwork never leaves your Mac at all (it's read
directly as image bytes via Apple Events). Nothing about what you listen to is ever sent
anywhere else.

## Performance

Designed to be left running indefinitely without a second thought:

- **No polling.** Playback state changes are entirely event-driven
  (`DistributedNotificationCenter`, `NSWorkspace` launch/terminate/sleep/wake,
  `NSApplication.didChangeScreenParametersNotification`).
- **Progress is extrapolated, not re-queried.** A snapshot's `(position, timestamp, state)` is
  enough to compute "where is playback right now" locally; SwiftUI's `TimelineView` — the only
  thing that "ticks" anywhere in this app — only runs while the HUD/popover is actually visible,
  and SwiftUI stops invoking it the instant that's no longer true.
- **Artwork is cached and never re-fetched** for the same track (two-tier: in-memory + a bounded,
  LRU-evicted disk cache), with in-flight request coalescing so concurrent requests for the same
  artwork share one download.
- **The global mouse-move monitor for hover detection only runs while the HUD is on screen** —
  typically a few seconds at a time.
- Idle CPU usage should read as effectively 0% in Activity Monitor.

## Troubleshooting

**Nothing happens when I change tracks.**
Check Settings → Advanced → Automation Permission. If Spotify shows "Denied," go to
System Settings → Privacy & Security → Automation and enable it, then use **Test Spotify
Connection**. If it shows "Not Running," open Spotify first.

**It worked, then stopped asking for permission correctly after I rebuilt.**
See [Gatekeeper and signing](#gatekeeper-and-signing) — an ad-hoc-signed build's identity changes
on every rebuild, which can confuse macOS's remembered Automation decision. Run
`tccutil reset AppleEvents com.nowplayinghud.app` and try again.

**The HUD shows title/artist but no artwork, or Automation shows "Denied."**
NowPlayingHUD degrades gracefully in this case: Spotify's own `PlaybackStateChanged` notification
carries enough (title, artist, album, duration, position, play state) to show a useful HUD even
with zero Apple Events — it just can't get an artwork URL, volume, shuffle, or repeat state
without Automation permission.

**The permission dialog never appeared at all.**
macOS only asks once per app identity and remembers "don't ask again" style denials. Check
Settings → Advanced for the actual status rather than waiting for a dialog that already happened.

**Global shortcuts don't fire.**
Confirm the combination is actually bound in Settings → Shortcuts (nothing is bound by default).
If a shortcut is claimed by another app or macOS itself, `RegisterEventHotKey` will fail
silently at the OS level for that combination — try a different one.

**Launch at Login doesn't take effect / shows "requires approval."**
Click the link Settings provides to System Settings → General → Login Items and approve it there
— macOS sometimes requires this extra step even after a successful `SMAppService.register()`.

## Known limitations

These are limitations of the *public, stable* scripting interfaces themselves, verified directly
against the sdef dictionaries and a live Spotify client rather than assumed — not shortcuts taken
in this implementation. Where a limitation exists, the app degrades gracefully rather than
pretending otherwise.

- **No system-wide "Now Playing" for arbitrary apps.** macOS has no public API for this; the
  private `MediaRemote` framework is deliberately not used. Only Spotify and Apple Music are
  supported, matching the brief.
- **Spotify has no "Repeat One."** Its scripting dictionary exposes only a boolean `repeating`
  (queue repeat on/off) — there's no distinct repeat-one mode to expose, so the HUD doesn't offer
  one for Spotify. Apple Music's tri-state repeat does support it.
- **Spotify has no dedicated `seek` command.** Seeking is implemented by writing Spotify's
  `player position` property directly (its own scripting dictionary's documented mechanism for
  this — not a workaround).
- **Spotify's `shuffling enabled`/`repeating enabled` read-only properties share a four-letter
  code** in its own `.sdef` (both `pReE`) and are therefore never read by this app — only the
  unambiguous `shuffling`/`repeating` properties are used.
- **Apple Music's notification payload wasn't empirically re-verified** the way Spotify's was
  (doing so would have required starting audio playback as a side effect of a build). Its
  playback-state *fetching* uses the officially documented, stable `.sdef` interface either way;
  only the "trigger vs. also-carries-fast-path-data" optimization Spotify gets was skipped for
  Apple Music as a result — see the doc comment on `MusicScript.notificationIsTriggerOnly`.

## Testing

```bash
make test
```

**Why not `swift test`?** This machine has only Xcode's Command Line Tools installed — no
`XCTest.framework`. Swift Testing ships with the toolchain itself, but on this exact setup `swift
test` was verified (with a deliberately-failing assertion) to compile and link the test bundle
successfully and then **never actually execute it** — `swiftpm-testing-helper` reports a clean
exit having run nothing, for both passing and failing suites alike. Rather than ship tests that
only *compile* without ever being confirmed to run, the suite is a small, dependency-free
executable (`Tests/NowPlayingHUDKitTests`, built as a SwiftPM executable target) using its own
~70-line harness (`MiniTest.swift`) — `swift run`'s ordinary process-exit code is the pass/fail
signal, with no test-bundle-loading machinery involved at all. If you have Xcode installed,
`swift test`/Xcode's Test Navigator may well work fine in that environment; this project just
doesn't depend on it working.

Coverage focuses on everything that's pure logic and AppKit-independent: track-change/duplicate-
notification detection, rapid-skip HUD deduplication, the HUD's presentation state machine
(including hover suspension/resumption), progress extrapolation, screen positioning math
(including notch-aware and negative-origin-display cases), multi-display selection with
disconnect fallback, preference persistence, artwork cache-key derivation/eviction/coalescing,
and Automatic-mode provider arbitration.

Manual smoke-testing (real Spotify, real screen, real hover) covered: Spotify already playing at
launch, Spotify launched afterward, quitting Spotify, rapid Next presses, pause/resume, the
Automation permission flow end to end, and idle CPU/memory (0.0% CPU, ~50 MB RSS at idle for the
assembled `.app`). Testing across multiple physical displays, an actual notched MacBook, Reduce
Motion/Reduce Transparency, Stage Manager, and a real full-screen app requires hardware/session
configurations this build environment doesn't have — the underlying logic each of those depends
on (screen selection, notch-safe positioning, the state machine, the accessibility environment
checks in the SwiftUI views) is unit-tested per above, but re-verifying the visual result on your
actual setup is worth doing once after your first build.

## Uninstalling completely

```bash
# Quit the app first (menu bar icon → right-click → Quit, or):
osascript -e 'tell application id "com.nowplayinghud.app" to quit'

# Remove the app itself:
rm -rf /Applications/NowPlayingHUD.app

# Remove its preferences:
defaults delete com.nowplayinghud.app 2>/dev/null

# Remove its artwork cache:
rm -rf ~/Library/Caches/NowPlayingHUD

# If you enabled Launch at Login, disable it first from within the app's Settings, or:
osascript -e 'tell application "System Events" to delete login item "NowPlayingHUD"' 2>/dev/null

# Revoke the Automation permission decision (optional — macOS will just ask again if reinstalled):
tccutil reset AppleEvents com.nowplayinghud.app
```

No installer, no launch daemon, no files anywhere else on disk.

## Renaming

Everything is keyed off two places:

1. `Sources/NowPlayingHUDKit/App/Branding.swift` — `Branding.appName`, `Branding.bundleIdentifier`
2. The `APP_NAME`/`BUNDLE_ID` variables at the top of `Makefile` (and the matching values in
   `project.yml`, if you're using the Xcode path)

Change both, run `make clean app`, and everything downstream (the `.app` bundle name, the
`Info.plist`, code signing, `UserDefaults` suite, TCC/Automation identity) follows automatically.
