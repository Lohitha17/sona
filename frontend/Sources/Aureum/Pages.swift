import Foundation

enum Pages {
    static func vault(_ summary: Summary, rateSaved: Bool) -> String {
        let settings = summary.settings
        let totals = summary.totals
        let filtered = !summary.query.isEmpty || !summary.category.isEmpty
        let title = filtered ? "Matching pieces" : "The vault"
        let lede: String
        if totals.pieces == 0 && !filtered {
            lede = "Add a photograph, a bill, a weight, and a karat."
        } else if totals.pieces == 0 {
            lede = "Nothing in the vault matches this search."
        } else {
            lede = ""
        }
        let banner = rateSaved
            ? "<p class=\"banner\">Gold rate updated. Every piece has been revalued.</p>"
            : ""
        let cards: String
        if summary.pieces.isEmpty {
            cards = """
            <section class="empty">
              <h2>\(filtered ? "No matches" : "The vault is empty")</h2>
              <p class="lede" style="margin-left:auto;margin-right:auto">\(filtered ? "Try another name, or clear the filter." : "Start with one necklace, bangle, or ring.")</p>
              <p><a class="btn primary" href="\(filtered ? "/" : "/new")">\(filtered ? "Show the whole vault" : "Add a piece")</a></p>
            </section>
            """
        } else {
            cards = "<section class=\"grid\">\(summary.pieces.map { card($0, currency: settings.currency) }.joined())</section>"
        }
        let body = """
        \(banner)
        <header class="top">
          <div>
            <p class="eyebrow">Private ledger</p>
            <h1>\(title)</h1>
            \(lede.isEmpty ? "" : "<p class=\"lede\">\(lede)</p>")
          </div>
          <a class="rate-pill" href="/rate">\(Esc.text(Format.rateLine(settings)))</a>
        </header>
        \(stats(totals, currency: settings.currency))
        \(toolbar(summary))
        <div class="split">
          <div>\(cards)</div>
          <aside class="panel">
            <p class="label">By category</p>
            <h2 style="margin-top:8px">Where the value sits</h2>
            \(bars(summary.byCategory, currency: settings.currency))
          </aside>
        </div>
        """
        return Shell.document(title: "Aureum · Vault", active: "vault", body: body)
    }

    static func detail(_ piece: Piece, settings: Settings) -> String {
        let photo = picture(piece, large: true)
        let changeClass = piece.unrealized < 0 ? "down" : "up"
        let notes = piece.notes.isEmpty
            ? ""
            : "<p class=\"notes\">\(Esc.lines(piece.notes))</p>"
        let body = """
        <p class="eyebrow">\(Esc.text(Catalogue.label(piece.category)))</p>
        <h1>\(Esc.text(piece.name))</h1>
        <p class="lede">Kept in \(Esc.text(piece.storage)). Valued at \(Esc.text(Format.rateLine(settings))).</p>
        <div class="hero" style="margin-top:22px">
          \(photo)
          <div class="stack">
            <section class="panel">
              <span class="label">Vault value</span>
              <strong class="money">\(Esc.text(Format.money(piece.estimatedValue, currency: settings.currency)))</strong>
              <p class="meta">Gold \(Esc.text(Format.money(piece.goldValue, currency: settings.currency))) + making \(Esc.text(Format.money(piece.makingCharge, currency: settings.currency)))</p>
              <p class="\(changeClass)">Change since purchase \(Esc.text(Format.signedMoney(piece.unrealized, currency: settings.currency)))</p>
            </section>
            <dl>
              <div><dt>Gross</dt><dd>\(Esc.text(Format.grams(piece.grossWeightG)))</dd></div>
              <div><dt>Stones</dt><dd>\(Esc.text(Format.grams(piece.stoneWeightG)))</dd></div>
              <div><dt>Net gold</dt><dd>\(Esc.text(Format.grams(piece.netWeightG)))</dd></div>
              <div><dt>Purity</dt><dd>\(Esc.text(Format.karat(piece.karat)))</dd></div>
              <div><dt>Wastage</dt><dd>\(Esc.text(Format.percent(piece.wastagePercent)))</dd></div>
              <div><dt>Fine gold</dt><dd>\(Esc.text(Format.grams(piece.fineWeightG)))</dd></div>
              <div><dt>Hallmark</dt><dd>\(piece.hallmark.isEmpty ? "None recorded" : Esc.text(piece.hallmark))</dd></div>
              <div><dt>Acquired</dt><dd>\(Esc.text(Format.date(piece.acquiredOn)))</dd></div>
              <div><dt>Paid</dt><dd>\(Esc.text(Format.money(piece.purchasePrice, currency: settings.currency)))</dd></div>
              <div><dt>Storage</dt><dd>\(Esc.text(piece.storage))</dd></div>
            </dl>
            \(notes)
            \(piece.hasBill ? savedThumb(src: "/bills/\(Esc.attr(piece.id))?v=\(Esc.attr(piece.updatedAt))", alt: "Bill for \(piece.name)", caption: "This bill is saved on the piece.") : "")
            <form class="panel" method="post" action="/pieces/\(Esc.attr(piece.id))/photo" enctype="multipart/form-data">
              \(camera(field: "image", label: "Photograph", openLabel: "Take a picture", shutterLabel: "Save picture", autosave: true, note: "Take a picture and it is saved on this piece immediately.", lineup: "Line up the piece, then save the picture.", ready: "Picture ready. It is saved when you save the piece."))
            </form>
            <form class="panel" method="post" action="/pieces/\(Esc.attr(piece.id))/bill" enctype="multipart/form-data">
              \(camera(field: "bill", label: "Bill", openLabel: "Take the bill", shutterLabel: "Save bill", autosave: true, note: "Take a picture of the bill and it is saved on this piece immediately.", lineup: "Line up the bill, then save it.", ready: "Bill ready. It is saved when you save the piece."))
            </form>
            \(cameraScript)
            <div class="actions">
              <a class="btn primary" href="/pieces/\(Esc.attr(piece.id))/edit">Edit</a>
              <a class="btn quiet" href="/">Back to the vault</a>
              <form method="post" action="/pieces/\(Esc.attr(piece.id))/delete" onsubmit="return confirm('Remove this piece from the vault?')">
                <button class="btn danger" type="submit">Remove</button>
              </form>
            </div>
          </div>
        </div>
        """
        return Shell.document(title: "\(piece.name) · Aureum", active: "vault", body: body)
    }

