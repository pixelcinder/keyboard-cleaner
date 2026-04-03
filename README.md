# Keyboard Cleaner

A macOS utility with Liquid Glass design that locks your keyboard so you can clean every key without accidentally triggering anything. Unlocks with Touch ID, PIN, or the system password depending on device capabilities and your settings.

---

## Features

- **One-tap lock** — blocks all keyboard input once the global event tap is active
- **Deliberate unlock paths** — Touch ID by default, with optional PIN and password fallback
- **Liquid Glass UI** — animated aurora background, frosted glass surfaces, Apple-native feel
- **Full accessibility** — all elements labelled for VoiceOver
- **Animated states** — breathing pulse ring when locked, colour-coded authentication feedback
- **Utility features** — menu bar mode, launch at login, overlay styles, and auto-unlock

---

## Requirements

- macOS 14 Sonoma or later
- Mac with Touch ID, or a PIN/password fallback configured
- Xcode 15+

---

## Build & Run

1. Open `KeyboardCleaner.xcodeproj` in Xcode
2. Change the bundle identifier in Build Settings from `com.yourname.KeyboardCleaner` to your own
3. Set your Team in Signing & Capabilities
4. Build & Run (`⌘R`)

> **First launch:** macOS will ask for **Accessibility permission** in System Settings → Privacy & Security → Accessibility. This is required for the CGEventTap that intercepts keystrokes.

---

## How it works

### Keyboard Blocking
`CGEvent.tapCreate` is used at `.cghidEventTap` level with `.headInsertEventTap` placement, which intercepts all keyboard events (`keyDown`, `keyUp`, `flagsChanged`) at the HID layer — before they reach any application. The callback returns `nil` for every event, effectively dropping them all.

### Authentication
`LocalAuthentication.LAContext` uses `.deviceOwnerAuthenticationWithBiometrics` when Touch ID is available and falls back to `.deviceOwnerAuthentication` for system password auth when needed. The app can also unlock through its mouse-clickable PIN pad when a PIN has been configured.

### Why Accessibility permission?
CGEventTap at the HID level (`cghidEventTap`) requires the app to be trusted for accessibility in order to tap global events. Without it, locking is refused and the app prompts you to grant access.

---

## Accessibility

All interactive elements carry `accessibilityLabel` and `accessibilityHint`. The lock/unlock button state is communicated through dynamic labels. The animated elements are marked `accessibilityHidden` so VoiceOver isn't distracted by decorative motion.

---

## File Structure

```
KeyboardCleaner/
├── KeyboardCleanerApp.swift      — App entry, window config
├── ContentView.swift             — All SwiftUI views + animated background
├── CleaningStateManager.swift    — @MainActor state, CGEventTap, LocalAuthentication
├── Assets.xcassets/
│   └── AppIcon.appiconset/       — All icon sizes (16–1024)
├── Info.plist                    — Permissions descriptions
└── KeyboardCleaner.entitlements  — Sandbox entitlements
```

---

## Customisation

- **Window size** — change `frame(width: 480, height: 560)` in `KeyboardCleanerApp.swift`
- **Aurora colours** — edit the `AnimatedBackgroundView` blob colors in `ContentView.swift`
- **macOS deployment target** — currently set to 14.0; lower to 13.0 to support Ventura (`.ultraThinMaterial` works from macOS 12+)

---

## Notes on Sandbox

The app is sandboxed. CGEventTap at `cghidEventTap` level is a sensitive operation — if you distribute outside the App Store, you can remove the sandbox entirely for simpler permission handling. For App Store distribution, the HID-level tap requires an entitlement exception from Apple.
