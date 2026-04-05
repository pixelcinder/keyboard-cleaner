import Foundation

enum AppStrings {
    static func lockedFor(_ duration: String) -> String {
        String(format: NSLocalizedString("Locked for %@", comment: "Locked duration status"), duration)
    }

    static func autoUnlockIn(_ duration: String) -> String {
        String(format: NSLocalizedString("Auto-unlock in %@", comment: "Auto unlock remaining time"), duration)
    }

    static func preset(_ title: String) -> String {
        String(format: NSLocalizedString("Preset: %@", comment: "Current preset label"), title)
    }

    static func step(_ number: String, _ text: String) -> String {
        String(format: NSLocalizedString("Step %@: %@", comment: "Permission step label"), number, text)
    }

    static func diagnosticsRow(_ label: String, _ value: String) -> String {
        String(format: NSLocalizedString("%@: %@", comment: "Diagnostics row accessibility label"), label, value)
    }

    static func pinDigitsEntered(_ count: Int, _ maxLength: Int) -> String {
        String(
            format: NSLocalizedString("%d of %d digits entered", comment: "PIN entry progress"),
            count,
            maxLength
        )
    }

    static func enterDigit(_ label: String) -> String {
        String(format: NSLocalizedString("Enter digit %@", comment: "PIN digit hint"), label)
    }

    static func keyboardLocked(_ subtitle: String) -> String {
        String(format: NSLocalizedString("Keyboard locked. %@", comment: "Minimal overlay status"), subtitle)
    }
}
