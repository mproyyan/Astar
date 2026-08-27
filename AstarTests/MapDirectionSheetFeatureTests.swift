import ComposableArchitecture
import Testing
import CoreLocation
import MapKit
@testable import Astar

struct MapDirectionSheetFeatureTests {
  @Test
  @MainActor
  func testCancelDirectionsTapped() async {
    let dest = SavedPlace(name: "Dest", subtitle: "Sub", iconName: "star", coordinate: CLLocationCoordinate2D(latitude: 0, longitude: 0))
    let store = TestStore(initialState: MapDirectionSheetFeature.State(destination: dest)) {
      MapDirectionSheetFeature()
    }

    await store.send(.cancelDirectionsTapped)
    await store.receive(\.delegate.navigationEnded)
  }

  @Test
  @MainActor
  func testStartNavigationTapped() async {
    let dest = SavedPlace(name: "Dest", subtitle: "Sub", iconName: "star", coordinate: CLLocationCoordinate2D(latitude: 0, longitude: 0))
    let store = TestStore(initialState: MapDirectionSheetFeature.State(destination: dest)) {
      MapDirectionSheetFeature()
    }

    await store.send(.startNavigationTapped(currentLocation: CLLocationCoordinate2D(latitude: 1, longitude: 1))) {
      $0.isNavigating = true
      $0.walkingRouteInfo = nil
    }
    await store.receive(\.delegate.navigationStarted)
  }
}
