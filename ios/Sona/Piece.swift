import Foundation

struct Piece: Identifiable, Codable, Equatable {
    var id: UUID
    var name: String
    var category: String
    var grossWeightG: Double
    var stoneWeightG: Double
    var karat: Int
    var wastagePercent: Double
    var makingCharge: Double
    var purchasePrice: Double
    var acquiredOn: Date?
    var storage: String
    var hallmark: String
    var notes: String
    var imageData: Data?
    var billData: Data?
    var createdAt: Date
    var updatedAt: Date

    static let rate24K = 9860.0
    static let karats = [18, 22, 24]
    static let categories = [
        "necklace", "earring", "ring", "bangle", "bracelet",
        "chain", "pendant", "anklet", "nose-pin", "other",
    ]
    static let storages = ["Home safe", "Bank locker", "Worn", "With family", "Other"]

    static func label(_ category: String) -> String {
        switch category {
        case "necklace": return "Necklace"
        case "earring": return "Earrings"
        case "ring": return "Ring"
        case "bangle": return "Bangles"
        case "bracelet": return "Bracelet"
        case "chain": return "Chain"
        case "pendant": return "Pendant"
        case "anklet": return "Anklet"
        case "nose-pin": return "Nose pin"
        case "other": return "Other"
        default: return category.replacingOccurrences(of: "-", with: " ").capitalized
        }
    }

    var netWeightG: Double { max(grossWeightG - stoneWeightG, 0) }

    /// Used only to price the piece. The screens do not show this weight.
    var fineWeightG: Double {
        netWeightG * (Double(karat) / 24.0) * (1 + wastagePercent / 100.0)
    }

    var goldValue: Double { fineWeightG * Self.rate24K }
    var vaultValue: Double { goldValue + makingCharge }
    var change: Double { vaultValue - purchasePrice }

    static func blank() -> Piece {
        let now = Date()
        return Piece(
            id: UUID(),
            name: "",
            category: "necklace",
            grossWeightG: 0,
            stoneWeightG: 0,
            karat: 22,
            wastagePercent: 0,
            makingCharge: 0,
            purchasePrice: 0,
            acquiredOn: nil,
            storage: "Home safe",
            hallmark: "",
            notes: "",
            imageData: nil,
            billData: nil,
            createdAt: now,
            updatedAt: now
        )
    }
}
