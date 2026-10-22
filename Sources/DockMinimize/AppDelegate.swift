import AppKit
import Combine
import SwiftUI

/// Accessibility permission state, observed by the settings window.
final class PermissionState: ObservableObject {
    @Published var isTrusted = AX.isTrusted
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    private let monitor = DockClickMonitor()
    private let permission = PermissionState()
    private var statusItem: NSStatusItem!
    private var enabledMenuItem: NSMenuItem!
    private var settingsWindow: NSWindow?
    private var permissionTimer: Timer?
    private var cancellables = Set<AnyCancellable>()

    func applicationDidFinishLaunching(_ notification: Notification) {
        setUpStatusItem()

        Settings.shared.$isEnabled
            .sink { [weak self] enabled in self?.updateStatusItem(enabled: enabled) }
            .store(in: &cancellables)

        if AX.isTrusted {
            monitor.start()
        } else {
            AX.requestTrust()
            showSettings()
            waitForPermission()
        }
    }

    // MARK: - Permission

    /// Polls until Accessibility access is granted, then starts the Dock monitor.
    private func waitForPermission() {
        permissionTimer = Timer.scheduledTimer(withTimeInterval: 1.5, repeats: true) { [weak self] timer in
            guard let self, AX.isTrusted else { return }
            timer.invalidate()
            self.permissionTimer = nil
            self.permission.isTrusted = true
            self.monitor.start()
        }
    }

    // MARK: - Status item

    private func setUpStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)

        let menu = NSMenu()
        enabledMenuItem = NSMenuItem(title: "Enabled", action: #selector(toggleEnabled), keyEquivalent: "")
        enabledMenuItem.target = self
        menu.addItem(enabledMenuItem)
        menu.addItem(.separator())

        let settingsItem = NSMenuItem(title: "Settings…", action: #selector(openSettings), keyEquivalent: ",")
        settingsItem.target = self
        menu.addItem(settingsItem)
        menu.addItem(.separator())

        menu.addItem(NSMenuItem(title: "Quit DockMinimize", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        statusItem.menu = menu
    }

    private func updateStatusItem(enabled: Bool) {
        enabledMenuItem.state = enabled ? .on : .off
        let symbol = enabled ? "dock.arrow.down.rectangle" : "dock.rectangle"
        let image = NSImage(systemSymbolName: symbol, accessibilityDescription: "DockMinimize")
        image?.isTemplate = true
        statusItem.button?.image = image
    }

    @objc private func toggleEnabled() {
        Settings.shared.isEnabled.toggle()
    }

    @objc private func openSettings() {
        showSettings()
    }

    // MARK: - Settings window

    private func showSettings() {
        if settingsWindow == nil {
            let window = NSWindow(
                contentRect: .zero,
                styleMask: [.titled, .closable],
                backing: .buffered,
                defer: false
            )
            window.title = "DockMinimize Settings"
            window.isReleasedWhenClosed = false
            window.contentView = NSHostingView(rootView: SettingsView(permission: permission))
            window.center()
            settingsWindow = window
        }
        permission.isTrusted = AX.isTrusted
        NSApp.activate(ignoringOtherApps: true)
        settingsWindow?.makeKeyAndOrderFront(nil)
    }
}
