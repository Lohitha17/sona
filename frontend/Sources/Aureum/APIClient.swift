import Foundation
import FoundationNetworking
import Hummingbird

enum APIError: Error {
    case unreachable(String)
    case badStatus(Int, String)
    case decode(String)
}

struct ProxyResult: Sendable {
    var status: Int
    var data: Data
    var contentType: String
}

struct APIClient: Sendable {
    let base: URL

    func summary(q: String, category: String, karat: String) async throws -> Summary {
        try await get("/api/summary", query: ["q": q, "category": category, "karat": karat])
    }

    func piece(_ id: String) async throws -> PieceEnvelope {
        try await get("/api/pieces/\(id)")
    }

    func settings() async throws -> Settings {
        try await get("/api/settings")
    }

    func meta() async throws -> Meta {
        try await get("/api/meta")
    }

    func forward(_ request: Request, path: String) async throws -> ProxyResult {
        let target = try url(path)
        var incoming = request
        let body = try await incoming.collectBody(upTo: 12 * 1024 * 1024)
        var urlRequest = URLRequest(url: target)
        urlRequest.httpMethod = request.method.rawValue
        if let type = request.headers[.contentType] {
            urlRequest.setValue(type, forHTTPHeaderField: "Content-Type")
        }
        if body.readableBytes > 0 {
            var copy = body
            if let bytes = copy.readBytes(length: copy.readableBytes) {
                urlRequest.httpBody = Data(bytes)
            }
        }
        return try await perform(urlRequest)
    }

    func fetchData(_ path: String) async throws -> ProxyResult {
        var urlRequest = URLRequest(url: try url(path))
        urlRequest.httpMethod = "GET"
        return try await perform(urlRequest)
    }

    func errorMessage(_ data: Data) -> String {
        if let body = try? JSONDecoder().decode(ErrorBody.self, from: data),
            let detail = body.detail,
            !detail.isEmpty
        {
            return detail
        }
        return "The ledger could not save that."
    }

    func decodePiece(_ data: Data) -> Piece? {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return try? decoder.decode(Piece.self, from: data)
    }

    private func get<T: Decodable>(_ path: String, query: [String: String] = [:]) async throws -> T {
        var urlRequest = URLRequest(url: try url(path, query: query))
        urlRequest.httpMethod = "GET"
        let result = try await perform(urlRequest)
        return try decode(T.self, from: result)
    }

    private func perform(_ request: URLRequest) async throws -> ProxyResult {
        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch {
            throw APIError.unreachable("The Python ledger is not running.")
        }
        guard let http = response as? HTTPURLResponse else {
            throw APIError.unreachable("The Python ledger returned an unexpected response.")
        }
        let type = http.value(forHTTPHeaderField: "Content-Type") ?? "application/octet-stream"
        return ProxyResult(status: http.statusCode, data: data, contentType: type)
    }

    private func decode<T: Decodable>(_ type: T.Type, from result: ProxyResult) throws -> T {
        if !(200..<300).contains(result.status) {
            throw APIError.badStatus(result.status, errorMessage(result.data))
        }
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        do {
            return try decoder.decode(T.self, from: result.data)
        } catch {
            let snippet = String(data: result.data, encoding: .utf8) ?? ""
            throw APIError.decode(String(snippet.prefix(400)))
        }
    }

    private func url(_ path: String, query: [String: String] = [:]) throws -> URL {
        guard var components = URLComponents(url: base, resolvingAgainstBaseURL: false) else {
            throw APIError.unreachable("The ledger address is not a valid URL.")
        }
        components.path = path
        let items = query.compactMap { key, value -> URLQueryItem? in
            value.isEmpty ? nil : URLQueryItem(name: key, value: value)
        }
        if !items.isEmpty {
            components.queryItems = items
        }
        guard let url = components.url else {
            throw APIError.unreachable("The ledger address is not a valid URL.")
        }
        return url
    }
}

enum Query {
    static func one(_ request: Request, _ key: String) -> String {
        request.uri.queryParameters[key[...]].map { String($0) } ?? ""
    }
}

func safePieceID(_ id: String) -> Bool {
    id.range(of: #"^[A-Za-z0-9-]{8,80}$"#, options: .regularExpression) != nil
}
