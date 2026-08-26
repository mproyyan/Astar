//
//  DirectionRow.swift
//  Astar
//
//  Created by Dimas Prihady Setyawan on 25/08/26.
//

import SwiftUI

struct DirectionRow: View {
    let place: SavedPlace
    let isFirst: Bool
    let isLast: Bool

    var body: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(place.categoryColor)
                .overlay {
                    Image(systemName: place.iconName)
                        .font(.body.weight(.semibold))
                        .foregroundStyle(.white)
                }
                .frame(width: 40, height: 40)

            VStack(alignment: .leading, spacing: 4) {
                Text(place.name)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)

                if !place.subtitle.isEmpty {
                    Text(place.subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 8)

            Button {
            } label: {
                Image(systemName: "ellipsis")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .frame(width: 34, height: 34)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Options")
        }
        .padding(.top, isFirst ? 16 : 8)
        .padding(.bottom, isLast ? 8 : 16)
    }
}

#Preview {
    VStack {
        DirectionRow(
            place: SavedPlace(name: "Current Location", subtitle: "Bendungan Hilir, South Jakarta", iconName: "location.fill"),
            isFirst: true,
            isLast: false
        )

        DirectionRow(
            place: SavedPlace(name: "Autograph Tower", subtitle: "Thamrin Nine, Jl. M.H. Thamrin No. 10, Central Jakarta", iconName: "building.2.fill", distance: "250 m"),
            isFirst: false,
            isLast: true
        )
    }
    .padding()
}
