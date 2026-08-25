//
//  DirectionJourneyLogRow.swift
//  Astar
//
//  Created by Dimas Prihady Setyawan on 25/08/26.
//

import SwiftUI

struct DirectionJourneyLogRow: View {
    let entry: JourneyLogEntry
    let isFirst: Bool
    let isLast: Bool

    private var iconBackgroundColor: Color {
        switch entry.entryType {
        case .start:
            return .red
        case .destination:
            return .green
        case .currentLocation:
            return .blue
        case .checkpoint:
            return Color(red: 0.78, green: 0.82, blue: 0.97).opacity(0.92)
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
    VStack(spacing: 0) {
        DirectionJourneyLogRow(
            entry: JourneyLogSampleData.doneEntries[0],
            isFirst: true,
            isLast: false
        )
        Divider()
        DirectionJourneyLogRow(
            entry: JourneyLogSampleData.doneEntries[4],
            isFirst: false,
            isLast: true
        )
    }
    .padding()
}
