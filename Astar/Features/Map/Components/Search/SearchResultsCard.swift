//
//  SearchResultsCard.swift
//  Astar
//
//  Created by Dimas Prihady Setyawan on 25/08/26.
//

import SwiftUI

struct SearchResultsCard: View {
    let places: [SavedPlace]
    var onSelectPlace: ((SavedPlace) -> Void)? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Search Results")
                .font(.title3.weight(.semibold))
                .foregroundStyle(.primary)

            VStack(spacing: 0) {
                ForEach(places.enumerated(), id: \.element.id) { index, place in
                    SearchResultRow(
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
    SearchResultsCard(places: MapSampleData.allSearchablePlaces)
        .padding()
}
