import ComposableArchitecture
import CoreLocation
import MapKit
import SwiftUI

struct MapSheetDirectionContent: View {
    @Bindable var store: StoreOf<MapDirectionSheetFeature>
    let onCancel: () -> Void
    var onStartNavigation: (() -> Void)? = nil
    var currentLocation: CLLocationCoordinate2D? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            let destination = store.destination
            let defaultOrigin = SavedPlace(
                name: "Current Location",
                subtitle: "Locating current area...",
                iconName: "location.fill",
                coordinate: currentLocation
            )

            DirectionCard(
                origin: store.originPlace ?? defaultOrigin,
                destination: destination,
                walkingRoute: store.walkingRouteInfo,
                isLoadingRoute: store.isCalculatingRoute,
                onCancel: {
                    store.send(.cancelDirectionsTapped)
                    onCancel()
                },
                onStartNavigation: {
                    store.send(.startNavigationTapped(currentLocation: currentLocation))
                    onStartNavigation?()
                }
            )
            .padding(.top, 8)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16)
        .padding(.top, 12)
    }
}
