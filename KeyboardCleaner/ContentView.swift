import SwiftUI

// MARK: - Animation Constants

private enum Timing {
    static let pulse: Double = 2.8
    static let background: Double = 20.0
    static let errorShakeUnit: Double = 0.06
    static let errorShakeRepeat = 6
}

// MARK: - Design Tokens

private enum Design {
    static let cardRadius: CGFloat = 16
    static let buttonRadius: CGFloat = 16

    // Fresh mint → cool teal CTA gradient
    static let accentStart = Color(red: 0.22, green: 0.80, blue: 0.64)
    static let accentEnd   = Color(red: 0.08, green: 0.60, blue: 0.80)

    static var accentGradient: LinearGradient {
        LinearGradient(
            colors: [accentStart, accentEnd],
            startPoint: .topLeading, endPoint: .bottomTrailing
        )
    }
}

// MARK: - Root View

struct ContentView: View {
    @EnvironmentObject private var cleaningState: CleaningStateManager
    @AppStorage("hasSeenOnboarding") private var hasSeenOnboarding = false
    @State private var showSettings = false
    @State private var showDiagnostics = false
    @State private var showHelp = false

    var body: some View {
        ZStack {
            AquaBackgroundView()

            if !cleaningState.isAccessibilityAuthorized {
                SceneScrollView {
                    AccessibilityPermissionView(cleaningState: cleaningState)
                }
                    .transition(.asymmetric(
                        insertion: .scale(scale: 0.96).combined(with: .opacity),
                        removal:   .scale(scale: 1.04).combined(with: .opacity)
                    ))
            } else if !hasSeenOnboarding {
                SceneScrollView {
                    OnboardingView(hasSeenOnboarding: $hasSeenOnboarding)
                }
                    .transition(.asymmetric(
                        insertion: .scale(scale: 0.96).combined(with: .opacity),
                        removal:   .scale(scale: 1.04).combined(with: .opacity)
                    ))
            } else if cleaningState.isLocked {
                LockedView(cleaningState: cleaningState)
                    .transition(.asymmetric(
                        insertion: .scale(scale: 0.96).combined(with: .opacity),
                        removal:   .scale(scale: 1.04).combined(with: .opacity)
                    ))
            } else {
                SceneScrollView {
                    IdleView(cleaningState: cleaningState, showSettings: $showSettings)
                }
                    .transition(.asymmetric(
                        insertion: .scale(scale: 0.96).combined(with: .opacity),
                        removal:   .scale(scale: 1.04).combined(with: .opacity)
                    ))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .ignoresSafeArea()
        .animation(.spring(response: 0.45, dampingFraction: 0.82), value: cleaningState.isAccessibilityAuthorized)
        .animation(.spring(response: 0.45, dampingFraction: 0.82), value: cleaningState.isLocked)
        .animation(.spring(response: 0.45, dampingFraction: 0.82), value: hasSeenOnboarding)
        .safeAreaInset(edge: .top, spacing: 0) {
            if cleaningState.isAccessibilityAuthorized && hasSeenOnboarding && !cleaningState.isLocked {
                WindowAccessoryBar(
                    openSettings: { showSettings = true },
                    openHelp: { showHelp = true }
                )
                .padding(.top, 12)
                .padding(.horizontal, 20)
                .padding(.bottom, 8)
                .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .sheet(isPresented: $showSettings) {
            SettingsSheet(cleaningState: cleaningState)
        }
        .sheet(isPresented: $showDiagnostics) {
            DiagnosticsSheet(cleaningState: cleaningState)
        }
        .sheet(isPresented: $showHelp) {
            HelpSheet(cleaningState: cleaningState)
        }
        .onReceive(NotificationCenter.default.publisher(for: .openSettingsRequested)) { _ in
            showSettings = true
        }
        .onReceive(NotificationCenter.default.publisher(for: .openDiagnosticsRequested)) { _ in
            showDiagnostics = true
        }
        .onReceive(NotificationCenter.default.publisher(for: .openHelpRequested)) { _ in
            showHelp = true
        }
        .onReceive(NotificationCenter.default.publisher(for: .menuBarOnlyChanged)) { notification in
            guard let enabled = notification.object as? Bool, enabled else { return }
            showSettings = false
            showDiagnostics = false
            showHelp = false
        }
        .alert(
            "Unable to Lock Keyboard",
            isPresented: Binding(
                get: { cleaningState.lockFailureMessage != nil },
                set: { if !$0 { cleaningState.lockFailureMessage = nil } }
            )
        ) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(cleaningState.lockFailureMessage ?? "")
        }
    }
}

private struct SceneScrollView<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            content
                .frame(maxWidth: .infinity)
                .padding(.bottom, 24)
        }
        .scrollBounceBehavior(.basedOnSize)
    }
}

// MARK: - Accessibility Permission Gate

struct AccessibilityPermissionView: View {
    @ObservedObject var cleaningState: CleaningStateManager
    @State private var didCheck = false
    @State private var checkFailed = false

    var body: some View {
        VStack(spacing: 0) {
            Spacer().frame(height: 88)

            VStack(spacing: 24) {
                GlassCircle(diameter: 96) {
                    Image(systemName: "keyboard.badge.ellipsis")
                        .font(.system(size: 36, weight: .light))
                        .foregroundStyle(.primary)
                        .accessibilityHidden(true)
                }
                .accessibilityHidden(true)

                VStack(spacing: 8) {
                    Text("Accessibility Access Required")
                        .font(.system(size: 28, weight: .bold))
                        .tracking(-0.5)
                        .foregroundStyle(.primary)
                        .multilineTextAlignment(.center)
                        .accessibilityAddTraits(.isHeader)

                    Text("Keyboard Cleaner needs accessibility permission to intercept keyboard input before it reaches other apps.")
                        .font(.system(size: 14))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: 340)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(.bottom, 22)
            .accessibilitySortPriority(3)

            InsetGroup(spacing: 0) {
                PermissionStepRow(number: "1", text: "Open System Settings")
                PermissionStepRow(number: "2", text: "Privacy & Security → Accessibility")
                PermissionStepRow(number: "3", text: "Enable Keyboard Cleaner")
            }
            .padding(.horizontal, 32)
            .padding(.bottom, 18)
            .accessibilitySortPriority(2)

            InsetGroup(spacing: 0) {
                Button {
                    cleaningState.requestAccessibilityPermission()
                    didCheck = false
                    checkFailed = false
                } label: {
                    HStack(spacing: 9) {
                        Image(systemName: "gear")
                            .font(.system(size: 15, weight: .semibold))
                            .accessibilityHidden(true)
                        Text("Open System Settings")
                            .font(.system(size: 15, weight: .semibold))
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(AccentButtonBackground())
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 16)
                .padding(.top, 16)
                .accessibilityLabel("Open System Settings to grant accessibility access")
                .keyboardShortcut(.defaultAction)

                Button {
                    didCheck = true
                    let granted = cleaningState.recheckAccessibility()
                    checkFailed = !granted
                } label: {
                    Text("I’ve Granted Access")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(checkFailed ? Color.red.opacity(0.8) : Design.accentEnd)
                        .frame(maxWidth: .infinity)
                        .frame(height: 36)
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 16)
                .padding(.bottom, checkFailed ? 8 : 16)
                .accessibilityLabel("Recheck accessibility permission")

                if checkFailed {
                    VStack(spacing: 8) {
                        Text("Permission not detected yet.")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(.secondary)
                        Button {
                            cleaningState.relaunch()
                        } label: {
                            Text("Relaunch App")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(.primary)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 8)
                                .background(GlassCapsuleBackground())
                        }
                        .buttonStyle(.plain)
                        .keyboardShortcut(.defaultAction)
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 16)
                    .transition(.opacity.combined(with: .scale(scale: 0.95)))
                }
            }
            .padding(.horizontal, 32)
            .accessibilitySortPriority(1)

            Spacer()
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: checkFailed)
    }
}

struct PermissionStepRow: View {
    let number: String
    let text: String

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(Design.accentStart.opacity(0.14))
                    .frame(width: 28, height: 28)
                Text(number)
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(Design.accentStart)
            }
            Text(text)
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            Spacer()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(GlassPanelBackground(cornerRadius: Design.cardRadius))
        .accessibilityElement(children: .combine)
        .accessibilityLabel(AppStrings.step(number, text))
    }
}

// MARK: - Idle / Home Screen

struct IdleView: View {
    @ObservedObject var cleaningState: CleaningStateManager
    @Binding var showSettings: Bool

