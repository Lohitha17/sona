import Foundation

enum Format {
    static func money(_ value: Double) -> String {
        "₹" + grouped(abs(value))
    }

    static func signedMoney(_ value: Double) -> String {
        if value > 0.004 { return "+" + money(value) }
        if value < -0.004 { return "−" + money(value) }
        return money(value)
    }

    static func grams(_ value: Double) -> String {
        var text = String(format: "%.3f", value)
        while text.contains(".") && (text.hasSuffix("0") || text.hasSuffix(".")) {
            text.removeLast()
        }
        return text + " g"
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

    static func day(_ date: Date?) -> String {
        guard let date else { return "Not recorded" }
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }

    private static func grouped(_ value: Double) -> String {
        let digits = String(Int(value.rounded()))
        if digits.count <= 3 { return digits }
        let tail = digits.suffix(3)
        var head = String(digits.dropLast(3))
        var groups: [String] = []
        while head.count > 2 {
            groups.insert(String(head.suffix(2)), at: 0)
            head = String(head.dropLast(2))
        }
        if !head.isEmpty { groups.insert(head, at: 0) }
        return groups.joined(separator: ",") + "," + tail
    }
}
