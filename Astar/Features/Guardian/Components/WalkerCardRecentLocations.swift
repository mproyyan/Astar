//
//  WalkerCardRecentLocations.swift
//  Astar
//
//  Created by Dimas Prihady Setyawan on 25/08/26.
//

import SwiftUI

struct WalkerCardRecentLocations: View {
    var locations: [JourneyLogEntry] = WalkerSampleData.awanLocations

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Recent locations")
                .font(.title3.weight(.semibold))
                .foregroundStyle(.primary)

            VStack(spacing: 0) {
                ForEach(locations.enumerated(), id: \.element.id) { index, entry in
                    WalkerRecentLocationRow(
                        entry: entry,
                        isFirst: index == 0,
                        isLast: index == locations.count - 1
                    )

                    if index < locations.count - 1 {
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
            return Color(red: 0.15, green: 0.15, blue: 0.15)
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