    var body: some View {
        VStack(spacing: 0) {
            Spacer().frame(height: 86)

            // Icon + title
            VStack(spacing: 16) {
                GlassCircle(diameter: 88) {
                    Image(systemName: "keyboard")
                        .font(.system(size: 34, weight: .light))
                        .foregroundStyle(.primary)
                        .accessibilityHidden(true)
                }
                .accessibilityHidden(true)

                VStack(spacing: 8) {
                    Text("Keyboard Cleaner")
                        .font(.system(size: 28, weight: .bold))
                        .tracking(-0.6)
                        .foregroundStyle(.primary)
                        .accessibilityAddTraits(.isHeader)

                    Text("A quiet way to lock the keyboard while you clean.")
                        .font(.system(size: 14))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
            }
            .padding(.bottom, 24)
            .accessibilitySortPriority(4)

            // Info cards
            InsetGroup(spacing: 0) {
                InfoCardRow(
                    icon: "hand.raised.slash",
                    iconTint: Design.accentStart,
                    title: "Blocks all keystrokes",
                    subtitle: "No accidental input while cleaning"
                )
                InsetDivider()
                InfoCardRow(
                    icon: cleaningState.hasTouchID ? "touchid" : "circle.grid.3x3.fill",
                    iconTint: Design.accentEnd,
                    title: cleaningState.hasTouchID ? "Touch ID to unlock" : "PIN or Password to unlock",
                    subtitle: "A deliberate unlock path when you’re done"
                )
                InsetDivider()
                InfoCardRow(
                    icon: "sparkles",
                    iconTint: Color(red: 0.60, green: 0.40, blue: 0.90),
                    title: "Wipe with confidence",
                    subtitle: "Designed for quick, low-friction cleaning sessions"
                )
            }
            .padding(.horizontal, 32)
            .padding(.bottom, 14)
            .accessibilitySortPriority(3)

            InsetGroup(spacing: 0) {
                AutoUnlockPickerRow(cleaningState: cleaningState)
                InsetDivider()
                OverlayStyleRow(cleaningState: cleaningState)
            }
            .padding(.horizontal, 32)
            .accessibilitySortPriority(2)

            if !cleaningState.hasCompletedLockTest && (cleaningState.hasTouchID || cleaningState.pinEnabled) {
                QuickLockTestRow {
                    cleaningState.startCleaning()
                }
                .padding(.horizontal, 32)
                .padding(.top, 12)
                .accessibilitySortPriority(1.5)
            }

            // Fixed gap — a flexible Spacer() inside a ScrollView produces undefined heights
            Spacer().frame(height: 24)

            // No Touch ID + no PIN → must set up PIN first
            if !cleaningState.hasTouchID && !cleaningState.pinEnabled {
                NoPINWarningRow()
                    .padding(.horizontal, 32)
                    .padding(.bottom, 10)
                    .transition(.scale(scale: 0.95).combined(with: .opacity))
            }

            // Lock button — prominent accent CTA
            Button {
                if !cleaningState.hasTouchID && !cleaningState.pinEnabled {
                    showSettings = true   // open settings so the user can set up a PIN
                } else {
                    cleaningState.startCleaning()
                }
            } label: {
                HStack(spacing: 9) {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 15, weight: .semibold))
                        .accessibilityHidden(true)
                    Text(!cleaningState.hasTouchID && !cleaningState.pinEnabled
                         ? "Set Up PIN to Continue"
                         : "Lock Keyboard")
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(AccentButtonBackground())
                .shadow(color: Design.accentStart.opacity(0.30), radius: 14, y: 6)
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 32)
            .accessibilityLabel("Lock keyboard for cleaning")
            .accessibilityHint("Blocks all keyboard input. Unlock when done.")
            .accessibilitySortPriority(1)
            .keyboardShortcut(.defaultAction)

            Text(
                !cleaningState.hasTouchID && !cleaningState.pinEnabled
                    ? "No Touch ID detected — set a PIN to unlock"
                    : cleaningState.pinEnabled
                        ? "Touch ID or PIN to unlock  ·  ⌃⌘L to lock from anywhere"
                        : "Touch ID to unlock  ·  ⌃⌘L to lock from anywhere"
            )
            .font(.system(size: 11))
            .foregroundStyle(.tertiary)
            .multilineTextAlignment(.center)
            .padding(.top, 10)
            .padding(.bottom, 36)
            .accessibilityLabel(
                !cleaningState.hasTouchID && !cleaningState.pinEnabled
                    ? "No Touch ID detected — set a PIN to unlock"
                    : cleaningState.pinEnabled
                        ? "Touch ID or PIN to unlock. Tip: press Control Command L to lock from anywhere."
                        : "Touch ID to unlock. Tip: press Control Command L to lock from anywhere."
            )
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: cleaningState.pinEnabled)
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: cleaningState.hasTouchID)
    }
}

private struct QuickLockTestRow: View {
    let action: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "checkmark.shield")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Design.accentEnd)
                .frame(width: 32, height: 32)
                .background(Circle().fill(Design.accentEnd.opacity(0.12)))
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 3) {
                Text("Run a Quick Lock Test")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.primary)
                Text("Try one short lock now so you know accessibility access is working before you start cleaning.")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 10)

            Button("Test") { action() }
                .buttonStyle(.plain)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Design.accentEnd)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(GlassCapsuleBackground())
                .accessibilityLabel("Run a quick lock test")
                .keyboardShortcut(.defaultAction)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(GlassPanelBackground(cornerRadius: Design.cardRadius))
        .accessibilityElement(children: .contain)
    }
}

// MARK: - No PIN Warning (shown on Macs without Touch ID when no PIN is set)

private struct NoPINWarningRow: View {
    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 13))
                .foregroundStyle(.orange)
                .accessibilityHidden(true)
            Text("No Touch ID detected. Open Settings → PIN Code to set up a PIN.")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(
            GlassPanelBackground(cornerRadius: Design.cardRadius)
                .overlay(
                    RoundedRectangle(cornerRadius: Design.cardRadius)
                        .fill(Color.orange.opacity(0.06))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: Design.cardRadius)
                        .stroke(Color.orange.opacity(0.16), lineWidth: 0.5)
                )
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("No Touch ID detected. Open Settings to set up a PIN.")
    }
}

// MARK: - Glass Segmented Control

private struct GlassSegmentedControl<T: Hashable>: View {
    let options: [T]
    let label: (T) -> String
    @Binding var selection: T

    var body: some View {
        HStack(spacing: 3) {
            ForEach(options, id: \.self) { option in
                let isSelected = option == selection
                Button {
                    withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                        selection = option
                    }
                } label: {
                    Text(label(option))
                        .font(.system(size: 12, weight: isSelected ? .semibold : .medium))
                        .foregroundStyle(isSelected ? .primary : .secondary)
                        .frame(maxWidth: .infinity)
                        .frame(height: 28)
                        .background {
                            if isSelected {
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(.thinMaterial)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 8)
                                            .stroke(.primary.opacity(0.10), lineWidth: 0.5)
                                    )
                                    .shadow(color: .black.opacity(0.08), radius: 3, y: 1)
                            }
                        }
                }
                .buttonStyle(.plain)
                .contentShape(Rectangle())
                .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
                .accessibilityLabel(label(option))
                .accessibilityValue(isSelected ? "Selected" : "Not selected")
            }
        }
        .padding(3)
        .background(GlassPanelBackground(cornerRadius: 11))
        .accessibilityElement(children: .contain)
    }
}

// MARK: - Auto-Unlock Picker Row

struct AutoUnlockPickerRow: View {
    @ObservedObject var cleaningState: CleaningStateManager

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "timer")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)

            Text("Auto-unlock")
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)

            Spacer()

            GlassSegmentedControl(
                options: AutoUnlockTimeout.allCases,
                label: \.label,
                selection: $cleaningState.autoUnlockTimeout
            )
            .frame(width: 210)
            .accessibilityLabel("Auto-unlock timeout")
            .accessibilityHint("Set a duration after which the keyboard unlocks automatically")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 13)
    }
}

// MARK: - Overlay Style Row

struct OverlayStyleRow: View {
    @ObservedObject var cleaningState: CleaningStateManager

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "rectangle.on.rectangle")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)

            Text("Overlay")
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)

            Spacer()

            GlassSegmentedControl(
                options: OverlayStyle.allCases,
                label: \.label,
                selection: $cleaningState.overlayStyle
            )
            .frame(width: 210)
            .accessibilityLabel("Overlay style")
            .accessibilityHint("Full Screen covers all displays; Minimal shows only a small floating button")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 13)
    }
}

struct FullScreenCoverageRow: View {
    @ObservedObject var cleaningState: CleaningStateManager

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "macwindow.on.rectangle")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)

            Text("Display Target")
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)

            Spacer()

            GlassSegmentedControl(
                options: FullScreenCoverage.allCases,
                label: \.label,
                selection: $cleaningState.fullScreenCoverage
            )
            .frame(width: 210)
            .accessibilityLabel("Full-screen coverage")
            .accessibilityHint("Choose whether the full-screen overlay covers all displays or only the active display")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 13)
    }
}

// MARK: - Info Card Row

struct InfoCardRow: View {
    let icon: String
    let iconTint: Color
    let title: String
    let subtitle: String

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 11)
                    .fill(iconTint.opacity(0.12))
                    .frame(width: 38, height: 38)
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(iconTint)
                    .accessibilityHidden(true)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(.primary)
                Text(subtitle)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 13)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title). \(subtitle)")
    }
}