    static func form(piece: Piece?, settings: Settings, meta: Meta, error: String?) -> String {
        let editing = piece != nil
        let title = editing ? "Edit piece" : "Add a piece"
        let action = editing ? "/pieces/\(Esc.attr(piece!.id))" : "/pieces"
        let banner = error.map { "<p class=\"banner warn\">\(Esc.text($0))</p>" } ?? ""
        let currentPhoto: String
        if let piece, piece.hasImage {
            currentPhoto = """
            <div class="span-2">
              <img src="/media/\(Esc.attr(piece.id))?v=\(Esc.attr(piece.updatedAt))" alt="Current photograph of \(Esc.attr(piece.name))" style="width:180px;height:180px;object-fit:cover;border-radius:16px;border:1px solid var(--line)">
              <p class="meta">This is the photograph already saved. Take or choose another one to replace it.</p>
            </div>
            """
        } else {
            currentPhoto = ""
        }
        let currentBill: String
        if let piece, piece.hasBill {
            currentBill = savedThumb(
                src: "/bills/\(Esc.attr(piece.id))?v=\(Esc.attr(piece.updatedAt))",
                alt: "Current bill for \(piece.name)",
                caption: "This is the bill already saved. Take or choose another one to replace it."
            )
        } else {
            currentBill = ""
        }
        let categoryOptions = meta.categories.map { key in
            option(key, Catalogue.label(key), selected: piece?.category ?? "necklace")
        }.joined()
        let storageOptions = meta.storages.map { place in
            option(place, place, selected: piece?.storage ?? "Home safe")
        }.joined()
        let body = """
        \(banner)
        <p class="eyebrow">\(editing ? "Update the record" : "New record")</p>
        <h1>\(title)</h1>
        <p class="lede">Gross weight minus stones is the gold. Fine gold is that weight brought to 24K, including wastage if the invoice charged it.</p>
        <form class="panel" style="margin-top:22px" method="post" action="\(action)" enctype="multipart/form-data" data-estimate data-rate="\(settings.goldRate24K)" data-currency="\(Esc.attr(settings.currency))">
          <div class="form-grid">
            <label class="span-2"><span class="label">Name</span><input name="name" required maxlength="80" value="\(Esc.attr(piece?.name ?? ""))" placeholder="Temple mango necklace"></label>
            <label><span class="label">Category</span><select name="category">\(categoryOptions)</select></label>
            <label><span class="label">Where it is kept</span><select name="storage">\(storageOptions)</select></label>
            <label><span class="label">Gross weight (g)</span><input name="gross_weight_g" type="number" min="0.001" max="100000" step="0.001" required value="\(Esc.attr(piece.map { Format.plain($0.grossWeightG) } ?? ""))"></label>
            <label><span class="label">Stone weight (g)</span><input name="stone_weight_g" type="number" min="0" max="100000" step="0.001" value="\(Esc.attr(piece.map { Format.plain($0.stoneWeightG) } ?? "0"))"></label>
            <label><span class="label">Karat</span><input name="karat" type="number" min="1" max="24" step="0.1" required list="karats" value="\(Esc.attr(piece.map { Format.plain($0.karat) } ?? "22"))"></label>
            <label><span class="label">Wastage (%)</span><input name="wastage_percent" type="number" min="0" max="100" step="0.1" value="\(Esc.attr(piece.map { Format.plain($0.wastagePercent) } ?? "0"))"></label>
            <label><span class="label">Making charge</span><input name="making_charge" type="number" min="0" step="0.01" value="\(Esc.attr(piece.map { Format.plain($0.makingCharge) } ?? "0"))"></label>
            <label><span class="label">Purchase price</span><input name="purchase_price" type="number" min="0" step="0.01" value="\(Esc.attr(piece.map { Format.plain($0.purchasePrice) } ?? "0"))"></label>
            <label><span class="label">Acquired</span><input name="acquired_on" type="date" value="\(Esc.attr(piece?.acquiredOn ?? ""))"></label>
            <label><span class="label">Hallmark</span><input name="hallmark" maxlength="80" value="\(Esc.attr(piece?.hallmark ?? ""))" placeholder="BIS 916"></label>
            <label class="span-2"><span class="label">Notes</span><textarea name="notes" maxlength="2000">\(Esc.text(piece?.notes ?? ""))</textarea></label>
            \(currentPhoto)
            \(camera(field: "image", label: "Photograph", openLabel: "Take a picture", shutterLabel: "Use this picture", autosave: false, note: "Take a picture here, or choose one you already have. It is saved when you save the piece.", lineup: "Line up the piece, then use this picture.", ready: "Picture ready. It is saved when you save the piece."))
            \(currentBill)
            \(camera(field: "bill", label: "Bill", openLabel: "Take the bill", shutterLabel: "Use this bill", autosave: false, note: "Photograph the jeweller’s bill. It is saved when you save the piece.", lineup: "Line up the bill, then use this picture.", ready: "Bill ready. It is saved when you save the piece."))
          </div>
          <datalist id="karats">
            <option value="24"></option>
            <option value="22"></option>
            <option value="18"></option>
            <option value="14"></option>
            <option value="9"></option>
          </datalist>
          <p class="estimate" id="estimate"></p>
          <div class="actions">
            <button class="btn primary" type="submit">\(editing ? "Save changes" : "Add to the vault")</button>
            <a class="btn quiet" href="\(editing ? "/pieces/\(Esc.attr(piece!.id))" : "/")">Cancel</a>
          </div>
        </form>
        <script>
        (function () {
          const form = document.querySelector("[data-estimate]");
          const out = document.getElementById("estimate");
          if (!form || !out) return;
          const rate = Number(form.dataset.rate || "0");
          const currency = form.dataset.currency || "INR";
          const money = new Intl.NumberFormat(currency === "INR" ? "en-IN" : "en-US", {
            style: "currency",
            currency: currency,
            maximumFractionDigits: currency === "INR" ? 0 : 2
          });
          function num(name) {
            const field = form.querySelector('[name="' + name + '"]');
            const value = field ? Number(field.value) : 0;
            return Number.isFinite(value) ? value : 0;
          }
          function render() {
            const gross = num("gross_weight_g");
            const stone = num("stone_weight_g");
            const karat = num("karat");
            const wastage = num("wastage_percent");
            const making = num("making_charge");
            if (stone > gross && gross > 0) {
              out.textContent = "Stone weight is heavier than the gross weight.";
              return;
            }
            const net = Math.max(gross - stone, 0);
            const fine = net * (karat / 24) * (1 + wastage / 100);
            const vault = fine * rate + making;
            out.textContent = "Net " + net.toFixed(2) + " g · fine gold " + fine.toFixed(2) + " g · vault " + money.format(vault);
          }
          form.addEventListener("input", render);
          render();
        })();
        </script>
        \(cameraScript)
        """
        return Shell.document(title: "\(title) · Aureum", active: editing ? "vault" : "add", body: body)
    }

