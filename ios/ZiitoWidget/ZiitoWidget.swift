import WidgetKit
import SwiftUI

nonisolated struct ZiitoProvider: TimelineProvider {
    func placeholder(in context: Context) -> ZiitoSimpleEntry {
        ZiitoSimpleEntry(date: .now)
    }

    func getSnapshot(in context: Context, completion: @escaping (ZiitoSimpleEntry) -> Void) {
        completion(ZiitoSimpleEntry(date: .now))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<ZiitoSimpleEntry>) -> Void) {
        let entries = [ZiitoSimpleEntry(date: .now)]
        completion(Timeline(entries: entries, policy: .atEnd))
    }
}

nonisolated struct ZiitoSimpleEntry: TimelineEntry {
    let date: Date
}

struct ZiitoWidgetView: View {
    var entry: ZiitoProvider.Entry

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label("ZIITO", systemImage: "mountain.2.fill")
                .font(.caption.weight(.heavy))
                .tracking(2)
                .foregroundStyle(.white)
            Text("Con cada paso avanzas")
                .font(.caption2)
                .foregroundStyle(.white.opacity(0.75))
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

struct ZiitoWidget: Widget {
    let kind: String = "ZiitoWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: ZiitoProvider()) { entry in
            ZiitoWidgetView(entry: entry)
                .containerBackground(
                    LinearGradient(
                        colors: [Color(red: 0.08, green: 0.10, blue: 0.16), Color(red: 0.18, green: 0.22, blue: 0.32)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    for: .widget
                )
        }
        .configurationDisplayName("Ziito")
        .description("Con cada paso avanzas.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}
