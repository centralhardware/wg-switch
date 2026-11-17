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
    /// The request travels in the notification *name* (Darwin notifications carry no payload),
    /// e.g. me.centralhardware.wgswitch.request.on.wg0. The prefs copy is only a fallback for the
    /// app's 10 s tick; reading it right after the ping returned a stale cached value.
    static func name(profile: String, on: Bool) -> String {
        "\(notification as String).\(on ? "on" : "off").\(profile)"
    }

    static func parse(_ name: String) -> (profile: String, on: Bool)? {
        let prefix = (notification as String) + "."
        guard name.hasPrefix(prefix) else { return nil }
        let rest = name.dropFirst(prefix.count)
        if rest.hasPrefix("on.") { return (String(rest.dropFirst(3)), true) }
        if rest.hasPrefix("off.") { return (String(rest.dropFirst(4)), false) }
        return nil
    }

    static func send(profile: String, on: Bool) {
        wgLog.notice("send request \(profile, privacy: .public) on=\(on)")
        SharedState.defaults?.set(["profile": profile, "on": on], forKey: key)
        CFNotificationCenterPostNotification(CFNotificationCenterGetDarwinNotifyCenter(),
                                             CFNotificationName(name(profile: profile, on: on) as CFString), nil, nil, true)
    }

    static func take() -> (profile: String, on: Bool)? {
        SharedState.defaults?.synchronize()
        guard let d = SharedState.defaults?.dictionary(forKey: key),
              let p = d["profile"] as? String, let on = d["on"] as? Bool else { return nil }
        SharedState.defaults?.removeObject(forKey: key)
        return (p, on)
    }
}

import os
/// `log stream --predicate 'subsystem == "me.centralhardware.wgswitch"' --level debug`
let wgLog = Logger(subsystem: "me.centralhardware.wgswitch", category: Bundle.main.bundleURL.pathExtension == "appex" ? "control" : "app")
