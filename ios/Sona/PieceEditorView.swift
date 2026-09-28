import SwiftUI

struct PieceEditorView: View {
    @Environment(Ledger.self) private var ledger
    @Environment(\.dismiss) private var dismiss

    @State private var draft: Piece
    @State private var photograph: UIImage?
    @State private var bill: UIImage?
    @State private var photoChanged = false
    @State private var billChanged = false
    @State private var recordDate: Bool
    @State private var error: String?

    init(piece: Piece?) {
        let starting = piece ?? Piece.blank()
        _draft = State(initialValue: starting)
        _recordDate = State(initialValue: starting.acquiredOn != nil)
    }

    private var isEditing: Bool {
        ledger.pieces.contains { $0.id == draft.id }
    }

    private var canSave: Bool {
        !draft.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && draft.grossWeightG > 0
    }

    var body: some View {
        Form {
            Section {
                TextField("Temple mango necklace", text: $draft.name)
                Picker("Category", selection: $draft.category) {
                    ForEach(Piece.categories, id: \.self) { Text(Piece.label($0)).tag($0) }
                }
                Picker("Where it is kept", selection: $draft.storage) {
                    ForEach(Piece.storages, id: \.self) { Text($0).tag($0) }
                }
            }
            Section {
                numberField("Gross weight (g)", value: $draft.grossWeightG)
                numberField("Stone weight (g)", value: $draft.stoneWeightG)
                Picker("Karat", selection: $draft.karat) {
                    ForEach(Piece.karats, id: \.self) { Text("\($0)K").tag($0) }
                }
                numberField("Wastage (%)", value: $draft.wastagePercent)
                numberField("Making charge", value: $draft.makingCharge)
                numberField("Purchase price", value: $draft.purchasePrice)
            }
            Section {
                Toggle("Acquired date", isOn: $recordDate)
                if recordDate {
                    DatePicker(
                        "Acquired",
                        selection: Binding(
                            get: { draft.acquiredOn ?? Date() },
                            set: { draft.acquiredOn = $0 }
                        ),
                        displayedComponents: .date
                    )
                }
                TextField("BIS 916", text: $draft.hallmark)
                TextField("Notes", text: $draft.notes, axis: .vertical)
                    .lineLimit(3...6)
            }
            Section {
                PhotoButtons(title: "Photograph", image: photograph ?? ledger.image(named: draft.imageFilename)) { image in
                    photograph = image
                    photoChanged = true
                }
                PhotoButtons(title: "Bill", image: bill ?? ledger.image(named: draft.billFilename)) { image in
                    bill = image
                    billChanged = true
                }
            }
            Section {
                if let error {
                    Text(error).foregroundStyle(Theme.down)
                }
                Text("Net \(Format.grams(draft.netWeightG)) · vault \(Format.money(draft.vaultValue))")
                    .foregroundStyle(Theme.gold)
            }
        }
        .scrollContentBackground(.hidden)
        .background(Theme.background)
        .navigationTitle(isEditing ? "Edit piece" : "Add a piece")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button(isEditing ? "Save" : "Add") { save() }
                    .disabled(!canSave)
            }
        }
        .onChange(of: recordDate) { _, isOn in
            draft.acquiredOn = isOn ? (draft.acquiredOn ?? Date()) : nil
        }
    }

    private func numberField(_ title: String, value: Binding<Double>) -> some View {
        HStack {
            Text(title)
            Spacer()
            TextField("0", value: value, format: .number)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .frame(maxWidth: 140)
        }
    }

    private func save() {
        let name = draft.name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else {
            error = "Enter a name."
            return
        }
        guard draft.grossWeightG > 0 else {
            error = "Enter a gross weight."
            return
        }
        guard draft.stoneWeightG >= 0, draft.stoneWeightG <= draft.grossWeightG else {
            error = "Stone weight cannot be heavier than the gross weight."
            return
        }
        guard Piece.karats.contains(draft.karat) else {
            error = "Choose 18K, 22K, or 24K."
            return
        }
        draft.name = name
        draft.hallmark = draft.hallmark.trimmingCharacters(in: .whitespacesAndNewlines)
        draft.notes = draft.notes.trimmingCharacters(in: .whitespacesAndNewlines)
        if !recordDate { draft.acquiredOn = nil }
        if photoChanged, let photograph {
            draft.imageFilename = ledger.store(photograph, replacing: draft.imageFilename)
        }
        if billChanged, let bill {
            draft.billFilename = ledger.store(bill, replacing: draft.billFilename)
        }
        ledger.upsert(draft)
        dismiss()
    }
}