    static func rate(_ settings: Settings, meta: Meta, error: String?) -> String {
        let banner = error.map { "<p class=\"banner warn\">\(Esc.text($0))</p>" } ?? ""
        let options = meta.currencies.map { code in
            option(code, code, selected: settings.currency)
        }.joined()
        let body = """
        \(banner)
        <p class="eyebrow">Your price</p>
        <h1>Gold rate</h1>
        <p class="lede">Aureum does not fetch a live market price. Enter the 24K rate per gram you want the vault valued at. 22K and 18K pieces are scaled from that rate.</p>
        <form class="panel" style="margin-top:22px;max-width:520px" method="post" action="/rate">
          <div class="form-grid">
            <label><span class="label">Currency</span><select name="currency">\(options)</select></label>
            <label><span class="label">24K price per gram</span><input name="gold_rate_24k" type="number" min="0.01" step="0.01" required value="\(Esc.attr(Format.plain(settings.goldRate24K)))"></label>
          </div>
          <div class="actions">
            <button class="btn primary" type="submit">Save rate</button>
            <a class="btn quiet" href="/">Cancel</a>
          </div>
        </form>
        """
        return Shell.document(title: "Gold rate · Aureum", active: "rate", body: body)
    }

    static func failure(_ error: Error, back: String = "/", backLabel: String = "Back to the vault") -> String {
        let message: String
        let hint: String
        switch error {
        case APIError.unreachable(let text):
            message = text
            hint = "From the backend folder, run: uvicorn aureum_api.main:app --host 127.0.0.1 --port 8741"
        case APIError.badStatus(_, let text):
            message = text
            hint = ""
        case APIError.decode(let text):
            message = "The ledger replied in a shape Aureum did not understand."
            hint = text
        default:
            message = "Something went wrong while talking to the ledger."
            hint = error.localizedDescription
        }
        return failureMessage(message, hint: hint, back: back, backLabel: backLabel)
    }

