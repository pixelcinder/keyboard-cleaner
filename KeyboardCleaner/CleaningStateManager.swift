import Foundation
import LocalAuthentication
import AppKit
import Carbon
import Combine
import Security
import SwiftUI
import ServiceManagement
import os.log

// MARK: - Notification Names

extension Notification.Name {
    static let menuBarOnlyChanged = Notification.Name("menuBarOnlyChanged")
    static let openSettingsRequested = Notification.Name("openSettingsRequested")
    static let openDiagnosticsRequested = Notification.Name("openDiagnosticsRequested")
    static let openHelpRequested = Notification.Name("openHelpRequested")
}

// MARK: - Auto-Unlock Timeout

enum AutoUnlockTimeout: Int, CaseIterable, Identifiable {
    case never        = 0
    case threeMinutes = 180
    case fiveMinutes  = 300
    case tenMinutes   = 600

    var id: Int { rawValue }

    var label: String {
        switch self {
        case .never:        return "Never"
        case .threeMinutes: return "3 min"
        case .fiveMinutes:  return "5 min"
        case .tenMinutes:   return "10 min"
        }
    }
}

// MARK: - Overlay Style

enum OverlayStyle: String, CaseIterable, Identifiable {
    case full    = "full"
    case minimal = "minimal"

    var id: String { rawValue }

    var label: String {
        switch self {
        case .full:    return "Full Screen"
        case .minimal: return "Minimal"
        }
    }
}

enum FullScreenCoverage: String, CaseIterable, Identifiable {
    case allDisplays
    case activeDisplay

    var id: String { rawValue }

    var label: String {
        switch self {
        case .allDisplays:  return "All Displays"
        case .activeDisplay: return "Active Only"
        }
    }
}

enum PreferredUnlockMethod {
    case touchID
    case pin
    case password
}

enum CleaningPreset: String, CaseIterable, Identifiable {
    case quickWipe
    case focusedDesk
    case deepClean

    var id: String { rawValue }

    var title: String {
        switch self {
        case .quickWipe:  return "Quick Wipe"
        case .focusedDesk: return "Focused Desk"
        case .deepClean:  return "Deep Clean"
        }
    }

    var summary: String {
        switch self {
        case .quickWipe:  return "3 min, minimal overlay, sound off"
        case .focusedDesk: return "5 min, full screen, sound on"
        case .deepClean:  return "10 min, full screen, sound on"
        }
    }

    var autoUnlockTimeout: AutoUnlockTimeout {
        switch self {
        case .quickWipe:  return .threeMinutes
        case .focusedDesk: return .fiveMinutes
        case .deepClean:  return .tenMinutes
        }
    }

    var overlayStyle: OverlayStyle {
        switch self {
        case .quickWipe:  return .minimal
        case .focusedDesk, .deepClean: return .full
        }
    }

    var soundEnabled: Bool {
        switch self {
        case .quickWipe:  return false
        case .focusedDesk, .deepClean: return true
        }
    }

    var fullScreenCoverage: FullScreenCoverage {
        switch self {
        case .quickWipe:  return .activeDisplay
        case .focusedDesk, .deepClean: return .allDisplays
        }
    }
}

// MARK: - Auth State

enum AuthState: Equatable {
    case idle
    case authenticating
    case failed
    case success
}

// MARK: - Cleaning State Manager

@MainActor
final class CleaningStateManager: ObservableObject {

    // MARK: Published State

    @Published var isLocked = false
    @Published var authState: AuthState = .idle
    @Published var isAccessibilityAuthorized = false
    @Published var elapsedSeconds = 0
    @Published var lockFailureMessage: String?

    // Password fallback — shown after first Touch ID failure
    @Published var showPasswordFallback = false

    // Settings
    @Published var autoUnlockTimeout: AutoUnlockTimeout
    @Published var overlayStyle: OverlayStyle
    @Published var fullScreenCoverage: FullScreenCoverage
    @Published var soundEnabled: Bool
    @Published var menuBarOnly: Bool
    @Published var hasCompletedLockTest: Bool

