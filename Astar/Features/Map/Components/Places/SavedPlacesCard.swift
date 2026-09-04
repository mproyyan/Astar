//
//  SavedPlacesCard.swift
//  Astar
//
//  Created by Dimas Prihady Setyawan on 25/08/26.
//

import SwiftUI
import ComposableArchitecture

struct SavedPlacesCard: View {
    let title: String
    let places: [SavedPlace]
    var onSelectPlace: ((SavedPlace) -> Void)? = nil
    var onHeaderTap: (() -> Void)? = nil

    init(
        title: String,
        places: [SavedPlace],
        onSelectPlace: ((SavedPlace) -> Void)? = nil,
        onHeaderTap: (() -> Void)? = nil
    ) {
        self.title = title
        self.places = places
        self.onSelectPlace = onSelectPlace
        self.onHeaderTap = onHeaderTap
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            if title == "Saved Places" || title == "Saved" {
                Button {
                    onHeaderTap?()
                } label: {
                    HStack(spacing: 4) {
                        Text(title)
                            .font(.title3.weight(.semibold))
                            .foregroundStyle(.primary)

                        Image(systemName: "chevron.right")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.secondary)

                        Spacer(minLength: 0)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            } else {
                Text(title)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.primary)
            }


            VStack(spacing: 0) {
                ForEach(places.enumerated(), id: \.element.id) { index, place in
                    SavedPlaceRow(
                        place: place,
                        isFirst: index == 0,
                        isLast: index == places.count - 1,
                        onSelect: {
                            onSelectPlace?(place)
                        }
                    )

                    if index < places.count - 1 {
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

#Preview {
    SavedPlacesCard(title: "Search Results", places: MapSampleData.savedPlaces)
        .padding()
}
