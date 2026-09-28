import Foundation
import Hummingbird

enum Esc {
    static func text(_ value: String) -> String {
        value
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
    }

    static func attr(_ value: String) -> String {
        text(value)
            .replacingOccurrences(of: "\"", with: "&quot;")
            .replacingOccurrences(of: "'", with: "&#39;")
    }

    static func lines(_ value: String) -> String {
        value.split(separator: "\n", omittingEmptySubsequences: false)
            .map { text(String($0)) }
            .joined(separator: "<br>")
    }
}

enum Link {
    static func vault(category: String = "", q: String = "", karat: Int = 0) -> String {
        var parts: [String] = []
        if !category.isEmpty {
            parts.append("category=\(encode(category))")
        }
        if karat > 0 {
            parts.append("karat=\(karat)")
        }
        if !q.isEmpty {
            parts.append("q=\(encode(q))")
        }
        if parts.isEmpty { return "/" }
        return "/?" + parts.joined(separator: "&")
    }

    static func encode(_ value: String) -> String {
        var allowed = CharacterSet.urlQueryAllowed
        allowed.remove(charactersIn: "&+=?#")
        return value.addingPercentEncoding(withAllowedCharacters: allowed) ?? value
    }
}

struct HTML: ResponseGenerator {
    let html: String

    func response(from request: Request, context: some RequestContext) throws -> Response {
        var headers = HTTPFields()
        headers[.contentType] = "text/html; charset=utf-8"
        headers[.cacheControl] = "no-store"
        return Response(status: .ok, headers: headers, body: .init(byteBuffer: ByteBuffer(string: html)))
    }
}

enum Page: ResponseGenerator {
    case html(String)
    case redirect(String)
    case bytes(status: Int, type: String, data: Data, cache: String)

    func response(from request: Request, context: some RequestContext) throws -> Response {
        switch self {
        case .html(let markup):
            return try HTML(html: markup).response(from: request, context: context)
        case .redirect(let location):
            var headers = HTTPFields()
            headers[.location] = location
            headers[.cacheControl] = "no-store"
            return Response(status: .seeOther, headers: headers, body: .init(byteBuffer: ByteBuffer(string: "")))
        case .bytes(let status, let type, let data, let cache):
            var headers = HTTPFields()
            headers[.contentType] = type
            headers[.cacheControl] = cache
            var buffer = ByteBuffer()
            buffer.writeBytes(data)
            let code = HTTPResponse.Status(code: status, reasonPhrase: status == 200 ? "OK" : "Error")
            return Response(status: code, headers: headers, body: .init(byteBuffer: buffer))
        }
    }
}

enum Shell {
    static func document(title: String, active: String, body: String) -> String {
        """
        <!DOCTYPE html>
        <html lang="en">
        <head>
          <meta charset="utf-8">
          <meta name="viewport" content="width=device-width, initial-scale=1">
          <meta name="robots" content="noindex">
          <title>\(Esc.text(title))</title>
          <link rel="preconnect" href="https://fonts.googleapis.com">
          <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
          <link href="https://fonts.googleapis.com/css2?family=Fraunces:opsz,wght@9..144,500;9..144,620&family=Outfit:wght@360;480;560&display=swap" rel="stylesheet">
          <style>\(css)</style>
        </head>
        <body>
          <div class="shell">
            <header class="rail">
              <a class="brand" href="/">
                <span class="mark" aria-hidden="true"></span>
                <span>Aureum</span>
              </a>
              <nav>
                <a href="/" class="\(active == "vault" ? "active" : "")">Vault</a>
                <a href="/new" class="\(active == "add" ? "active" : "")">Add piece</a>
              </nav>
              <p class="aside-note">A count of weight, purity, and what the pieces are worth.</p>
            </header>
            <main>\(body)</main>
          </div>
        </body>
        </html>
        """
    }

