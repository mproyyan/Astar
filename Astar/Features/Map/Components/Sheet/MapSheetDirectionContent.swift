//
//  MapSheetDirectionContent.swift
//  Astar
//
//  Created by Dimas Prihady Setyawan on 25/08/26.
//

import ComposableArchitecture
import CoreLocation
import MapKit
import SwiftUI

struct MapSheetDirectionContent: View {
    @Bindable var store: StoreOf<MainFeature>
    let onCancel: () -> Void
    var onStartNavigation: (() -> Void)? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            if let destination = store.map.selectedDestination {
                let defaultOrigin = SavedPlace(
                    name: "Current Location",
                    subtitle: "Locating current area...",
                    iconName: "location.fill",
//                    coordinate: store.map.currentLocation
                    latitude: store.map.currentLocation?.latitude,
                    longitude: store.map.currentLocation?.longitude
                )

                DirectionCard(
                    origin: store.map.originPlace ?? defaultOrigin,
                    destination: destination,
                    walkingRoute: store.map.walkingRouteInfo,
                    isLoadingRoute: store.map.isCalculatingRoute,
                    onCancel: {
                        store.send(.map(.cancelDirectionsTapped))
                        onCancel()
                    },
                    onStartNavigation: {
                        store.send(.map(.startNavigationTapped))
                        onStartNavigation?()
                    }
                )
                .padding(.top, 8)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16)
        .padding(.top, 12)
    }
}

#Preview {
    MapSheetDirectionContent(
        store: Store(initialState: MainFeature.State()) {
            MainFeature()
        },
        onCancel: {}
    )
}
