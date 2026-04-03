import SwiftUI
import ServiceManagement

@main
struct KeyboardCleanerApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var cleaningState = CleaningStateManager()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(cleaningState)
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 560, height: 760)
        .windowResizability(.automatic)
        .commands {
            CommandGroup(replacing: .newItem) {}
            CommandGroup(after: .appInfo) {
                Divider()
                Button("Keyboard Cleaner Help") {
                    NotificationCenter.default.post(name: .menuBarOnlyChanged, object: false)
                    NotificationCenter.default.post(name: .openHelpRequested, object: nil)
                }
                .keyboardShortcut("/", modifiers: [.command, .shift])
            }
        }

        MenuBarExtra {
            MenuBarView()
                .environmentObject(cleaningState)
        } label: {
            Label(
                cleaningState.isLocked ? String(localized: "Keyboard Locked") : String(localized: "Keyboard Cleaner"),
                image: "MenuBarIcon"
            )
            .labelStyle(.iconOnly)
        }
        .menuBarExtraStyle(.menu)
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    private var mainWindow: NSWindow?

    func applicationDidFinishLaunching(_ notification: Notification) {
        guard let window = NSApplication.shared.windows.first else { return }
        mainWindow = window
        window.styleMask.insert(.resizable)
        window.minSize = NSSize(width: 520, height: 680)

        window.backgroundColor = NSColor(name: nil, dynamicProvider: { appearance in
            switch appearance.bestMatch(from: [.aqua, .darkAqua]) {
            case .darkAqua:
                return NSColor(srgbRed: 0.07, green: 0.07, blue: 0.08, alpha: 1)
            default:
                return NSColor(srgbRed: 0.97, green: 0.97, blue: 0.975, alpha: 1)
            }
        })

        if let contentView = window.contentView {
            contentView.wantsLayer = true
            contentView.layer?.cornerRadius = 20
            contentView.layer?.masksToBounds = true
        }

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleMenuBarOnlyChanged(_:)),
            name: .menuBarOnlyChanged,
            object: nil
        )

        // If the app launched in menu bar-only mode, hide the window immediately
        if UserDefaults.standard.bool(forKey: "menuBarOnly") {
            window.orderOut(nil)
        }
    }

    @objc private func handleMenuBarOnlyChanged(_ notification: Notification) {
        guard let enabled = notification.object as? Bool else { return }
        if enabled {
            if let sheet = mainWindow?.attachedSheet {
                mainWindow?.endSheet(sheet)
            }
            mainWindow?.orderOut(nil)
        } else {
            mainWindow?.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        // When menu bar-only mode is on, closing the window should not quit the app.
        return !UserDefaults.standard.bool(forKey: "menuBarOnly")
    }
}
