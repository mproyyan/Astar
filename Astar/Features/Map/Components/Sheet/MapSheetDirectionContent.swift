/// ============================================================================
/// 🧭 DIRECTION CONTENT DRAWER (MapSheetDirectionContent)
/// ============================================================================
///
/// 💡 COMPUTER SCIENCE CONCEPTS:
/// - **State-Driven Flow Control**:
///   Renders either the pre-trip route calculation card, the live navigation progress card, or the
///   detailed journey log list depending on the direction feature's internal mode.
///
/// 🌍 REAL-LIFE ANALOGY:
///   Think of an airline passenger boarding pass screen that automatically flips from "Gate & Flight Info"
///   to "In-Flight Progress Bar" once the plane takes off.
/// ============================================================================
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
        .onAppear {
            if store.walkingRouteInfo == nil && !store.isCalculatingRoute {
                let origin = currentLocation ?? CLLocationCoordinate2D(latitude: -6.2088, longitude: 106.8456)
                store.send(.onAppear(currentLocation: origin))
            }
        }
    }
}
