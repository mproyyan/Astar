//
//  SavedPlaceRow.swift
//  Astar
//
//  Created by Dimas Prihady Setyawan on 25/08/26.
//

import SwiftUI

struct SavedPlaceRow: View {
    let place: SavedPlace
    let isFirst: Bool
    let isLast: Bool
    var onSelect: (() -> Void)? = nil

    var body: some View {
        HStack(spacing: 12) {
            Button {
                onSelect?()
            } label: {
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

                        Text(place.subtitle)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }

                    Spacer(minLength: 8)
                }
            }
            .buttonStyle(.plain)

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
        .padding(.top, isFirst ? 20 : 16)
        .padding(.bottom, isLast ? 16 : 20)
    }
}

#Preview {
    SavedPlaceRow(
        place: SavedPlace(name: "Home", subtitle: "Bendungan Hilir, South Jakarta", iconName: "house.fill"),
        isFirst: true,
        isLast: false
    )
    .padding()
}