struct PresetRow: View {
    @ObservedObject var cleaningState: CleaningStateManager

    var body: some View {
        VStack(spacing: 0) {
            ForEach(Array(CleaningPreset.allCases.enumerated()), id: \.element.id) { index, preset in
                Button {
                    cleaningState.applyPreset(preset)
                } label: {
                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(preset.title)
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(.primary)
                            Text(preset.summary)
                                .font(.system(size: 11))
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        if cleaningState.currentPreset == preset {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 15))
                                .foregroundStyle(Design.accentEnd)
                                .accessibilityHidden(true)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("\(preset.title). \(preset.summary)")
                .accessibilityHint("Apply preset")

                if index < CleaningPreset.allCases.count - 1 {
                    InsetDivider()
                }
            }
        }
    }
}

struct WindowAccessoryBar: View {
    let openSettings: () -> Void
    let openHelp: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            HStack(spacing: 10) {
                ZStack {
                    Circle()
                        .fill(Design.accentGradient.opacity(0.16))
                        .frame(width: 28, height: 28)
                    Image(systemName: "keyboard")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(Design.accentGradient)
                }

                VStack(alignment: .leading, spacing: 1) {
                    Text("Keyboard Cleaner")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.primary)
                    Text("Ready to lock")
                        .font(.system(size: 11))
                        .foregroundStyle(.tertiary)
                }
            }

            Spacer()

            HStack(spacing: 8) {
                Button(action: openHelp) {
                    Image(systemName: "questionmark")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .frame(width: 30, height: 30)
                        .background(Circle().fill(.thinMaterial))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Open help")
                .accessibilityHint("Open help and usage guidance")
                .keyboardShortcut("/", modifiers: [.command, .shift])

                Button(action: openSettings) {
                    Image(systemName: "slider.horizontal.3")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .frame(width: 30, height: 30)
                        .background(Circle().fill(.thinMaterial))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Open settings")
                .accessibilityHint("Open cleaning, unlock, and menu bar preferences")
                .keyboardShortcut(",", modifiers: [.command])
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(GlassPanelBackground(cornerRadius: 18))
        .shadow(color: .black.opacity(0.08), radius: 16, y: 8)
    }
}

struct InsetGroup<Content: View>: View {
    let spacing: CGFloat
    @ViewBuilder var content: Content

    var body: some View {
        VStack(spacing: spacing) {
            content
        }
        .background(GlassPanelBackground(cornerRadius: Design.cardRadius))
    }
}

struct InsetDivider: View {
    var body: some View {
        Rectangle()
            .fill(.primary.opacity(0.08))
            .frame(height: 1)
            .padding(.leading, 62)
            .accessibilityHidden(true)
    }
}

// MARK: - Locked View

struct LockedView: View {
    @ObservedObject var cleaningState: CleaningStateManager
    @State private var pulseAnimation = false
    @State private var errorShake = false
    @State private var lockClosed = false

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            VStack(spacing: 22) {
                ZStack {
                    PulseRings(animating: pulseAnimation, count: 3,
                               baseSize: 130, step: 34, maxOpacity: 0.06)
                    GlassCircle(diameter: 114) {
                        ZStack {
                            Image(systemName: "lock.open.fill")
                                .font(.system(size: 42, weight: .light))
                                .foregroundStyle(.primary)
                                .scaleEffect(lockClosed ? 0.5 : 1.0)
                                .opacity(lockClosed ? 0 : 1)
                                .accessibilityHidden(true)
                            Image(systemName: "lock.fill")
                                .font(.system(size: 42, weight: .light))
                                .foregroundStyle(.primary)
                                .scaleEffect(lockClosed ? 1.0 : 0.5)
                                .opacity(lockClosed ? 1 : 0)
                                .accessibilityHidden(true)
                        }
                        .animation(.spring(response: 0.45, dampingFraction: 0.65), value: lockClosed)
                    }
                }
                .offset(x: errorShake ? -8 : 0)
                .animation(
                    errorShake
                        ? .easeInOut(duration: Timing.errorShakeUnit)
                            .repeatCount(Timing.errorShakeRepeat, autoreverses: true)
                        : .default,
                    value: errorShake
                )
                .onAppear {
                    pulseAnimation = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { lockClosed = true }
                }
                .onChange(of: cleaningState.authState) { _, new in
                    if new == .success {
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) { lockClosed = false }
                    }
                }
                .accessibilityLabel("Keyboard is locked")

                VStack(spacing: 8) {
                    HStack(alignment: .lastTextBaseline, spacing: 4) {
                        Text("Keyboard")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(.secondary)
                        Text("Locked")
                            .font(.system(size: 26, weight: .black))
                            .tracking(-0.6)
                            .foregroundStyle(Design.accentGradient)
                    }
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("Keyboard Locked")
                    .accessibilityAddTraits(.isHeader)

                    HStack(spacing: 5) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 11, weight: .medium))
                            .accessibilityHidden(true)
                        Text("Wipe with confidence")
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                    }
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 5)
                    .background(GlassCapsuleBackground())

                    Text(statusMessage)
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: 260)
                        .animation(.easeInOut(duration: 0.2), value: cleaningState.authState)

                    if cleaningState.authState == .idle || cleaningState.authState == .failed {
                        TimerDisplay(cleaningState: cleaningState)
                            .padding(.top, 4)
                    }
                }
                .padding(.horizontal, 26)
                .padding(.vertical, 22)
                .background(GlassPanelBackground(cornerRadius: 24))
                .padding(.horizontal, 44)
                .accessibilitySortPriority(2)
            }

            Spacer()

            UnlockButton(cleaningState: cleaningState, onFailure: triggerErrorShake)
                .accessibilitySortPriority(1)

            if cleaningState.hasTouchID {
                TouchIDKeyNote()
                    .padding(.top, 12)
                    .accessibilitySortPriority(0.5)
            }
            Spacer().frame(height: 44)
        }
        .frame(maxWidth: .infinity)
    }

    private var statusMessage: String {
        switch cleaningState.authState {
        case .idle:           return "All keystrokes are blocked.\nClean your keyboard freely."
        case .authenticating: return cleaningState.hasTouchID ? "Place your finger on Touch ID…" : "Verifying…"
        case .failed:         return cleaningState.hasTouchID ? "Touch ID failed. Try again." : "Authentication failed. Try again."
        case .success:        return "Unlocked successfully!"
        }
    }

    private func triggerErrorShake() {
        errorShake = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { errorShake = false }
    }
}

// MARK: - PIN Pad (mouse-clickable, keyboard is blocked during lock)

private struct PINKey: View {
    let label: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 18, weight: .regular, design: .rounded))
                .foregroundStyle(.primary)
                .frame(width: 56, height: 44)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(.thinMaterial)
                        .overlay(RoundedRectangle(cornerRadius: 10)
                            .stroke(.primary.opacity(0.08), lineWidth: 0.5))
                )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
        .accessibilityHint(AppStrings.enterDigit(label))
        .focusable()
    }
}

struct PINPadView: View {
    @Binding var entry: String
    let maxLength = 4
    let onComplete: () -> Void
    let onCancel: () -> Void
    var lockedOutMessage: String? = nil

    var body: some View {
        VStack(spacing: 12) {
            if let lockMsg = lockedOutMessage {
                Text(lockMsg)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Color(red: 0.90, green: 0.28, blue: 0.28))
                    .multilineTextAlignment(.center)
                    .accessibilityLabel(lockMsg)
            }

            // Dot indicators — hidden from VoiceOver; count spoken via label below
            HStack(spacing: 12) {
                ForEach(0..<maxLength, id: \.self) { i in
                    Circle()
                        .fill(i < entry.count
                              ? AnyShapeStyle(Design.accentGradient)
                              : AnyShapeStyle(Color.primary.opacity(0.18)))
                        .frame(width: 10, height: 10)
                        .animation(.spring(response: 0.2, dampingFraction: 0.6), value: entry.count)
                        .accessibilityHidden(true)
                }
            }
            .accessibilityLabel(AppStrings.pinDigitsEntered(entry.count, maxLength))

            // Numpad
            VStack(spacing: 5) {
                ForEach([[1,2,3],[4,5,6],[7,8,9]], id: \.first) { row in
                    HStack(spacing: 5) {
                        ForEach(row, id: \.self) { n in
                            PINKey(label: "\(n)") { append("\(n)") }
                        }
                    }
                }
                HStack(spacing: 5) {
                    Button(action: onCancel) {
                        Text("Cancel")
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                            .foregroundStyle(.secondary)
                            .frame(width: 56, height: 44)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Cancel PIN entry")
                    .keyboardShortcut(.cancelAction)
                    .focusable()

                    PINKey(label: "0") { append("0") }

                    Button {
                        if !entry.isEmpty { entry.removeLast() }
                    } label: {
                        Image(systemName: "delete.left")
                            .font(.system(size: 16, weight: .light))
                            .foregroundStyle(.secondary)
                            .frame(width: 56, height: 44)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Delete last digit")
                    .focusable()
                }
            }
        }
        .accessibilityElement(children: .contain)
    }

    private func append(_ digit: String) {
        guard entry.count < maxLength else { return }
        entry.append(digit)
        if entry.count == maxLength { onComplete() }
    }
}

// MARK: - Unlock Button (shared by LockedView and OverlayView)

struct UnlockButton: View {
    @ObservedObject var cleaningState: CleaningStateManager
    let onFailure: () -> Void

