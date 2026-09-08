import ComposableArchitecture
import Testing
import CoreLocation
import MapKit
import SwiftUI
@testable import Astar

@Suite(.serialized)
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

    let saved = store.state.savedPlaces
    await store.send(.searchTapped) {
      $0.sheet = .search(MapSearchSheetFeature.State(userLocation: location, savedPlaces: saved))
    }
  }

  @Test
  @MainActor
  func testSearchDismissed() async {
    let location = CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194)
    let store = TestStore(initialState: MainMapFeature.State(
      currentLocation: location,
      sheet: .search(MapSearchSheetFeature.State(userLocation: location))
    )) {
      MainMapFeature()
    }

    await store.send(.sheet(.presented(.search(.delegate(.dismissed))))) {
      $0.sheet = nil
    }
  }

  @Test
  @MainActor
  func testDismissSearch() async {
    let location = CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194)
    let store = TestStore(initialState: MainMapFeature.State(
      currentLocation: location,
      sheet: .search(MapSearchSheetFeature.State(userLocation: location))
    )) {
      MainMapFeature()
    }

    #expect(store.state.isSearchActive == true)

    await store.send(.dismissSearch) {
      $0.sheet = nil
    }

    #expect(store.state.isSearchActive == false)
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
      $0.sheet = .walker(MapWalkerSheetFeature.State(walker: person, status: person.status, isDestinationReached: false))
    }
  }

  @Test
  @MainActor
  func testSelectPersonArrived() async {
    let store = TestStore(initialState: MainMapFeature.State()) {
      MainMapFeature()
    }

    let person = Person(
        name: "John Doe",
        status: "Arrived"
    )

    await store.send(.selectPerson(person)) {
      $0.sheet = .walker(MapWalkerSheetFeature.State(walker: person, status: person.status, isDestinationReached: true))
    }
  }

  @Test
  @MainActor
  func testSelectPersonAccompany() async {
    let store = TestStore(initialState: MainMapFeature.State()) {
      MainMapFeature()
    }

    let person = Person(
        name: "Companion Person",
        status: "accompany"
    )

    await store.send(.selectPerson(person)) {
      $0.sheet = .walker(MapWalkerSheetFeature.State(walker: person, status: person.status, isDestinationReached: false))
    }
  }

  @Test
  @MainActor
  func testStartAlwaysHomeNavigation() async {
    let now = Date(timeIntervalSince1970: 1000)
    let mockCoord = CLLocationCoordinate2D(latitude: -6.2088, longitude: 106.8456)
    let mockRouteInfo = WalkingRouteInfo(
      travelTimeString: "15 min",
      etaString: "10.30 ETA",
      distanceString: "1.2 km",
      rawTravelTime: 900,
      rawDistanceMeters: 1200,
      route: nil
    )

    DeveloperSettingsStorage.isDevelopmentMode = false
    let store = TestStore(initialState: MainMapFeature.State()) {
      MainMapFeature()
    } withDependencies: {
      $0.uuid = .incrementing
      $0.date.now = now
      $0.locationManager.getCurrentLocation = { mockCoord }
      $0.directionRoute.reverseGeocode = { _ in "Jl. Sudirman, Central Jakarta" }
      $0.directionRoute.calculateWalkingRoute = { _, _ in mockRouteInfo }
    }

    let homePlace = store.state.savedPlaces.first(where: { $0.isHome })!

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
      $0.lastLoggedTime = now
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
        coordinate: homePlace.coordinate,
        label: homePlace.label
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
    let now = Date(timeIntervalSince1970: 1000)
    let mockCoord = CLLocationCoordinate2D(latitude: -6.2088, longitude: 106.8456)
    let mockRouteInfo = WalkingRouteInfo(
      travelTimeString: "12 min",
      etaString: "10.25 ETA",
      distanceString: "888 m",
      rawTravelTime: 720,
      rawDistanceMeters: 888,
      route: nil
    )

    DeveloperSettingsStorage.isDevelopmentMode = false
    let store = TestStore(initialState: MainMapFeature.State()) {
      MainMapFeature()
    } withDependencies: {
      $0.uuid = .incrementing
      $0.date.now = now
      $0.locationManager.getCurrentLocation = { mockCoord }
      $0.directionRoute.reverseGeocode = { _ in "Jl. M.H. Thamrin, Central Jakarta" }
      $0.directionRoute.calculateWalkingRoute = { _, _ in mockRouteInfo }
    }

    let officePlace = store.state.savedPlaces.first(where: { $0.isOffice })!

    await store.send(.startDirectNavigation(destinationQuery: "Office")) {
      $0.isFollowingUser = true
      $0.isNavigating = true
      $0.sheet = .direction(MapDirectionSheetFeature.State(
        destination: officePlace,
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
      $0.lastLoggedTime = now
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
        id: officePlace.id,
        name: officePlace.name,
        subtitle: officePlace.subtitle,
        iconName: officePlace.iconName,
        distance: mockRouteInfo.distanceString,
        coordinate: officePlace.coordinate,
        label: officePlace.label
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
  func testSelectDoeWalking() async {
    let now = Date(timeIntervalSince1970: 1000)
    let store = TestStore(initialState: MainMapFeature.State()) {
      MainMapFeature()
    } withDependencies: {
      $0.date.now = now
    }

    let walkingDoe = Person(id: Person.mockDoeID, name: "Doe", status: "Walking")
    var expectedWalkerState = MapWalkerSheetFeature.State(
      walker: walkingDoe,
      status: "Walking",
      isDestinationReached: false
    )
    expectedWalkerState.originPlaceName = "Autograph Tower"
    expectedWalkerState.originIconName = "briefcase.fill"
    expectedWalkerState.destinationPlaceName = "Home"
    expectedWalkerState.destinationIconName = "house.fill"
    expectedWalkerState.journeyLogEntries = MockDoeWalkSimulation.journeyLogFromStartToFinish(now: now)
    expectedWalkerState.trips = []

    await store.send(.selectPerson(walkingDoe)) {
      $0.sheet = .walker(expectedWalkerState)
    }

    let entries = expectedWalkerState.journeyLogEntries
    #expect(entries.count == 6)
    #expect(entries.first?.entryType == .destination)
    #expect(entries.first?.landmarkName == "Destination: Home")
    #expect(entries.last?.entryType == .start)
    #expect(entries.last?.landmarkName == "Start: Autograph Tower")
  }

  @Test
  @MainActor
  func testMockDoeReachedDestination() async {
    let now = Date(timeIntervalSince1970: 1000)
    let initialWalker = Person(id: Person.mockDoeID, name: "Doe", status: "Walking")
    let store = TestStore(initialState: MainMapFeature.State(
      activeWalkSessionID: "mock-doe-session",
      trackedWalkerDestination: MockDoeWalkSimulation.destinationCoordinate,
      trackedWalkerPolyline: MockDoeWalkSimulation.fallbackPolyline,
      sheet: .walker(MapWalkerSheetFeature.State(
        walker: initialWalker,
        status: "Walking",
        isDestinationReached: false,
        activeParticipantID: "mock-doe-session"
      ))
    )) {
      MainMapFeature()
    } withDependencies: {
      $0.date.now = now
      $0.trackingClient.updateUserStatus = { _, _, _, _ in }
    }

    let idleWalker = Person(id: Person.mockDoeID, name: "Doe", status: "Idle")
    let completedTrip = MockDoeWalkSimulation.completedTrip(now: now)

    await store.send(.mockDoeReachedDestination) {
      $0.activeWalkSessionID = nil
      $0.trackedWalkerPolyline = nil
      $0.trackedWalkerRoute = nil
      $0.trackedWalkerDestination = nil
      $0.trackedWalkerLocation = MockDoeWalkSimulation.destinationCoordinate
      $0.mockDoeHistoryTrips = [completedTrip]
      var expectedWalkerState = MapWalkerSheetFeature.State(
        walker: idleWalker,
        status: "Idle",
        isDestinationReached: true,
        activeParticipantID: nil
      )
      expectedWalkerState.journeyLogEntries = MockDoeWalkSimulation.completedJourneyLog(now: now)
      expectedWalkerState.trips = [completedTrip]
      $0.sheet = .walker(expectedWalkerState)
    }

    await store.receive(.delegate(.walkerStatusChanged(id: Person.mockDoeID, newStatus: "Idle")))
    await store.receive(.delegate(.companionStatusChanged(newStatus: "idle")))
  }

  @Test
  @MainActor
  func testTrackingEndedRemovesGuidingLineAndContinuesSimulation() async {
    let initialWalker = Person(id: Person.mockDoeID, name: "Doe", status: "Walking")
    let store = TestStore(initialState: MainMapFeature.State(
      activeWalkSessionID: "mock-doe-session",
      trackedWalkerLocation: MockDoeWalkSimulation.originCoordinate,
      trackedWalkerDestination: MockDoeWalkSimulation.destinationCoordinate,
      trackedWalkerPolyline: MockDoeWalkSimulation.fallbackPolyline,
      sheet: .walker(MapWalkerSheetFeature.State(
        walker: initialWalker,
        status: "Walking",
        isDestinationReached: false,
        activeParticipantID: "mock-doe-session"
      ))
    )) {
      MainMapFeature()
    } withDependencies: {
      $0.trackingClient.updateUserStatus = { _, _, _, _ in }
      $0.trackingClient.setSubscribeWalkSession = { _, _ in }
      $0.trackingClient.updateParticipantStatus = { _, _, status in
        SessionParticipant(id: "p", sessionRef: "mock-doe-session", companionRef: "c", status: status)
      }
    }

    await store.send(.sheet(.presented(.walker(.delegate(.trackingEnded))))) {
      $0.activeWalkSessionID = nil
      $0.trackedWalkerDestination = nil
      $0.trackedWalkerRoute = nil
      $0.trackedWalkerPolyline = nil
      // trackedWalkerLocation is preserved
      $0.trackedWalkerLocation = MockDoeWalkSimulation.originCoordinate
    }

    await store.receive(.delegate(.companionStatusChanged(newStatus: "idle")))
  }

  @Test
  @MainActor
  func testRejoinWalkSessionWhenDoeAlreadyWalking() async {
    let walker = Person(id: Person.mockDoeID, name: "Doe", status: "Walking")
    let currentWalkLocation = CLLocationCoordinate2D(latitude: -6.2110, longitude: 106.8200)
    let mockSession = WalkSession(
      id: "mock-doe-session",
      walkerRef: "mock-doe",
      status: "active",
      destinationName: MockDoeWalkSimulation.destinationName,
      destinationLatitude: MockDoeWalkSimulation.destinationCoordinate.latitude,
      destinationLongitude: MockDoeWalkSimulation.destinationCoordinate.longitude,
      routePolyline: nil,
      startedAt: Date(),
      endedAt: nil,
      currentCoordinate: nil,
      lastPingAt: Date()
    )

    let now = Date(timeIntervalSince1970: 1000)
    let store = TestStore(initialState: MainMapFeature.State(
      activeWalkSessionID: nil,
      trackedWalkerLocation: currentWalkLocation,
      isMockDoeWalking: true,
      sheet: .walker(MapWalkerSheetFeature.State(
        walker: walker,
        status: "Walking",
        isDestinationReached: false,
        activeParticipantID: nil
      ))
    )) {
      MainMapFeature()
    } withDependencies: {
      $0.date.now = now
      $0.directionRoute.calculateWalkingRoute = { _, _ in
        WalkingRouteInfo(travelTimeString: "8 min", etaString: "11.00 ETA", distanceString: "500 m", rawTravelTime: 480, rawDistanceMeters: 500, route: nil)
      }
    }

    await store.send(.sheet(.presented(.walker(.delegate(.trackingStarted(walker, mockSession)))))) {
      $0.activeWalkSessionID = mockSession.id
      $0.trackedWalkerDestinationName = mockSession.destinationName
      $0.trackedWalkerDestination = CLLocationCoordinate2D(latitude: mockSession.destinationLatitude, longitude: mockSession.destinationLongitude)
      $0.hasFittedTrackedWalker = false
      $0.trackedWalkerAttributes = TrailWalkAttributes(
        sessionID: "mock-doe-session",
        walkerName: "Doe",
        originTitle: "Autograph Tower",
        destinationTitle: "Home"
      )
      $0.trackedWalkerLiveActivityState = TrailWalkAttributes.ContentState(
        step: "Walking",
        progressPercentage: 0.0,
        remainingDistanceMeters: 650.0,
        currentLandmark: "Home",
        estimatedArrivalDate: now.addingTimeInterval(6 * 60),
        expectedTravelTime: "6 min",
        isApproaching: false
      )
      // Doe is already walking: retains existing location and isMockDoeWalking flag
      $0.trackedWalkerLocation = currentWalkLocation
      $0.isMockDoeWalking = true
    }

    await store.receive(\.setTrackedWalkerRoute)
    await store.receive(\.setTrackedWalkerPolyline) {
      $0.trackedWalkerPolyline = MockDoeWalkSimulation.fallbackPolyline
    }
  }

  @Test
  @MainActor
  func testMockDoeSamplePointsFollowsPolyline() {
    let polyline = MockDoeWalkSimulation.fallbackPolyline
    let coords = polyline.coordinates
    #expect(!coords.isEmpty)
    #expect(abs(coords.first!.latitude - MockDoeWalkSimulation.originCoordinate.latitude) < 0.0001)
    #expect(abs(coords.last!.latitude - MockDoeWalkSimulation.destinationCoordinate.latitude) < 0.0001)

    let sampled = MockDoeWalkSimulation.samplePoints(from: polyline, targetCount: 10)
    #expect(sampled.count == 10)
    #expect(abs(sampled.first!.latitude - MockDoeWalkSimulation.originCoordinate.latitude) < 0.0001)
    #expect(abs(sampled.last!.latitude - MockDoeWalkSimulation.destinationCoordinate.latitude) < 0.0001)

    let completedLog = MockDoeWalkSimulation.completedJourneyLog()
    #expect(completedLog.count == 6)
    #expect(completedLog.first?.entryType == .destination)
    #expect(completedLog.last?.entryType == .start)
  }

  @Test
  @MainActor
  func testResetDoeWalking() async {
    let store = TestStore(initialState: MainMapFeature.State(
      trackedWalkerLocation: MockDoeWalkSimulation.originCoordinate,
      trackedWalkerDestination: MockDoeWalkSimulation.destinationCoordinate,
      hasFittedTrackedWalker: true
    )) {
      MainMapFeature()
    }

    await store.send(.resetDoeWalking) {
      // Preserves accurate location!
      $0.trackedWalkerDestination = nil
      $0.trackedWalkerRoute = nil
      $0.hasFittedTrackedWalker = false
    }

    await store.receive(.delegate(.walkerStatusChanged(id: Person.mockDoeID, newStatus: "Walking")))
  }

  @Test
  @MainActor
  func testSelectPersonDoeWhenAtHomeSetsReturnTripDestination() async {
    let doe = Person(id: Person.mockDoeID, name: "Doe", status: "Walking")
    let store = TestStore(initialState: MainMapFeature.State(
      trackedWalkerLocation: MockDoeWalkSimulation.destinationCoordinate
    )) {
      MainMapFeature()
    } withDependencies: {
      $0.date.now = Date(timeIntervalSince1970: 1000)
    }

    await store.send(.selectPerson(doe)) {
      var walkerState = MapWalkerSheetFeature.State(
        walker: doe,
        status: "Walking",
        isDestinationReached: false
      )
      walkerState.originPlaceName = "Home"
      walkerState.originIconName = "house.fill"
      walkerState.destinationPlaceName = "Autograph Tower"
      walkerState.destinationIconName = "building.2.fill"
      walkerState.journeyLogEntries = MockDoeWalkSimulation.completedJourneyLog(isReturnTrip: true, now: Date(timeIntervalSince1970: 1000))
      walkerState.trips = []
      $0.sheet = .walker(walkerState)
    }
  }

  @Test
  @MainActor
  func testDoeMultipleWalksRecordedInHistory() async {
    let now1 = Date(timeIntervalSince1970: 1000)
    let now2 = Date(timeIntervalSince1970: 3000)

    let trip1 = MockDoeWalkSimulation.completedTrip(now: now1, isReturnTrip: false)
    let trip2 = MockDoeWalkSimulation.completedTrip(now: now2, isReturnTrip: true)

    // 1. First walk: Doe reaches Home
    let store = TestStore(initialState: MainMapFeature.State(
      trackedWalkerDestinationName: "Home",
      mockDoeHistoryTrips: []
    )) {
      MainMapFeature()
    } withDependencies: {
      $0.date.now = now1
      $0.trackingClient.updateUserStatus = { _, _, _, _ in }
    }

    await store.send(.mockDoeReachedDestination) {
      $0.trackedWalkerLocation = MockDoeWalkSimulation.destinationCoordinate
      $0.mockDoeHistoryTrips = [trip1]
    }
    await store.receive(.delegate(.walkerStatusChanged(id: Person.mockDoeID, newStatus: "Idle")))
    await store.receive(.delegate(.companionStatusChanged(newStatus: "idle")))
    #expect(store.state.mockDoeHistoryTrips == [trip1])

    // 2. Return walk: Doe reaches Autograph Tower and adds return trip to history
    let returnStore = TestStore(initialState: MainMapFeature.State(
      trackedWalkerLocation: MockDoeWalkSimulation.destinationCoordinate,
      trackedWalkerDestinationName: "Autograph Tower",
      mockDoeHistoryTrips: [trip1]
    )) {
      MainMapFeature()
    } withDependencies: {
      $0.date.now = now2
      $0.trackingClient.updateUserStatus = { _, _, _, _ in }
    }

    await returnStore.send(.mockDoeReachedDestination) {
      $0.trackedWalkerLocation = MockDoeWalkSimulation.originCoordinate
      $0.mockDoeHistoryTrips = [trip2, trip1]
    }
    await returnStore.receive(.delegate(.walkerStatusChanged(id: Person.mockDoeID, newStatus: "Idle")))
    await returnStore.receive(.delegate(.companionStatusChanged(newStatus: "idle")))

    #expect(returnStore.state.mockDoeHistoryTrips.count == 2)
    #expect(returnStore.state.mockDoeHistoryTrips[0] == trip2)
    #expect(returnStore.state.mockDoeHistoryTrips[1] == trip1)
  }

  @Test
  @MainActor
  func testNavigationStartedClearsTrackedWalkerAndSetsUserWalkSession() async {
    let now = Date(timeIntervalSince1970: 1000)
    let mockDestination = CLLocationCoordinate2D(latitude: -6.2125, longitude: 106.8166)
    let destinationPlace = SavedPlace(name: "Home", subtitle: "Bendungan Hilir, South Jakarta", iconName: "house.fill", coordinate: mockDestination)

    let store = TestStore(initialState: MainMapFeature.State(
      activeWalkSessionID: "mock-doe-session",
      trackedWalkerLocation: MockDoeWalkSimulation.originCoordinate,
      trackedWalkerDestination: MockDoeWalkSimulation.destinationCoordinate,
      trackedWalkerPolyline: MockDoeWalkSimulation.fallbackPolyline,
      sheet: .direction(MapDirectionSheetFeature.State(
        destination: destinationPlace,
        mode: .progress,
        isNavigating: true
      ))
    )) {
      MainMapFeature()
    } withDependencies: {
      $0.date.now = now
      $0.trackingClient.endWalkSession = { _ in }
      $0.trackingClient.setSubscribeSessionParticipants = { _, _ in }
      $0.trackingClient.subscribeToSessionParticipants = { _ in
        AsyncStream { $0.finish() }
      }
    }

    await store.send(.sheet(.presented(.direction(.delegate(.navigationStarted(sessionID: "user-session-123")))))) {
      $0.isNavigating = true
      $0.userWalkSessionID = "user-session-123"
      $0.activeWalkSessionID = nil
      $0.trackedWalkerPolyline = nil
      $0.trackedWalkerRoute = nil
      $0.trackedWalkerDestination = nil
      $0.lastLoggedCoordinate = nil
      $0.lastLoggedStreet = "Current Area"
      $0.lastLoggedIcon = "figure.walk"
      $0.lastLoggedTime = now
    }

    await store.send(.sheet(.presented(.direction(.delegate(.navigationEnded))))) {
      $0.isNavigating = false
      $0.userWalkSessionID = nil
      $0.activeWalkSessionID = nil
      $0.activeRoute = nil
      $0.sheet = nil
    }
  }

  @Test
  @MainActor
  func testWalkerNavigationSubscribesToAcceptedCompanionsWatching() async {
    let now = Date(timeIntervalSince1970: 1000)
    let mockDestination = CLLocationCoordinate2D(latitude: -6.2125, longitude: 106.8166)
    let destinationPlace = SavedPlace(name: "Home", subtitle: "Bendungan Hilir", iconName: "house.fill", coordinate: mockDestination)

    let participantStream = AsyncStream.makeStream(of: [SessionParticipant].self)

    let companion1Profile = UserProfile(
      appleUserId: "c1_apple",
      cloudKitUserId: "c1_ck",
      name: "Mentari Awan",
      email: "mentari@example.com"
    )

    let store = TestStore(initialState: MainMapFeature.State(
      sheet: .direction(MapDirectionSheetFeature.State(
        destination: destinationPlace,
        mode: .progress,
        isNavigating: true
      ))
    )) {
      MainMapFeature()
    } withDependencies: {
      $0.date.now = now
      $0.trackingClient.endWalkSession = { _ in }
      $0.trackingClient.setSubscribeSessionParticipants = { _, _ in }
      $0.trackingClient.subscribeToSessionParticipants = { _ in
        participantStream.stream
      }
      $0.usersClient.fetchUserByRecordID = { recordID in
        if recordID == "UserProfile_c1_apple_c1_ck" {
          return companion1Profile
        }
        return nil
      }
      $0.connectionsClient.fetchConnections = { _ in [] }
      $0.contactPhotoClient.fetchContactPhotoByEmail = { _ in nil }
      $0.contactPhotoClient.fetchContactPhotoByName = { _ in nil }
    }

    await store.send(.sheet(.presented(.direction(.delegate(.navigationStarted(sessionID: "user-session-abc")))))) {
      $0.isNavigating = true
      $0.userWalkSessionID = "user-session-abc"
      $0.lastLoggedStreet = "Current Area"
      $0.lastLoggedIcon = "figure.walk"
      $0.lastLoggedTime = now
    }

    // 1. Emit list with mixed statuses: only "accept" should be included
    let mixedParticipants = [
      SessionParticipant(id: "p1", sessionRef: "user-session-abc", companionRef: "UserProfile_c1_apple_c1_ck", status: "accept"),
      SessionParticipant(id: "p2", sessionRef: "user-session-abc", companionRef: "UserProfile_c2_apple_c2_ck", status: "notDetermined"),
      SessionParticipant(id: "p3", sessionRef: "user-session-abc", companionRef: "UserProfile_c3_apple_c3_ck", status: "dismiss"),
      SessionParticipant(id: "p4", sessionRef: "user-session-abc", companionRef: "UserProfile_c4_apple_c4_ck", status: "left")
    ]

    participantStream.continuation.yield(mixedParticipants)

    let expectedCompanion1 = Person(
      id: Person.stableID(appleUserId: "c1_apple", cloudKitUserId: "c1_ck"),
      name: "Mentari Awan",
      status: "Idle",
      appleUserId: "c1_apple",
      cloudKitUserId: "c1_ck",
      email: "mentari@example.com"
    )

    await store.receive(.sheet(.presented(.direction(.setWatchingPeople([expectedCompanion1]))))) {
      if case var .direction(dirState) = $0.sheet {
        dirState.watchingPeople = [expectedCompanion1]
        $0.sheet = .direction(dirState)
      }
    }

    // 2. Companion leaves (status changes to "left") -> watchingPeople becomes empty
    let leftParticipants = [
      SessionParticipant(id: "p1", sessionRef: "user-session-abc", companionRef: "UserProfile_c1_apple_c1_ck", status: "left")
    ]
    participantStream.continuation.yield(leftParticipants)

    await store.receive(.sheet(.presented(.direction(.setWatchingPeople([]))))) {
      if case var .direction(dirState) = $0.sheet {
        dirState.watchingPeople = []
        $0.sheet = .direction(dirState)
      }
    }

    participantStream.continuation.finish()

    await store.send(.sheet(.presented(.direction(.delegate(.navigationEnded))))) {
      $0.isNavigating = false
      $0.userWalkSessionID = nil
      $0.sheet = nil
    }
  }

  @Test
  @MainActor
  func testWalkSessionUpdatedUpdatesTrackedLocation() async {
    let store = TestStore(initialState: MainMapFeature.State(
      activeWalkSessionID: "session-abc"
    )) {
      MainMapFeature()
    }

    let lat = -6.2088
    let lon = 106.8456
    let coordData = try! JSONEncoder().encode([lat, lon])
    let mockSession = WalkSession(
      id: "session-abc",
      walkerRef: "walker-123",
      status: "active",
      destinationName: "Testing Dest",
      destinationLatitude: 0,
      destinationLongitude: 0,
      routePolyline: nil,
      startedAt: Date(),
      endedAt: nil,
      currentCoordinate: coordData,
      lastPingAt: Date()
    )

    await store.send(.walkSessionUpdated(mockSession)) {
      $0.trackedWalkerLocation = CLLocationCoordinate2D(latitude: lat, longitude: lon)
    }
  }

  @Test
  @MainActor
  func testStopTrackingTappedUnsubscribes() async {
    var unsubscribedSessionID: String? = nil
    let store = TestStore(initialState: MainMapFeature.State(
      activeWalkSessionID: "session-xyz"
    )) {
      MainMapFeature()
    } withDependencies: {
      $0.trackingClient.setSubscribeWalkSession = { sessionID, isSubscribed in
        if !isSubscribed {
          unsubscribedSessionID = sessionID
        }
      }
      $0.trackingClient.updateParticipantStatus = { _, _, _ in
        SessionParticipant(id: "p", sessionRef: "s", companionRef: "c", status: "left")
      }
    }

    await store.send(.stopTrackingTapped) {
      $0.activeWalkSessionID = nil
    }
    #expect(unsubscribedSessionID == "session-xyz")
  }

  @Test
  @MainActor
  func testRealWalkerTrackingStartedImmediatelySetsLocationAndRoute() async {
    UserProfileStorage.clear()
    let now = Date(timeIntervalSince1970: 1000)
    let walkerLat = -6.2125
    let walkerLon = 106.8166
    let destLat = -6.1950
    let destLon = 106.8200
    let initialCoordData = try! JSONEncoder().encode([walkerLat, walkerLon])

    let testPerson = Person(
      id: UUID(),
      name: "Mentari",
      status: "Walking",
      appleUserId: "mentari-apple",
      cloudKitUserId: "mentari-ck"
    )

    let testSession = WalkSession(
      id: "session-real-123",
      walkerRef: "UserProfile_mentari_apple_mentari_ck",
      status: "active",
      destinationName: "Grand Indonesia",
      destinationLatitude: destLat,
      destinationLongitude: destLon,
      routePolyline: nil,
      startedAt: now,
      endedAt: nil,
      currentCoordinate: initialCoordData,
      lastPingAt: now
    )

    let fallbackPoly = MKPolyline(coordinates: [
      CLLocationCoordinate2D(latitude: walkerLat, longitude: walkerLon),
      CLLocationCoordinate2D(latitude: destLat, longitude: destLon)
    ], count: 2)

    let mockRouteInfo = WalkingRouteInfo(
      travelTimeString: "15 min",
      etaString: "10.15",
      distanceString: "1.2 km",
      rawTravelTime: 900,
      rawDistanceMeters: 1200,
      route: nil,
      fallbackPolyline: fallbackPoly
    )

    let walkerState = MapWalkerSheetFeature.State(
      walker: testPerson,
      status: "Walking"
    )
    let store = TestStore(initialState: MainMapFeature.State(
      sheet: .walker(walkerState)
    )) {
      MainMapFeature()
    } withDependencies: {
      $0.date.now = now
      $0.directionRoute.calculateWalkingRoute = { origin, dest in
        #expect(origin.latitude == walkerLat)
        #expect(origin.longitude == walkerLon)
        #expect(dest.latitude == destLat)
        #expect(dest.longitude == destLon)
        return mockRouteInfo
      }
      $0.trackingClient.updateParticipantStatus = { _, _, _ in
        SessionParticipant(id: "p", sessionRef: "session-real-123", companionRef: "c", status: "accept")
      }
      $0.trackingClient.updateUserStatus = { _, _, _, _ in }
      $0.trackingClient.setSubscribeWalkSession = { _, _ in }
      $0.trackingClient.subscribeToWalkSession = { _ in
        AsyncStream { $0.finish() }
      }
      $0.trackingClient.subscribeToJourneyLogs = { _ in
        AsyncStream { $0.finish() }
      }
    }

    await store.send(.sheet(.presented(.walker(.delegate(.trackingStarted(testPerson, testSession)))))) {
      $0.activeWalkSessionID = "session-real-123"
      $0.trackedWalkerDestinationName = "Grand Indonesia"
      $0.trackedWalkerDestination = CLLocationCoordinate2D(latitude: destLat, longitude: destLon)
      $0.trackedWalkerLocation = CLLocationCoordinate2D(latitude: walkerLat, longitude: walkerLon)
      $0.hasFittedTrackedWalker = false
      $0.trackedWalkerAttributes = TrailWalkAttributes(
        sessionID: "session-real-123",
        walkerName: "Mentari",
        originTitle: "Starting Point",
        destinationTitle: "Grand Indonesia"
      )
      $0.trackedWalkerLiveActivityState = TrailWalkAttributes.ContentState(
        step: "Walking",
        progressPercentage: 0.0,
        remainingDistanceMeters: 650.0,
        currentLandmark: "Grand Indonesia",
        estimatedArrivalDate: now.addingTimeInterval(6 * 60),
        expectedTravelTime: "6 min",
        isApproaching: false
      )
    }

    await store.receive(.setTrackedWalkerPolyline(fallbackPoly)) {
      $0.trackedWalkerPolyline = fallbackPoly
    }
  }

  @Test
  @MainActor
  func testSelectPersonIgnoredWhileActivelyNavigating() async {
    let dummyPerson = Person(name: "Mentari", status: "Walking")
    let directionState = MapDirectionSheetFeature.State(
      destination: SavedPlace(name: "Home", subtitle: "My house", iconName: "house.fill"),
      mode: .progress,
      watchingPeople: []
    )
    let store = TestStore(initialState: MainMapFeature.State(
      isNavigating: true,
      userWalkSessionID: "active-walk-123",
      sheet: .direction(directionState)
    )) {
      MainMapFeature()
    }

    // Selecting a person while actively navigating must NOT overwrite the direction progress sheet
    await store.send(.selectPerson(dummyPerson))
    // No state change expected, sheet remains .direction
  }

  @Test
  @MainActor
  func testWalkSessionUpdatedUpdatesTrackedWalkerLocation() async {
    let initialCoord = CLLocationCoordinate2D(latitude: -6.2000, longitude: 106.8166)
    let store = TestStore(initialState: MainMapFeature.State(
      activeWalkSessionID: "session-stream-1",
      trackedWalkerLocation: initialCoord
    )) {
      MainMapFeature()
    }

    let nextLat = -6.2010
    let nextLon = 106.8175
    let nextCoordData = try! JSONEncoder().encode([nextLat, nextLon])
    let updatedSession = WalkSession(
      id: "session-stream-1",
      walkerRef: "walker-1",
      status: "active",
      destinationName: "Plaza Indonesia",
      destinationLatitude: -6.1930,
      destinationLongitude: 106.8220,
      routePolyline: nil,
      startedAt: Date(),
      endedAt: nil,
      currentCoordinate: nextCoordData,
      lastPingAt: Date()
    )

    await store.send(.walkSessionUpdated(updatedSession)) {
      $0.trackedWalkerLocation = CLLocationCoordinate2D(latitude: nextLat, longitude: nextLon)
    }

    // Next step update
    let step2Lat = -6.2025
    let step2Lon = 106.8189
    let step2CoordData = try! JSONEncoder().encode([step2Lat, step2Lon])
    let step2Session = WalkSession(
      id: "session-stream-1",
      walkerRef: "walker-1",
      status: "active",
      destinationName: "Plaza Indonesia",
      destinationLatitude: -6.1930,
      destinationLongitude: 106.8220,
      routePolyline: nil,
      startedAt: Date(),
      endedAt: nil,
      currentCoordinate: step2CoordData,
      lastPingAt: Date()
    )

    await store.send(.walkSessionUpdated(step2Session)) {
      $0.trackedWalkerLocation = CLLocationCoordinate2D(latitude: step2Lat, longitude: step2Lon)
    }
  }

  @Test
  @MainActor
  func testRealTimeTrackingStreamYieldsAndCancelsOnStop() async {
    let initialCoord = CLLocationCoordinate2D(latitude: -6.2000, longitude: 106.8166)
    let store = TestStore(initialState: MainMapFeature.State(
      activeWalkSessionID: "session-live-stream",
      trackedWalkerLocation: initialCoord,
      trackedWalkerDestination: CLLocationCoordinate2D(latitude: -6.1930, longitude: 106.8220),
      trackedWalkerDestinationName: "Grand Indonesia"
    )) {
      MainMapFeature()
    } withDependencies: {
      $0.trackingClient.setSubscribeWalkSession = { _, _ in }
      $0.trackingClient.updateParticipantStatus = { _, _, _ in
        SessionParticipant(id: "p1", sessionRef: "session-live-stream", companionRef: "c1", status: "left")
      }
    }

    let movingLat = -6.2005
    let movingLon = 106.8170
    let movingCoordData = try! JSONEncoder().encode([movingLat, movingLon])
    let movingSession = WalkSession(
      id: "session-live-stream",
      walkerRef: "walker-test",
      status: "active",
      destinationName: "Grand Indonesia",
      destinationLatitude: -6.1930,
      destinationLongitude: 106.8220,
      routePolyline: nil,
      startedAt: Date(),
      endedAt: nil,
      currentCoordinate: movingCoordData,
      lastPingAt: Date()
    )

    await store.send(.walkSessionUpdated(movingSession)) {
      $0.trackedWalkerLocation = CLLocationCoordinate2D(latitude: movingLat, longitude: movingLon)
    }

    await store.send(.stopTrackingTapped) {
      $0.activeWalkSessionID = nil
      $0.trackedWalkerLocation = nil
      $0.trackedWalkerDestination = nil
      $0.trackedWalkerDestinationName = nil
    }
  }
}

