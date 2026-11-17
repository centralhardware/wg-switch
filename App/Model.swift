import Foundation
import WidgetKit

@MainActor
final class Model: ObservableObject {
    @Published var profiles: [String] = []
    @Published var active: String?
    @Published var busy = false
    @Published var error: String?

    private var timer: Timer?

    init() {
        refresh()
        listenForControls()
        ToggleProfile.handler = { [weak self] name, on in
            try await self?.apply(name, on: on)
        }
        // Pick up tunnels started/stopped from the terminal too.
        timer = Timer.scheduledTimer(withTimeInterval: 10, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.tick() }
        }
    }

    /// Periodic check; also picks up a tile request whose Darwin notification was missed.
    private func tick() {
        if let req = SwitchRequest.take() {
            wgLog.notice("tick picked up request \(req.profile, privacy: .public) on=\(req.on)")
            set(req.profile, on: req.on)
        } else {
            refresh()
        }
    }

    func refresh() {
        do {
            profiles = try WireGuard.profiles()
            error = nil
        } catch {
            self.error = error.localizedDescription
        }
        active = WireGuard.active().first
        listenForControls()
        publish()
    }

    func toggle(_ name: String) {
        guard !busy else { return }
        busy = true
        Task.detached {
            var failure: String?
            do { try WireGuard.toggle(name) } catch { failure = error.localizedDescription }
            await MainActor.run {
                self.busy = false
                self.refresh()
                if let failure { self.error = failure; self.publish() }
            }
        }
    }

    /// Used by the Control Center intent when it runs in the app: waits for wg-quick, throws on failure.
    func apply(_ name: String, on: Bool) async throws {
        wgLog.notice("apply \(name, privacy: .public) on=\(on)")
        busy = true
        defer { busy = false; refresh() }
        do {
            try await Task.detached { try WireGuard.set(name, on: on) }.value
        } catch {
            self.error = error.localizedDescription
            throw error
        }
    }

    func grantAccess() {
        do { try WireGuard.installSudoers() } catch { self.error = error.localizedDescription; return }
        refresh()
    }

    /// Bring `name` up (everything else down) or take it down.
    func set(_ name: String, on: Bool) {
        guard profiles.contains(name) else { refresh(); return }   // e.g. an unconfigured tile
        Task { try? await apply(name, on: on) }
    }

    private var observedProfiles: [String] = []

    private func listenForControls() {
        // Darwin observers need exact names, so (re)register one on/off pair per profile.
        guard observedProfiles != profiles else { return }
        let center = CFNotificationCenterGetDarwinNotifyCenter()
        let observer = Unmanaged.passUnretained(self).toOpaque()
        CFNotificationCenterRemoveEveryObserver(center, observer)
        for p in profiles {
            for on in [true, false] {
                CFNotificationCenterAddObserver(center, observer, { _, observer, name, _, _ in
                    guard let observer, let raw = name?.rawValue as String?,
                          let req = SwitchRequest.parse(raw) else { return }
                    let model = Unmanaged<Model>.fromOpaque(observer).takeUnretainedValue()
                    wgLog.notice("control request \(req.profile, privacy: .public) on=\(req.on)")
                    Task { @MainActor in
                        _ = SwitchRequest.take()   // drop the fallback copy
                        model.set(req.profile, on: req.on)
                    }
                }, SwitchRequest.name(profile: p, on: on) as CFString, nil, .deliverImmediately)
            }
        }
        observedProfiles = profiles
    }

    func handle(_ url: URL) {
        guard url.scheme == "wgswitch" else { return }
        if url.host == "toggle", let name = url.pathComponents.dropFirst().first {
            toggle(name)
        } else {
            refresh()
        }
    }

    private func publish() {
        SharedState(profiles: profiles, active: active, error: error).save()
        ControlCenter.shared.reloadAllControls()
    }
}