    @State private var showPINPad = false
    @State private var pinEntry = ""
    @State private var pinFailed = false
    @State private var pinLockoutMessage: String? = nil

    var body: some View {
        VStack(spacing: 14) {
            if showPINPad {
                // Mouse-clickable PIN pad (keyboard is blocked)
                PINPadView(
                    entry: $pinEntry,
                    onComplete: submitPIN,
                    onCancel: {
                        withAnimation(.spring(response: 0.3)) {
                            showPINPad = false
                            pinEntry = ""
                            pinFailed = false
                            pinLockoutMessage = nil
                        }
                    },
                    lockedOutMessage: pinLockoutMessage
                )
                .transition(.asymmetric(
                    insertion: .scale(scale: 0.9).combined(with: .opacity),
                    removal:   .scale(scale: 0.9).combined(with: .opacity)
                ))
            } else {
                // On Macs without Touch ID, PIN is the primary unlock — auto-open the pad
                // Touch ID / password button
                Button {
                    cleaningState.authenticateToUnlock { success in
                        if !success { onFailure() }
                    }
                } label: {
                    VStack(spacing: 10) {
                        ZStack {
                            Circle()
                                .fill(stateColor.opacity(0.12))
                                .frame(width: 80, height: 80)
                                .blur(radius: 16)

                            GlassCircle(diameter: 62) {
                                Image(systemName: stateIcon)
                                    .font(.system(size: 26, weight: .light))
                                    .foregroundStyle(stateColor)
                                    .accessibilityHidden(true)
                            }
                            .overlay(
                                Circle()
                                    .stroke(stateColor.opacity(0.45), lineWidth: 1)
                                    .frame(width: 62, height: 62)
                            )
                        }
                        .scaleEffect(cleaningState.authState == .authenticating ? 1.06 : 1.0)
                        .animation(
                            .easeInOut(duration: 0.8).repeatWhile(
                                cleaningState.authState == .authenticating, autoreverses: true),
                            value: cleaningState.authState
                        )

                        Text(stateLabel)
                            .font(.system(size: 13, weight: .medium, design: .rounded))
                            .foregroundStyle(.secondary)
                    }
                }
                .buttonStyle(.plain)
                .disabled(cleaningState.authState == .authenticating || cleaningState.authState == .success)
                .accessibilityLabel(stateLabel)
                .accessibilityHint(stateHint)
                .keyboardShortcut(.defaultAction)
                .transition(.asymmetric(
                    insertion: .scale(scale: 0.9).combined(with: .opacity),
                    removal:   .scale(scale: 0.9).combined(with: .opacity)
                ))

                // Fallback row: PIN (always shown if set) + password (after failure)
                HStack(spacing: 10) {
                    if cleaningState.pinEnabled {
                        FallbackPill(label: "Use PIN") {
                            withAnimation(.spring(response: 0.3)) {
                                pinEntry = ""
                                pinFailed = false
                                showPINPad = true
                            }
                        }
                    }
                    if cleaningState.showPasswordFallback && cleaningState.authState != .authenticating {
                        FallbackPill(label: "Use Password") {
                            cleaningState.authenticateToUnlock(usePassword: true) { success in
                                if !success { onFailure() }
                            }
                        }
                        .transition(.scale(scale: 0.9).combined(with: .opacity))
                    }
                }
            }
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: showPINPad)
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: cleaningState.showPasswordFallback)
        .onAppear {
            // Macs without Touch ID: if a PIN is set, make the pad the default view
            if !cleaningState.hasTouchID && cleaningState.pinEnabled {
                showPINPad = true
            }
        }
        .accessibilityElement(children: .contain)
    }

    private func submitPIN() {
        if cleaningState.isPINLockedOut {
            updateLockoutMessage()
            onFailure()
            return
        }
        if cleaningState.verifyPin(pinEntry) {
            pinLockoutMessage = nil
            withAnimation { showPINPad = false }
            cleaningState.unlockWithVerifiedPIN()
        } else {
            if cleaningState.isPINLockedOut {
                updateLockoutMessage()
            }
            withAnimation(.easeInOut(duration: 0.08).repeatCount(5, autoreverses: true)) {
                pinFailed = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                pinEntry = ""
                pinFailed = false
            }
            onFailure()
        }
    }

    private func updateLockoutMessage() {
        guard let until = cleaningState.pinLockedUntil else { return }
        let remaining = max(0, Int(until.timeIntervalSinceNow.rounded(.up)))
        pinLockoutMessage = "Too many attempts. Try again in \(remaining)s."
    }

    private var stateIcon: String {
        switch cleaningState.authState {
        case .idle, .authenticating: return cleaningState.hasTouchID ? "touchid" : "key.fill"
        case .failed:                return "arrow.clockwise"
        case .success:               return "checkmark.circle"
        }
    }

    private var stateLabel: String {
        switch cleaningState.authState {
        case .idle:           return cleaningState.hasTouchID ? "Unlock with Touch ID" : "Unlock with Password"
        case .authenticating: return "Verifying…"
        case .failed:         return "Try Again"
        case .success:        return "Unlocked"
        }
    }

    private var stateColor: Color {
        switch cleaningState.authState {
        case .failed:         return Color(red: 0.90, green: 0.28, blue: 0.28)
        case .authenticating: return Design.accentEnd
        case .success:        return Design.accentStart
        default:              return Design.accentEnd
        }
    }

    private var stateHint: String {
        switch cleaningState.authState {
        case .idle:
            if cleaningState.hasTouchID && cleaningState.pinEnabled {
                return "Uses Touch ID or PIN to unlock the keyboard"
            } else if cleaningState.hasTouchID {
                return "Uses Touch ID to unlock the keyboard"
            } else {
                return "Uses PIN or system password to unlock the keyboard"
            }
        case .failed: return "Previous attempt failed. Tap to try again."
        default:      return ""
        }
    }
}

private struct FallbackPill: View {
    let label: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 14)
                .padding(.vertical, 6)
                .background(GlassCapsuleBackground())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
        .accessibilityHint("Alternative unlock method")
    }
}

// MARK: - Minimal Overlay Pill (shown when overlay style = Minimal)

struct MinimalOverlayView: View {
    @ObservedObject var cleaningState: CleaningStateManager
    @State private var pinEntry = ""
    @State private var pinFailed = false

    var body: some View {
        VStack(spacing: cleaningState.preferredUnlockMethod == .pin ? 14 : 0) {
            HStack(spacing: 14) {
                GlassCircle(diameter: 34) {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(Design.accentGradient)
                        .accessibilityHidden(true)
                }
                .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Keyboard Locked")
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundStyle(.primary)
                    Text(subtitleText)
                        .font(.system(size: 11, design: .rounded).monospacedDigit())
                        .foregroundStyle(.secondary)
                        .contentTransition(.numericText())
                        .animation(.easeInOut(duration: 0.35), value: cleaningState.elapsedSeconds)
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel(AppStrings.keyboardLocked(subtitleText))

                Spacer()

                if cleaningState.preferredUnlockMethod == .pin {
                    Text("PIN")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Design.accentEnd)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(GlassCapsuleBackground())
                        .accessibilityHidden(true)
                } else {
                    Button {
                        if cleaningState.preferredUnlockMethod == .password {
                            cleaningState.authenticateToUnlock(usePassword: true) { _ in }
                        } else {
                            cleaningState.authenticateToUnlock { _ in }
                        }
                    } label: {
                        Image(systemName: cleaningState.preferredUnlockMethod == .touchID ? "touchid" : "key.fill")
                            .font(.system(size: 20, weight: .light))
                            .foregroundStyle(Design.accentGradient)
                            .frame(width: 36, height: 36)
                            .background(Circle().fill(.thinMaterial))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(cleaningState.preferredUnlockMethod == .touchID ? "Unlock with Touch ID" : "Unlock with Password")
                    .accessibilityHint("Authenticate to unlock the keyboard")
                    .keyboardShortcut(.defaultAction)
                }
            }

            if cleaningState.preferredUnlockMethod == .pin {
                PINPadView(entry: $pinEntry, onComplete: submitPIN, onCancel: {
                    pinEntry = ""
                    pinFailed = false
                })
                .padding(.bottom, 2)
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, cleaningState.preferredUnlockMethod == .pin ? 14 : 0)
        .frame(width: 280, height: cleaningState.preferredUnlockMethod == .pin ? 248 : 78)
        .background(GlassPanelBackground(cornerRadius: 20))
        .accessibilityElement(children: .contain)
    }

    private var subtitleText: String {
        switch cleaningState.preferredUnlockMethod {
        case .touchID:
            return cleaningState.elapsedTimeString
        case .pin:
            return pinFailed ? "Incorrect PIN. Try again." : "Enter PIN to unlock"
        case .password:
            return "Use your Mac password"
        }
    }

    private func submitPIN() {
        if cleaningState.verifyPin(pinEntry) {
            cleaningState.unlockWithVerifiedPIN()
            pinEntry = ""
            pinFailed = false
        } else {
            pinFailed = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                pinEntry = ""
                pinFailed = false
            }
        }
    }
}