    // PIN code unlock (mouse-clickable numpad, no keyboard needed)
    @Published var pinEnabled: Bool
    private(set) var storedPin: String

    // PIN brute-force protection
    @Published var pinLockedUntil: Date?
    private var pinFailedAttempts = 0
    private static let pinLockoutThreshold = 5
    private static let pinLockoutDuration: TimeInterval = 30

    var isPINLockedOut: Bool {
        guard let until = pinLockedUntil else { return false }
        if Date() >= until { pinLockedUntil = nil; return false }
        return true
    }

    // MARK: Private

    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var timerCancellable: AnyCancellable?
    private var appActiveCancellable: AnyCancellable?
    private var settingsCancellables = Set<AnyCancellable>()
    private var accessibilityPollCancellable: AnyCancellable?
    private let overlayController = OverlayWindowController()

    // Global / local hotkey monitors for ⌃⌘L
    private var globalHotkeyMonitor: Any?
    private var localHotkeyMonitor: Any?

    private let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "com.keyboards.cleaner",
        category: "EventTap"
    )

    // MARK: - Init

    init() {
        // Register defaults so bool(forKey:) returns the right default on first launch
        UserDefaults.standard.register(defaults: [
            "soundEnabled":      true,
            "menuBarOnly":       false,
            "autoUnlockTimeout": AutoUnlockTimeout.fiveMinutes.rawValue,
            "fullScreenCoverage": FullScreenCoverage.allDisplays.rawValue,
            "hasCompletedLockTest": false,
        ])

        overlayStyle      = OverlayStyle(rawValue: UserDefaults.standard.string(forKey: "overlayStyle") ?? "") ?? .full
        fullScreenCoverage = FullScreenCoverage(rawValue: UserDefaults.standard.string(forKey: "fullScreenCoverage") ?? "") ?? .allDisplays
        soundEnabled      = UserDefaults.standard.bool(forKey: "soundEnabled")
        menuBarOnly       = UserDefaults.standard.bool(forKey: "menuBarOnly")
        autoUnlockTimeout = AutoUnlockTimeout(rawValue: UserDefaults.standard.integer(forKey: "autoUnlockTimeout")) ?? .fiveMinutes
        // Migrate any PIN that was stored in Keychain back to UserDefaults
        if let keychainPin = PinKeychainStore.loadPin(), !keychainPin.isEmpty {
            UserDefaults.standard.set(keychainPin, forKey: "pinCode")
            PinKeychainStore.deletePin()
        }
        let savedPin = UserDefaults.standard.string(forKey: "pinCode") ?? ""
        storedPin         = savedPin
        pinEnabled        = !storedPin.isEmpty
        hasCompletedLockTest = UserDefaults.standard.bool(forKey: "hasCompletedLockTest")

        // Persist settings changes via Combine (dropFirst skips the initial emission)
        $overlayStyle.dropFirst()
            .sink { UserDefaults.standard.set($0.rawValue, forKey: "overlayStyle") }
            .store(in: &settingsCancellables)

        $soundEnabled.dropFirst()
            .sink { UserDefaults.standard.set($0, forKey: "soundEnabled") }
            .store(in: &settingsCancellables)

        $fullScreenCoverage.dropFirst()
            .sink { UserDefaults.standard.set($0.rawValue, forKey: "fullScreenCoverage") }
            .store(in: &settingsCancellables)

        $menuBarOnly.dropFirst()
            .sink { enabled in
                UserDefaults.standard.set(enabled, forKey: "menuBarOnly")
                NotificationCenter.default.post(name: .menuBarOnlyChanged, object: enabled)
            }
            .store(in: &settingsCancellables)

        $autoUnlockTimeout.dropFirst()
            .sink { UserDefaults.standard.set($0.rawValue, forKey: "autoUnlockTimeout") }
            .store(in: &settingsCancellables)

        $hasCompletedLockTest.dropFirst()
            .sink { UserDefaults.standard.set($0, forKey: "hasCompletedLockTest") }
            .store(in: &settingsCancellables)

        checkAccessibilityAuthorization()

        setupHotkey()

        appActiveCancellable = NotificationCenter.default
            .publisher(for: NSApplication.didBecomeActiveNotification)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.checkAccessibilityAuthorization() }
    }

    // MARK: - Accessibility Authorization

    func checkAccessibilityAuthorization() {
        // AXIsProcessTrusted() caches its result per-process on macOS — using
        // AXIsProcessTrustedWithOptions(prompt:false) forces a fresh system query every time.
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue(): false] as CFDictionary
        isAccessibilityAuthorized = AXIsProcessTrustedWithOptions(options)
    }

    func requestAccessibilityPermission() {
        // Trigger the native prompt (works on first run when the app isn't in the list yet)
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue(): true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)

        // Also open System Settings directly — this is the only reliable path when the app
        // has already been added to the list (macOS ignores the prompt in that case)
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }

        startAccessibilityPolling()
    }

    private func startAccessibilityPolling() {
        accessibilityPollCancellable?.cancel()
        // Use a main-RunLoop timer — more reliable than a Swift Concurrency Task
        // for detecting system permission changes in sandboxed apps.
        accessibilityPollCancellable = Timer.publish(every: 0.5, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                guard let self else { return }
                self.checkAccessibilityAuthorization()
                if self.isAccessibilityAuthorized {
                    self.accessibilityPollCancellable?.cancel()
                }
            }
    }

    /// Called from the UI "I've Granted Access" button — forces an immediate re-check.
    /// If still not trusted, macOS may require a relaunch; this method signals that.
    @discardableResult
    func recheckAccessibility() -> Bool {
        checkAccessibilityAuthorization()
        return isAccessibilityAuthorized
    }

    func relaunch() {
        // Open a fresh instance then quit this one.
        NSWorkspace.shared.openApplication(
            at: URL(fileURLWithPath: Bundle.main.bundlePath),
            configuration: NSWorkspace.OpenConfiguration()
        )
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            NSApp.terminate(nil)
        }
    }

    // MARK: - Global Hotkey (⌃⌘L)

    private func setupHotkey() {
        // keyCode 37 = L key on all keyboard layouts
        let lockKeyCode: UInt16 = 37

        // Monitor when other apps are focused
        globalHotkeyMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard event.keyCode == lockKeyCode,
                  event.modifierFlags.intersection([.command, .control]) == [.command, .control]
            else { return }
            Task { @MainActor [weak self] in
                guard let self, !self.isLocked else { return }
                self.startCleaning()
            }
        }

        // Monitor when our own app is focused — return nil to consume the event
        localHotkeyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard event.keyCode == lockKeyCode,
                  event.modifierFlags.intersection([.command, .control]) == [.command, .control]
            else { return event }
            Task { @MainActor [weak self] in
                guard let self, !self.isLocked else { return }
                self.startCleaning()
            }
            return nil  // consume so the hotkey doesn't type "l" anywhere
        }
    }

    // MARK: - Touch ID Availability

    /// True if the device has biometrics (Touch ID / Face ID on Macs with Apple Silicon).
    /// On MacBooks without Touch ID this returns false.
    var hasTouchID: Bool {
        let context = LAContext()
        var error: NSError?
        return context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error)
    }

    // MARK: - Launch at Login

    var isLaunchAtLoginEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }

    func setLaunchAtLogin(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
            objectWillChange.send()
        } catch {
            logger.error("Launch at login failed: \(error.localizedDescription)")
        }
    }

    // MARK: - PIN Unlock (bypasses LAContext — PIN was already verified by the UI)

    func unlockWithVerifiedPIN() {
        authState = .success
        showPasswordFallback = false
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 500_000_000)
            stopCleaning()
        }
    }

    // MARK: - PIN Code

    func setPin(_ pin: String) {
        storedPin = pin
        pinEnabled = true
        UserDefaults.standard.set(pin, forKey: "pinCode")
    }

    func clearPin() {
        storedPin = ""
        pinEnabled = false
        UserDefaults.standard.removeObject(forKey: "pinCode")
    }

    func verifyPin(_ pin: String) -> Bool {
        guard !isPINLockedOut else {
            logger.warning("PIN entry blocked — lockout active")
            return false
        }
        guard pin == storedPin else {
            pinFailedAttempts += 1
            if pinFailedAttempts >= Self.pinLockoutThreshold {
                pinLockedUntil = Date().addingTimeInterval(Self.pinLockoutDuration)
                pinFailedAttempts = 0
                logger.warning("PIN locked out for \(Int(Self.pinLockoutDuration))s after \(Self.pinLockoutThreshold) failed attempts")
            }
            return false
        }
        pinFailedAttempts = 0
        pinLockedUntil = nil
        return true
    }

    // MARK: - Computed Time Strings

    var elapsedTimeString: String { formatDuration(elapsedSeconds) }

    var remainingTimeString: String? {
        guard autoUnlockTimeout != .never else { return nil }
        return formatDuration(max(0, autoUnlockTimeout.rawValue - elapsedSeconds))
    }

    private func formatDuration(_ total: Int) -> String {
        String(format: "%d:%02d", total / 60, total % 60)
    }

    var preferredUnlockMethod: PreferredUnlockMethod {
        if hasTouchID { return .touchID }
        if pinEnabled { return .pin }
        return .password
    }

    var currentPreset: CleaningPreset? {
        CleaningPreset.allCases.first {
            $0.autoUnlockTimeout == autoUnlockTimeout &&
            $0.overlayStyle == overlayStyle &&
            $0.soundEnabled == soundEnabled &&
            $0.fullScreenCoverage == fullScreenCoverage
        }
    }

    var isEventTapInstalled: Bool {
        eventTap != nil
    }

    var diagnosticsItems: [(label: String, value: String)] {
        [
            ("Accessibility", isAccessibilityAuthorized ? "Granted" : "Missing"),
            ("Event Tap", isEventTapInstalled ? "Installed" : "Inactive"),
            ("Unlock Method", diagnosticsUnlockMethodLabel),
            ("Overlay Style", overlayStyle.label),
            ("Display Target", fullScreenCoverage.label),
            ("Auto Unlock", autoUnlockTimeout.label),
            ("Menu Bar Only", menuBarOnly ? "On" : "Off"),
            ("Sound", soundEnabled ? "On" : "Off"),
            ("Lock Test", hasCompletedLockTest ? "Completed" : "Pending")
        ]
    }

    func applyPreset(_ preset: CleaningPreset) {
        autoUnlockTimeout = preset.autoUnlockTimeout
        overlayStyle = preset.overlayStyle
        soundEnabled = preset.soundEnabled
        fullScreenCoverage = preset.fullScreenCoverage
    }

    private var diagnosticsUnlockMethodLabel: String {
        switch preferredUnlockMethod {
        case .touchID: return pinEnabled ? "Touch ID + PIN" : "Touch ID"
        case .pin: return "PIN"
        case .password: return "Password"
        }
    }

    // MARK: - Start Cleaning

    func startCleaning() {
        // Refuse to lock if there's no way to unlock (no Touch ID and no PIN set)
        guard hasTouchID || pinEnabled else { return }
        guard installEventTap() else { return }

        isLocked = true
        authState = .idle
        showPasswordFallback = false
        lockFailureMessage = nil
        elapsedSeconds = 0
        hasCompletedLockTest = true
        startTimer()
        playSound("Tink")
        performHaptic(.generic)
        overlayController.show(cleaningState: self, style: overlayStyle, coverage: fullScreenCoverage)

    }

    // MARK: - Timer

    private func startTimer() {
        timerCancellable?.cancel()
        timerCancellable = Timer.publish(every: 1, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                guard let self else { return }
                self.elapsedSeconds += 1
                if self.autoUnlockTimeout != .never,
                   self.elapsedSeconds >= self.autoUnlockTimeout.rawValue {
                    self.stopCleaning()
                }
            }
    }

    private func stopTimer() {
        timerCancellable?.cancel()
        timerCancellable = nil
    }

    // MARK: - Authenticate to Unlock

    /// Primary unlock method. Uses Touch ID (biometrics) by default.
    /// - Parameter usePassword: When true, skips biometrics and goes straight to the system password dialog.
    func authenticateToUnlock(usePassword: Bool = false, completion: @escaping (Bool) -> Void) {
        guard authState != .authenticating else { return }
        authState = .authenticating

        let context = LAContext()
        var error: NSError?
        let policy: LAPolicy
        if usePassword {
            policy = .deviceOwnerAuthentication
        } else {
            policy = context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error)
                ? .deviceOwnerAuthenticationWithBiometrics
                : .deviceOwnerAuthentication
        }

        context.evaluatePolicy(policy, localizedReason: "Unlock your keyboard after cleaning") { [weak self] success, error in
            Task { @MainActor [weak self] in
                guard let self else { return }
                if success {
                    self.authState = .success
                    self.showPasswordFallback = false
                    try? await Task.sleep(nanoseconds: 500_000_000)
                    self.stopCleaning()
                    completion(true)
                } else {
                    if let error { self.logger.error("Authentication failed: \(error.localizedDescription)") }
                    self.authState = .failed
                    self.showPasswordFallback = true  // reveal password fallback after first failure
                    try? await Task.sleep(nanoseconds: 1_200_000_000)
                    if self.authState == .failed { self.authState = .idle }
                    completion(false)
                }
            }
        }
    }

    // MARK: - Stop Cleaning

    private func stopCleaning() {
        isLocked = false
        authState = .idle
        showPasswordFallback = false
        stopTimer()
        removeEventTap()
        playSound("Glass")
        overlayController.hide()
        performHaptic(.levelChange)
    }

    // MARK: - Sound Feedback

    private func playSound(_ name: String) {
        guard soundEnabled else { return }
        NSSound(named: NSSound.Name(name))?.play()
    }

    // MARK: - Event Tap

    @discardableResult
    private func installEventTap() -> Bool {
        checkAccessibilityAuthorization()

        guard isAccessibilityAuthorized else {
            logger.error("Accessibility permission not granted — keyboard events will not be blocked")
            lockFailureMessage = "Accessibility access is required before the keyboard can be locked."
            requestAccessibilityPermission()
            return false
        }

        let mask: CGEventMask =
            (1 << CGEventType.keyDown.rawValue)    |
            (1 << CGEventType.keyUp.rawValue)      |
            (1 << CGEventType.flagsChanged.rawValue)

        let tap = CGEvent.tapCreate(
            tap: .cghidEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: mask,
            callback: { _, _, _, _ in nil },
            userInfo: nil
        )

        guard let tap else {
            logger.error("CGEvent tap creation failed — event tap returned nil")
            lockFailureMessage = "Keyboard lock failed because the system event tap could not be created."
            return false
        }

        eventTap = tap
        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        runLoopSource = source
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        lockFailureMessage = nil
        logger.info("Event tap installed successfully")
        return true
    }

    private func removeEventTap() {
        guard let tap = eventTap else { return }
        CGEvent.tapEnable(tap: tap, enable: false)
        if let source = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes)
        }
        eventTap = nil
        runLoopSource = nil
        logger.info("Event tap removed")
    }

    // MARK: - Haptic Feedback

    private func performHaptic(_ pattern: NSHapticFeedbackManager.FeedbackPattern) {
        NSHapticFeedbackManager.defaultPerformer.perform(pattern, performanceTime: .default)
    }

    deinit {
        if let tap = eventTap { CGEvent.tapEnable(tap: tap, enable: false) }
        if let m = globalHotkeyMonitor { NSEvent.removeMonitor(m) }
        if let m = localHotkeyMonitor  { NSEvent.removeMonitor(m) }
    }
}

