import Foundation

@main
@MainActor
struct FlowSettingsHarness {
    static func main() {
        let suiteName = "stash-flow-settings-tests-\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suiteName) else { fatalError("Unable to create disposable defaults suite") }
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let initial = NotchPreferences(defaults: defaults)
        precondition(initial.isEnabled)
        precondition(!initial.automaticallyCollapses)
        precondition(initial.animationIntensity == .standard)
        precondition(initial.postDropBehavior == .notchShelf)

        initial.isEnabled = false
        initial.automaticallyCollapses = true
        initial.animationIntensity = .subtle
        initial.postDropBehavior = .newFloatingShelf

        let restored = NotchPreferences(defaults: defaults)
        precondition(!restored.isEnabled)
        precondition(restored.automaticallyCollapses)
        precondition(restored.animationIntensity == .subtle)
        precondition(restored.postDropBehavior == .newFloatingShelf)
        print("PASS: FLOW settings defaults and persistence")
    }
}
