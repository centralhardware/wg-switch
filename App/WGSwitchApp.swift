import SwiftUI
import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    var model: Model?
    func application(_ application: NSApplication, open urls: [URL]) {
        Task { @MainActor in urls.forEach { self.model?.handle($0) } }
    }
}

@main
struct WGSwitchApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var delegate
    @StateObject private var model = Model()

    var body: some Scene {
        MenuBarExtra {
            MenuContent(model: model)
                .onAppear { delegate.model = model }
        } label: {
            Image(systemName: model.active == nil ? "network.slash" : "network.badge.shield.half.filled")
                .onAppear { delegate.model = model }
        }
        .menuBarExtraStyle(.window)
    }
}

struct MenuContent: View {
    @ObservedObject var model: Model

    /// One switch per profile; turning one on turns every other one off.
    private func binding(_ name: String) -> Binding<Bool> {
        Binding(get: { model.active == name },
                set: { on in if on != (model.active == name) { model.toggle(name) } })
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("WireGuard").font(.headline)
            if model.profiles.isEmpty {
                Text("No profiles in /etc/wireguard").foregroundStyle(.secondary)
            }
            ForEach(model.profiles, id: \.self) { name in
                Toggle(name, isOn: binding(name))
                    .toggleStyle(.switch)
                    .disabled(model.busy)
            }
            if let error = model.error {
                Text(error).font(.caption).foregroundStyle(.red).fixedSize(horizontal: false, vertical: true)
            }
            Divider()
            HStack {
                Button("Refresh") { model.refresh() }
                Spacer()
                Button("Quit") { NSApp.terminate(nil) }.keyboardShortcut("q")
            }
        }
        .padding(12)
        .frame(width: 240)
    }
}