    static func failureMessage(_ message: String, hint: String = "", back: String, backLabel: String) -> String {
        let extra = hint.isEmpty ? "" : "<p class=\"meta\">\(Esc.text(hint))</p>"
        let body = """
        <p class="eyebrow">Ledger</p>
        <h1>Can’t reach the books</h1>
        <section class="empty" style="text-align:left">
          <p>\(Esc.text(message))</p>
          \(extra)
          <p><a class="btn primary" href="\(Esc.attr(back))">\(Esc.text(backLabel))</a></p>
        </section>
        """
        return Shell.document(title: "Aureum", active: "vault", body: body)
    }

    private static func savedThumb(src: String, alt: String, caption: String) -> String {
        """
        <div class="span-2">
          <img src="\(Esc.attr(src))" alt="\(Esc.attr(alt))" style="width:180px;height:180px;object-fit:cover;border-radius:16px;border:1px solid var(--line)">
          <p class="meta">\(Esc.text(caption))</p>
        </div>
        """
    }

    private static func camera(
        field: String,
        label: String,
        openLabel: String,
        shutterLabel: String,
        autosave: Bool,
        note: String,
        lineup: String,
        ready: String
    ) -> String {
        """
        <div class="span-2 camera" data-camera data-autosave="\(autosave ? "1" : "0")" data-lineup="\(Esc.attr(lineup))" data-ready="\(Esc.attr(ready))" data-filename="\(Esc.attr(field)).jpg">
          <span class="label">\(Esc.text(label))</span>
          <div class="viewfinder">
            <video class="camera-live" playsinline autoplay muted hidden></video>
            <img class="camera-still" alt="\(Esc.attr(label)) just taken" hidden>
            <p class="viewfinder-empty camera-empty">The camera preview shows here.</p>
          </div>
          <div class="actions">
            <button type="button" class="btn primary camera-open">\(Esc.text(openLabel))</button>
            <button type="button" class="btn primary camera-shutter" hidden>\(Esc.text(shutterLabel))</button>
            <button type="button" class="btn quiet camera-retake" hidden>Retake</button>
            <label class="btn quiet file-btn">Choose a photo
              <input class="camera-file" name="\(Esc.attr(field))" type="file" accept="image/jpeg,image/png,image/webp,image/gif">
            </label>
          </div>
          <p class="meta camera-note">\(Esc.text(note))</p>
        </div>
        """
    }