// MARK: - Touch ID Key Note

private struct TouchIDKeyNote: View {
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "exclamationmark.circle.fill")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.orange.opacity(0.8))
                .accessibilityHidden(true)
            Text("Physical Touch ID key may trigger macOS lock screen")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 9)
        .background(
            GlassCapsuleBackground()
                .overlay(Capsule().stroke(.orange.opacity(0.2), lineWidth: 0.5))
        )
        .accessibilityLabel("Note: physical Touch ID key may trigger macOS lock screen")
    }
}

// MARK: - Pulse Rings

struct PulseRings: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let animating: Bool
    let count: Int
    let baseSize: CGFloat
    let step: CGFloat
    let maxOpacity: Double

    var body: some View {
        ZStack {
            ForEach(0..<count, id: \.self) { i in
                let ringOpacity = max(0, maxOpacity - Double(i) * 0.02)
                let ringSize = baseSize + CGFloat(i) * step

                Circle()
                    .stroke(.primary.opacity(ringOpacity), lineWidth: 1)
                    .frame(width: ringSize, height: ringSize)
                    .scaleEffect(animating && !reduceMotion ? 1.07 : 1.0)
                    .animation(
                        reduceMotion
                            ? .default
                            : .easeInOut(duration: Timing.pulse)
                                .repeatForever(autoreverses: true)
                                .delay(Double(i) * 0.32),
                        value: animating
                    )
            }
        }
        .accessibilityHidden(true)
    }
}

// MARK: - Glass Circle

/// Liquid-glass orb — uses thin material for maximum transparency.
/// Specular and rim highlights simulate light from top-left.
struct GlassCircle<Content: View>: View {
    let diameter: CGFloat
    let content: Content

    init(diameter: CGFloat, @ViewBuilder content: () -> Content) {
        self.diameter = diameter
        self.content = content()
    }

    var body: some View {
        ZStack {
            // Depth shadow
            Circle()
                .fill(Color.black.opacity(0.09))
                .frame(width: diameter, height: diameter)
                .blur(radius: diameter * 0.22)
                .offset(y: diameter * 0.08)

            Circle()
                .fill(.thinMaterial)
                .frame(width: diameter, height: diameter)
                // Primary top-left specular catch-light
                .overlay(
                    Circle()
                        .fill(LinearGradient(
                            colors: [.white.opacity(0.20), .white.opacity(0.04), .clear],
                            startPoint: UnitPoint(x: 0.14, y: 0.02),
                            endPoint: UnitPoint(x: 0.66, y: 0.56)
                        ))
                )
                // Rim — bright arc top-left, fades bottom-right
                .overlay(
                    Circle()
                        .stroke(LinearGradient(
                            colors: [.white.opacity(0.55), .white.opacity(0.02), .white.opacity(0.15)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ), lineWidth: 0.75)
                )
                .shadow(color: .black.opacity(0.09), radius: diameter * 0.16, y: diameter * 0.05)

            content
        }
    }
}

// MARK: - Timer Display

struct TimerDisplay: View {
    @ObservedObject var cleaningState: CleaningStateManager

    var body: some View {
        HStack(spacing: 14) {
            Label {
                Text(cleaningState.elapsedTimeString)
                    .font(.system(size: 12, weight: .medium, design: .rounded).monospacedDigit())
                    .foregroundStyle(.secondary)
            } icon: {
                Image(systemName: "clock")
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
                    .accessibilityHidden(true)
            }
            .accessibilityLabel(AppStrings.lockedFor(cleaningState.elapsedTimeString))

            if let remaining = cleaningState.remainingTimeString {
                Label {
                    Text(remaining)
                        .font(.system(size: 12, weight: .medium, design: .rounded).monospacedDigit())
                        .foregroundStyle(.secondary)
                } icon: {
                    Image(systemName: "timer")
                        .font(.system(size: 10))
                        .foregroundStyle(.tertiary)
                        .accessibilityHidden(true)
                }
                .accessibilityLabel(AppStrings.autoUnlockIn(remaining))
            }
        }
    }
}

// MARK: - Accent Button Background (primary CTA)

struct AccentButtonBackground: View {
    var body: some View {
        RoundedRectangle(cornerRadius: Design.buttonRadius)
            .fill(Design.accentGradient)
            // Subtle inner top highlight for glass-like depth
            .overlay(
                RoundedRectangle(cornerRadius: Design.buttonRadius)
                    .fill(LinearGradient(
                        colors: [.white.opacity(0.18), .clear],
                        startPoint: .top, endPoint: .center
                    ))
            )
    }
}

struct GlassPanelBackground: View {
    @Environment(\.colorScheme) private var colorScheme
    let cornerRadius: CGFloat

    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(.ultraThinMaterial)
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(LinearGradient(
                        colors: colorScheme == .dark
                            ? [.white.opacity(0.16), .white.opacity(0.04), .clear]
                            : [.white.opacity(0.14), .white.opacity(0.02), .clear],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ))
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(
                        LinearGradient(
                            colors: colorScheme == .dark
                                ? [.white.opacity(0.20), .white.opacity(0.04)]
                                : [.white.opacity(0.34), .primary.opacity(0.03)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 0.6
                    )
            )
            .shadow(
                color: .black.opacity(colorScheme == .dark ? 0.22 : 0.06),
                radius: colorScheme == .dark ? 22 : 18,
                y: colorScheme == .dark ? 10 : 8
            )
    }
}

struct GlassCapsuleBackground: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Capsule()
            .fill(.ultraThinMaterial)
            .overlay(
                Capsule()
                    .fill(LinearGradient(
                        colors: colorScheme == .dark ? [.white.opacity(0.14), .clear] : [.white.opacity(0.12), .clear],
                        startPoint: .top,
                        endPoint: .bottom
                    ))
            )
            .overlay(
                Capsule()
                    .stroke(
                        LinearGradient(
                            colors: colorScheme == .dark
                                ? [.white.opacity(0.18), .white.opacity(0.05)]
                                : [.white.opacity(0.28), .primary.opacity(0.04)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 0.6
                    )
            )
            .shadow(color: .black.opacity(colorScheme == .dark ? 0.12 : 0.04), radius: 10, y: 4)
    }
}

// MARK: - Glass Button Background (secondary)

struct GlassButtonBackground: View {
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: Design.buttonRadius).fill(.ultraThinMaterial)
            RoundedRectangle(cornerRadius: Design.buttonRadius)
                .fill(LinearGradient(
                    colors: [.primary.opacity(0.06), .primary.opacity(0.01)],
                    startPoint: .top, endPoint: .bottom))
            RoundedRectangle(cornerRadius: Design.buttonRadius)
                .stroke(LinearGradient(
                    colors: [.primary.opacity(0.16), .primary.opacity(0.04)],
                    startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 0.5)
        }
    }
}

// MARK: - Menu Bar View

struct MenuBarView: View {
    @EnvironmentObject var cleaningState: CleaningStateManager

    var body: some View {
        if cleaningState.isLocked {
            Menu("Locked") {
                Text(AppStrings.lockedFor(cleaningState.elapsedTimeString))
                if let remaining = cleaningState.remainingTimeString {
                    Text(AppStrings.autoUnlockIn(remaining))
                }
            }
            Button("Unlock Keyboard…") { cleaningState.authenticateToUnlock { _ in } }
        } else {
            Button("Lock Keyboard") { cleaningState.startCleaning() }
        }

        Menu("Presets") {
            if let preset = cleaningState.currentPreset {
                Text(AppStrings.preset(preset.title))
            }
            ForEach(CleaningPreset.allCases) { preset in
                Button(preset.title) { cleaningState.applyPreset(preset) }
            }
        }

        Divider()

        Menu("Open") {
            if cleaningState.menuBarOnly {
                Button("Show Window") {
                    NotificationCenter.default.post(name: .menuBarOnlyChanged, object: false)
                    cleaningState.menuBarOnly = false
                }
            }

            Button("Settings…") {
                NotificationCenter.default.post(name: .menuBarOnlyChanged, object: false)
                cleaningState.menuBarOnly = false
                NotificationCenter.default.post(name: .openSettingsRequested, object: nil)
            }
            Button("Diagnostics…") {
                NotificationCenter.default.post(name: .menuBarOnlyChanged, object: false)
                cleaningState.menuBarOnly = false
                NotificationCenter.default.post(name: .openDiagnosticsRequested, object: nil)
            }
            Button("Help…") {
                NotificationCenter.default.post(name: .menuBarOnlyChanged, object: false)
                cleaningState.menuBarOnly = false
                NotificationCenter.default.post(name: .openHelpRequested, object: nil)
            }
        }

        Divider()
        Button("Quit Keyboard Cleaner") { NSApplication.shared.terminate(nil) }
    }
}

