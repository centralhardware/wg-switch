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
        WidgetCenter.shared.reloadAllTimelines()
    }
}