    private static let cameraScript = """
    <script>
    (function () {
      const cameras = document.querySelectorAll("[data-camera]");
      if (!cameras.length) return;
      const streams = [];

      cameras.forEach(function (root) {
        const autosave = root.dataset.autosave === "1";
        const lineup = root.dataset.lineup || "Line up the picture, then save it.";
        const ready = root.dataset.ready || "Picture ready. It is saved when you save the piece.";
        const filename = root.dataset.filename || "piece.jpg";
        const live = root.querySelector(".camera-live");
        const still = root.querySelector(".camera-still");
        const empty = root.querySelector(".camera-empty");
        const open = root.querySelector(".camera-open");
        const shutter = root.querySelector(".camera-shutter");
        const retake = root.querySelector(".camera-retake");
        const fileInput = root.querySelector(".camera-file");
        const note = root.querySelector(".camera-note");
        const canvas = document.createElement("canvas");
        let stream = null;

        function say(text) {
          if (note) note.textContent = text;
        }

        function stop() {
          if (!stream) return;
          stream.getTracks().forEach(function (track) { track.stop(); });
          stream = null;
          if (live) live.srcObject = null;
        }
        streams.push(stop);

        function showStill(url) {
          stop();
          if (live) live.hidden = true;
          if (empty) empty.hidden = true;
          if (still) {
            still.hidden = false;
            still.src = url;
          }
          if (open) open.hidden = true;
          if (shutter) shutter.hidden = true;
          if (retake) retake.hidden = false;
        }

        async function start() {
          if (!navigator.mediaDevices || !navigator.mediaDevices.getUserMedia) {
            say("This browser cannot open the camera. Choose a photo instead.");
            return;
          }
          const attempts = [
            { video: { facingMode: { ideal: "environment" } }, audio: false },
            { video: true, audio: false }
          ];
          stream = null;
          for (let i = 0; i < attempts.length; i++) {
            try {
              stream = await navigator.mediaDevices.getUserMedia(attempts[i]);
              break;
            } catch (error) {
              stream = null;
            }
          }
          if (!stream || !live) {
            say("Allow the camera to take a picture, or choose a photo instead.");
            return;
          }
          live.hidden = false;
          live.srcObject = stream;
          if (empty) empty.hidden = true;
          if (still) still.hidden = true;
          if (open) open.hidden = true;
          if (shutter) shutter.hidden = false;
          if (retake) retake.hidden = true;
          say(lineup);
          try { await live.play(); } catch (error) {}
        }

        function capture() {
          if (!stream || !live || !live.videoWidth) {
            say("The camera is not ready yet.");
            return;
          }
          const scale = Math.min(1, 1600 / Math.max(live.videoWidth, live.videoHeight));
          canvas.width = Math.round(live.videoWidth * scale);
          canvas.height = Math.round(live.videoHeight * scale);
          const context = canvas.getContext("2d");
          if (!context) {
            say("The picture could not be saved. Try again.");
            return;
          }
          context.drawImage(live, 0, 0, canvas.width, canvas.height);
          canvas.toBlob(function (blob) {
            if (!blob || !fileInput) {
              say("The picture could not be saved. Try again.");
              return;
            }
            const picture = new File([blob], filename, { type: "image/jpeg" });
            const transfer = new DataTransfer();
            transfer.items.add(picture);
            fileInput.files = transfer.files;
            showStill(URL.createObjectURL(blob));
            if (autosave) {
              say("Saving…");
              const form = root.closest("form");
              if (form) form.submit();
              return;
            }
            say(ready);
          }, "image/jpeg", 0.92);
        }

        if (open) open.addEventListener("click", function () { start(); });
        if (shutter) shutter.addEventListener("click", capture);
        if (retake) {
          retake.addEventListener("click", function () {
            if (fileInput) fileInput.value = "";
            if (still) {
              still.hidden = true;
              still.removeAttribute("src");
            }
            start();
          });
        }
        if (fileInput) {
          fileInput.addEventListener("change", function () {
            const file = fileInput.files && fileInput.files[0];
            if (!file) return;
            showStill(URL.createObjectURL(file));
            if (autosave) {
              say("Saving…");
              const form = root.closest("form");
              if (form) form.submit();
              return;
            }
            say(ready);
          });
        }
      });

      window.addEventListener("pagehide", function () {
        streams.forEach(function (stop) { stop(); });
      });
    })();
    </script>
    """

