import ComposableArchitecture
import Testing
import CoreLocation
import MapKit
@testable import Astar

struct MainMapFeatureTests {
  @Test
  @MainActor
  func testOnAppearAndLocationAuthorization() async {
    let authStream = AsyncStream.makeStream(of: CLAuthorizationStatus.self)
    let locationStream = AsyncStream.makeStream(of: CLLocationCoordinate2D.self)
    let errorStream = AsyncStream.makeStream(of: Error.self)
    
    let store = TestStore(initialState: MainMapFeature.State()) {
      MainMapFeature()
    } withDependencies: {
      $0.locationManager.authorizationStatus = { authStream.stream }
      $0.locationManager.locationUpdates = { locationStream.stream }
      $0.locationManager.errorUpdates = { errorStream.stream }
      $0.locationManager.requestWhenInUseAuthorization = {}
      $0.locationManager.requestLocation = {}
    }
    
    await store.send(.onAppear)
    await store.receive(.requestLocation)

    authStream.continuation.yield(.authorizedWhenInUse)
    
    await store.receive(.locationManager(.didChangeAuthorization(.authorizedWhenInUse))) {
      $0.authorizationStatus = .authorizedWhenInUse
    }
    
    let location = CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194)
    locationStream.continuation.yield(location)
    
    await store.receive(.locationManager(.didUpdateLocation(location))) {
      $0.currentLocation = location
    }
    
    await store.receive(.delegate(.locationUpdated(location)))
    
