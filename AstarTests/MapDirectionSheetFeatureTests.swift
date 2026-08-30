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

  @Test
  @MainActor
  func testOnAppearPreservesValidDestinationCoordinate() async {
    let cibuburCoord = CLLocationCoordinate2D(latitude: -6.3725, longitude: 106.9015)
    let dest = SavedPlace(
      name: "Kopi Kenangan Cibubur Drive Thru",
      subtitle: "Cibubur, East Jakarta",
      iconName: "cup.and.saucer.fill",
      coordinate: cibuburCoord
    )
    let origin = CLLocationCoordinate2D(latitude: -6.2088, longitude: 106.8456)
    let sampleRouteInfo = WalkingRouteInfo(
      travelTimeString: "4 hr 20 min",
      etaString: "15.20 ETA",
      distanceString: "22.0 km",
      rawTravelTime: 16000,
      rawDistanceMeters: 22000,
      route: nil,
      fallbackPolyline: nil
    )

    let store = TestStore(initialState: MapDirectionSheetFeature.State(destination: dest)) {
      MapDirectionSheetFeature()
    } withDependencies: {
      $0.uuid = .incrementing
      $0.directionRoute.reverseGeocode = { _ in "Sudirman, Central Jakarta" }
      $0.directionRoute.calculateWalkingRoute = { _, _ in sampleRouteInfo }
    }
    store.exhaustivity = .off

    await store.send(MapDirectionSheetFeature.Action.onAppear(currentLocation: origin))

    await store.receive(\.destinationResolved) {
      #expect($0.destination.coordinate?.latitude == cibuburCoord.latitude)
      #expect($0.destination.coordinate?.longitude == cibuburCoord.longitude)
    }

    await store.receive(\.routeCalculated)
  }
}
