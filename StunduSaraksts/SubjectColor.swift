import SwiftUI

/// A calm, stable colour per subject so the day is easier to scan.
enum SubjectColor {
    private static let palette: [Color] = [
        Color(red: 0.00, green: 0.44, blue: 0.90), Color(red: 0.20, green: 0.65, blue: 0.45),
        Color(red: 0.55, green: 0.35, blue: 0.85), Color(red: 0.85, green: 0.30, blue: 0.45),
        Color(red: 0.10, green: 0.60, blue: 0.70), Color(red: 0.70, green: 0.55, blue: 0.15),
        Color(red: 0.40, green: 0.45, blue: 0.55)
    ]
    static func color(for subject: String) -> Color {
        // String.hashValue changes between launches; this does not.
        let sum = subject.unicodeScalars.reduce(0) { ($0 &* 31 &+ Int($1.value)) & 0xFFFFFF }
        return palette[sum % palette.count]
    }
}
