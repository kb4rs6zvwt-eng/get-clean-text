import AppKit
import Carbon

struct Shortcut: Codable, Equatable {
    let keyCode: UInt32
    let modifiers: UInt32
    static let standard = Shortcut(keyCode: UInt32(kVK_ANSI_K), modifiers: UInt32(cmdKey | shiftKey))
    static let defaultsKey = "cleaningShortcut"
    static let allowedModifiers = UInt32(cmdKey | shiftKey | optionKey | controlKey)

    var isValid: Bool {
        keyCode < 128 && ![UInt32(kVK_Escape), 54, 55, 56, 57, 58, 59, 60, 61, 62, 63].contains(keyCode)
            && modifiers & ~Self.allowedModifiers == 0
            && modifiers & UInt32(cmdKey | optionKey | controlKey) != 0
    }

    static func from(_ event: NSEvent) -> Shortcut {
        var flags: UInt32 = 0
        if event.modifierFlags.contains(.command) { flags |= UInt32(cmdKey) }
        if event.modifierFlags.contains(.shift) { flags |= UInt32(shiftKey) }
        if event.modifierFlags.contains(.option) { flags |= UInt32(optionKey) }
        if event.modifierFlags.contains(.control) { flags |= UInt32(controlKey) }
        return Shortcut(keyCode: UInt32(event.keyCode), modifiers: flags)
    }

    static func load(from defaults: UserDefaults = .standard) -> Shortcut {
        guard let data = defaults.data(forKey: defaultsKey),
              let value = try? JSONDecoder().decode(Self.self, from: data), value.isValid else { return .standard }
        return value
    }

    func save(to defaults: UserDefaults = .standard) {
        guard let data = try? JSONEncoder().encode(self) else { return }
        defaults.set(data, forKey: Self.defaultsKey)
    }

    var display: String {
        var result = ""
        if modifiers & UInt32(controlKey) != 0 { result += "⌃" }
        if modifiers & UInt32(optionKey) != 0 { result += "⌥" }
        if modifiers & UInt32(shiftKey) != 0 { result += "⇧" }
        if modifiers & UInt32(cmdKey) != 0 { result += "⌘" }
        return result + keyLabel
    }

    private var keyLabel: String {
        let special: [UInt32: String] = [36: "↩", 48: "⇥", 49: "Espace", 51: "⌫", 76: "⌅", 117: "⌦",
            123: "←", 124: "→", 125: "↓", 126: "↑", 122: "F1", 120: "F2", 99: "F3", 118: "F4",
            96: "F5", 97: "F6", 98: "F7", 100: "F8", 101: "F9", 109: "F10", 103: "F11", 111: "F12"]
        if let value = special[keyCode] { return value }
        let source = TISCopyCurrentKeyboardLayoutInputSource().takeRetainedValue()
        if let pointer = TISGetInputSourceProperty(source, kTISPropertyUnicodeKeyLayoutData) {
            let data = Unmanaged<CFData>.fromOpaque(pointer).takeUnretainedValue()
            let layout = UnsafeRawPointer(CFDataGetBytePtr(data)).assumingMemoryBound(to: UCKeyboardLayout.self)
            var deadKey: UInt32 = 0
            var length = 0
            var characters = [UniChar](repeating: 0, count: 8)
            let status = UCKeyTranslate(layout, UInt16(keyCode), UInt16(kUCKeyActionDisplay), 0,
                UInt32(LMGetKbdType()), OptionBits(kUCKeyTranslateNoDeadKeysBit), &deadKey,
                characters.count, &length, &characters)
            if status == noErr, length > 0 {
                return String(utf16CodeUnits: characters, count: length).uppercased()
            }
        }
        return "Touche \(keyCode)"
    }
}

final class GlobalHotKey {
    private var hotKey: EventHotKeyRef?
    private var handler: EventHandlerRef?
    var onPress: (() -> Void)?
    private static let signature: OSType = 0x54584252 // TXBR

    init() throws {
        var type = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        let status = InstallEventHandler(GetApplicationEventTarget(), { _, event, context in
            guard let event, let context else { return OSStatus(eventNotHandledErr) }
            var identifier = EventHotKeyID()
            let status = GetEventParameter(event, EventParamName(kEventParamDirectObject),
                EventParamType(typeEventHotKeyID), nil, MemoryLayout<EventHotKeyID>.size, nil, &identifier)
            guard status == noErr, identifier.signature == GlobalHotKey.signature else {
                return OSStatus(eventNotHandledErr)
            }
            Unmanaged<GlobalHotKey>.fromOpaque(context).takeUnretainedValue().onPress?()
            return noErr
        }, 1, &type, Unmanaged.passUnretained(self).toOpaque(), &handler)
        guard status == noErr else { throw Failure(status: status) }
    }

    func register(_ shortcut: Shortcut) throws {
        guard shortcut.isValid else { throw Failure(status: OSStatus(paramErr)) }
        var candidate: EventHotKeyRef?
        let status = RegisterEventHotKey(shortcut.keyCode, shortcut.modifiers,
            EventHotKeyID(signature: Self.signature, id: 1), GetApplicationEventTarget(), OptionBits(kEventHotKeyExclusive), &candidate)
        guard status == noErr else { throw Failure(status: status) }
        suspend()
        hotKey = candidate
    }

    func suspend() {
        if let hotKey { UnregisterEventHotKey(hotKey) }
        hotKey = nil
    }

    deinit {
        suspend()
        if let handler { RemoveEventHandler(handler) }
    }

    struct Failure: LocalizedError {
        let status: OSStatus
        var errorDescription: String? {
            "Ce raccourci est indisponible (code \(status)). Choisissez une autre combinaison."
        }
    }
}
