import SwiftUI

struct PieceDetailView: View {
    @Environment(Ledger.self) private var ledger
    @Environment(\.dismiss) private var dismiss
    var pieceID: UUID
    @State private var editing = false
    @State private var confirmingDelete = false

    private var piece: Piece? {
        ledger.pieces.first { $0.id == pieceID }
    }

    var body: some View {
        Group {
            if let piece {
                content(piece)
            } else {
                ContentUnavailableView("That piece is gone", systemImage: "tray")
            }
        }
        .background(Theme.background)
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $editing) {
            if let piece {
                NavigationStack {
                    PieceEditorView(piece: piece)
                }
            }
        }
    }

    private func content(_ piece: Piece) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                photo(piece)
                Text(Piece.label(piece.category))
                    .font(.caption)
                    .tracking(1.4)
                    .textCase(.uppercase)
                    .foregroundStyle(Theme.gold)
                Text(piece.name)
                    .font(Theme.serif(36))
                Text("Kept in \(piece.storage).")
                    .foregroundStyle(Theme.muted)
                valueCard(piece)
                facts(piece)
                if !piece.notes.isEmpty {
                    Text(piece.notes)
                        .foregroundStyle(Theme.muted)
                }
                if let bill = ledger.image(named: piece.billFilename) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Bill")
                            .font(.caption)
                            .tracking(1.2)
                            .textCase(.uppercase)
                            .foregroundStyle(Theme.dim)
                        Image(uiImage: bill)
                            .resizable()
                            .scaledToFit()
                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        Text("This bill is saved on the piece.")
                            .font(.footnote)
                            .foregroundStyle(Theme.muted)
                    }
                }
                HStack {
                    Button("Edit") { editing = true }
                        .buttonStyle(.borderedProminent)
                    Button("Remove", role: .destructive) { confirmingDelete = true }
                }
            }
            .padding(16)
        }
        .confirmationDialog("Remove this piece from the vault?", isPresented: $confirmingDelete, titleVisibility: .visible) {
            Button("Remove", role: .destructive) {
                ledger.delete(piece)
                dismiss()
            }
        }
    }

    @ViewBuilder
    private func photo(_ piece: Piece) -> some View {
        if let image = ledger.image(named: piece.imageFilename) {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(maxWidth: .infinity)
                .frame(height: 280)
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
    }

    private func valueCard(_ piece: Piece) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Vault value")
                .font(.caption)
                .tracking(1.2)
                .textCase(.uppercase)
                .foregroundStyle(Theme.dim)
            Text(Format.money(piece.vaultValue))
                .font(Theme.serif(32))
            Text("Gold \(Format.money(piece.goldValue)) + making \(Format.money(piece.makingCharge))")
                .font(.subheadline)
                .foregroundStyle(Theme.muted)
            Text("Change since purchase \(Format.signedMoney(piece.change))")
                .foregroundStyle(piece.change < 0 ? Theme.down : Theme.gold)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Theme.panel)
                .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(Theme.line))
        )
    }

    private func facts(_ piece: Piece) -> some View {
        let rows: [(String, String)] = [
            ("Gross", Format.grams(piece.grossWeightG)),
            ("Stones", Format.grams(piece.stoneWeightG)),
            ("Net gold", Format.grams(piece.netWeightG)),
            ("Purity", "\(piece.karat)K"),
            ("Wastage", Format.percent(piece.wastagePercent)),
            ("Hallmark", piece.hallmark.isEmpty ? "None recorded" : piece.hallmark),
            ("Acquired", Format.day(piece.acquiredOn)),
            ("Paid", Format.money(piece.purchasePrice)),
            ("Storage", piece.storage),
        ]
        return LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], alignment: .leading, spacing: 14) {
            ForEach(rows, id: \.0) { row in
                VStack(alignment: .leading, spacing: 3) {
                    Text(row.0)
                        .font(.caption2)
                        .tracking(1)
                        .textCase(.uppercase)
                        .foregroundStyle(Theme.dim)
                    Text(row.1)
                        .foregroundStyle(Theme.ink)
                }
            }
        }
    }
}
