//
//  WalkerCardHistoryDetail.swift
//  Astar
//
//  Created by Dimas Prihady Setyawan on 25/08/26.
//

import SwiftUI

struct WalkerCardHistoryDetail: View {
    var trip: WalkerHistoryTrip = WalkerSampleData.defaultTrips[0]
    var onDismiss: (() -> Void)? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header Bar
            HStack {
                Spacer()

                Text(trip.destinationName)
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

            // Date Subtitle
            Text("21 August 2026")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)

            // Stat Cards Row
            HStack(spacing: 12) {
                // Duration Card
                VStack(spacing: 4) {
                    HStack(spacing: 6) {
                        Image(systemName: "clock")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.primary)

                        Text(trip.durationString)
                            .font(.title3.weight(.bold))
                            .foregroundStyle(.primary)
                    }

                    Text("Duration")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(Color.white, in: .rect(cornerRadius: 16))

                // Distance Card
                VStack(spacing: 4) {
                    HStack(spacing: 6) {
                        Image(systemName: "point.topleft.down.to.point.bottomright.curvepath")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.primary)

                        Text(trip.distanceString)
                            .font(.title3.weight(.bold))
                            .foregroundStyle(.primary)
                    }

                    Text("Distance")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(Color.white, in: .rect(cornerRadius: 16))
            }

            // Milestones Timeline Card
            VStack(spacing: 0) {
                // 1. Destination Node
                HStack(spacing: 14) {
                    Circle()
                        .fill(Color.blue)
                        .frame(width: 32, height: 32)
                        .overlay {
                            Image(systemName: trip.iconName)
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(.white)
                        }

                    Text("Destination")
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(.primary)

                    Spacer()

                    Text("9:45 PM")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 16)
                .padding(.top, 16)
                .padding(.bottom, 8)

                // Connecting Line + Intermediate Checkpoint 1
                timelineSegment(title: "Near Plaza Indonesia", subtitle: "Walking north on Jl. M.H. Thamrin", time: "9:45 PM")

                // Connecting Line + Intermediate Checkpoint 2
                timelineSegment(title: "Near Plaza Indonesia", subtitle: "Walking north on Jl. M.H. Thamrin", time: "9:45 PM")

                // Connecting Line + Intermediate Checkpoint 3
                timelineSegment(title: "Near Plaza Indonesia", subtitle: "Walking north on Jl. M.H. Thamrin", time: "9:45 PM")

                // Connecting Line to Start
                HStack(spacing: 0) {
                    Rectangle()
                        .fill(Color.secondary.opacity(0.25))
                        .frame(width: 3, height: 16)
                        .padding(.leading, 30.5)
                    Spacer()
                }

                // Start Position Node
                HStack(spacing: 14) {
                    Circle()
                        .fill(Color.blue)
                        .frame(width: 32, height: 32)
                        .overlay {
                            Image(systemName: "mappin.fill")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(.white)
                        }

                    Text("Start position")
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(.primary)

                    Spacer()

                    Text("9:45 PM")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 16)
                .padding(.top, 4)
                .padding(.bottom, 16)
            }
            .background(Color.white, in: .rect(cornerRadius: 16))
        }
        .padding(.top, 8)
    }

    @ViewBuilder
    private func timelineSegment(title: String, subtitle: String, time: String) -> some View {
        VStack(spacing: 0) {
            // Connecting line above dot
            HStack(spacing: 0) {
                Rectangle()
                    .fill(Color.secondary.opacity(0.25))
                    .frame(width: 3, height: 16)
                    .padding(.leading, 30.5)
                Spacer()
            }

            // Dot row
            HStack(spacing: 14) {
                Circle()
                    .fill(Color(red: 0.85, green: 0.88, blue: 0.98))
                    .frame(width: 24, height: 24)
                    .padding(.leading, 4)

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)

                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer()

                Text(time)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 16)
        }
    }
}

#Preview {
    ScrollView {
        WalkerCardHistoryDetail()
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
    }
    .background(Color(red: 0.95, green: 0.95, blue: 0.97))
}