// MARK: - Overlay Window Controller

@MainActor
final class OverlayWindowController {
    private var windows: [NSWindow] = []

    func show(cleaningState: CleaningStateManager, style: OverlayStyle, coverage: FullScreenCoverage) {
        guard windows.isEmpty else { return }
        switch style {
        case .full:
            let screens: [NSScreen]
            switch coverage {
            case .allDisplays:
                screens = NSScreen.screens
            case .activeDisplay:
                screens = [activeScreen()]
            }

            for (index, screen) in screens.enumerated() {
                let window = makeFullWindow(for: screen, cleaningState: cleaningState)
                if index == 0 { window.makeKeyAndOrderFront(nil) } else { window.orderFront(nil) }
                windows.append(window)
            }
        case .minimal:
            let panel = makeMinimalPanel(cleaningState: cleaningState)
            panel.orderFront(nil)
            windows.append(panel)
        }
    }

    func hide() {
        windows.forEach { $0.close() }
        windows.removeAll()
    }

    private func makeMinimalPanel(cleaningState: CleaningStateManager) -> NSPanel {
        let size = CGSize(
            width: 280,
            height: cleaningState.preferredUnlockMethod == .pin ? 300 : 78
        )
        let screen = activeScreen()
        let origin = CGPoint(
            x: screen.visibleFrame.maxX - size.width - 24,
            y: screen.visibleFrame.minY + 24
        )
        let panel = NSPanel(
            contentRect: CGRect(origin: origin, size: size),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.level = .floating
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.isReleasedWhenClosed = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.isMovableByWindowBackground = true
        panel.contentView = NSHostingView(rootView: MinimalOverlayView(cleaningState: cleaningState))
        return panel
    }

    private func makeFullWindow(for screen: NSScreen, cleaningState: CleaningStateManager) -> NSWindow {
        let window = NSWindow(
            contentRect: screen.frame,
            styleMask: .borderless,
            backing: .buffered,
            defer: false
        )
        window.level = NSWindow.Level(rawValue: NSWindow.Level.screenSaver.rawValue - 1)
        window.isOpaque = false
        window.backgroundColor = .clear
        window.isReleasedWhenClosed = false
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        window.contentView = NSHostingView(rootView: OverlayView(cleaningState: cleaningState))
        return window
    }

    private func activeScreen() -> NSScreen {
        let pointerLocation = NSEvent.mouseLocation
        if let match = NSScreen.screens.first(where: { NSMouseInRect(pointerLocation, $0.frame, false) }) {
            return match
        }
        if let main = NSScreen.main { return main }
        // NSScreen.screens is never empty on a running system; guard defensively
        guard let first = NSScreen.screens.first else {
            preconditionFailure("No displays found")
        }
        return first
    }
}

private enum PinKeychainStore {
    private static let account = "keyboard-cleaner-pin"

    private static var service: String {
        Bundle.main.bundleIdentifier ?? "com.keyboards.cleaner"
    }

    static func loadPin() -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status == errSecSuccess,
              let data = item as? Data,
              let pin = String(data: data, encoding: .utf8)
        else { return nil }
        return pin
    }

    static func savePin(_ pin: String) {
        let data = Data(pin.utf8)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        let attributes: [String: Any] = [
            kSecValueData as String: data
        ]

        let updateStatus = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        if updateStatus == errSecItemNotFound {
            var addQuery = query
            addQuery[kSecValueData as String] = data
            let addStatus = SecItemAdd(addQuery as CFDictionary, nil)
            if addStatus != errSecSuccess {
                os_log(.error, "Keychain: SecItemAdd failed with status %d", addStatus)
            }
        } else if updateStatus != errSecSuccess {
            os_log(.error, "Keychain: SecItemUpdate failed with status %d", updateStatus)
        }
    }

    static func deletePin() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        SecItemDelete(query as CFDictionary)
    }
}
