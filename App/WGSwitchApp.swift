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
    }
}

struct MenuContent: View {
    @ObservedObject var model: Model

    var body: some View {
        if model.profiles.isEmpty {
            Text("No profiles in /etc/wireguard")
        }
        ForEach(model.profiles, id: \.self) { name in
            Button {
                model.toggle(name)
            } label: {
                if model.active == name {
                    Label(name, systemImage: "checkmark")
                } else {
                    Text(name)
                }
            }
            .disabled(model.busy)
        }
        if let error = model.error {
            Divider()
            Text(error).foregroundStyle(.red)
        }
        Divider()
        if model.active != nil {
            Button("Disconnect") { if let a = model.active { model.toggle(a) } }
        }
        Button("Refresh") { model.refresh() }
        Button("Quit") { NSApp.terminate(nil) }.keyboardShortcut("q")
    }
}
