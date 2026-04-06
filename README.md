# Keyboard Cleaner

Lock your Mac keyboard while you clean it. One tap blocks every keystroke — no accidental typing, no shortcuts firing, nothing getting through. Unlock with Touch ID or a PIN when you're done.

Built for macOS 14+. Free.

---

## What it does

When locked, a CGEventTap intercepts all keyboard input at the HID layer before it reaches any app. The overlay shows a countdown ring if you've set an auto-unlock timer, or just the elapsed time if you haven't. Touch ID unlocks instantly; the on-screen PIN pad works with just the mouse.

## Setup

1. Open `KeyboardCleaner.xcodeproj` in Xcode 15+
2. Set your bundle ID and signing team
3. Build & run (`⌘R`)

On first launch, macOS will ask for Accessibility permission — this is needed for the keyboard tap to work. Grant it in System Settings → Privacy & Security → Accessibility.

## Files

```
KeyboardCleaner/
├── KeyboardCleanerApp.swift      — app entry, window setup
├── ContentView.swift             — all views
├── CleaningStateManager.swift    — state, event tap, Touch ID
├── Assets.xcassets/              — icons
├── Info.plist
└── KeyboardCleaner.entitlements
```

## Notes

- The app is sandboxed. CGEventTap at `cghidEventTap` level needs the Accessibility entitlement — this works fine for local/direct distribution but requires an exception from Apple for App Store.
- No code signing yet — on first open, right-click → Open to bypass Gatekeeper.
- PIN is stored in UserDefaults (4 digits, low sensitivity). Keychain support is planned once the app is properly signed.
