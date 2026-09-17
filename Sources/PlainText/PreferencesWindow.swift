import AppKit

final class ShortcutRecorder: NSButton {
    var onBegin: (() -> Void)?
    var onCancel: (() -> Void)?
    var onCandidate: ((Shortcut) -> Bool)?
    var isRecording = false
    var shortcut: Shortcut = .standard { didSet { updateTitle() } }
    override var acceptsFirstResponder: Bool { true }

    init() {
        super.init(frame: .zero)
        // A flexible bezel respects the 48-point height and centers the title.
        bezelStyle = .regularSquare
        font = .monospacedSystemFont(ofSize: 23, weight: .medium)
        target = self
        action = #selector(beginRecording)
        setAccessibilityLabel("Raccourci de nettoyage")
        setAccessibilityHelp("Activez ce bouton, puis tapez votre nouveau raccourci. Échap pour annuler.")
        updateTitle()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    @objc private func beginRecording() {
        guard !isRecording else { return }
        window?.makeFirstResponder(self)
        isRecording = true
        onBegin?()
        updateTitle()
    }

    func cancel() {
        guard isRecording else { return }
        isRecording = false
        updateTitle()
        onCancel?()
    }

    override func resignFirstResponder() -> Bool {
        cancel()
        return super.resignFirstResponder()
    }

    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        guard isRecording, event.type == .keyDown else { return super.performKeyEquivalent(with: event) }
        capture(event)
        return true
    }

    override func keyDown(with event: NSEvent) {
        guard isRecording else { super.keyDown(with: event); return }
        capture(event)
    }

    private func capture(_ event: NSEvent) {
        guard !event.isARepeat else { return }
        if event.keyCode == 53 { cancel(); return }
        if onCandidate?(Shortcut.from(event)) == true {
            isRecording = false
            updateTitle()
        }
    }

    private func updateTitle() {
        title = isRecording ? "Tapez le raccourci…" : shortcut.display
        setAccessibilityValue(isRecording ? "Enregistrement en cours" : shortcut.display)
    }
}

final class PreferencesWindow: NSWindowController, NSWindowDelegate {
    let recorder = ShortcutRecorder()
    var onReset: (() -> Void)?
    private let feedback = NSTextField(wrappingLabelWithString: "")
    private let status = NSTextField(wrappingLabelWithString: "")

    init(shortcut: Shortcut) {
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 480, height: 490),
            styleMask: [.titled, .closable, .miniaturizable], backing: .buffered, defer: false)
        window.title = "Get Clean Text"
        window.isReleasedWhenClosed = false
        super.init(window: window)
        window.delegate = self
        window.center()
        recorder.shortcut = shortcut
        buildContent()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    private func buildContent() {
        guard let content = window?.contentView else { return }
        let symbol = NSImageView(image: NSImage(systemSymbolName: "textformat", accessibilityDescription: nil)!)
        symbol.contentTintColor = .controlAccentColor
        symbol.symbolConfiguration = NSImage.SymbolConfiguration(pointSize: 36, weight: .medium)
        let heading = label("Get Clean Text", size: 25, weight: .semibold)
        let description = label("Copiez du texte, lancez le raccourci, puis collez.\nLes polices, couleurs et styles disparaissent.", size: 14)
        description.textColor = .secondaryLabelColor
        let shortcutHeading = label("RACCOURCI DE NETTOYAGE", size: 11, weight: .semibold)
        shortcutHeading.textColor = .secondaryLabelColor
        let help = label("Cliquez pour modifier · Échap pour annuler", size: 12)
        help.textColor = .secondaryLabelColor
        let reset = NSButton(title: "Rétablir ⇧⌘K", target: self, action: #selector(resetShortcut))
        reset.bezelStyle = .inline
        reset.font = .systemFont(ofSize: 12)
        feedback.alignment = .center
        feedback.font = .systemFont(ofSize: 12)
        feedback.textColor = .secondaryLabelColor
        feedback.stringValue = "Utilisez ⌘, ⌥ ou ⌃ avec une touche."
        let separator = NSBox()
        separator.boxType = .separator
        let privacy = label("Discret par nature", size: 13, weight: .semibold)
        let detail = label("Aucun historique, aucun envoi de données.\nLe presse-papiers est lu uniquement à votre demande.", size: 12)
        detail.textColor = .secondaryLabelColor
        status.alignment = .center
        status.font = .systemFont(ofSize: 12)
        status.textColor = .secondaryLabelColor
        status.stringValue = "Actif dans la barre des menus"

        let stack = NSStackView(views: [symbol, heading, description, shortcutHeading, recorder,
                                       help, reset, feedback, separator, privacy, detail, status])
        stack.orientation = .vertical
        stack.alignment = .centerX
        stack.spacing = 10
        stack.setCustomSpacing(7, after: symbol)
        stack.setCustomSpacing(23, after: description)
        stack.setCustomSpacing(3, after: help)
        stack.setCustomSpacing(17, after: feedback)
        stack.setCustomSpacing(16, after: separator)
        stack.setCustomSpacing(6, after: privacy)
        stack.setCustomSpacing(16, after: detail)
        stack.translatesAutoresizingMaskIntoConstraints = false
        content.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: content.topAnchor, constant: 27),
            stack.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 30),
            stack.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -30),
            symbol.heightAnchor.constraint(equalToConstant: 42),
            recorder.widthAnchor.constraint(equalToConstant: 290),
            recorder.heightAnchor.constraint(equalToConstant: 48),
            feedback.widthAnchor.constraint(equalTo: stack.widthAnchor),
            separator.widthAnchor.constraint(equalTo: stack.widthAnchor),
            status.widthAnchor.constraint(equalTo: stack.widthAnchor)
        ])
    }

    private func label(_ text: String, size: CGFloat, weight: NSFont.Weight = .regular) -> NSTextField {
        let field = NSTextField(wrappingLabelWithString: text)
        field.font = .systemFont(ofSize: size, weight: weight)
        field.alignment = .center
        return field
    }

    func setFeedback(_ message: String, error: Bool = false) {
        feedback.stringValue = message
        feedback.textColor = error ? .systemRed : .secondaryLabelColor
    }

    func setStatus(_ message: String) { status.stringValue = message }

    @objc private func resetShortcut() { recorder.cancel(); onReset?() }
    func windowWillClose(_ notification: Notification) { recorder.cancel() }
    func windowDidResignKey(_ notification: Notification) { recorder.cancel() }
}
