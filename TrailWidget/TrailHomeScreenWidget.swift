//
//  TrailHomeScreenWidget.swift
//  TrailWidget
//
//  Home Screen Timeline Widget for Trail
//

import SwiftUI
import WidgetKit

struct TrailTimelineEntry: TimelineEntry {
  let date: Date
  let status: String
}

struct TrailTimelineProvider: TimelineProvider {
  func placeholder(in context: Context) -> TrailTimelineEntry {
    TrailTimelineEntry(date: Date(), status: "Ready to walk")
  }

  func getSnapshot(in context: Context, completion: @escaping (TrailTimelineEntry) -> Void) {
    completion(TrailTimelineEntry(date: Date(), status: "Ready to walk"))
  }

  func getTimeline(in context: Context, completion: @escaping (Timeline<TrailTimelineEntry>) -> Void) {
    let entry = TrailTimelineEntry(date: Date(), status: "Ready to walk")
    let timeline = Timeline(entries: [entry], policy: .atEnd)
    completion(timeline)
  }
}

struct TrailHomeScreenWidgetEntryView: View {
  var entry: TrailTimelineProvider.Entry

  var body: some View {
    VStack(alignment: .leading, spacing: 6) {
      HStack {
        Image(systemName: "figure.walk.circle.fill")
          .font(.system(size: 24))
          .foregroundStyle(Color(red: 0.20, green: 0.50, blue: 0.98))
        Spacer()
      }

      Spacer()

      Text("Trail")
        .font(.system(size: 16, weight: .bold, design: .rounded))
        .foregroundStyle(.white)

      Text(entry.status)
        .font(.system(size: 12, weight: .medium))
        .foregroundStyle(.white.opacity(0.7))
    }
    .padding()
    .containerBackground(Color(red: 0.10, green: 0.10, blue: 0.12), for: .widget)
  }
}

public struct TrailHomeScreenWidget: Widget {
  public let kind: String = "TrailHomeScreenWidget"

  public init() {}

  public var body: some WidgetConfiguration {
    StaticConfiguration(kind: kind, provider: TrailTimelineProvider()) { entry in
      TrailHomeScreenWidgetEntryView(entry: entry)
    }
    .configurationDisplayName("Trail")
    .description("Track and share walks with companions.")
    .supportedFamilies([.systemSmall, .systemMedium])
  }
}
