//
//  WalkerCardHistoryList.swift
//  Astar
//
//  Created by Dimas Prihady Setyawan on 25/08/26.
//

import SwiftUI

struct WalkerCardHistoryList: View {
    var sections: [WalkerHistorySection] = WalkerSampleData.defaultHistorySections
    var onDismiss: (() -> Void)? = nil
    var onSelectTrip: ((WalkerHistoryTrip) -> Void)? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Header Bar
            HStack {
                Spacer()

                Text("History")
                    .font(.title3.weight(.bold))
                    .foregroundStyle(.primary)

                Spacer()
            }
            .overlay(alignment: .trailing) {
                Button {
                    onDismiss?()
                } label: {
                    Image(systemName: "xmark")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(.primary)
                        .frame(width: 36, height: 36)
                }
                .buttonStyle(.plain)
                .glassEffect(.regular.interactive(), in: .circle)
                .accessibilityLabel("Close")
            }

            // Time Sections
            ForEach(sections) { section in
                VStack(alignment: .leading, spacing: 10) {
                    Text(section.title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)

                    VStack(spacing: 0) {
                        ForEach(Array(section.trips.enumerated()), id: \.element.id) { index, trip in
                            Button {
                                onSelectTrip?(trip)
                            } label: {
                                HStack(spacing: 16) {
                                    // Icon
                                    Circle()
                                        .fill(trip.iconColor)
                                        .frame(width: 32, height: 32)
                                        .overlay {
                                            Image(systemName: trip.iconName)
                                                .font(.system(size: 15, weight: .semibold))
                                                .foregroundStyle(.white)
                                        }

                                    // Text Info
                                    VStack(alignment: .leading, spacing: 3) {
                                        Text(trip.destinationName)
                                            .font(.headline.weight(.semibold))
                                            .foregroundStyle(.primary)

                                        HStack(spacing: 4) {
                                            Text(trip.dateString)
                                            Text("•")
                                            Text("\(trip.durationString), 1.4km")
                                        }
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(1)
                                    }

                                    Spacer(minLength: 0)

                                    Image(systemName: "chevron.right")
                                        .font(.footnote.weight(.semibold))
                                        .foregroundStyle(Color(UIColor.tertiaryLabel))
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 14)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)

                            if index < section.trips.count - 1 {
                                Divider()
                                    .padding(.leading, 64)
                            }
                        }
                    }
                    .background(Color.white, in: .rect(cornerRadius: 16))
                }
            }
        }
        .padding(.top, 8)
    }
}

#Preview {
    ScrollView {
        WalkerCardHistoryList()
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
    }
    .background(Color(red: 0.95, green: 0.95, blue: 0.97))
}
