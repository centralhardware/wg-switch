import Foundation

/// State the menu-bar app publishes for the sandboxed Control Center extension,
/// which can neither read /etc/wireguard nor run sudo.
struct SharedState: Codable {
    var profiles: [String] = []
    var active: String? = nil
    var error: String? = nil

    private static let key = "state"
    /// ~/Library/Preferences/me.centralhardware.wgswitch.shared.plist. The sandboxed extension reaches it
    /// through a shared-preference entitlement exception (app groups would need a provisioning profile).
    static let suite = "me.centralhardware.wgswitch.shared"
    static var defaults: UserDefaults? { UserDefaults(suiteName: suite) }

    static func load() -> SharedState {
        defaults?.synchronize()   // another process wrote it; drop any cached copy
        guard let data = defaults?.data(forKey: key),
              let s = try? JSONDecoder().decode(SharedState.self, from: data) else { return SharedState() }
        return s
    }

    func save() {
        if let data = try? JSONEncoder().encode(self) { Self.defaults?.set(data, forKey: Self.key) }
    }
}

/// Control → app requests. The extension writes the wanted end state to the shared preferences domain and pings
/// the app with a payload-less Darwin notification (the request itself sits in the shared preferences domain).
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
