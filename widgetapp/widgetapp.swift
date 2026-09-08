import ActivityKit
import WidgetKit
import SwiftUI

struct CompanionJourneyLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: CompanionJourneyAttributes.self) { context in
            // Lock screen / Banner UI
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Label(context.attributes.walkerName, systemImage: "figure.walk")
                        .font(.headline)
                        .foregroundColor(.blue)

                    Spacer()

                    Text(context.state.latestTimeString)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Text(context.state.isArrived ? "Telah sampai di tujuan!" : "Melewati:")
                    .font(.caption)
                    .foregroundColor(context.state.isArrived ? .green : .secondary)

                Text(context.state.latestLandmarkName)
                    .font(.headline)
                    .lineLimit(2)
            }
            .padding()
        } dynamicIsland: { context in
            DynamicIsland {
                // Expanded UI
                DynamicIslandExpandedRegion(.leading) {
                    Label(context.attributes.walkerName, systemImage: "figure.walk")
                        .font(.subheadline)
                        .foregroundColor(.blue)
                        .padding(.top, 8)
                }

                DynamicIslandExpandedRegion(.trailing) {
                    Text(context.state.latestTimeString)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.top, 8)
                }

                DynamicIslandExpandedRegion(.bottom) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(context.state.isArrived ? "Telah sampai di tujuan!" : "Melewati:")
                            .font(.caption)
                            .foregroundColor(context.state.isArrived ? .green : .secondary)

                        Text(context.state.latestLandmarkName)
                            .font(.headline)
                            .lineLimit(2)
                    }
                    .padding(.bottom, 8)
                }
            } compactLeading: {
                Image(systemName: "figure.walk")
                    .foregroundColor(.blue)
            } compactTrailing: {
                Image(systemName: context.state.isArrived ? "checkmark.circle.fill" : "location.fill")
                    .foregroundColor(context.state.isArrived ? .green : .blue)
            } minimal: {
                Image(systemName: "figure.walk")
                    .foregroundColor(.blue)
            }
        }
    }
}
