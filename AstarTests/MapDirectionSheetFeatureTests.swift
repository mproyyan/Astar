import ComposableArchitecture
import Testing
import CoreLocation
import MapKit
import Foundation
@testable import Astar

@Suite(.serialized)
struct MapDirectionSheetFeatureTests {
  @Test
  @MainActor
  func testCancelDirectionsTapped() async {
    let dest = SavedPlace(name: "Dest", subtitle: "Sub", iconName: "star", coordinate: CLLocationCoordinate2D(latitude: 0, longitude: 0))
    let store = TestStore(initialState: MapDirectionSheetFeature.State(destination: dest)) {
      MapDirectionSheetFeature()
    } withDependencies: {
      $0.trackingClient.updateUserStatus = { _, _, _, _ in }
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
      $0.trackingClient.startWalkSession = { _, _, _, _, _ in
        WalkSession(
          id: "session-1",
          walkerRef: "ref",
          status: "active",
          destinationName: "Dest",
          destinationLatitude: 0,
          destinationLongitude: 0,
          routePolyline: nil,
          startedAt: Date(timeIntervalSince1970: 0),
          endedAt: nil,
          lastPingAt: Date(timeIntervalSince1970: 0)
        )
      }
      $0.trackingClient.updateUserStatus = { _, _, _, _ in }
    }

    await store.send(.startNavigationTapped(currentLocation: coord)) {
      $0.isNavigating = true
      $0.isDestinationReached = false
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
    if UserProfileStorage.load() != nil {
      await store.receive(.delegate(.navigationStarted(sessionID: "session-1")))
    } else {
      await store.receive(.delegate(.navigationStarted(sessionID: nil)))
    }
  }

  @Test
  @MainActor
  func testSimulateArrivalTapped() async {
    let dest = SavedPlace(name: "Home", subtitle: "123 Main St", iconName: "house.fill", coordinate: CLLocationCoordinate2D(latitude: -6.2, longitude: 106.8))
    let store = TestStore(initialState: MapDirectionSheetFeature.State(destination: dest, mode: .progress)) {
      MapDirectionSheetFeature()
    } withDependencies: {
      $0.uuid = .incrementing
      $0.trackingClient.updateUserStatus = { _, _, _, _ in }
    }

    await store.send(.simulateArrivalTapped) {
      $0.isDestinationReached = true
      let timeString = DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .short)
      let destEntry = JourneyLogEntry(
        id: UUID(0),
        landmarkName: "Destination: Home",
        address: "123 Main St",
        timeString: timeString,
        iconName: "house.fill",
        entryType: .destination,
        coordinate: dest.coordinate
      )
      let intermediateEntry = JourneyLogEntry(
        id: UUID(1),
        landmarkName: "Passed Jl. M.H. Thamrin",
        address: "Central Jakarta",
        timeString: timeString,
        iconName: "figure.walk",
        entryType: .checkpoint,
        coordinate: nil
      )
      $0.journeyLogEntries = [destEntry, intermediateEntry]
    }
  }
}
