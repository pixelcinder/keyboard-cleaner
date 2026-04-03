import Foundation

enum AppStrings {
    static func lockedFor(_ duration: String) -> String {
        String(format: NSLocalizedString("Locked for %@", comment: "Locked duration status"), locale: .current, duration)
    }

    static func autoUnlockIn(_ duration: String) -> String {
        String(format: NSLocalizedString("Auto-unlock in %@", comment: "Auto unlock remaining time"), locale: .current, duration)
    }

    static func preset(_ title: String) -> String {
        String(format: NSLocalizedString("Preset: %@", comment: "Current preset label"), locale: .current, title)
    }

    static func step(_ number: String, _ text: String) -> String {
        String(format: NSLocalizedString("Step %@: %@", comment: "Permission step label"), locale: .current, number, text)
    }

    static func diagnosticsRow(_ label: String, _ value: String) -> String {
        String(format: NSLocalizedString("%@: %@", comment: "Diagnostics row accessibility label"), locale: .current, label, value)
    }

    static func pinDigitsEntered(_ count: Int, _ maxLength: Int) -> String {
        String(
            format: NSLocalizedString("%d of %d digits entered", comment: "PIN entry progress"),
            locale: .current,
            count,
            maxLength
        )
    }

    static func enterDigit(_ label: String) -> String {
        String(format: NSLocalizedString("Enter digit %@", comment: "PIN digit hint"), locale: .current, label)
    }

    static func keyboardLocked(_ subtitle: String) -> String {
        String(format: NSLocalizedString("Keyboard locked. %@", comment: "Minimal overlay status"), locale: .current, subtitle)
    }
}
