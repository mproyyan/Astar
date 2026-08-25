//
//  SavedSection.swift
//  Astar
//
//  Created by Dimas Prihady Setyawan on 25/08/26.
//

import SwiftUI

struct SavedSection: View {
    let savedPlaces: [SavedPlace]
    var onSelectPlace: ((SavedPlace) -> Void)? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 4) {
                Text("Saved")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.primary)

                Image(systemName: "chevron.right")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
            }

            VStack(spacing: 0) {
                ForEach(savedPlaces.enumerated(), id: \.element.id) { index, place in
                    SavedPlaceRow(
                        place: place,
                        isFirst: index == 0,
                        isLast: index == savedPlaces.count - 1,
                        onSelect: {
                            onSelectPlace?(place)
                        }
                    )

                    if index < savedPlaces.count - 1 {
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
    SavedSection(savedPlaces: MapSampleData.savedPlaces)
        .padding()
}
