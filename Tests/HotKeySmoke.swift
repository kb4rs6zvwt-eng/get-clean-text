import AppKit

// Optional end-to-end check: run, then press ⇧⌘K within 30 seconds.
// Holds the old clipboard in memory and restores it if the test still owns it.
let board = NSPasteboard.general
let originalItems = (board.pasteboardItems ?? []).map { item -> NSPasteboardItem in
    let copy = NSPasteboardItem()
    for type in item.types {
        if let data = item.data(forType: type) { copy.setData(data, forType: type) }
    }
    return copy
}
let sample = "Vérification Texte brut · éàç 👋\nDeuxième ligne\tfin"
let testItem = NSPasteboardItem()
testItem.setString(sample, forType: .string)
testItem.setString("<strong>Vérification Texte brut</strong>", forType: .html)
board.clearContents()
guard board.writeObjects([testItem]) else { fatalError("Cannot initialize clipboard test") }
let initialCount = board.changeCount
print("READY: press Shift Command K now")
fflush(stdout)
let deadline = Date().addingTimeInterval(30)
while board.changeCount == initialCount && Date() < deadline {
    Thread.sleep(forTimeInterval: 0.1)
}
let success = board.string(forType: .string) == sample && board.pasteboardItems?.first?.types == [.string]
if board.string(forType: .string) == sample {
    board.clearContents()
    if !originalItems.isEmpty { _ = board.writeObjects(originalItems) }
    print("Original clipboard restored")
} else {
    print("Clipboard changed externally; not overwritten")
}
print(success ? "PASS: global shortcut removed formatting and preserved exact text" : "FAIL: shortcut did not produce expected plain text")
exit(success ? 0 : 1)
