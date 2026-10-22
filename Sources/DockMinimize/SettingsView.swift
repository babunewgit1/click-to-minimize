import AppKit
import ServiceManagement
import SwiftUI
import UniformTypeIdentifiers

struct SettingsView: View {
    @ObservedObject var settings = Settings.shared
    @ObservedObject var permission: PermissionState
    @ObservedObject private var state = SettingsViewState()

    var body: some View {
        Form {
            if !permission.isTrusted {
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Label("Accessibility access needed", systemImage: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange)
                            .font(.headline)
                        Text("Turn on DockMinimize in System Settings › Privacy & Security › Accessibility. It starts working as soon as access is granted.")
                            .foregroundStyle(.secondary)
                        Button("Open Accessibility Settings") { AX.openAccessibilitySettings() }
                    }
                }
            }

            Section {
                Toggle("Click Dock icon to minimize", isOn: $settings.isEnabled)
                Toggle("Launch at login", isOn: $state.launchAtLogin)
                    .onChange(of: state.launchAtLogin) { setLaunchAtLogin($0) }
            }

            Section("When you click the active app's Dock icon") {
                Picker("Action", selection: $settings.action) {
                    Text("Minimize windows").tag(ClickAction.minimize)
                    Text("Hide the app").tag(ClickAction.hide)
                }
                .pickerStyle(.radioGroup)

                Picker("If the app has several windows", selection: $settings.windowScope) {
                    Text("All windows").tag(WindowScope.allWindows)
                    Text("Only the front window").tag(WindowScope.frontWindow)
                }
                .pickerStyle(.radioGroup)
                .disabled(settings.action == .hide)
            }

            Section {
                if settings.excludedBundleIDs.isEmpty {
                    Text("No apps excluded")
                        .foregroundStyle(.secondary)
                } else {
                    List(settings.excludedBundleIDs, id: \.self, selection: $state.selectedExclusion) { bundleID in
                        ExcludedAppRow(bundleID: bundleID)
                    }
                    .frame(minHeight: 100)
                }
                HStack {
                    Button("Add App…", action: addExcludedApps)
                    Button("Remove", action: removeSelectedExclusion)
                        .disabled(state.selectedExclusion == nil)
                }
            } header: {
                Text("Excluded apps")
            } footer: {
                Text("Clicking these apps' Dock icons keeps the normal macOS behaviour.")
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .formStyle(.grouped)
        .safeAreaInset(edge: .bottom) {
            Text("Developed by [MHBabu](https://www.facebook.com/babuwd/)")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .padding(.bottom, 14)
        }
        .frame(width: 460)
        .fixedSize(horizontal: false, vertical: true)
    }

    private func setLaunchAtLogin(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            NSLog("DockMinimize: launch at login change failed: \(error)")
        }
        let actual = SMAppService.mainApp.status == .enabled
        if state.launchAtLogin != actual { state.launchAtLogin = actual }
    }

    private func addExcludedApps() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.application]
        panel.allowsMultipleSelection = true
        panel.directoryURL = URL(fileURLWithPath: "/Applications")
        panel.prompt = "Exclude"
        guard panel.runModal() == .OK else { return }

        for url in panel.urls {
            guard let bundleID = Bundle(url: url)?.bundleIdentifier,
                  !settings.excludedBundleIDs.contains(bundleID) else { continue }
            settings.excludedBundleIDs.append(bundleID)
        }
    }

    private func removeSelectedExclusion() {
        guard let selected = state.selectedExclusion else { return }
        settings.excludedBundleIDs.removeAll { $0 == selected }
        state.selectedExclusion = nil
    }
}

/// Local UI state. Kept in an ObservableObject because the SwiftUI `@State` macro
/// is unavailable when building with Command Line Tools only.
final class SettingsViewState: ObservableObject {
    @Published var launchAtLogin = SMAppService.mainApp.status == .enabled
    @Published var selectedExclusion: String?
}

private struct ExcludedAppRow: View {
    let bundleID: String

    var body: some View {
        let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID)
        HStack {
            if let url {
                Image(nsImage: NSWorkspace.shared.icon(forFile: url.path))
                    .resizable()
                    .frame(width: 20, height: 20)
                Text(FileManager.default.displayName(atPath: url.path))
            } else {
                Text(bundleID)
            }
        }
    }
}