    authStream.continuation.finish()
    locationStream.continuation.finish()
    errorStream.continuation.finish()
    await store.finish()
  }

  @Test
  @MainActor
  func testSearchTapped() async {
    let location = CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194)
    let store = TestStore(initialState: MainMapFeature.State(currentLocation: location)) {
      MainMapFeature()
    }

    await store.send(.searchTapped) {
      $0.sheet = .search(MapSearchSheetFeature.State(userLocation: location))
    }
  }

  @Test
  @MainActor
  func testSelectPerson() async {
    let store = TestStore(initialState: MainMapFeature.State()) {
      MainMapFeature()
    }

    let person = Person(
        name: "Test Person",
        status: "Walking"
    )

    await store.send(.selectPerson(person)) {
      $0.sheet = .walker(MapWalkerSheetFeature.State(walker: person, status: person.status))
    }
  }

  @Test
  @MainActor
  func testStartAlwaysHomeNavigation() async {
    let homePlace = MapSampleData.savedPlaces.first(where: { $0.name == "Home" })!
    let mockCoord = CLLocationCoordinate2D(latitude: -6.2088, longitude: 106.8456)
    let mockRouteInfo = WalkingRouteInfo(
      travelTimeString: "15 min",
      etaString: "10.30 ETA",
      distanceString: "1.2 km",
      rawTravelTime: 900,
      rawDistanceMeters: 1200,
      route: nil
    )

    let store = TestStore(initialState: MainMapFeature.State()) {
      MainMapFeature()
    } withDependencies: {
      $0.uuid = .incrementing
      $0.locationManager.getCurrentLocation = { mockCoord }
      $0.directionRoute.reverseGeocode = { _ in "Jl. Sudirman, Central Jakarta" }
      $0.directionRoute.calculateWalkingRoute = { _, _ in mockRouteInfo }
    }

    await store.send(.startAlwaysHomeNavigation) {
      $0.isFollowingUser = true
      $0.isNavigating = true
      $0.sheet = .direction(MapDirectionSheetFeature.State(
        destination: homePlace,
        mode: .progress,
        originPlace: SavedPlace(
          id: UUID(0),
          name: "Current Location",
          subtitle: "Locating current area...",
          iconName: "location.fill",
          coordinate: nil
        ),
        isCalculatingRoute: true,
        isNavigating: true
      ))
    }

    await store.receive(\.directNavigationReady) {
      $0.currentLocation = mockCoord
      $0.activeRoute = nil
      $0.lastLoggedCoordinate = mockCoord
      $0.lastLoggedStreet = "Jl. Sudirman"
      $0.lastLoggedIcon = "figure.walk"
      let streetName = "Jl. Sudirman"
      let startTimeString = DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .short)
      let startEntry = JourneyLogEntry(
        id: UUID(1),
        landmarkName: "Start Position",
        address: "Jl. Sudirman, Central Jakarta",
        timeString: startTimeString,
        iconName: "figure.walk.motion",
        entryType: .start,
        coordinate: mockCoord
      )
      let currentEntry = JourneyLogEntry(
        id: UUID(2),
        landmarkName: "Near \(streetName)",
        address: "Jl. Sudirman, Central Jakarta",
        timeString: "Now",
        iconName: "location.fill",
        entryType: .currentLocation,
        coordinate: mockCoord
      )
      let originPlace = SavedPlace(
        id: UUID(3),
        name: "Current Location",
        subtitle: "Jl. Sudirman, Central Jakarta",
        iconName: "location.fill",
        coordinate: mockCoord
      )
      let expectedDest = SavedPlace(
        id: homePlace.id,
        name: homePlace.name,
        subtitle: homePlace.subtitle,
        iconName: homePlace.iconName,
        distance: mockRouteInfo.distanceString,
        coordinate: homePlace.coordinate
      )
      $0.sheet = .direction(MapDirectionSheetFeature.State(
        destination: expectedDest,
        mode: .progress,
        originPlace: originPlace,
        activeRoute: nil,
        walkingRouteInfo: mockRouteInfo,
        isCalculatingRoute: false,
        isNavigating: true,
        isDestinationReached: false,
        journeyLogEntries: [currentEntry, startEntry]
      ))
    }
  }

  @Test
  @MainActor
  func testStartDirectNavigationOffice() async {
    let autographPlace = MapSampleData.allSearchablePlaces.first(where: { $0.name == "Autograph Tower" })!
    let mockCoord = CLLocationCoordinate2D(latitude: -6.2088, longitude: 106.8456)
    let mockRouteInfo = WalkingRouteInfo(
      travelTimeString: "12 min",
      etaString: "10.25 ETA",
      distanceString: "888 m",
      rawTravelTime: 720,
      rawDistanceMeters: 888,
      route: nil
    )

    let store = TestStore(initialState: MainMapFeature.State()) {
      MainMapFeature()
    } withDependencies: {
      $0.uuid = .incrementing
      $0.locationManager.getCurrentLocation = { mockCoord }
      $0.directionRoute.reverseGeocode = { _ in "Jl. M.H. Thamrin, Central Jakarta" }
      $0.directionRoute.calculateWalkingRoute = { _, _ in mockRouteInfo }
    }

    await store.send(.startDirectNavigation(destinationQuery: "Office")) {
      $0.isFollowingUser = true
      $0.isNavigating = true
      $0.sheet = .direction(MapDirectionSheetFeature.State(
        destination: autographPlace,
        mode: .progress,
        originPlace: SavedPlace(
          id: UUID(0),
          name: "Current Location",
          subtitle: "Locating current area...",
          iconName: "location.fill",
          coordinate: nil
        ),
        isCalculatingRoute: true,
        isNavigating: true
      ))
    }

    await store.receive(\.directNavigationReady) {
      $0.currentLocation = mockCoord
      $0.activeRoute = nil
      $0.lastLoggedCoordinate = mockCoord
      $0.lastLoggedStreet = "Jl. M.H. Thamrin"
      $0.lastLoggedIcon = "figure.walk"
      let streetName = "Jl. M.H. Thamrin"
      let startTimeString = DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .short)
      let startEntry = JourneyLogEntry(
        id: UUID(1),
        landmarkName: "Start Position",
        address: "Jl. M.H. Thamrin, Central Jakarta",
        timeString: startTimeString,
        iconName: "figure.walk.motion",
        entryType: .start,
        coordinate: mockCoord
      )
      let currentEntry = JourneyLogEntry(
        id: UUID(2),
        landmarkName: "Near \(streetName)",
        address: "Jl. M.H. Thamrin, Central Jakarta",
        timeString: "Now",
        iconName: "location.fill",
        entryType: .currentLocation,
        coordinate: mockCoord
      )
      let originPlace = SavedPlace(
        id: UUID(3),
        name: "Current Location",
        subtitle: "Jl. M.H. Thamrin, Central Jakarta",
        iconName: "location.fill",
        coordinate: mockCoord
      )
      let expectedDest = SavedPlace(
        id: autographPlace.id,
        name: autographPlace.name,
        subtitle: autographPlace.subtitle,
        iconName: autographPlace.iconName,
        distance: mockRouteInfo.distanceString,
        coordinate: autographPlace.coordinate
      )
      $0.sheet = .direction(MapDirectionSheetFeature.State(
        destination: expectedDest,
        mode: .progress,
        originPlace: originPlace,
        activeRoute: nil,
        walkingRouteInfo: mockRouteInfo,
        isCalculatingRoute: false,
        isNavigating: true,
        isDestinationReached: false,
        journeyLogEntries: [currentEntry, startEntry]
      ))
    }
  }
}
