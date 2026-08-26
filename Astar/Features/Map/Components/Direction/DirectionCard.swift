//
//  DirectionCard.swift
//  Astar
//
//  Created by Dimas Prihady Setyawan on 25/08/26.
//

import SwiftUI

struct DirectionCard: View {
    var origin: SavedPlace = SavedPlace(
        name: "Current Location",
        subtitle: "Bendungan Hilir, South Jakarta",
        iconName: "location.fill"
    )
    var destination: SavedPlace = SavedPlace(
        name: "Autograph Tower",
        subtitle: "Thamrin Nine, Jl. M.H. Thamrin No. 10, Central Jakarta",
        iconName: "building.2.fill",
        distance: "250 m"
    )
    var walkingRoute: WalkingRouteInfo? = nil
    var isLoadingRoute: Bool = false
    let onCancel: () -> Void
    var onStartNavigation: (() -> Void)? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack {
                Text("Directions")
                    .font(.title.weight(.bold))
                    .foregroundStyle(.primary)

                Spacer()

                Button(action: onCancel) {
                    Image(systemName: "xmark")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(.primary)
                        .frame(width: 40, height: 40)
                }
                .buttonStyle(.plain)
                .glassEffect(.regular.interactive(), in: .circle)
                .accessibilityLabel("Cancel directions")
            }

            VStack(spacing: 0) {
                DirectionRow(
                    place: origin,
                    isFirst: true,
                    isLast: false
                )

                ZStack(alignment: .leading) {
                    Divider()
                        .padding(.leading, 52)
                        .opacity(0.5)

                    Capsule()
                        .fill(Color(red: 0.67, green: 0.72, blue: 0.93))
                        .frame(width: 4, height: 20)
                        .frame(width: 40)
                }

                DirectionRow(
                    place: destination,
                    isFirst: false,
                    isLast: false
                )

                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        if isLoadingRoute {
                            Text("Calculating...")
                                .font(.title3.weight(.semibold))
                                .foregroundStyle(.secondary)
                        } else {
                            Text(walkingRoute?.travelTimeString ?? "12 min")
                                .font(.title3.weight(.semibold))
                                .foregroundStyle(.primary)
                        }

                        HStack(spacing: 6) {
                            Text(walkingRoute?.etaString ?? "--.-- ETA")
                                .font(.callout)
                                .foregroundStyle(.secondary)

                            Circle()
                                .fill(Color.secondary.opacity(0.6))
                                .frame(width: 4, height: 4)

                            Text(walkingRoute?.distanceString ?? destination.distance ?? "-- km")
                                .font(.callout)
                                .foregroundStyle(.secondary)
                        }
                    }

                    Spacer(minLength: 8)

                    Button {
                        onStartNavigation?()
                    } label: {
                        Text("GO")
                            .font(.headline.weight(.bold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 16)
                            .background(Color.green, in: .capsule)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Start navigation")
                }
                .padding(.top, 16)
                .padding(.bottom, 20)
                .padding(.horizontal, 2)

                Divider()
                    .opacity(0.5)

                Text("Trusted contacts will watch over you once they accept your request.")
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(.gray)
                    .multilineTextAlignment(.center)
                    .padding(.top, 16)
                    .padding(.bottom, 8)
                    .padding(.horizontal, 20)
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

#Preview {
    DirectionCard(
        walkingRoute: WalkingRouteInfo(
            travelTimeString: "14 min",
            etaString: "11.02 ETA",
            distanceString: "850 m",
            rawTravelTime: 840,
            rawDistanceMeters: 850
        ),
        onCancel: {}
    )
    .padding()
    .background(Color(red: 0.95, green: 0.95, blue: 0.97))
}
