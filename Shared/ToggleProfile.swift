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
        let handler = await ToggleProfile.handler
        wgLog.notice("ToggleProfile.perform profile=\(profile, privacy: .public) on=\(value) inApp=\(handler != nil)")
        if let handler {
            try await handler(profile, value)
        } else {
            // Running in the extension: hand the request to the app. Only the app writes `state`.
            SwitchRequest.send(profile: profile, on: value)
        }
        return .result()
    }
}
