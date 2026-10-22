import Foundation

/// What happens when the Dock icon of the active app is clicked.
enum ClickAction: String, CaseIterable, Identifiable {
    case minimize
    case hide

    var id: String { rawValue }
}

/// Which windows are minimized / restored when the app has more than one.
enum WindowScope: String, CaseIterable, Identifiable {
    case allWindows
    case frontWindow

    var id: String { rawValue }
}

/// User preferences, persisted in UserDefaults.
final class Settings: ObservableObject {
    static let shared = Settings()

    private enum Keys {
        static let isEnabled = "isEnabled"
        static let action = "action"
        static let windowScope = "windowScope"
        static let excludedBundleIDs = "excludedBundleIDs"
    }

    private let defaults = UserDefaults.standard

    @Published var isEnabled: Bool {
        didSet { defaults.set(isEnabled, forKey: Keys.isEnabled) }
    }

    @Published var action: ClickAction {
        didSet { defaults.set(action.rawValue, forKey: Keys.action) }
    }

    @Published var windowScope: WindowScope {
        didSet { defaults.set(windowScope.rawValue, forKey: Keys.windowScope) }
    }

    @Published var excludedBundleIDs: [String] {
        didSet { defaults.set(excludedBundleIDs, forKey: Keys.excludedBundleIDs) }
    }

    private init() {
        defaults.register(defaults: [
            Keys.isEnabled: true,
            Keys.action: ClickAction.minimize.rawValue,
            Keys.windowScope: WindowScope.allWindows.rawValue,
            Keys.excludedBundleIDs: [String](),
        ])
        isEnabled = defaults.bool(forKey: Keys.isEnabled)
        action = ClickAction(rawValue: defaults.string(forKey: Keys.action) ?? "") ?? .minimize
        windowScope = WindowScope(rawValue: defaults.string(forKey: Keys.windowScope) ?? "") ?? .allWindows
        excludedBundleIDs = defaults.stringArray(forKey: Keys.excludedBundleIDs) ?? []
    }

    func isExcluded(_ bundleID: String?) -> Bool {
        guard let bundleID else { return false }
        return excludedBundleIDs.contains(bundleID)
    }
}
