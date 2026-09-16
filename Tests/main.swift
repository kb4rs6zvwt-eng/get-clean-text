import AppKit
import Carbon

// A standalone runner keeps verification available with Command Line Tools alone.
struct TestFailure: Error, CustomStringConvertible { let description: String }
var failures = 0
var testCount = 0

func expect(_ condition: @autoclosure () -> Bool, _ message: String = "Assertion failed",
            line: Int = #line) throws {
    if !condition() { throw TestFailure(description: "line \(line): \(message)") }
}

func test(_ name: String, _ body: () throws -> Void) {
    testCount += 1
    do { try body(); print("PASS \(name)") }
    catch { failures += 1; print("FAIL \(name): \(error)") }
}

func withPasteboard(_ body: (NSPasteboard) throws -> Void) rethrows {
    let pasteboard = NSPasteboard.withUniqueName()
    defer { pasteboard.releaseGlobally() }
    try body(pasteboard)
}

func richText(_ text: String) throws -> Data {
    let attributed = NSAttributedString(string: text, attributes: [
        .font: NSFont.boldSystemFont(ofSize: 24), .foregroundColor: NSColor.red,
        .underlineStyle: NSUnderlineStyle.single.rawValue
    ])
    return try attributed.data(from: NSRange(location: 0, length: attributed.length),
                               documentAttributes: [.documentType: NSAttributedString.DocumentType.rtf])
}

_ = NSApplication.shared

test("Rich clipboard becomes only plain text, preserving Unicode and whitespace") {
    try withPasteboard { board in
        let text = "  Café 👩🏽‍💻\t東京\nDeuxième ligne\nhttps://example.com  \n"
        let item = NSPasteboardItem()
        item.setString(text, forType: .string)
        item.setString("<b>Café</b>", forType: .html)
        item.setData(try richText(text), forType: .rtf)
        try expect(board.writeObjects([item]), "Cannot access test pasteboard")
        try expect(ClipboardCleaner.clean(board) == .cleaned)
        try expect(board.string(forType: .string) == text)
        try expect(board.pasteboardItems?.count == 1)
        try expect(board.pasteboardItems?.first?.types == [.string])
    }
}

test("Plain text is idempotent") {
    try withPasteboard { board in
        board.setString("Déjà brut\n", forType: .string)
        let count = board.changeCount
        try expect(ClipboardCleaner.clean(board) == .alreadyPlain)
        try expect(board.changeCount == count)
    }
}

test("RTF-only text can be converted") {
    try withPasteboard { board in
        board.setData(try richText("Texte riche, été 🎉\n"), forType: .rtf)
        try expect(ClipboardCleaner.clean(board) == .cleaned)
        try expect(board.string(forType: .string) == "Texte riche, été 🎉\n")
    }
}

test("Empty clipboard is untouched") {
    try withPasteboard { board in
        let count = board.changeCount
        try expect(ClipboardCleaner.clean(board) == .noText)
        try expect(board.changeCount == count)
    }
}

test("Image-only clipboard is untouched") {
    try withPasteboard { board in
        let bytes = Data([0x89, 0x50, 0x4e, 0x47])
        board.setData(bytes, forType: .png)
        let count = board.changeCount
        try expect(ClipboardCleaner.clean(board) == .noText)
        try expect(board.changeCount == count)
        try expect(board.data(forType: .png) == bytes)
    }
}

test("Finder file is kept even when it advertises a name") {
    try withPasteboard { board in
        let item = NSPasteboardItem()
        item.setString("file:///tmp/example.txt", forType: .fileURL)
        item.setString("example.txt", forType: .string)
        board.writeObjects([item])
        let count = board.changeCount
        try expect(ClipboardCleaner.clean(board) == .noText)
        try expect(board.changeCount == count)
        try expect(board.string(forType: .fileURL) == "file:///tmp/example.txt")
    }
}

test("Multiple text items preserve order") {
    try withPasteboard { board in
        let items = ["Premier", "Deuxième", "Troisième"].map { text in
            let item = NSPasteboardItem()
            item.setString(text, forType: .string)
            return item
        }
        board.writeObjects(items)
        try expect(ClipboardCleaner.clean(board) == .cleaned)
        try expect(board.string(forType: .string) == "Premier\nDeuxième\nTroisième")
    }
}

test("Mixed text and image items stay intact") {
    try withPasteboard { board in
        let text = NSPasteboardItem()
        text.setString("Légende", forType: .string)
        let image = NSPasteboardItem()
        image.setData(Data([1, 2, 3]), forType: .png)
        board.writeObjects([text, image])
        let count = board.changeCount
        try expect(ClipboardCleaner.clean(board) == .noText)
        try expect(board.changeCount == count)
        try expect(board.pasteboardItems?.count == 2)
    }
}

test("Malformed RTF and unsupported HTML-only are preserved") {
    try withPasteboard { board in
        let item = NSPasteboardItem()
        item.setData(Data([0, 1, 2]), forType: .rtf)
        item.setString("<b>Texte</b>", forType: .html)
        board.writeObjects([item])
        let count = board.changeCount
        try expect(ClipboardCleaner.clean(board) == .noText)
        try expect(board.changeCount == count)
    }
}

test("Default shortcut is Shift Command K") {
    try expect(Shortcut.standard.keyCode == UInt32(kVK_ANSI_K))
    try expect(Shortcut.standard.modifiers == UInt32(cmdKey | shiftKey))
    try expect(Shortcut.standard.isValid)
}

test("Unsafe and invalid key combinations are rejected") {
    for shortcut in [Shortcut(keyCode: 0, modifiers: 0),
                     Shortcut(keyCode: 0, modifiers: UInt32(shiftKey)),
                     Shortcut(keyCode: 55, modifiers: UInt32(cmdKey)),
                     Shortcut(keyCode: 53, modifiers: UInt32(cmdKey)),
                     Shortcut(keyCode: 999, modifiers: UInt32(cmdKey)),
                     Shortcut(keyCode: 0, modifiers: UInt32.max)] {
        try expect(!shortcut.isValid)
    }
}

test("Custom shortcut persists and corrupt preferences fall back") {
    let name = "TexteBrutTests.\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: name)!
    defer { defaults.removePersistentDomain(forName: name) }
    let custom = Shortcut(keyCode: 40, modifiers: UInt32(controlKey | optionKey))
    custom.save(to: defaults)
    try expect(Shortcut.load(from: defaults) == custom)
    defaults.set(Data("invalid".utf8), forKey: Shortcut.defaultsKey)
    try expect(Shortcut.load(from: defaults) == .standard)
    Shortcut(keyCode: 888, modifiers: 0).save(to: defaults)
    try expect(Shortcut.load(from: defaults) == .standard)
}

test("Conflicting registration fails without losing the previous shortcut") {
    let first = try GlobalHotKey()
    let second = try GlobalHotKey()
    let a = Shortcut(keyCode: UInt32(kVK_F18), modifiers: UInt32(cmdKey | optionKey | controlKey))
    let b = Shortcut(keyCode: UInt32(kVK_F19), modifiers: UInt32(cmdKey | optionKey | controlKey))
    try first.register(a)
    try second.register(b)
    var conflict = false
    do { try second.register(a) } catch { conflict = true }
    try expect(conflict)
    let third = try GlobalHotKey()
    conflict = false
    do { try third.register(b) } catch { conflict = true }
    try expect(conflict, "Previous shortcut should still be registered")
    second.suspend()
    try third.register(b)
    first.suspend()
    try second.register(a)
}

print("\(testCount - failures)/\(testCount) tests passed")
exit(failures == 0 ? 0 : 1)
