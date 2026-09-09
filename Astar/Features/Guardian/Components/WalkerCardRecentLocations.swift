//
//  WalkerCardRecentLocations.swift
//  Astar
//
//  Created by Dimas Prihady Setyawan on 25/08/26.
//

import SwiftUI

struct WalkerCardRecentLocations: View {
    var locations: [JourneyLogEntry] = WalkerSampleData.awanLocations

    var sortedLocations: [JourneyLogEntry] {
        var current: [JourneyLogEntry] = []
        var checkpoints: [JourneyLogEntry] = []
        var starts: [JourneyLogEntry] = []

        for loc in locations {
            switch loc.entryType {
            case .currentLocation, .destination:
                current.append(loc)
            case .checkpoint:
                checkpoints.append(loc)
            case .start:
                starts.append(loc)
            }
        }

        var effectiveTop: [JourneyLogEntry] = []
        var demotedCheckpoints: [JourneyLogEntry] = []

        if let topEntry = current.first {
            effectiveTop = [topEntry]
            for extra in current.dropFirst() {
                let cleanLandmark = extra.landmarkName
                    .replacingOccurrences(of: "Near ", with: "")
                    .replacingOccurrences(of: "Passed ", with: "")
                let newTitle = "Passed \(cleanLandmark)"
                demotedCheckpoints.append(
                    JourneyLogEntry(
                        id: extra.id,
                        landmarkName: newTitle,
                        address: extra.address,
                        timeString: extra.timeString,
                        iconName: extra.iconName == "location.fill" ? "figure.walk" : extra.iconName,
                        entryType: .checkpoint,
                        coordinate: extra.coordinate
                    )
                )
            }
        }

        let sanitizedCheckpoints = (demotedCheckpoints + checkpoints).map { cp -> JourneyLogEntry in
            if cp.landmarkName.hasPrefix("Near ") {
                let cleanLandmark = cp.landmarkName.replacingOccurrences(of: "Near ", with: "")
                return JourneyLogEntry(
                    id: cp.id,
                    landmarkName: "Passed \(cleanLandmark)",
                    address: cp.address,
                    timeString: cp.timeString,
                    iconName: cp.iconName == "location.fill" ? "figure.walk" : cp.iconName,
                    entryType: .checkpoint,
                    coordinate: cp.coordinate
                )
            }
            return cp
        }

        let effectiveStarts = starts.prefix(1)

        return effectiveTop + sanitizedCheckpoints + effectiveStarts
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Recent locations")
                .font(.title3.weight(.semibold))
                .foregroundStyle(.primary)

            let entries = sortedLocations
            if !entries.isEmpty {
                VStack(spacing: 0) {
                    ForEach(entries.enumerated(), id: \.element.id) { index, entry in
                        WalkerRecentLocationRow(
                            entry: entry,
                            isFirst: index == 0,
                            isLast: index == entries.count - 1
                        )

                        if index < entries.count - 1 {
                            Divider()
                                .padding(.leading, 52)
                                .opacity(0.5)
                        }
                    }
                }
                .padding(.horizontal, 14)
                .background(.white, in: .rect(cornerRadius: 24))
                .overlay {
                    RoundedRectangle(cornerRadius: 24)
                        .stroke(Color.primary.opacity(0.06), lineWidth: 1)
                }
            }
        }
    }
}

struct WalkerRecentLocationRow: View {
    let entry: JourneyLogEntry
    let isFirst: Bool
    let isLast: Bool

    private var iconBackgroundColor: Color {
        switch entry.entryType {
        case .currentLocation:
            return .blue
        case .start:
            return .red
        case .destination:
            return .green
        case .checkpoint:
            return SavedPlace.categoryColor(for: entry.iconName)
        }
    }

    var body: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(iconBackgroundColor)
                .overlay {
                    Image(systemName: entry.iconName)
                        .font(.body.weight(.semibold))
                        .foregroundStyle(.white)
                }
                .frame(width: 40, height: 40)

            VStack(alignment: .leading, spacing: 4) {
                Text(entry.landmarkName)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)

                Text(entry.address)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 8)

            Text(entry.timeString)
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)
        }
        .padding(.top, isFirst ? 20 : 16)
        .padding(.bottom, isLast ? 20 : 16)
    }
}

#Preview {
    WalkerCardRecentLocations()
        .padding()
        .background(Color(red: 0.95, green: 0.95, blue: 0.97))
}
