import AppKit
import SwiftUI

enum NotchAnimationIntensity: String, CaseIterable, Identifiable {
    case off
    case subtle
    case standard

    var id: String { rawValue }
    var title: String { rawValue.capitalized }
    var duration: TimeInterval {
        switch self { case .off: return 0; case .subtle: return 0.22; case .standard: return 0.32 }
    }
}

enum NotchPostDropBehavior: String, CaseIterable, Identifiable {
    case notchShelf
    case newFloatingShelf

    var id: String { rawValue }
    var title: String {
        switch self { case .notchShelf: return "Show in Notch Shelf"; case .newFloatingShelf: return "Open New Floating Shelf" }
    }
}

@MainActor
final class NotchPreferences: ObservableObject {
    static let shared = NotchPreferences()

    @Published var isEnabled: Bool { didSet { save("enabled", isEnabled); notifyChange() } }
    @Published var automaticallyCollapses: Bool { didSet { save("auto-collapse", automaticallyCollapses); notifyChange() } }
    @Published var animationIntensity: NotchAnimationIntensity { didSet { save("animation", animationIntensity.rawValue); notifyChange() } }
    @Published var postDropBehavior: NotchPostDropBehavior { didSet { save("post-drop", postDropBehavior.rawValue); notifyChange() } }

    var onChange: (() -> Void)?
    private let defaults: UserDefaults
    private let prefix = "stash.flow.notch."

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        isEnabled = defaults.object(forKey: prefix + "enabled") as? Bool ?? true
        automaticallyCollapses = defaults.object(forKey: prefix + "auto-collapse") as? Bool ?? false
        animationIntensity = NotchAnimationIntensity(rawValue: defaults.string(forKey: prefix + "animation") ?? "") ?? .standard
        postDropBehavior = NotchPostDropBehavior(rawValue: defaults.string(forKey: prefix + "post-drop") ?? "") ?? .notchShelf
    }

    private func save(_ suffix: String, _ value: Any) { defaults.set(value, forKey: prefix + suffix) }
    private func notifyChange() { onChange?() }
}

@MainActor
final class StashSettingsWindowController: NSWindowController {
    init(preferences: NotchPreferences) {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 420, height: 290),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "Stash Settings"
        window.isReleasedWhenClosed = false
        window.contentView = NSHostingView(rootView: StashSettingsView(preferences: preferences))
        super.init(window: window)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func show() {
        window?.center()
        showWindow(nil)
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}

private struct StashSettingsView: View {
    @ObservedObject var preferences: NotchPreferences

    var body: some View {
        Form {
            Section("Notch Mode") {
                Toggle("Enable top-center drop target", isOn: $preferences.isEnabled)
                Toggle("Collapse automatically when idle", isOn: $preferences.automaticallyCollapses)
                    .disabled(!preferences.isEnabled)
            }
            Section("Interaction") {
                Picker("Animation intensity", selection: $preferences.animationIntensity) {
                    ForEach(NotchAnimationIntensity.allCases) { Text($0.title).tag($0) }
                }
                Picker("After dropping", selection: $preferences.postDropBehavior) {
                    ForEach(NotchPostDropBehavior.allCases) { Text($0.title).tag($0) }
                }
            }
            Text("Reduce Motion always disables notch geometry animation. Settings apply immediately.")
                .font(.caption).foregroundStyle(.secondary)
        }
        .formStyle(.grouped)
        .padding(12)
        .frame(width: 420, height: 290)
    }
}
