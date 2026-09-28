import Foundation
import Hummingbird

#if canImport(Glibc)
import Glibc
#elseif canImport(Darwin)
import Darwin
#endif

@main
enum Aureum {
    static func main() async throws {
        let env = ProcessInfo.processInfo.environment
        let apiBase = env["AUREUM_API"] ?? "http://127.0.0.1:8741"
        let port = Int(env["PORT"] ?? "43123") ?? 43123
        guard let base = URL(string: apiBase) else {
            fatalError("AUREUM_API is not a valid URL")
        }
        let api = APIClient(base: base)
        let router = Router()

        router.get("/") { request, _ -> Page in
            do {
                let summary = try await api.summary(
                    q: Query.one(request, "q"),
                    category: Query.one(request, "category")
                )
                return .html(Pages.vault(summary))
            } catch {
                return .html(Pages.failure(error))
            }
        }

        router.get("new") { _, _ -> Page in
            await formPage(api: api, piece: nil, error: nil)
        }

        router.post("pieces") { request, _ -> Page in
            await savePiece(api: api, request: request, path: "/api/pieces", piece: nil)
        }

        router.get("pieces/:id") { _, context -> Page in
            let id = try context.parameters.require("id")
            guard safePieceID(id) else {
                return .html(Pages.failureMessage("That address is not a piece.", back: "/", backLabel: "Back to the vault"))
            }
            do {
                let envelope = try await api.piece(id)
                return .html(Pages.detail(envelope.piece, settings: envelope.settings))
            } catch {
                return .html(Pages.failure(error))
            }
        }

        router.get("pieces/:id/edit") { _, context -> Page in
            let id = try context.parameters.require("id")
            guard safePieceID(id) else {
                return .html(Pages.failureMessage("That address is not a piece.", back: "/", backLabel: "Back to the vault"))
            }
            do {
                let envelope = try await api.piece(id)
                return await formPage(api: api, piece: envelope.piece, error: nil)
            } catch {
                return .html(Pages.failure(error))
            }
        }

        router.post("pieces/:id") { request, context -> Page in
            let id = try context.parameters.require("id")
            guard safePieceID(id) else {
                return .html(Pages.failureMessage("That address is not a piece.", back: "/", backLabel: "Back to the vault"))
            }
            let piece = try? await api.piece(id).piece
            return await savePiece(api: api, request: request, path: "/api/pieces/\(id)", piece: piece)
        }

        router.post("pieces/:id/photo") { request, context -> Page in
            await saveAttachment(api: api, request: request, context: context, path: "image")
        }

        router.post("pieces/:id/bill") { request, context -> Page in
            await saveAttachment(api: api, request: request, context: context, path: "bill")
        }

        router.get("bills/:id") { _, context -> Page in
            await attachment(api: api, context: context, path: "bill")
        }

        router.post("pieces/:id/delete") { request, context -> Page in
            let id = try context.parameters.require("id")
            guard safePieceID(id) else {
                return .html(Pages.failureMessage("That address is not a piece.", back: "/", backLabel: "Back to the vault"))
            }
            do {
                let result = try await api.forward(request, path: "/api/pieces/\(id)/delete")
                if (200..<300).contains(result.status) {
                    return .redirect("/")
                }
                return .html(Pages.failureMessage(api.errorMessage(result.data), back: "/pieces/\(id)", backLabel: "Back to the piece"))
            } catch {
                return .html(Pages.failure(error))
            }
        }

        router.get("media/:id") { _, context -> Page in
            let id = try context.parameters.require("id")
            guard safePieceID(id) else {
                return .bytes(status: 404, type: "text/plain", data: Data("Not found".utf8), cache: "no-store")
            }
            do {
                let result = try await api.fetchData("/api/pieces/\(id)/image")
                let type = result.contentType.split(separator: ";").first.map(String.init) ?? "application/octet-stream"
                return .bytes(status: result.status, type: type, data: result.data, cache: "public, max-age=86400")
            } catch {
                return .bytes(status: 502, type: "text/plain", data: Data("Ledger unavailable".utf8), cache: "no-store")
            }
        }

        let app = Application(
            router: router,
            configuration: .init(address: .hostname("0.0.0.0", port: port))
        )
        print("Aureum interface http://127.0.0.1:\(port)  ledger \(apiBase)")
        do {
            try await app.runService()
        } catch {
            let text = String(describing: error)
            if text.contains("Address already in use") || text.contains("errno: 98") {
                let message = """
                Port \(port) is already in use, so this copy of Aureum stopped.
                One is already open at http://127.0.0.1:\(port)
                Stop that copy before starting another, or choose a free port: PORT=43124 swift run Aureum

                """
                FileHandle.standardError.write(Data(message.utf8))
                exit(1)
            }
            throw error
        }
    }
}

private func saveAttachment(api: APIClient, request: Request, context: some RequestContext, path: String) async -> Page {
    let id: String
    do {
        id = try context.parameters.require("id")
    } catch {
        return .html(Pages.failure(error))
    }
    guard safePieceID(id) else {
        return .html(Pages.failureMessage("That address is not a piece.", back: "/", backLabel: "Back to the vault"))
    }
    do {
        let result = try await api.forward(request, path: "/api/pieces/\(id)/\(path)")
        if (200..<300).contains(result.status) {
            return .redirect("/pieces/\(id)")
        }
        return .html(Pages.failureMessage(api.errorMessage(result.data), back: "/pieces/\(id)", backLabel: "Back to the piece"))
    } catch {
        return .html(Pages.failure(error))
    }
}

private func attachment(api: APIClient, context: some RequestContext, path: String) async -> Page {
    let id: String
    do {
        id = try context.parameters.require("id")
    } catch {
        return .bytes(status: 404, type: "text/plain", data: Data("Not found".utf8), cache: "no-store")
    }
    guard safePieceID(id) else {
        return .bytes(status: 404, type: "text/plain", data: Data("Not found".utf8), cache: "no-store")
    }
    do {
        let result = try await api.fetchData("/api/pieces/\(id)/\(path)")
        let type = result.contentType.split(separator: ";").first.map(String.init) ?? "application/octet-stream"
        return .bytes(status: result.status, type: type, data: result.data, cache: "public, max-age=86400")
    } catch {
        return .bytes(status: 502, type: "text/plain", data: Data("Ledger unavailable".utf8), cache: "no-store")
    }
}

private func formPage(api: APIClient, piece: Piece?, error: String?) async -> Page {
    do {
        async let settings = api.settings()
        async let meta = api.meta()
        return .html(Pages.form(piece: piece, settings: try await settings, meta: try await meta, error: error))
    } catch {
        return .html(Pages.failure(error, back: piece == nil ? "/new" : "/pieces/\(piece!.id)/edit", backLabel: "Try again"))
    }
}

private func savePiece(api: APIClient, request: Request, path: String, piece: Piece?) async -> Page {
    let back = piece.map { "/pieces/\($0.id)/edit" } ?? "/new"
    do {
        let result = try await api.forward(request, path: path)
        if (200..<300).contains(result.status), let saved = api.decodePiece(result.data) {
            return .redirect("/pieces/\(saved.id)")
        }
        return await formPage(api: api, piece: piece, error: api.errorMessage(result.data))
    } catch {
        return .html(Pages.failure(error, back: back, backLabel: "Back to the form"))
    }
}
