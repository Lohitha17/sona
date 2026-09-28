import Foundation

struct Settings: Codable, Sendable {
    var currency: String
    var goldRate24K: Double
}

struct Piece: Codable, Sendable {
    var id: String
    var name: String
    var category: String
    var grossWeightG: Double
    var stoneWeightG: Double
    var netWeightG: Double
    var karat: Double
    var wastagePercent: Double
    var makingCharge: Double
    var purchasePrice: Double
    var acquiredOn: String?
    var storage: String
    var hallmark: String
    var notes: String
    var hasImage: Bool
    var hasBill: Bool
    var goldValue: Double
    var estimatedValue: Double
    var unrealized: Double
    var updatedAt: String
}

struct CategoryTotal: Codable, Sendable {
    var category: String
    var estimatedValue: Double
}

struct Totals: Codable, Sendable {
    var pieces: Int
    var netWeightG: Double
    var makingCharges: Double
    var estimatedValue: Double
    var purchasePrice: Double
    var unrealized: Double
}

struct KaratTotal: Codable, Sendable {
    var karat: Int
    var pieces: Int
    var netWeightG: Double
    var estimatedValue: Double
}

struct Summary: Codable, Sendable {
    var settings: Settings
    var totals: Totals
    var byKarat: [KaratTotal]
    var byCategory: [CategoryTotal]
    var pieces: [Piece]
    var query: String
    var category: String
    var karat: Int
    var availableCategories: [String]
}

struct PieceEnvelope: Codable, Sendable {
    var piece: Piece
    var settings: Settings
}

struct Meta: Codable, Sendable {
    var categories: [String]
    var storages: [String]
    var karats: [Int]
}

struct ErrorBody: Codable, Sendable {
    var detail: String?
}
