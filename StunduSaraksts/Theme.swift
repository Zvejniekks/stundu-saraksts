import SwiftUI
import UIKit

/// App colours chosen for at least 4.5:1 contrast as text on the app's backgrounds,
/// in both light and dark mode (WCAG AA).
enum Theme {
    private static func dynamic(light: (CGFloat, CGFloat, CGFloat), dark: (CGFloat, CGFloat, CGFloat)) -> Color {
        Color(UIColor { traits in
            let c = traits.userInterfaceStyle == .dark ? dark : light
            return UIColor(red: c.0, green: c.1, blue: c.2, alpha: 1)
        })
    }
    /// Text, icons and outlines.
    static let blue = dynamic(light: (0.00, 0.40, 0.85), dark: (0.45, 0.70, 1.00))
    /// Changes and warnings.
    static let orange = dynamic(light: (0.72, 0.33, 0.00), dark: (1.00, 0.65, 0.30))
    /// Filled backgrounds behind white text (selected day).
    static let blueFill = Color(red: 0.00, green: 0.40, blue: 0.85)
}
