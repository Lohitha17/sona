import Foundation

enum Format {
    static func money(_ value: Double, currency: String) -> String {
        if currency == "INR" {
            return "₹" + groupedINR(abs(value))
        }
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = currency
        formatter.locale = Locale(identifier: "en_US")
        formatter.maximumFractionDigits = 2
        formatter.minimumFractionDigits = 2
        if let text = formatter.string(from: NSNumber(value: abs(value))) {
            return text
        }
        return "\(symbol(currency))\(String(format: "%.2f", abs(value)))"
    }

    /// Groups a rupee amount as 12,34,567.
    private static func groupedINR(_ value: Double) -> String {
        let digits = String(Int(value.rounded()))
        if digits.count <= 3 { return digits }
        let tail = digits.suffix(3)
        var head = String(digits.dropLast(3))
        var groups: [String] = []
        while head.count > 2 {
            groups.insert(String(head.suffix(2)), at: 0)
            head = String(head.dropLast(2))
        }
        if !head.isEmpty {
            groups.insert(head, at: 0)
        }
        return groups.joined(separator: ",") + "," + tail
    }

    static func signedMoney(_ value: Double, currency: String) -> String {
        let text = money(value, currency: currency)
        if value > 0.004 { return "+\(text)" }
        if value < -0.004 { return "−\(text)" }
        return text
    }

    static func grams(_ value: Double) -> String {
        var text = String(format: "%.3f", value)
        while text.contains(".") && (text.hasSuffix("0") || text.hasSuffix(".")) {
            text.removeLast()
        }
        return "\(text) g"
    }

    static func karat(_ value: Double) -> String {
        if abs(value.rounded() - value) < 0.001 {
            return "\(Int(value.rounded()))K"
        }
        return String(format: "%.1fK", value)
    }

    static func plain(_ value: Double) -> String {
        if abs(value.rounded() - value) < 0.0001 {
            return String(Int(value.rounded()))
        }
        var text = String(format: "%.3f", value)
        while text.contains(".") && (text.hasSuffix("0") || text.hasSuffix(".")) {
            text.removeLast()
        }
        return text
    }

    static func percent(_ value: Double) -> String {
        plain(value) + "%"
    }

    static func date(_ iso: String?) -> String {
        guard let iso, !iso.isEmpty else { return "Not recorded" }
        let parser = DateFormatter()
        parser.calendar = Calendar(identifier: .gregorian)
        parser.locale = Locale(identifier: "en_US_POSIX")
        parser.dateFormat = "yyyy-MM-dd"
        guard let date = parser.date(from: iso) else { return iso }
        let output = DateFormatter()
        output.locale = Locale(identifier: "en_GB")
        output.dateFormat = "d MMM yyyy"
        return output.string(from: date)
    }

    static func symbol(_ currency: String) -> String {
        switch currency {
        case "INR": return "₹"
        case "USD": return "$"
        case "EUR": return "€"
        case "GBP": return "£"
        case "AED": return "AED "
        case "SAR": return "SAR "
        default: return ""
        }
    }

    static func rateLine(_ settings: Settings) -> String {
        "\(money(settings.goldRate24K, currency: settings.currency)) / g · 24K"
    }
}

enum Catalogue {
    static let labels: [String: String] = [
        "necklace": "Necklace",
        "earring": "Earrings",
        "ring": "Ring",
        "bangle": "Bangles",
        "bracelet": "Bracelet",
        "chain": "Chain",
        "pendant": "Pendant",
        "anklet": "Anklet",
        "nose-pin": "Nose pin",
        "other": "Other",
    ]

    static func label(_ key: String) -> String {
        if let known = labels[key] { return known }
        return key.replacingOccurrences(of: "-", with: " ").capitalized
    }
}
