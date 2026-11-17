import WidgetKit
import SwiftUI

struct Entry: TimelineEntry {
    let date: Date
    let state: SharedState
}

struct Provider: TimelineProvider {
    func placeholder(in context: Context) -> Entry {
        Entry(date: .now, state: SharedState(profiles: ["wg0", "wg1"], active: "wg0"))
    }
    func getSnapshot(in context: Context, completion: @escaping (Entry) -> Void) {
        completion(Entry(date: .now, state: SharedState.load()))
    }
    func getTimeline(in context: Context, completion: @escaping (Timeline<Entry>) -> Void) {
        // The app reloads timelines on every change; this is just a fallback.
        completion(Timeline(entries: [Entry(date: .now, state: SharedState.load())],
                            policy: .after(.now.addingTimeInterval(900))))
    }
}

struct WidgetView: View {
    let entry: Entry
    @Environment(\.widgetFamily) var family

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: entry.state.active == nil ? "network.slash" : "lock.shield.fill")
                Text(entry.state.active ?? "Off").font(.headline)
            }
            .foregroundStyle(entry.state.active == nil ? Color.secondary : Color.green)

            if entry.state.profiles.isEmpty {
                Link("Open WGSwitch", destination: SwitchURL.refresh).font(.caption)
            }
            ForEach(entry.state.profiles.prefix(family == .systemSmall ? 3 : 6), id: \.self) { name in
                Link(destination: SwitchURL.toggle(name)) {
                    HStack {
                        Text(name).lineLimit(1)
                        Spacer()
                        SwitchGlyph(on: entry.state.active == name)
                    }
                    .padding(.horizontal, 8).padding(.vertical, 4)
                    .background(entry.state.active == name ? Color.green.opacity(0.25) : Color.secondary.opacity(0.15),
                                in: RoundedRectangle(cornerRadius: 6))
                }
            }
            if let error = entry.state.error {
                Text(error).font(.caption2).foregroundStyle(.red).lineLimit(2)
            }
            Spacer(minLength: 0)
        }
        .containerBackground(.fill.tertiary, for: .widget)
    }
}

/// Static look-alike of a switch: widgets can only open links, the app does the toggling.
struct SwitchGlyph: View {
    let on: Bool
    var body: some View {
        Capsule().fill(on ? Color.green : Color.secondary.opacity(0.35))
            .frame(width: 26, height: 15)
            .overlay(alignment: on ? .trailing : .leading) {
                Circle().fill(.white).padding(2)
            }
    }
}

@main
struct WGSwitchWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "WGSwitchWidget", provider: Provider()) { WidgetView(entry: $0) }
            .configurationDisplayName("WireGuard")
            .description("Switch the active wg-quick profile. Only one runs at a time.")
            .supportedFamilies([.systemSmall, .systemMedium])
    }
}