    static let css = """
    :root {
      --bg: #110e0b;
      --bg-2: #1b1612;
      --panel: #241c16;
      --panel-2: #2c241c;
      --line: rgba(231, 201, 138, 0.22);
      --gold: #e7c98a;
      --gold-2: #f6e7c1;
      --ink: #f6f1e8;
      --muted: #b7ab9d;
      --dim: #8c8174;
      --down: #e3a090;
      --up: #d9c08a;
      --shadow: 0 24px 60px rgba(0, 0, 0, 0.35);
      --serif: "Fraunces", "Iowan Old Style", Palatino, Georgia, serif;
      --sans: "Outfit", "Avenir Next", "Segoe UI", sans-serif;
    }
    * { box-sizing: border-box; }
    html, body { margin: 0; padding: 0; }
    body {
      min-height: 100vh;
      color: var(--ink);
      font-family: var(--sans);
      background:
        radial-gradient(900px 420px at 100% -10%, rgba(231, 201, 138, 0.16), transparent 55%),
        radial-gradient(700px 380px at -10% 20%, rgba(120, 72, 32, 0.28), transparent 50%),
        var(--bg);
    }
    a { color: inherit; }
    .shell {
      display: grid;
      grid-template-columns: 240px 1fr;
      min-height: 100vh;
    }
    .rail {
      position: sticky;
      top: 0;
      height: 100vh;
      padding: 28px 22px;
      border-right: 1px solid var(--line);
      background: rgba(17, 14, 11, 0.88);
      display: flex;
      flex-direction: column;
      gap: 28px;
    }
    .brand {
      display: flex;
      align-items: center;
      gap: 12px;
      text-decoration: none;
      letter-spacing: 0.22em;
      text-transform: uppercase;
      font-size: 13px;
      font-weight: 560;
    }
    .mark {
      width: 18px;
      height: 18px;
      border-radius: 50%;
      border: 1.5px solid var(--gold);
      box-shadow: inset 0 0 0 4px rgba(231, 201, 138, 0.18);
    }
    nav { display: flex; flex-direction: column; gap: 6px; }
    nav a {
      text-decoration: none;
      color: var(--muted);
      padding: 10px 12px;
      border-radius: 999px;
      font-size: 15px;
    }
    nav a.active, nav a:hover { color: var(--ink); background: rgba(231, 201, 138, 0.1); }
    .aside-note { margin-top: auto; color: var(--dim); font-size: 13px; line-height: 1.5; }
    main { padding: 32px 36px 72px; max-width: 1180px; }
    .top {
      display: flex;
      justify-content: space-between;
      gap: 18px;
      align-items: flex-end;
      margin-bottom: 22px;
    }
    .eyebrow {
      margin: 0 0 6px;
      color: var(--gold);
      letter-spacing: 0.16em;
      text-transform: uppercase;
      font-size: 12px;
    }
    h1 {
      font-family: var(--serif);
      font-weight: 500;
      font-size: clamp(36px, 4vw, 56px);
      line-height: 1.02;
      margin: 0;
      letter-spacing: -0.03em;
    }
    .lede { color: var(--muted); margin: 10px 0 0; max-width: 46ch; line-height: 1.5; }
    .karat-row {
      display: grid;
      grid-template-columns: repeat(3, minmax(0, 180px));
      gap: 12px;
      margin: 0 0 22px;
    }
    .karat-box { padding: 12px 14px 11px; }
    .karat-box span { color: var(--gold); }
    .karat-box strong {
      display: block;
      margin-top: 6px;
      font-family: var(--serif);
      font-size: 26px;
      font-weight: 500;
      letter-spacing: -0.03em;
    }
    .karat-box em {
      display: block;
      margin-top: 2px;
      color: var(--dim);
      font-style: normal;
      font-size: 12px;
      letter-spacing: 0.08em;
      text-transform: uppercase;
    }
    .karat-box p {
      margin: 6px 0 0;
      color: var(--muted);
      font-size: 13px;
      line-height: 1.35;
    }
    .karat-box .karat-value { color: var(--ink); margin-top: 8px; }
    .stats {
      display: grid;
      grid-template-columns: repeat(3, 1fr);
      gap: 12px;
      margin: 8px 0 14px;
    }
    .stat, .karat-box, .panel, .card, .banner, .empty, .photo-frame {
      background: linear-gradient(180deg, rgba(44, 36, 28, 0.92), rgba(28, 22, 18, 0.92));
      border: 1px solid var(--line);
      border-radius: 18px;
    }
    .stat { padding: 16px 16px 14px; }
    .stat span, .label {
      display: block;
      color: var(--dim);
      font-size: 12px;
      letter-spacing: 0.12em;
      text-transform: uppercase;
    }
    .stat strong, .money {
      display: block;
      margin-top: 8px;
      font-family: var(--serif);
      font-size: clamp(22px, 1.7vw, 30px);
      font-weight: 500;
      letter-spacing: -0.03em;
      overflow-wrap: anywhere;
    }
    .stat em { font-style: normal; color: var(--muted); font-size: 13px; }
    .substats {
      display: flex;
      flex-wrap: wrap;
      gap: 18px 28px;
      color: var(--muted);
      margin: 0 0 22px;
      font-size: 14px;
    }
    .up { color: var(--up); }
    .down { color: var(--down); }
    .toolbar { display: flex; flex-direction: column; gap: 12px; margin-bottom: 18px; }
    .search { display: flex; gap: 8px; }
    input, select, textarea {
      font: inherit;
      color: var(--ink);
      background: #16120f;
      border: 1px solid var(--line);
      border-radius: 12px;
      padding: 12px 12px;
      width: 100%;
    }
    textarea { min-height: 110px; resize: vertical; }
    input:focus, select:focus, textarea:focus { outline: 2px solid rgba(231, 201, 138, 0.55); outline-offset: 1px; }
    .search input { max-width: 420px; }
    .chips { display: flex; flex-wrap: wrap; gap: 8px; }
    .chips a, .btn {
      text-decoration: none;
      border-radius: 999px;
      padding: 8px 12px;
      border: 1px solid var(--line);
      color: var(--muted);
      background: transparent;
      font: inherit;
      cursor: pointer;
    }
    .chips a.on, .btn.primary {
      background: var(--gold);
      color: #2a2114;
      border-color: transparent;
      font-weight: 560;
    }
    .btn.quiet { color: var(--ink); }
    .btn.danger { color: var(--down); }
    .btn.primary, .btn.quiet, .btn.danger { display: inline-flex; align-items: center; justify-content: center; }
    .split { display: grid; grid-template-columns: 1.4fr 0.8fr; gap: 16px; align-items: start; }
    .grid {
      display: grid;
      grid-template-columns: repeat(auto-fill, minmax(230px, 1fr));
      gap: 14px;
    }
    .card { overflow: hidden; display: flex; flex-direction: column; text-decoration: none; min-height: 100%; }
    .card:hover { border-color: rgba(231, 201, 138, 0.55); }
    .card img, .placeholder, .hero img {
      width: 100%;
      aspect-ratio: 1;
      object-fit: cover;
      display: block;
      background: #1a140f;
    }
    .placeholder {
      display: grid;
      place-items: center;
      color: var(--gold);
      font-family: var(--serif);
      font-size: 42px;
    }
    .card .pad, .panel { padding: 14px 14px 16px; }
    .card h2, .panel h2 { font-family: var(--serif); font-size: 22px; font-weight: 500; margin: 4px 0; letter-spacing: -0.02em; }
    .meta { color: var(--muted); font-size: 14px; margin: 0; }
    .card .money { font-size: 22px; }
    .bars { display: flex; flex-direction: column; gap: 12px; }
    .bar-row { display: grid; grid-template-columns: 92px 1fr auto; gap: 10px; align-items: center; font-size: 14px; }
    .track { height: 8px; border-radius: 99px; background: rgba(255,255,255,0.06); overflow: hidden; }
    .fill { height: 100%; background: linear-gradient(90deg, #8c6a32, var(--gold)); }
    .banner {
      padding: 12px 14px;
      margin-bottom: 16px;
      color: var(--gold-2);
    }
    .empty { padding: 36px 22px; text-align: center; }
    .empty h2 { font-family: var(--serif); font-weight: 500; margin-bottom: 8px; }
    .form-grid { display: grid; grid-template-columns: 1fr 1fr; gap: 14px 16px; }
    .span-2 { grid-column: span 2; }
    label .label { margin-bottom: 6px; }
    .actions { display: flex; flex-wrap: wrap; gap: 10px; margin-top: 8px; }
    .camera { display: flex; flex-direction: column; gap: 10px; }
    .viewfinder {
      position: relative;
      width: min(100%, 520px);
      aspect-ratio: 4 / 3;
      border-radius: 16px;
      overflow: hidden;
      background: #100d0a;
      border: 1px solid var(--line);
    }
    .viewfinder video, .viewfinder img {
      width: 100%;
      height: 100%;
      object-fit: cover;
    }
    .viewfinder video:not([hidden]), .viewfinder img:not([hidden]) { display: block; }
    .viewfinder-empty {
      position: absolute;
      inset: 0;
      place-items: center;
      margin: 0;
      color: var(--dim);
    }
    .viewfinder-empty:not([hidden]) { display: grid; }
    .file-btn { position: relative; cursor: pointer; }
    .file-btn input {
      position: absolute;
      width: 1px;
      height: 1px;
      padding: 0;
      margin: -1px;
      overflow: hidden;
      clip: rect(0, 0, 0, 0);
      white-space: nowrap;
      border: 0;
    }
    .estimate {
      margin-top: 8px;
      padding: 12px 14px;
      border-radius: 14px;
      background: rgba(231, 201, 138, 0.08);
      color: var(--gold-2);
    }
    .hero { display: grid; grid-template-columns: minmax(240px, 420px) 1fr; gap: 22px; align-items: start; }
    .hero img, .hero .placeholder { border-radius: 18px; border: 1px solid var(--line); }
    dl { display: grid; grid-template-columns: 1fr 1fr; gap: 12px 18px; margin: 18px 0; }
    dt { color: var(--dim); font-size: 12px; letter-spacing: 0.12em; text-transform: uppercase; }
    dd { margin: 4px 0 0; font-size: 16px; }
    .notes { color: var(--muted); line-height: 1.55; }
    .stack { display: flex; flex-direction: column; gap: 14px; }
    .warn { color: var(--down); }
    @media (max-width: 980px) {
      .shell { grid-template-columns: 1fr; }
      .rail {
        position: sticky;
        top: 0;
        height: auto;
        z-index: 4;
        flex-direction: row;
        align-items: center;
        gap: 12px;
        padding: 12px;
        backdrop-filter: blur(16px);
      }
      nav { flex-direction: row; }
      .aside-note { display: none; }
      main { padding: 20px 16px 48px; }
      .stats, .split, .hero, .form-grid, dl { grid-template-columns: 1fr; }
      .span-2 { grid-column: auto; }
      .top { flex-direction: column; align-items: flex-start; }
      .search input { max-width: none; }
      .bar-row { grid-template-columns: 1fr; }
    }
    """
}
