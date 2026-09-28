import SwiftUI

enum Theme {
    static let background = Color(red: 0.067, green: 0.055, blue: 0.043)
    static let panel = Color(red: 0.141, green: 0.110, blue: 0.086)
    static let gold = Color(red: 0.906, green: 0.788, blue: 0.541)
    static let ink = Color(red: 0.965, green: 0.945, blue: 0.910)
    static let muted = Color(red: 0.718, green: 0.671, blue: 0.616)
    static let dim = Color(red: 0.549, green: 0.506, blue: 0.455)
    static let line = Color(red: 0.906, green: 0.788, blue: 0.541).opacity(0.22)
    static let down = Color(red: 0.890, green: 0.627, blue: 0.565)

    static func serif(_ size: CGFloat) -> Font {
        .system(size: size, weight: .medium, design: .serif)
    }
}
