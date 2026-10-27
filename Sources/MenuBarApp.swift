import AppKit

// This is the UI: one status item, one native menu, and one timer.
final class MenuBarApp: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private var statusItem: NSStatusItem!
    private let menu = NSMenu()
    private var timer: Timer?
    private var menuIsOpen = false

    private let ramRow = NSMenuItem()
    private let cacheRow = NSMenuItem()
    private let swapRow = NSMenuItem()
    private let pressureRow = NSMenuItem()
    private let appRows = (0..<3).map { _ in NSMenuItem() }

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.button?.font = .monospacedDigitSystemFont(ofSize: 12, weight: .regular)
        statusItem.menu = menu
        menu.delegate = self
        menu.autoenablesItems = false
        menu.appearance = NSAppearance(named: .darkAqua)

        for row in [ramRow, cacheRow, swapRow, pressureRow] {
            addReadOnly(row)
        }
        menu.addItem(.separator())
        let heading = NSMenuItem(title: "Top apps · includes bundled helpers", action: nil, keyEquivalent: "")
        addReadOnly(heading)
        for row in appRows { addReadOnly(row) }
        menu.addItem(.separator())
        let quit = NSMenuItem(title: "Quit RAM Monitor", action: #selector(quitApp), keyEquivalent: "q")
        quit.target = self
        menu.addItem(quit)

        refresh()
        // Common run-loop modes keep updates working while the menu is open.
        let timer = Timer(timeInterval: 5, repeats: true) { [weak self] _ in
            self?.refresh()
        }
        timer.tolerance = 1
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    func menuWillOpen(_ menu: NSMenu) {
        menuIsOpen = true
        refresh()
    }

    func menuDidClose(_ menu: NSMenu) {
        menuIsOpen = false
    }

    private func addReadOnly(_ row: NSMenuItem) {
        // Custom labels avoid the dimmed text macOS uses for disabled items.
        row.view = InfoRowView(text: row.title)
        row.isEnabled = false
        menu.addItem(row)
    }

    private func refresh() {
        let stats = MemoryStats.read()
        let symbol: String
        switch stats.pressure {
        case .normal: symbol = "🟢"
        case .warning: symbol = "🟡"
        case .critical: symbol = "🔴"
        case .unknown: symbol = "⚪️"
        }
        let swapSummary: String
        if let swapBytes = stats.swapBytes, swapBytes > 0 {
            swapSummary = " · S \(gigabytes(swapBytes)) GB"
        } else {
            swapSummary = ""
        }
        statusItem.button?.title = "\(symbol) R \(gigabytes(stats.usedBytes)) · C \(gigabytes(stats.cachedBytes))\(swapSummary)"
        statusItem.button?.toolTip = "R: RAM used · C: Cached · S: Swap used. All in GB. Memory pressure: \(stats.pressure.rawValue)."

        guard menuIsOpen else { return }
        ramRow.title = "RAM used: \(gigabytes(stats.usedBytes)) / \(gigabytes(ProcessInfo.processInfo.physicalMemory)) GB"
        cacheRow.title = "Cached: \(gigabytes(stats.cachedBytes)) GB"
        swapRow.title = "Swap used: \(gigabytes(stats.swapBytes)) GB"
        pressureRow.title = "Memory pressure: \(stats.pressure.rawValue)"

        let apps = AppMemory.topThree()
        for (index, row) in appRows.enumerated() {
            row.isHidden = index >= apps.count
            if index < apps.count {
                row.title = "\(apps[index].name): \(gigabytes(apps[index].bytes)) GB"
            }
        }
        if apps.isEmpty {
            appRows[0].isHidden = false
            appRows[0].title = "App memory unavailable"
        }
        for row in menu.items {
            (row.view as? InfoRowView)?.label.stringValue = row.title
        }
    }

    @objc private func quitApp() {
        NSApp.terminate(nil)
    }
}

// Opaque charcoal and white stay readable regardless of the wallpaper/theme.
private final class InfoRowView: NSView {
    let label = NSTextField(labelWithString: "")

    init(text: String) {
        super.init(frame: NSRect(x: 0, y: 0, width: 380, height: 34))
        label.stringValue = text
        label.font = .monospacedDigitSystemFont(ofSize: 14, weight: .medium)
        label.textColor = .white
        label.lineBreakMode = .byTruncatingTail
        label.frame = NSRect(x: 14, y: 8, width: 352, height: 18)
        label.autoresizingMask = [.width]
        addSubview(label)
    }

    required init?(coder: NSCoder) {
        fatalError("This view is created in code, not a storyboard")
    }

    override var isOpaque: Bool { true }

    override func draw(_ dirtyRect: NSRect) {
        NSColor(calibratedWhite: 0.10, alpha: 1).setFill()
        bounds.fill()
    }
}