// MARK: - Background (main window — adapts to light / dark mode)

struct AquaBackgroundView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorScheme) private var colorScheme
    @State private var phase: CGFloat = 0

    var body: some View {
        ZStack {
            // Base: near-white in light, deep graphite in dark (no heavy blue)
            LinearGradient(
                colors: colorScheme == .light
                    ? [Color(red: 0.97, green: 0.97, blue: 0.975),
                       Color(red: 0.92, green: 0.925, blue: 0.940)]
                    : [Color(red: 0.07, green: 0.07, blue: 0.08),
                       Color(red: 0.11, green: 0.11, blue: 0.13)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            // Blob 1 — soft sage/mint
            Ellipse()
                .fill(RadialGradient(
                    colors: [
                        (colorScheme == .light
                            ? Color(red: 0.30, green: 0.88, blue: 0.68)
                            : Color(red: 0.18, green: 0.74, blue: 0.62))
                        .opacity(colorScheme == .light ? 0.16 : 0.20),
                        .clear
                    ],
                    center: .center, startRadius: 0, endRadius: 200))
                .frame(width: 380, height: 280)
                .offset(x: -50 + sin(phase) * 20, y: -80 + cos(phase * 0.7) * 15)
                .blur(radius: 65)

            // Blob 2 — soft lavender/violet
            Ellipse()
                .fill(RadialGradient(
                    colors: [
                        (colorScheme == .light
                            ? Color(red: 0.62, green: 0.48, blue: 0.92)
                            : Color(red: 0.42, green: 0.28, blue: 0.86))
                        .opacity(colorScheme == .light ? 0.09 : 0.13),
                        .clear
                    ],
                    center: .center, startRadius: 0, endRadius: 170))
                .frame(width: 300, height: 310)
                .offset(x: 85 + cos(phase * 0.8) * 24, y: 100 + sin(phase * 1.1) * 18)
                .blur(radius: 70)
        }
        .ignoresSafeArea()
        .onAppear {
            guard !reduceMotion else {
                phase = 0
                return
            }
            withAnimation(.linear(duration: Timing.background).repeatForever(autoreverses: false)) {
                phase = .pi * 2
            }
        }
    }
}

// MARK: - Overlay Background (full-screen lock)

struct OverlayBackgroundView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var phase: CGFloat = 0

    var body: some View {
        ZStack {
            Rectangle().fill(.ultraThinMaterial)

            Ellipse()
                .fill(Design.accentStart.opacity(0.06))
                .frame(width: 700, height: 500)
                .offset(x: -100 + sin(phase) * 35, y: -220 + cos(phase * 0.7) * 28)
                .blur(radius: 90)

            Ellipse()
                .fill(Color(red: 0.55, green: 0.38, blue: 0.88).opacity(0.04))
                .frame(width: 600, height: 550)
                .offset(x: 160 + cos(phase * 0.8) * 30, y: 160 + sin(phase * 1.1) * 25)
                .blur(radius: 100)
        }
        .ignoresSafeArea()
        .onAppear {
            guard !reduceMotion else {
                phase = 0
                return
            }
            withAnimation(.linear(duration: 20).repeatForever(autoreverses: false)) {
                phase = .pi * 2
            }
        }
    }
}

// MARK: - Overlay View (full-screen lock shown on every display)

struct OverlayView: View {
    @ObservedObject var cleaningState: CleaningStateManager
    @State private var pulseAnimation = false
    @State private var errorShake = false
    @State private var lockClosed = false

    var body: some View {
        ZStack {
            OverlayBackgroundView()

            // Scrollable top content — bottom padding reserves room for the fixed unlock section
            VStack(spacing: 0) {
                Spacer()

                ZStack {
                    PulseRings(animating: pulseAnimation, count: 3,
                               baseSize: 150, step: 46, maxOpacity: 0.05)
                    GlassCircle(diameter: 130) {
                        ZStack {
                            Image(systemName: "lock.open.fill")
                                .font(.system(size: 48, weight: .light))
                                .foregroundStyle(.primary)
                                .scaleEffect(lockClosed ? 0.5 : 1.0)
                                .opacity(lockClosed ? 0 : 1)
                                .accessibilityHidden(true)
                            Image(systemName: "lock.fill")
                                .font(.system(size: 48, weight: .light))
                                .foregroundStyle(.primary)
                                .scaleEffect(lockClosed ? 1.0 : 0.5)
                                .opacity(lockClosed ? 1 : 0)
                                .accessibilityHidden(true)
                        }
                        .animation(.spring(response: 0.45, dampingFraction: 0.65), value: lockClosed)
                    }
                }
                .onAppear {
                    pulseAnimation = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { lockClosed = true }
                }
                .onChange(of: cleaningState.authState) { _, new in
                    if new == .success {
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) { lockClosed = false }
                    }
                }
                .accessibilityLabel("Keyboard is locked")
                .padding(.bottom, 24)

                VStack(spacing: 24) {
                    VStack(spacing: 12) {
                        HStack(alignment: .lastTextBaseline, spacing: 5) {
                            Text("Keyboard")
                                .font(.system(size: 20, weight: .medium))
                                .foregroundStyle(.secondary)
                            Text("Locked")
                                .font(.system(size: 38, weight: .black))
                                .tracking(-0.8)
                                .foregroundStyle(Design.accentGradient)
                        }
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel("Keyboard Locked")
                        .accessibilityAddTraits(.isHeader)

                        HStack(spacing: 6) {
                            Image(systemName: "sparkles")
                                .font(.system(size: 12, weight: .medium))
                                .accessibilityHidden(true)
                            Text("Wipe with confidence")
                                .font(.system(size: 13, weight: .medium, design: .rounded))
                        }
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 7)
                        .background(GlassCapsuleBackground())
                    }

                    if cleaningState.autoUnlockTimeout != .never {
                        CountdownRingView(cleaningState: cleaningState)
                    } else {
                        OverlayElapsedView(cleaningState: cleaningState)
                    }
                }
                .padding(.horizontal, 34)
                .padding(.vertical, 28)
                .background(GlassPanelBackground(cornerRadius: 30))
                .padding(.horizontal, 32)
                .accessibilitySortPriority(2)

                Spacer(minLength: 180)  // guarantees space for the pinned bottom section
            }
            .frame(maxWidth: .infinity)

            // Bottom section pinned to screen regardless of top content height
            VStack(spacing: 0) {
                Spacer()

                VStack(spacing: 14) {
                    UnlockButton(cleaningState: cleaningState, onFailure: triggerErrorShake)
                        .offset(x: errorShake ? -8 : 0)
                        .animation(
                            errorShake
                                ? .easeInOut(duration: Timing.errorShakeUnit)
                                    .repeatCount(Timing.errorShakeRepeat, autoreverses: true)
                                : .default,
                            value: errorShake
                        )

                    if cleaningState.hasTouchID {
                        TouchIDKeyNote()
                    }
                }
                .padding(.horizontal, 28)
                .padding(.vertical, 20)
                .background(GlassPanelBackground(cornerRadius: 28))
                .padding(.horizontal, 28)
                .padding(.bottom, 40)
                .accessibilitySortPriority(1)
            }
            .frame(maxWidth: .infinity)
        }
        .ignoresSafeArea()
    }

    private func triggerErrorShake() {
        errorShake = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { errorShake = false }
    }
}

// MARK: - Countdown Ring View

struct CountdownRingView: View {
    @ObservedObject var cleaningState: CleaningStateManager

    private var progress: Double {
        let total = Double(cleaningState.autoUnlockTimeout.rawValue)
        guard total > 0 else { return 0 }
        return max(0, 1.0 - Double(cleaningState.elapsedSeconds) / total)
    }

