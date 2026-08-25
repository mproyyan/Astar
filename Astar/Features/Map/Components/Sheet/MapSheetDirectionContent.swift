//
//  MapSheetDirectionContent.swift
//  Astar
//
//  Created by Dimas Prihady Setyawan on 25/08/26.
//

import SwiftUI

struct MapSheetDirectionContent: View {
    var origin: SavedPlace = SavedPlace(
        name: "Current Location",
        subtitle: "Bendungan Hilir, South Jakarta",
        iconName: "location.fill"
    )
    let destination: SavedPlace
    let onCancel: () -> Void
    var onStartNavigation: (() -> Void)? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            DirectionCard(
                origin: origin,
                destination: destination,
                onCancel: onCancel,
                onStartNavigation: onStartNavigation
            )
            .padding(.top, 8)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16)
        .padding(.top, 12)
    }
}

#Preview {
    MapSheetDirectionContent(
        destination: MapSampleData.savedPlaces[0],
        onCancel: {}
    )
}
