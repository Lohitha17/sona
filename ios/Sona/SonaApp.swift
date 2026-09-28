import SwiftUI
import UIKit

@main
struct SonaApp: App {
    @State private var ledger: Ledger

    init() {
        _ledger = State(initialValue: Ledger())
        let appearance = UINavigationBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = UIColor(red: 0.067, green: 0.055, blue: 0.043, alpha: 1)
        appearance.titleTextAttributes = [.foregroundColor: UIColor(red: 0.965, green: 0.945, blue: 0.910, alpha: 1)]
        let serif = UIFont.systemFont(ofSize: 34, weight: .medium).fontDescriptor.withDesign(.serif)
        appearance.largeTitleTextAttributes = [
            .font: UIFont(descriptor: serif ?? UIFont.systemFont(ofSize: 34).fontDescriptor, size: 40),
            .foregroundColor: UIColor(red: 0.965, green: 0.945, blue: 0.910, alpha: 1),
        ]
        UINavigationBar.appearance().standardAppearance = appearance
        UINavigationBar.appearance().scrollEdgeAppearance = appearance
        UINavigationBar.appearance().compactAppearance = appearance
    }

    var body: some Scene {
        WindowGroup {
            VaultView()
                .environment(ledger)
                .preferredColorScheme(.dark)
                .tint(Theme.gold)
        }
    }
}