    var body: some View {
        VStack(spacing: 18) {
            ZStack {
                // Ambient glow behind ring (decorative)
                Circle()
                    .fill(RadialGradient(
                        colors: [Design.accentEnd.opacity(0.14), .clear],
                        center: .center, startRadius: 0, endRadius: 120))
                    .frame(width: 250, height: 250)
                    .blur(radius: 28)
                    .accessibilityHidden(true)

                // Track (decorative)
                Circle()
                    .stroke(.primary.opacity(0.06), lineWidth: 5)
                    .frame(width: 200, height: 200)
                    .accessibilityHidden(true)

                // Progress arc (decorative)
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(Design.accentGradient,
                            style: StrokeStyle(lineWidth: 5, lineCap: .round))
                    .frame(width: 200, height: 200)
                    .rotationEffect(.degrees(-90))
                    .animation(.linear(duration: 1), value: progress)
                    .accessibilityHidden(true)

                VStack(spacing: 3) {
                    Text(cleaningState.remainingTimeString ?? "")
                        .font(.system(size: 46, weight: .thin, design: .rounded).monospacedDigit())
                        .foregroundStyle(.primary)
                        .contentTransition(.numericText(countsDown: true))
                        .animation(.easeInOut(duration: 0.35), value: cleaningState.elapsedSeconds)
                        .accessibilityLabel(
                            cleaningState.remainingTimeString.map { AppStrings.autoUnlockIn($0) } ?? "")

                    Text("remaining")
                        .font(.system(size: 11, design: .rounded))
                        .foregroundStyle(.secondary)
                        .accessibilityHidden(true)
                }
            }

            HStack(spacing: 5) {
                Image(systemName: "clock")
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
                    .accessibilityHidden(true)
                Text(AppStrings.lockedFor(cleaningState.elapsedTimeString))
                    .font(.system(size: 12, design: .rounded).monospacedDigit())
                    .foregroundStyle(.tertiary)
            }
            .accessibilityLabel(AppStrings.lockedFor(cleaningState.elapsedTimeString))
        }
    }
}

// MARK: - Overlay Elapsed View (when auto-unlock is off)

struct OverlayElapsedView: View {
    @ObservedObject var cleaningState: CleaningStateManager

    var body: some View {
        VStack(spacing: 8) {
            Text(cleaningState.elapsedTimeString)
                .font(.system(size: 80, weight: .ultraLight, design: .rounded).monospacedDigit())
                .foregroundStyle(.primary)
                .contentTransition(.numericText())
                .animation(.easeInOut(duration: 0.3), value: cleaningState.elapsedSeconds)
                .accessibilityLabel(AppStrings.lockedFor(cleaningState.elapsedTimeString))

            Text("keyboard locked")
                .font(.system(size: 13, design: .rounded))
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)
        }
    }
}

// MARK: - Animation Extension

extension Animation {
    func repeatWhile(_ condition: Bool, autoreverses: Bool = true) -> Animation {
        condition ? repeatForever(autoreverses: autoreverses) : self
    }
}

// MARK: - Onboarding

struct OnboardingView: View {
    @EnvironmentObject private var cleaningState: CleaningStateManager
    @Binding var hasSeenOnboarding: Bool
    @State private var currentPage = 0

    private var pages: [(icon: String, title: String, subtitle: String)] {
        let unlockPage: (icon: String, title: String, subtitle: String)
        switch cleaningState.preferredUnlockMethod {
        case .touchID:
            unlockPage = (
                icon: "touchid",
                title: cleaningState.pinEnabled ? "Touch ID, With PIN Backup" : "Touch ID to Unlock",
                subtitle: cleaningState.pinEnabled
                    ? "Touch ID is the primary unlock path, and your PIN stays available as a deliberate fallback."
                    : "When you’re done cleaning, Touch ID unlocks everything instantly."
            )
        case .pin:
            unlockPage = (
                icon: "circle.grid.3x3.fill",
                title: "PIN to Unlock",
                subtitle: "This Mac doesn’t have Touch ID, so you’ll unlock from the on-screen PIN pad with your mouse."
            )
        case .password:
            unlockPage = (
                icon: "key.fill",
                title: "Password Fallback",
                subtitle: "If Touch ID isn’t available, Keyboard Cleaner falls back to your Mac password so you’re never locked in."
            )
        }

        return [
            (
                icon: "keyboard",
                title: "Meet Keyboard Cleaner",
                subtitle: "Lock your keyboard and clean every key safely — no accidental input, no worries."
            ),
            (
                icon: "lock.shield.fill",
                title: "One Tap, Fully Locked",
                subtitle: "Every keystroke is blocked the moment you tap Lock. Wipe as hard as you like."
            ),
            unlockPage,
        ]
    }

    var body: some View {
        VStack(spacing: 0) {
            Spacer().frame(height: 76)

            // Page content — animate between pages with a slide
            ZStack {
                ForEach(pages.indices, id: \.self) { i in
                    if i == currentPage {
                        OnboardingPage(
                            icon: pages[i].icon,
                            title: pages[i].title,
                            subtitle: pages[i].subtitle
                        )
                        .transition(.asymmetric(
                            insertion: .move(edge: .trailing).combined(with: .opacity),
                            removal:   .move(edge: .leading).combined(with: .opacity)
                        ))
                    }
                }
            }
            .animation(.spring(response: 0.48, dampingFraction: 0.82), value: currentPage)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(.horizontal, 32)

            // Page dots
            HStack(spacing: 7) {
                ForEach(pages.indices, id: \.self) { i in
                    Capsule()
                        .fill(i == currentPage ? Design.accentStart : Color.primary.opacity(0.18))
                        .frame(width: i == currentPage ? 20 : 7, height: 7)
                        .animation(.spring(response: 0.4, dampingFraction: 0.7), value: currentPage)
                }
            }
            .padding(.bottom, 28)

            // CTA button
            Button {
                if currentPage < pages.count - 1 {
                    currentPage += 1
                } else {
                    hasSeenOnboarding = true
                }
            } label: {
                Text(currentPage < pages.count - 1 ? "Continue" : "Get Started")
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(AccentButtonBackground())
                    .shadow(color: Design.accentStart.opacity(0.30), radius: 14, y: 6)
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 32)
            .accessibilityLabel(currentPage < pages.count - 1 ? "Continue to next page" : "Get started")
            .keyboardShortcut(.defaultAction)

            Spacer().frame(height: 36)
        }
        .accessibilityElement(children: .contain)
    }
}

struct OnboardingPage: View {
    let icon: String
    let title: String
    let subtitle: String

    var body: some View {
        VStack(spacing: 24) {
            GlassCircle(diameter: 110) {
                Image(systemName: icon)
                    .font(.system(size: 42, weight: .light))
                    .foregroundStyle(.primary)
                    .accessibilityHidden(true)
            }
            .accessibilityHidden(true)

            VStack(spacing: 10) {
                Text(title)
                    .font(.system(size: 28, weight: .bold))
                    .tracking(-0.5)
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.center)
                    .accessibilityAddTraits(.isHeader)

                Text(subtitle)
                    .font(.system(size: 15))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 320)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.horizontal, 36)
        .padding(.vertical, 34)
        .background(GlassPanelBackground(cornerRadius: 30))
    }
}

// MARK: - Settings Sheet

struct SettingsSheet: View {
    @ObservedObject var cleaningState: CleaningStateManager
    @Environment(\.dismiss) private var dismiss
    @State private var showPINSetup = false
    @State private var showDiagnostics = false

