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
        // Pick up tunnels started/stopped from the terminal too.
        timer = Timer.scheduledTimer(withTimeInterval: 10, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.refresh() }
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

    func grantAccess() {
        do { try WireGuard.installSudoers() } catch { self.error = error.localizedDescription; return }
        refresh()
    }

    /// Bring `name` up (everything else down) or take it down.
    func set(_ name: String, on: Bool) {
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
