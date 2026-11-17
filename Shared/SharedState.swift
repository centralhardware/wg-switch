import Foundation

/// State the menu-bar app publishes for the (sandboxed) widget, which cannot read /etc/wireguard itself.
struct SharedState: Codable {
    var profiles: [String] = []
    var active: String? = nil
    var error: String? = nil

    private static let key = "state"
    private static var defaults: UserDefaults? {
        guard let group = Bundle.main.object(forInfoDictionaryKey: "AppGroup") as? String else { return nil }
        return UserDefaults(suiteName: group)
    }

    static func load() -> SharedState {
        guard let data = defaults?.data(forKey: key),
              let s = try? JSONDecoder().decode(SharedState.self, from: data) else { return SharedState() }
        return s
    }

    func save() {
        if let data = try? JSONEncoder().encode(self) { Self.defaults?.set(data, forKey: Self.key) }
    }
}

enum SwitchURL {
    /// wgswitch://toggle/<profile>
    static func toggle(_ profile: String) -> URL { URL(string: "wgswitch://toggle/\(profile)")! }
    static let refresh = URL(string: "wgswitch://refresh")!
}
