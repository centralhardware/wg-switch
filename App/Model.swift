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
        if on == (active == name) { refresh(); return }
        busy = true
        defer { busy = false; refresh() }
        try await Task.detached { try WireGuard.toggle(name) }.value
    }

    func grantAccess() {
        do { try WireGuard.installSudoers() } catch { self.error = error.localizedDescription; return }
        refresh()
    }

    /// Bring `name` up (everything else down) or take it down.
    func set(_ name: String, on: Bool) {
        guard profiles.contains(name) else { refresh(); return }   // e.g. an unconfigured tile
        if on != (active == name) { toggle(name) } else { refresh() }
    }

    private func listenForControls() {
        let observer = Unmanaged.passUnretained(self).toOpaque()
        CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(), observer, { _, observer, _, _, _ in
            guard let observer else { return }
            let model = Unmanaged<Model>.fromOpaque(observer).takeUnretainedValue()
            Task { @MainActor in
                if let req = SwitchRequest.take() { model.set(req.profile, on: req.on) }
            }
        }, SwitchRequest.notification, nil, .deliverImmediately)
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
