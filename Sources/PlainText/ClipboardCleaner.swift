import AppKit

/// Reads only when explicitly invoked. Never stores clipboard contents on disk.
enum ClipboardCleaner {
    enum Result: Equatable {
        case cleaned, alreadyPlain, noText, changedDuringRead, writeFailed

        var message: String {
            switch self {
            case .cleaned: return "Texte brut prêt à coller"
            case .alreadyPlain: return "Le texte est déjà sans mise en forme"
            case .noText: return "Aucun texte à nettoyer — presse-papiers conservé"
            case .changedDuringRead: return "Le presse-papiers a changé. Réessayez."
            case .writeFailed: return "Impossible de modifier le presse-papiers"
            }
        }
    }

    static func clean(_ pasteboard: NSPasteboard = .general) -> Result {
        let originalChangeCount = pasteboard.changeCount
        guard let items = pasteboard.pasteboardItems, !items.isEmpty else { return .noText }
        var strings: [String] = []
        for item in items {
            // Finder can expose a file name as text. Keep the actual copied file intact.
            guard !item.types.contains(.fileURL), let string = text(from: item) else { return .noText }
            strings.append(string)
        }
        guard pasteboard.changeCount == originalChangeCount else { return .changedDuringRead }
        if items.count == 1, items[0].types.allSatisfy({ $0 == .string }) { return .alreadyPlain }

        // Prepare the complete replacement before clearing any original content.
        let replacement = NSPasteboardItem()
        guard replacement.setString(strings.joined(separator: "\n"), forType: .string) else { return .writeFailed }
        // Keep a short-lived in-memory snapshot so a failed write can be rolled back.
        let snapshots = items.map { item -> NSPasteboardItem in
            let snapshot = NSPasteboardItem()
            for type in item.types {
                if let data = item.data(forType: type) { snapshot.setData(data, forType: type) }
            }
            return snapshot
        }
        guard pasteboard.changeCount == originalChangeCount else { return .changedDuringRead }
        let clearedChangeCount = pasteboard.clearContents()
        guard pasteboard.writeObjects([replacement]) else {
            if pasteboard.changeCount == clearedChangeCount { _ = pasteboard.writeObjects(snapshots) }
            return .writeFailed
        }
        return .cleaned
    }

    private static func text(from item: NSPasteboardItem) -> String? {
        if let plain = item.string(forType: .string) { return plain }
        for (type, format) in [(NSPasteboard.PasteboardType.rtf, NSAttributedString.DocumentType.rtf),
                               (.rtfd, .rtfd)] {
            if let data = item.data(forType: type),
               let rich = try? NSAttributedString(data: data, options: [.documentType: format], documentAttributes: nil) {
                // Embedded rich-text attachments have no plain-text representation.
                let string = rich.string.replacingOccurrences(of: "\u{FFFC}", with: "")
                if string.isEmpty && !rich.string.isEmpty { return nil }
                return string
            }
        }
        return nil
    }
}