    private static func stats(_ totals: Totals, currency: String) -> String {
        let changeClass = totals.unrealized < 0 ? "down" : "up"
        return """
        <section class="stats">
          <article class="stat"><span>Pieces</span><strong>\(totals.pieces)</strong></article>
          <article class="stat"><span>Net gold</span><strong>\(Esc.text(Format.grams(totals.netWeightG)))</strong></article>
          <article class="stat"><span>Fine gold</span><strong>\(Esc.text(Format.grams(totals.fineWeightG)))</strong><em>24K equivalent</em></article>
          <article class="stat"><span>Vault value</span><strong>\(Esc.text(Format.money(totals.estimatedValue, currency: currency)))</strong></article>
        </section>
        <p class="substats">
          <span>Paid \(Esc.text(Format.money(totals.purchasePrice, currency: currency)))</span>
          <span>Making \(Esc.text(Format.money(totals.makingCharges, currency: currency)))</span>
          <span class="\(changeClass)">Change \(Esc.text(Format.signedMoney(totals.unrealized, currency: currency)))</span>
        </p>
        """
    }

    private static func toolbar(_ summary: Summary) -> String {
        let chips = [("" , "All")] + summary.availableCategories.map { ($0, Catalogue.label($0)) }
        let links = chips.map { key, label in
            let on = key == summary.category ? " class=\"on\"" : ""
            return "<a\(on) href=\"\(Link.vault(category: key, q: summary.query))\">\(Esc.text(label))</a>"
        }.joined()
        return """
        <div class="toolbar">
          <form class="search" method="get" action="/">
            \(summary.category.isEmpty ? "" : "<input type=\"hidden\" name=\"category\" value=\"\(Esc.attr(summary.category))\">")
            <input type="search" name="q" value="\(Esc.attr(summary.query))" placeholder="Search name, hallmark, notes" aria-label="Search pieces">
            <button class="btn quiet" type="submit">Search</button>
          </form>
          <div class="chips">\(links)</div>
        </div>
        """
    }

    private static func bars(_ rows: [CategoryTotal], currency: String) -> String {
        if rows.isEmpty {
            return "<p class=\"meta\">Categories appear here once a piece is saved.</p>"
        }
        let peak = rows.map(\.estimatedValue).max() ?? 1
        return "<div class=\"bars\" style=\"margin-top:16px\">" + rows.map { row in
            let width = peak <= 0 ? 0 : Int((row.estimatedValue / peak) * 100)
            return """
            <div class="bar-row">
              <span>\(Esc.text(Catalogue.label(row.category)))</span>
              <div class="track"><div class="fill" style="width:\(width)%"></div></div>
              <span>\(Esc.text(Format.money(row.estimatedValue, currency: currency)))</span>
            </div>
            """
        }.joined() + "</div>"
    }

    private static func card(_ piece: Piece, currency: String) -> String {
        let image: String
        if piece.hasImage {
            image = "<img src=\"/media/\(Esc.attr(piece.id))?v=\(Esc.attr(piece.updatedAt))\" alt=\"\(Esc.attr(piece.name))\">"
        } else {
            let initial = piece.name.first.map { String($0) } ?? "A"
            image = "<div class=\"placeholder\" aria-hidden=\"true\">\(Esc.text(initial.uppercased()))</div>"
        }
        return """
        <a class="card" href="/pieces/\(Esc.attr(piece.id))">
          \(image)
          <div class="pad">
            <p class="label">\(Esc.text(Catalogue.label(piece.category)))</p>
            <h2>\(Esc.text(piece.name))</h2>
            <p class="meta">\(Esc.text(Format.grams(piece.netWeightG))) · \(Esc.text(Format.karat(piece.karat)))\(piece.hasBill ? " · Bill saved" : "")</p>
            <strong class="money">\(Esc.text(Format.money(piece.estimatedValue, currency: currency)))</strong>
          </div>
        </a>
        """
    }

    private static func picture(_ piece: Piece, large: Bool) -> String {
        if piece.hasImage {
            return "<img src=\"/media/\(Esc.attr(piece.id))?v=\(Esc.attr(piece.updatedAt))\" alt=\"Photograph of \(Esc.attr(piece.name))\">"
        }
        let initial = piece.name.first.map { String($0) } ?? "A"
        return "<div class=\"placeholder\">\(Esc.text(initial.uppercased()))</div>"
    }

    private static func option(_ value: String, _ label: String, selected: String) -> String {
        let mark = value == selected ? " selected" : ""
        return "<option value=\"\(Esc.attr(value))\"\(mark)>\(Esc.text(label))</option>"
    }
}
