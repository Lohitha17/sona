import SwiftUI

struct VaultView: View {
    @Environment(Ledger.self) private var ledger
    @State private var query = ""
    @State private var category = ""
    @State private var adding = false

    private var visible: [Piece] {
        ledger.pieces.filter { piece in
            (category.isEmpty || piece.category == category)
                && (query.isEmpty || matches(piece, query))
        }
    }

    private var totals: (pieces: Int, net: Double, value: Double, paid: Double, making: Double, change: Double) {
        let rows = visible
        return (
            rows.count,
            rows.reduce(0) { $0 + $1.netWeightG },
            rows.reduce(0) { $0 + $1.vaultValue },
            rows.reduce(0) { $0 + $1.purchasePrice },
            rows.reduce(0) { $0 + $1.makingCharge },
            rows.reduce(0) { $0 + $1.change }
        )
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    statRow
                    substats
                    karatRow
                    categoryChips
                    if visible.isEmpty {
                        empty
                    } else {
                        ForEach(visible) { piece in
                            NavigationLink(value: piece.id) {
                                PieceRow(piece: piece)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 28)
            }
            .background(Theme.background)
            .navigationTitle("Sona")
            .navigationBarTitleDisplayMode(.large)
            .searchable(text: $query, prompt: "Search name, hallmark, notes")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        adding = true
                    } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel("Add a piece")
                }
            }
            .navigationDestination(for: UUID.self) { id in
                if let piece = ledger.pieces.first(where: { $0.id == id }) {
                    PieceDetailView(pieceID: piece.id)
                }
            }
            .sheet(isPresented: $adding) {
                NavigationStack {
                    PieceEditorView(piece: nil)
                }
            }
        }
    }

    private var statRow: some View {
        HStack(spacing: 10) {
            StatTile(label: "Pieces", value: "\(totals.pieces)")
            StatTile(label: "Net gold", value: Format.grams(totals.net))
            StatTile(label: "Vault value", value: Format.money(totals.value))
        }
    }

    private var substats: some View {
        HStack(spacing: 14) {
            Text("Paid \(Format.money(totals.paid))")
            Text("Making \(Format.money(totals.making))")
            Text("Change \(Format.signedMoney(totals.change))")
                .foregroundStyle(totals.change < 0 ? Theme.down : Theme.gold)
        }
        .font(.footnote)
        .foregroundStyle(Theme.muted)
    }

    private var karatRow: some View {
        HStack(spacing: 10) {
            ForEach(Piece.karats, id: \.self) { karat in
                let group = visible.filter { $0.karat == karat }
                VStack(alignment: .leading, spacing: 4) {
                    Text("\(karat)K")
                        .font(Theme.serif(22))
                        .foregroundStyle(Theme.gold)
                    Text("\(group.count)")
                        .font(Theme.serif(26))
                    Text(group.count == 1 ? "piece" : "pieces")
                        .font(.caption2)
                        .tracking(0.8)
                        .textCase(.uppercase)
                        .foregroundStyle(Theme.dim)
                    Text(Format.grams(group.reduce(0) { $0 + $1.netWeightG }) + " net")
                        .font(.caption)
                        .foregroundStyle(Theme.muted)
                    Text(Format.money(group.reduce(0) { $0 + $1.vaultValue }))
                        .font(.caption.weight(.medium))
                        .foregroundStyle(Theme.ink)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(12)
                .background { panel }
            }
        }
    }

    private var categoryChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                chip("All", key: "")
                ForEach(usedCategories, id: \.self) { key in
                    chip(Piece.label(key), key: key)
                }
            }
        }
    }

    private var usedCategories: [String] {
        Piece.categories.filter { key in ledger.pieces.contains { $0.category == key } }
    }

    private var empty: some View {
        VStack(spacing: 10) {
            Text(query.isEmpty && category.isEmpty ? "The vault is empty" : "No matches")
                .font(Theme.serif(28))
            Text(query.isEmpty && category.isEmpty
                 ? "Start with one necklace, bangle, or ring."
                 : "Try another name, or clear the filter.")
                .font(.subheadline)
                .foregroundStyle(Theme.muted)
                .multilineTextAlignment(.center)
            if query.isEmpty && category.isEmpty {
                Button("Add a piece") { adding = true }
                    .buttonStyle(.borderedProminent)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(28)
        .background { panel }
    }

    private func chip(_ title: String, key: String) -> some View {
        Button(title) { category = key }
            .font(.subheadline.weight(.medium))
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(category == key ? Theme.gold : Theme.panel, in: Capsule())
            .foregroundStyle(category == key ? Color.black : Theme.ink)
            .overlay(Capsule().stroke(Theme.line, lineWidth: category == key ? 0 : 1))
    }

    private var panel: some View {
        RoundedRectangle(cornerRadius: 18, style: .continuous)
            .fill(Theme.panel)
            .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(Theme.line))
    }

    private func matches(_ piece: Piece, _ query: String) -> Bool {
        let needle = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if needle.isEmpty { return true }
        let haystack = [piece.name, piece.notes, piece.hallmark, piece.storage, piece.category]
            .joined(separator: " ")
            .lowercased()
        return haystack.contains(needle)
    }
}

private struct StatTile: View {
    var label: String
    var value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.caption2)
                .tracking(1)
                .textCase(.uppercase)
                .foregroundStyle(Theme.dim)
            Text(value)
                .font(Theme.serif(18))
                .foregroundStyle(Theme.ink)
                .minimumScaleFactor(0.6)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Theme.panel)
                .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(Theme.line))
        )
    }
}

private struct PieceRow: View {
    @Environment(Ledger.self) private var ledger
    var piece: Piece

    var body: some View {
        HStack(spacing: 12) {
            thumbnail
            VStack(alignment: .leading, spacing: 4) {
                Text(Piece.label(piece.category))
                    .font(.caption2)
                    .tracking(1)
                    .textCase(.uppercase)
                    .foregroundStyle(Theme.dim)
                Text(piece.name)
                    .font(Theme.serif(20))
                    .foregroundStyle(Theme.ink)
                Text("\(Format.grams(piece.netWeightG)) · \(piece.karat)K\(piece.billData == nil ? "" : " · Bill saved")")
                    .font(.subheadline)
                    .foregroundStyle(Theme.muted)
                Text(Format.money(piece.vaultValue))
                    .font(Theme.serif(18))
                    .foregroundStyle(Theme.ink)
            }
            Spacer(minLength: 0)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Theme.panel)
                .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(Theme.line))
        )
    }

    @ViewBuilder
    private var thumbnail: some View {
        if let image = ledger.picture(piece.imageData) {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(width: 84, height: 84)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        } else {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Theme.gold.opacity(0.12))
                .frame(width: 84, height: 84)
                .overlay {
                    Text(String(piece.name.first ?? "S").uppercased())
                        .font(Theme.serif(28))
                        .foregroundStyle(Theme.gold)
                }
        }
    }
}
