# Keyboard Cleaner — Copy

## Tagline

Clean every key without a single misclick.

## Hero

**Headline:** Clean every key without a single misclick

**Sub:** Lock your keyboard in one tap. Wipe as hard as you like — nothing gets through. Unlock with Touch ID when you're done.

## Short description

A small Mac utility that locks your keyboard while you clean it. Blocks every keystroke until you unlock with Touch ID or PIN.

## Features (plain)

- Locks the keyboard instantly — no accidental typing or shortcuts
- Unlock with Touch ID or a 4-digit PIN (mouse-only, no keyboard needed)
- Auto-unlock timer with countdown ring
- Full-screen overlay so you don't accidentally click anything either
- Menu bar icon shows lock state at a glance
- Launch at login, global shortcut (⌃⌘L), presets

## FAQ

**Why does it need Accessibility permission?**
That's how it intercepts keystrokes before they reach other apps. Without it, the lock doesn't work. It's a one-time grant in System Settings.

**Why is the first launch blocked?**
The app isn't code-signed yet (beta). Right-click → Open to get past Gatekeeper. [Apple's guide](https://support.apple.com/en-ie/guide/mac-help/mh40616/mac)

**Does Touch ID work on Intel Macs?**
Only on models that have a Touch ID sensor. On machines without one, PIN is the default unlock method.

**Does it work on Apple Silicon?**
Yes — universal binary, runs natively on both.
