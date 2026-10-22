import AppKit
import ApplicationServices

/// Watches left clicks system-wide and intercepts the ones that land on an app icon in the Dock.
final class DockClickMonitor {
    private var tap: CFMachPort?
    private var swallowNextMouseUp = false

    var isRunning: Bool { tap != nil }

    /// Installs the event tap. Fails when Accessibility access has not been granted.
    @discardableResult
    func start() -> Bool {
        guard tap == nil else { return true }

        let mask = (1 << CGEventType.leftMouseDown.rawValue) | (1 << CGEventType.leftMouseUp.rawValue)
        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: CGEventMask(mask),
            callback: { _, type, event, refcon in
                let monitor = Unmanaged<DockClickMonitor>.fromOpaque(refcon!).takeUnretainedValue()
                return monitor.handle(type: type, event: event)
            },
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        ) else { return false }

        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        self.tap = tap
        return true
    }

    private func handle(type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        switch type {
        case .tapDisabledByTimeout, .tapDisabledByUserInput:
            if let tap { CGEvent.tapEnable(tap: tap, enable: true) }

        case .leftMouseDown:
            swallowNextMouseUp = false
            // Modifier clicks keep their Dock meaning (⌘ reveal in Finder, ⌥ hide others, …).
            let modifiers: CGEventFlags = [.maskCommand, .maskAlternate, .maskControl, .maskShift]
            guard Settings.shared.isEnabled, event.flags.intersection(modifiers).isEmpty,
                  let app = dockApplication(at: event.location) else { break }
            if WindowToggler.handleDockClick(on: app) {
                swallowNextMouseUp = true
                return nil
            }

        case .leftMouseUp:
            if swallowNextMouseUp {
                swallowNextMouseUp = false
                return nil
            }

        default:
            break
        }
        return Unmanaged.passUnretained(event)
    }

    /// The running app whose Dock icon is under `point` (global, top-left origin), if any.
    private func dockApplication(at point: CGPoint) -> NSRunningApplication? {
        guard let dock = NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.dock").first else {
            return nil
        }
        let dockElement = AXUIElementCreateApplication(dock.processIdentifier)
        AXUIElementSetMessagingTimeout(dockElement, 0.25)

        // Cheap bounds check first so ordinary clicks elsewhere stay fast.
        let list = AX.elements(dockElement, kAXChildrenAttribute).first { AX.string($0, kAXRoleAttribute) == kAXListRole }
        guard let list, let listFrame = AX.frame(list), listFrame.contains(point),
              let item = AX.element(at: point, in: dockElement),
              AX.string(item, kAXSubroleAttribute) == "AXApplicationDockItem",
              let itemURL = AX.url(item, kAXURLAttribute) else { return nil }

        let itemPath = itemURL.resolvingSymlinksInPath().path
        return NSWorkspace.shared.runningApplications.first { app in
            app.bundleURL?.resolvingSymlinksInPath().path == itemPath
        }
    }
}
