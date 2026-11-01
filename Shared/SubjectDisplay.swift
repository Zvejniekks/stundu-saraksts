import Foundation

/// Presentation only: the original subject remains available in the app and accessibility labels.
enum SubjectDisplay {
    static func name(_ subject: String) -> String {
        let cleaned = subject.split(whereSeparator: { $0.isWhitespace }).joined(separator: " ")
        let key = cleaned.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "lv_LV"))
        if key.contains("kriev") && key.contains("val") { return "Krievu valoda" }
        if key.contains("angl") && key.contains("val") { return "Angļu valoda" }
        if key.contains("vacu") && key.contains("val") { return "Vācu valoda" }
        if key.contains("valod") && key.contains("kultur") && key.contains("izpa") {
            return "Valoda un kultūra"
        }
        // Keep unknown names intact rather than inventing ambiguous word fragments.
        return cleaned
    }
}
