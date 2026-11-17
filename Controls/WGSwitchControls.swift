import AppIntents
import SwiftUI
import WidgetKit

// MARK: - Profile picked when the tile is added

struct ProfileEntity: AppEntity {
    static let typeDisplayRepresentation: TypeDisplayRepresentation = "WireGuard Profile"
    static let defaultQuery = ProfileQuery()
    let id: String
    var displayRepresentation: DisplayRepresentation { DisplayRepresentation(title: "\(id)") }
}

struct ProfileQuery: EntityQuery {
    func entities(for identifiers: [String]) async throws -> [ProfileEntity] { identifiers.map(ProfileEntity.init) }
    func suggestedEntities() async throws -> [ProfileEntity] { SharedState.load().profiles.map(ProfileEntity.init) }
}

struct SelectProfile: ControlConfigurationIntent {
    static let title: LocalizedStringResource = "WireGuard Profile"
    @Parameter(title: "Profile") var profile: ProfileEntity?
}

// MARK: - Toggle action

struct ToggleProfile: SetValueIntent {
    static let title: LocalizedStringResource = "Toggle WireGuard Profile"
    @Parameter(title: "Profile") var profile: String
    @Parameter(title: "On") var value: Bool

    init() {}
    init(profile: String) { self.profile = profile }

    func perform() async throws -> some IntentResult {
        // Show the new state right away; the app corrects it if wg-quick fails.
        var state = SharedState.load()
        state.active = value ? profile : (state.active == profile ? nil : state.active)
        state.save()
        SwitchRequest.send(profile: profile, on: value)
        return .result()
    }
}

// MARK: - Control

struct TileValue {
    let name: String
    let isOn: Bool
}

struct ProfileValue: AppIntentControlValueProvider {
    func previewValue(configuration: SelectProfile) -> TileValue {
        TileValue(name: configuration.profile?.id ?? "WireGuard", isOn: false)
    }
    func currentValue(configuration: SelectProfile) async throws -> TileValue {
        let name = configuration.profile?.id ?? "WireGuard"
        return TileValue(name: name, isOn: SharedState.load().active == name)
    }
}

struct WGProfileControl: ControlWidget {
    var body: some ControlWidgetConfiguration {
        AppIntentControlConfiguration(kind: "me.centralhardware.wgswitch.profile",
                                      provider: ProfileValue()) { value in
            ControlWidgetToggle(value.name, isOn: value.isOn,
                                action: ToggleProfile(profile: value.name)) { isOn in
                Label(isOn ? "On" : "Off", systemImage: isOn ? "lock.shield.fill" : "lock.shield")
            }
        }
        .displayName("WireGuard Profile")
        .description("Turn one wg-quick profile on. Any other active profile goes off.")
        .promptsForUserConfiguration()
    }
}

@main
struct WGSwitchControlsBundle: WidgetBundle {
    var body: some Widget { WGProfileControl() }
}
