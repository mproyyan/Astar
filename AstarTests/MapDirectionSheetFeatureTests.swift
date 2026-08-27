import ComposableArchitecture
import Testing
import CoreLocation
import MapKit
import Foundation
@testable import Astar

struct MapDirectionSheetFeatureTests {
  @Test
  @MainActor
  func testCancelDirectionsTapped() async {
    let dest = SavedPlace(name: "Dest", subtitle: "Sub", iconName: "star", coordinate: CLLocationCoordinate2D(latitude: 0, longitude: 0))
    let store = TestStore(initialState: MapDirectionSheetFeature.State(destination: dest)) {
      MapDirectionSheetFeature()
    } withDependencies: {
      $0.trackingClient = .testValue
    }

    await store.send(.cancelDirectionsTapped)
    await store.receive(.delegate(.navigationEnded))
  }

  @Test
  @MainActor
  func testStartNavigationTapped() async {
    let dest = SavedPlace(name: "Dest", subtitle: "Sub", iconName: "star", coordinate: CLLocationCoordinate2D(latitude: 0, longitude: 0))
    let coord = CLLocationCoordinate2D(latitude: 1, longitude: 1)
    let store = TestStore(initialState: MapDirectionSheetFeature.State(destination: dest)) {
      MapDirectionSheetFeature()
    } withDependencies: {
      $0.uuid = .incrementing
      $0.trackingClient = .testValue
    }

    await store.send(.startNavigationTapped(currentLocation: coord)) {
      $0.isNavigating = true
      $0.isDestinationReached = false
      $0.activeRoute = nil
      $0.mode = .progress
      let originAddress = "Current Location"
      let streetName = "Current Location"
      let startTimeString = DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .short)
      let startEntry = JourneyLogEntry(
        id: UUID(0),
        landmarkName: "Start Position",
        address: originAddress,
        timeString: startTimeString,
        iconName: "figure.walk.motion",
        entryType: .start,
        coordinate: coord
      )
      let currentEntry = JourneyLogEntry(
        id: UUID(1),
        landmarkName: "Near \(streetName)",
        address: originAddress,
        timeString: "Now",
        iconName: "location.fill",
        entryType: .currentLocation,
        coordinate: coord
      )
      $0.journeyLogEntries = [currentEntry, startEntry]
    }
    await store.receive(.delegate(.routeChanged(nil)))
    await store.receive(.delegate(.navigationStarted(sessionID: nil)))
  }
}
