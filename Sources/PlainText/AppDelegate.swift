import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private var statusItem: NSStatusItem!
    private var hotKey: GlobalHotKey?
    private var shortcut = Shortcut.load()
    private var preferences: PreferencesWindow?
    private var statusMenuItem: NSMenuItem!
    private var cleanMenuItem: NSMenuItem!
    private var shortcutActive = false
    private var feedbackWork: DispatchWorkItem?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Also protects direct launches of the executable against duplicate instances.
        let others = NSRunningApplication.runningApplications(withBundleIdentifier: "fr.theobellenger.TexteBrut")
        if let existing = others.first(where: { $0.processIdentifier != ProcessInfo.processInfo.processIdentifier }) {
            existing.activate(options: [])
            NSApp.terminate(nil)
            return
        }
        NSApp.setActivationPolicy(.accessory)
        createMenu()
        do {
            hotKey = try GlobalHotKey()
            hotKey?.onPress = { [weak self] in self?.cleanClipboard() }
            try hotKey?.register(shortcut)
            shortcutActive = true
        } catch {
            showPreferences(nil)
            preferences?.setFeedback(error.localizedDescription, error: true)
        }
        refreshMenu()
        let defaults = UserDefaults.standard
        if !defaults.bool(forKey: "hasLaunched") {
            defaults.set(true, forKey: "hasLaunched")
            showPreferences(nil)
        }
    }

    private func createMenu() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        updateIcon()
        let menu = NSMenu()
        menu.delegate = self
        let title = NSMenuItem(title: "Get Clean Text", action: nil, keyEquivalent: "")
        menu.addItem(title)
        statusMenuItem = NSMenuItem(title: "Prêt à nettoyer", action: nil, keyEquivalent: "")
        menu.addItem(statusMenuItem)
        menu.addItem(.separator())
        cleanMenuItem = NSMenuItem(title: "Nettoyer le presse-papiers", action: #selector(cleanClipboard), keyEquivalent: "")
        cleanMenuItem.target = self
        menu.addItem(cleanMenuItem)
        let settings = NSMenuItem(title: "Réglages…", action: #selector(showPreferences(_:)), keyEquivalent: ",")
        settings.target = self
        menu.addItem(settings)
        let about = NSMenuItem(title: "À propos de Get Clean Text…", action: #selector(showAbout(_:)), keyEquivalent: "")
        about.target = self
        menu.addItem(about)
        menu.addItem(.separator())
        let quit = NSMenuItem(title: "Quitter Get Clean Text", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        menu.addItem(quit)
        statusItem.menu = menu
    }

    @objc private func showAbout(_ sender: Any?) {
        NSApp.activate(ignoringOtherApps: true)
        NSApp.orderFrontStandardAboutPanel(options: [
            .credits: NSAttributedString(string: "Crédits : Enigami")
        ])
    }

    private func updateIcon(symbol: String = "textformat", message: String? = nil) {
        let image = NSImage(systemSymbolName: symbol, accessibilityDescription: "Get Clean Text")
        image?.isTemplate = true
        statusItem.button?.image = image
        statusItem.button?.toolTip = message ?? "Get Clean Text · \(shortcut.display)"
        statusItem.button?.setAccessibilityLabel(message ?? "Get Clean Text, nettoyer avec \(shortcut.display)")
    }

    private func refreshMenu() {
        cleanMenuItem.title = "Nettoyer le presse-papiers   \(shortcut.display)"
        statusMenuItem.title = shortcutActive ? "Prêt · \(shortcut.display)" : "Raccourci inactif · ouvrir les réglages"
        preferences?.setStatus(shortcutActive ? "Actif dans la barre des menus" : "Raccourci inactif")
        updateIcon()
    }

    func menuWillOpen(_ menu: NSMenu) {
        preferences?.recorder.cancel()
        cleanMenuItem.title = "Nettoyer le presse-papiers   \(shortcut.display)"
    }

    @objc private func cleanClipboard() {
        let result = ClipboardCleaner.clean()
        statusMenuItem.title = result.message
        preferences?.setStatus(result.message)
        let success = result == .cleaned || result == .alreadyPlain
        updateIcon(symbol: success ? "checkmark" : "exclamationmark", message: result.message)
        feedbackWork?.cancel()
        let work = DispatchWorkItem { [weak self] in self?.refreshMenu() }
        feedbackWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5, execute: work)
    }

    @objc private func showPreferences(_ sender: Any?) {
        if preferences == nil {
            let controller = PreferencesWindow(shortcut: shortcut)
            controller.recorder.onBegin = { [weak self] in
                self?.hotKey?.suspend()
                self?.shortcutActive = false
                self?.refreshMenu()
                self?.preferences?.setFeedback("Tapez votre combinaison. Échap pour annuler.")
            }
            controller.recorder.onCancel = { [weak self] in self?.restoreShortcut() }
            controller.recorder.onCandidate = { [weak self] candidate in self?.setShortcut(candidate) ?? false }
            controller.onReset = { [weak self] in
                guard let self else { return }
                if self.shortcut == .standard, self.shortcutActive {
                    self.preferences?.setFeedback("Le raccourci par défaut est déjà actif.")
                } else { _ = self.setShortcut(.standard) }
            }
            preferences = controller
        }
        NSApp.activate(ignoringOtherApps: true)
        preferences?.showWindow(nil)
        preferences?.window?.makeKeyAndOrderFront(nil)
    }

    private func setShortcut(_ candidate: Shortcut) -> Bool {
        guard candidate.isValid else {
            preferences?.setFeedback("Ajoutez ⌘, ⌥ ou ⌃ à votre touche.", error: true)
            return false
        }
        do {
            if hotKey == nil {
                hotKey = try GlobalHotKey()
                hotKey?.onPress = { [weak self] in self?.cleanClipboard() }
            }
            try hotKey?.register(candidate)
            shortcut = candidate
            shortcut.save()
            shortcutActive = true
            preferences?.recorder.shortcut = candidate
            preferences?.setFeedback("Raccourci enregistré")
            refreshMenu()
            return true
        } catch {
            preferences?.setFeedback(error.localizedDescription, error: true)
            return false
        }
    }

    private func restoreShortcut() {
        _ = setShortcut(shortcut)
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        showPreferences(nil)
        return true
    }

    func applicationWillTerminate(_ notification: Notification) {
        feedbackWork?.cancel()
        hotKey?.suspend()
    }
}
