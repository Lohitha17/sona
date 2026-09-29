import UIKit

@MainActor
@Observable
final class Ledger {
    private(set) var pieces: [Piece] = []
    private let fileURL: URL
    private let persists: Bool

    init(preview: Bool = false) {
        persists = !preview
        let root = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        fileURL = root.appendingPathComponent(preview ? "preview-pieces.json" : "pieces.json")
        if persists {
            load()
        }
    }

    func picture(_ data: Data?) -> UIImage? {
        guard let data else { return nil }
        return UIImage(data: data)
    }

    func jpeg(_ image: UIImage) -> Data? {
        image.sonaJPEG()
    }

    func upsert(_ piece: Piece) {
        var saved = piece
        saved.updatedAt = Date()
        if let index = pieces.firstIndex(where: { $0.id == saved.id }) {
            saved.createdAt = pieces[index].createdAt
            pieces[index] = saved
        } else {
            pieces.insert(saved, at: 0)
        }
        pieces.sort { $0.createdAt > $1.createdAt }
        save()
    }

    func delete(_ piece: Piece) {
        pieces.removeAll { $0.id == piece.id }
        save()
    }

    private func load() {
        guard let data = try? Data(contentsOf: fileURL) else { return }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        pieces = (try? decoder.decode([Piece].self, from: data)) ?? []
    }

    private func save() {
        guard persists else { return }
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard let data = try? encoder.encode(pieces) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }
}

extension UIImage {
    func sonaJPEG() -> Data? {
        let longest = max(size.width, size.height)
        let scale = longest > 2000 ? 2000 / longest : 1
        let target = CGSize(width: size.width * scale, height: size.height * scale)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let rendered = UIGraphicsImageRenderer(size: target, format: format).image { _ in
            draw(in: CGRect(origin: .zero, size: target))
        }
        return rendered.jpegData(compressionQuality: 0.82)
    }
}
