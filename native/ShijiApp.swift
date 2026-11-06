import AppKit
import WebKit

final class Bridge: NSObject, WKScriptMessageHandler {
    weak var appDelegate: AppDelegate?

    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        guard let body = message.body as? [String: Any], let action = body["action"] as? String else { return }
        DispatchQueue.main.async { [weak self] in
            guard let delegate = self?.appDelegate else { return }
            switch action {
            case "tick":
                delegate.updateTrayTitle(body["value"] as? String ?? "")
            case "pin":
                delegate.setPinned(body["value"] as? Bool ?? false)
            case "openMain":
                delegate.openMainWindow()
            case "close":
                delegate.closePopover()
            case "quit":
                NSApp.terminate(nil)
            default:
                break
            }
        }
    }
}

final class WebViewController: NSViewController {
    private let fileName: String
    private let bridge: Bridge?
    private(set) var webView: WKWebView!

    init(fileName: String, bridge: Bridge? = nil) {
        self.fileName = fileName
        self.bridge = bridge
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func loadView() {
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = .default()
        if let bridge { configuration.userContentController.add(bridge, name: "shiji") }
        webView = WKWebView(frame: .zero, configuration: configuration)
        webView.setValue(false, forKey: "drawsBackground")
        view = webView
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        guard let resourceURL = Bundle.main.resourceURL else { return }
        let fileURL = resourceURL.appendingPathComponent(fileName)
        webView.loadFileURL(fileURL, allowingReadAccessTo: resourceURL)
    }

    func reloadPage() {
        _ = view
        if webView.url != nil {
            webView.reload()
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate, NSPopoverDelegate {
    private var statusItem: NSStatusItem!
    private let popover = NSPopover()
    private let bridge = Bridge()
    private var popoverController: WebViewController!
    private var mainController: WebViewController?
    private var mainWindow: NSWindow?
    private var pinned = false

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        bridge.appDelegate = self

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "timer", accessibilityDescription: "时迹")
            button.imagePosition = .imageLeading
            button.title = " 25:00"
            button.font = NSFont.monospacedDigitSystemFont(ofSize: 13, weight: .semibold)
            button.target = self
            button.action = #selector(togglePopover(_:))
            button.toolTip = "时迹 · 专注计时"
        }

        popoverController = WebViewController(fileName: "popover.html", bridge: bridge)
        popover.contentViewController = popoverController
        popover.contentSize = NSSize(width: 340, height: 340)
        popover.behavior = .transient
        popover.animates = true
        popover.delegate = self

        DistributedNotificationCenter.default().addObserver(
            self,
            selector: #selector(wakeFromSleep),
            name: NSNotification.Name("com.apple.screenIsUnlocked"),
            object: nil
        )

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) { [weak self] in
            self?.showPopover()
        }
    }

    @objc private func togglePopover(_ sender: Any?) {
        if popover.isShown {
            popover.performClose(sender)
        } else { showPopover() }
    }

    private func showPopover() {
        guard let button = statusItem.button else { return }
        popoverController.reloadPage()
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        popover.contentViewController?.view.window?.makeKey()
    }

    @objc private func wakeFromSleep() {
        popoverController.reloadPage()
    }

    func updateTrayTitle(_ value: String) {
        statusItem.button?.title = value.isEmpty ? "" : " \(value)"
    }

    func setPinned(_ value: Bool) {
        pinned = value
        popover.behavior = value ? .applicationDefined : .transient
    }

    func closePopover() {
        popover.performClose(nil)
    }

    func openMainWindow() {
        if mainWindow == nil {
            let controller = WebViewController(fileName: "index.html")
            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 1120, height: 780),
                styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
                backing: .buffered,
                defer: false
            )
            window.title = "时迹"
            window.titlebarAppearsTransparent = true
            window.isReleasedWhenClosed = false
            window.center()
            window.contentViewController = controller
            window.setFrameAutosaveName("ShijiMainWindow")
            mainController = controller
            mainWindow = window
        } else {
            mainController?.reloadPage()
        }
        popover.performClose(nil)
        mainWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func popoverShouldClose(_ popover: NSPopover) -> Bool { !pinned }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        showPopover()
        return true
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.run()
