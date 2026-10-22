import AppKit
import ApplicationServices

/// Decides what a Dock click on an app should do and performs it.
enum WindowToggler {
    /// Handles a Dock icon click on `app`.
    /// Returns true when the click was handled here and must not reach the Dock.
    static func handleDockClick(on app: NSRunningApplication) -> Bool {
        let settings = Settings.shared
        guard !settings.isExcluded(app.bundleIdentifier) else { return false }

        let isFrontmost = NSWorkspace.shared.frontmostApplication?.processIdentifier == app.processIdentifier
        let appElement = AXUIElementCreateApplication(app.processIdentifier)
        AXUIElementSetMessagingTimeout(appElement, 0.5)

        let windows = standardWindows(of: appElement)
        let visible = windows.filter { AX.bool($0, kAXMinimizedAttribute) != true }
        let minimized = windows.filter { AX.bool($0, kAXMinimizedAttribute) == true }

        switch settings.action {
        case .hide:
            if app.isHidden {
                app.unhide()
                app.activate()
                return true
            }
            if isFrontmost && !visible.isEmpty {
                app.hide()
                return true
            }
            return false

        case .minimize:
            // A hidden app is shown again by the Dock's normal behaviour.
            if app.isHidden { return false }

            if isFrontmost && !visible.isEmpty {
                minimize(visible, appElement: appElement, scope: settings.windowScope)
                return true
            }
            if visible.isEmpty && !minimized.isEmpty {
                restore(minimized, app: app, scope: settings.windowScope)
                return true
            }
            // Not frontmost with visible windows, or no windows at all:
            // let the Dock activate / reopen the app as usual.
            return false
        }
    }

    // MARK: - Private

    private static func standardWindows(of appElement: AXUIElement) -> [AXUIElement] {
        AX.elements(appElement, kAXWindowsAttribute).filter { window in
            let subrole = AX.string(window, kAXSubroleAttribute)
            return subrole == kAXStandardWindowSubrole || subrole == kAXDialogSubrole
        }
    }

    private static func minimize(_ visible: [AXUIElement], appElement: AXUIElement, scope: WindowScope) {
        let targets: [AXUIElement]
        switch scope {
        case .allWindows:
            targets = visible
        case .frontWindow:
            // kAXWindowsAttribute is ordered front to back; prefer the focused window.
            let focused = AX.element(appElement, kAXFocusedWindowAttribute)
            let front = visible.first { focused != nil && CFEqual($0, focused) } ?? visible[0]
            targets = [front]
        }
        for window in targets {
            AX.set(window, kAXMinimizedAttribute, true)
        }
    }

    private static func restore(_ minimized: [AXUIElement], app: NSRunningApplication, scope: WindowScope) {
        let targets = scope == .allWindows ? minimized : [minimized[0]]
        for window in targets {
            AX.set(window, kAXMinimizedAttribute, false)
        }
        app.activate()
        if let front = targets.first {
            AX.set(front, kAXMainAttribute, true)
            AX.raise(front)
        }
    }
}
