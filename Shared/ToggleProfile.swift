import AppIntents
import Foundation

/// The Control Center tile's action. It's compiled into both the app and the extension:
/// when the app target contains the intent, the system runs it in the app's process,
/// which (unlike the sandboxed extension) may call sudo wg-quick.
struct ToggleProfile: SetValueIntent {
    static let title: LocalizedStringResource = "Toggle WireGuard Profile"
    static let isDiscoverable = false

    @Parameter(title: "Profile") var profile: String
    @Parameter(title: "On") var value: Bool

    init() {}
    init(profile: String) { self.profile = profile }

    /// Set by the app at launch; nil inside the extension.
    @MainActor static var handler: ((String, Bool) async throws -> Void)?

    func perform() async throws -> some IntentResult {
        if let handler = await ToggleProfile.handler {
            try await handler(profile, value)
        } else {
            // Fallback when run in the extension: optimistic state + ping the app.
            var state = SharedState.load()
            state.active = value ? profile : (state.active == profile ? nil : state.active)
            state.save()
            SwitchRequest.send(profile: profile, on: value)
        }
        return .result()
    }
}
