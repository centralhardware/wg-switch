import Foundation

/// State the menu-bar app publishes for the sandboxed Control Center extension,
/// which can neither read /etc/wireguard nor run sudo.
struct SharedState: Codable {
    var profiles: [String] = []
    var active: String? = nil
    var error: String? = nil

    private static let key = "state"
    static var defaults: UserDefaults? {
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

/// Control → app requests. The extension writes the wanted end state to the app group and pings
/// the app with a payload-less Darwin notification (one of the few IPC paths a sandboxed extension has).
enum SwitchRequest {
    static let notification = "me.centralhardware.wgswitch.request" as CFString
    private static let key = "request"

    /// `profile` on → bring it up (and everything else down); off → bring it down.
    static func send(profile: String, on: Bool) {
        SharedState.defaults?.set(["profile": profile, "on": on], forKey: key)
        CFNotificationCenterPostNotification(CFNotificationCenterGetDarwinNotifyCenter(),
                                             CFNotificationName(notification), nil, nil, true)
    }

    static func take() -> (profile: String, on: Bool)? {
        guard let d = SharedState.defaults?.dictionary(forKey: key),
              let p = d["profile"] as? String, let on = d["on"] as? Bool else { return nil }
        SharedState.defaults?.removeObject(forKey: key)
        return (p, on)
    }
}
