//
//  SearchResultRow.swift
//  Astar
//
//  Created by Dimas Prihady Setyawan on 25/08/26.
//

import SwiftUI

struct SearchResultRow: View {
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
                            Image(systemName: place.resolvedIconName)
                                .font(.body.weight(.semibold))
                                .foregroundStyle(.white)
                        }
                        .frame(width: 40, height: 40)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(place.name)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.primary)

                        HStack(spacing: 6) {
                            if let distance = place.distance, !distance.isEmpty {
                                Text(distance)
                                    .font(.caption.weight(.medium))
                                    .foregroundStyle(.secondary)

                                Circle()
                                    .fill(Color.secondary.opacity(0.6))
                                    .frame(width: 3.5, height: 3.5)
                            }

                            Text(place.subtitle)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
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
    SearchResultRow(
        place: SavedPlace(
            name: "Autograph Tower",
            subtitle: "Thamrin Nine, Jl. M.H. Thamrin No. 10, Central Jakarta",
            iconName: "building.2.fill",
            distance: "250 m"
        ),
        isFirst: true,
        isLast: false
    )
    .padding()
}