    var body: some View {
        VStack(spacing: 0) {
            sheetHeader(title: "Settings") {
                Button {
                    showDiagnostics = true
                } label: {
                    Image(systemName: "waveform.path.ecg.text")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Open diagnostics")
                .keyboardShortcut("d", modifiers: [.command, .shift])
            }

            List {
                Section {
                    SettingsRow(
                        icon: "speaker.wave.2.fill",
                        iconTint: Design.accentEnd,
                        title: "Sound Feedback",
                        subtitle: "Play sounds when locking and unlocking"
                    ) {
                        Toggle("Sound Feedback", isOn: $cleaningState.soundEnabled)
                            .labelsHidden()
                            .accessibilityLabel("Sound Feedback")
                            .accessibilityHint("Play sounds when locking and unlocking")
                            .tint(Design.accentStart)
                    }

                    SettingsRow(
                        icon: "arrow.up.right.square.fill",
                        iconTint: Color(red: 0.60, green: 0.40, blue: 0.90),
                        title: "Launch at Login",
                        subtitle: "Start automatically when you log in"
                    ) {
                        Toggle("Launch at Login", isOn: Binding(
                            get: { cleaningState.isLaunchAtLoginEnabled },
                            set: { cleaningState.setLaunchAtLogin($0) }
                        ))
                        .labelsHidden()
                        .accessibilityLabel("Launch at Login")
                        .accessibilityHint("Start Keyboard Cleaner automatically when you log in")
                        .tint(Design.accentStart)
                    }

                    SettingsRow(
                        icon: "menubar.rectangle",
                        iconTint: Design.accentStart,
                        title: "Menu Bar Only",
                        subtitle: "Hide the main window, run from menu bar"
                    ) {
                        Toggle("Menu Bar Only", isOn: $cleaningState.menuBarOnly)
                            .labelsHidden()
                            .accessibilityLabel("Menu Bar Only")
                            .accessibilityHint("Hide the main window and keep Keyboard Cleaner in the menu bar")
                            .tint(Design.accentStart)
                    }

                    SettingsRow(
                        icon: "circle.grid.3x3.fill",
                        iconTint: Color(red: 0.30, green: 0.65, blue: 0.90),
                        title: "PIN Code",
                        subtitle: cleaningState.pinEnabled ? "Mouse-clickable numpad unlock" : "Unlock with a 4-digit PIN (no Touch ID needed)"
                    ) {
                        if cleaningState.pinEnabled {
                            HStack(spacing: 8) {
                                Button("Change") { showPINSetup = true }
                                    .buttonStyle(.plain)
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundStyle(Design.accentEnd)
                                    .accessibilityLabel("Change PIN code")
                                Button("Remove") { cleaningState.clearPin() }
                                    .buttonStyle(.plain)
                                    .font(.system(size: 12, weight: .medium))
                                    .accessibilityLabel("Remove PIN code")
                                    .foregroundStyle(.secondary)
                            }
                        } else {
                            Button("Set PIN") { showPINSetup = true }
                                .buttonStyle(.plain)
                                .font(.system(size: 13, weight: .semibold, design: .rounded))
                                .foregroundStyle(Design.accentEnd)
                        }
                    }
                }

                Section("Cleaning Session") {
                    AutoUnlockPickerRow(cleaningState: cleaningState)
                    OverlayStyleRow(cleaningState: cleaningState)
                    FullScreenCoverageRow(cleaningState: cleaningState)
                }

                Section("Presets") {
                    PresetRow(cleaningState: cleaningState)
                }
            }
            .listStyle(.inset(alternatesRowBackgrounds: false))
            .scrollContentBackground(.hidden)
            .background(AquaBackgroundView())
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(width: 520, height: 660)
        .sheet(isPresented: $showPINSetup) {
            PINSetupSheet(cleaningState: cleaningState)
        }
        .sheet(isPresented: $showDiagnostics) {
            DiagnosticsSheet(cleaningState: cleaningState)
        }
        .accessibilityElement(children: .contain)
    }
}

struct DiagnosticsSheet: View {
    @ObservedObject var cleaningState: CleaningStateManager
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            sheetHeader(title: "Diagnostics")

            List {
                Section {
                    ForEach(Array(cleaningState.diagnosticsItems.enumerated()), id: \.offset) { _, item in
                        HStack {
                            Text(item.label)
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text(item.value)
                                .fontWeight(.semibold)
                        }
                        .accessibilityElement(children: .combine)
                        .accessibilityLabel("\(item.label): \(item.value)")
                    }
                }
            }
            .listStyle(.inset(alternatesRowBackgrounds: false))
            .scrollContentBackground(.hidden)
            .background(AquaBackgroundView())
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(width: 440, height: 480)
        .accessibilityElement(children: .contain)
    }
}

struct HelpSheet: View {
    @ObservedObject var cleaningState: CleaningStateManager
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            sheetHeader(
                title: "Help",
                subtitle: "How to lock, unlock, and troubleshoot Keyboard Cleaner."
            )

            List {
                helpSectionList(title: "Start a Cleaning Session", items: [
                    "Click `Lock Keyboard` from the main window or menu bar.",
                    "You can also press `Control` + `Command` + `L` to lock from anywhere.",
                    "A successful lock blocks all keystrokes before they reach other apps."
                ])

                helpSectionList(title: "Unlock Safely", items: unlockHelpItems)

                helpSectionList(title: "Useful Settings", items: [
                    "Use `Overlay` to choose between a full-screen lock view and a compact floating view.",
                    "Use `Auto-unlock` when you want the session to end automatically after a short cleaning pass.",
                    "If your Mac has no Touch ID, set a PIN in Settings so you always have a mouse-only unlock path."
                ])

                helpSectionList(title: "Troubleshooting", items: [
                    "If the app cannot lock the keyboard, confirm Accessibility access is granted in System Settings.",
                    "Open `Diagnostics` from Settings or the menu bar to check permission, event-tap, and unlock state.",
                    "If permission changes are not detected immediately, relaunch the app and try a quick lock test."
                ])
            }
            .listStyle(.inset(alternatesRowBackgrounds: false))
            .scrollContentBackground(.hidden)
            .background(AquaBackgroundView())
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(width: 500, height: 580)
        .accessibilityElement(children: .contain)
    }

    private var unlockHelpItems: [String] {
        switch cleaningState.preferredUnlockMethod {
        case .touchID:
            if cleaningState.pinEnabled {
                return [
                    "Touch ID is the primary unlock path.",
                    "If needed, you can switch to the on-screen PIN pad as a fallback.",
                    "After a failed biometric attempt, password fallback can also appear."
                ]
            }
            return [
                "Touch ID is the primary unlock path.",
                "If biometric authentication fails, the app can fall back to your Mac password.",
                "The physical Touch ID key may still trigger the macOS lock screen on some Macs."
            ]
        case .pin:
            return [
                "Unlock from the on-screen PIN pad using your mouse.",
                "PIN unlock is useful on Macs without Touch ID or when keyboard input is intentionally blocked.",
                "If PIN entry fails, clear the digits and try again carefully."
            ]
        case .password:
            return [
                "Unlock with your Mac password when biometric or PIN unlock is not available.",
                "The password prompt comes from macOS authentication and does not type into other apps.",
                "If you want a mouse-only unlock path, set a PIN in Settings."
            ]
        }
    }

    @ViewBuilder
    private func helpSectionList(title: String, items: [String]) -> some View {
        Section(title) {
            ForEach(items, id: \.self) { item in
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(Design.accentEnd)
                        .accessibilityHidden(true)
                    Text(item)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel(item)
            }
        }
    }
}

private extension View {
    func sheetHeader(title: String, subtitle: String? = nil, @ViewBuilder trailing: () -> some View = { EmptyView() }) -> some View {
        modifier(SheetHeaderModifier(title: title, subtitle: subtitle, trailing: AnyView(trailing())))
    }
}

private struct SheetHeaderModifier: ViewModifier {
    @Environment(\.dismiss) private var dismiss

    let title: String
    let subtitle: String?
    let trailing: AnyView

    func body(content: Content) -> some View {
        VStack(spacing: 0) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(.primary)
                    if let subtitle {
                        Text(subtitle)
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
                HStack(spacing: 10) {
                    trailing
                    Button("Done") { dismiss() }
                        .buttonStyle(.plain)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Design.accentEnd)
                        .keyboardShortcut(.cancelAction)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 18)
            .padding(.bottom, 12)

            content
        }
    }
}

// MARK: - PIN Setup Sheet

struct PINSetupSheet: View {
    @ObservedObject var cleaningState: CleaningStateManager
    @Environment(\.dismiss) private var dismiss
    @State private var step: SetupStep = .enter
    @State private var firstPIN = ""
    @State private var confirmPIN = ""
    @State private var mismatch = false

    enum SetupStep { case enter, confirm }

    var body: some View {
        ZStack {
            AquaBackgroundView()

            VStack(spacing: 24) {
                Spacer()

                VStack(spacing: 22) {
                    VStack(spacing: 6) {
                        Text(step == .enter ? "Set a PIN Code" : "Confirm PIN")
                            .font(.system(size: 22, weight: .bold))
                            .foregroundStyle(.primary)
                        Text(step == .enter
                             ? "Enter a 4-digit PIN — you’ll use it to unlock with your mouse"
                             : mismatch ? "PINs don’t match. Try again." : "Re-enter your PIN to confirm")
                            .font(.system(size: 13))
                            .foregroundStyle(mismatch ? Color.red.opacity(0.8) : .secondary)
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: 280)
                    }

                    PINPadView(
                        entry: step == .enter ? $firstPIN : $confirmPIN,
                        onComplete: advance,
                        onCancel: {
                            if step == .confirm {
                                withAnimation(.spring(response: 0.3)) {
                                    step = .enter
                                    confirmPIN = ""
                                    mismatch = false
                                }
                            } else {
                                dismiss()
                            }
                        }
                    )
                }
                .padding(.horizontal, 26)
                .padding(.vertical, 26)
                .background(GlassPanelBackground(cornerRadius: 28))

                Spacer()
            }
            .padding(.horizontal, 40)
        }
        .frame(width: 340, height: 420)
        .accessibilityElement(children: .contain)
    }

    private func advance() {
        if step == .enter {
            withAnimation(.spring(response: 0.3)) {
                step = .confirm
                mismatch = false
            }
        } else {
            if confirmPIN == firstPIN {
                cleaningState.setPin(firstPIN)
                dismiss()
            } else {
                mismatch = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                    confirmPIN = ""
                    mismatch = false
                }
            }
        }
    }
}

struct SettingsRow<Control: View>: View {
    let icon: String
    let iconTint: Color
    let title: String
    let subtitle: String
    let control: Control

    init(
        icon: String,
        iconTint: Color,
        title: String,
        subtitle: String,
        @ViewBuilder control: () -> Control
    ) {
        self.icon = icon
        self.iconTint = iconTint
        self.title = title
        self.subtitle = subtitle
        self.control = control()
    }

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 9)
                    .fill(iconTint.opacity(0.12))
                    .frame(width: 36, height: 36)
                Image(systemName: icon)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(iconTint)
            }
            .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(.primary)
                Text(subtitle)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("\(title). \(subtitle)")

            Spacer()

            control
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }
}
