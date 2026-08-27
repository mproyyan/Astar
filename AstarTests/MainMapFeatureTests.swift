import ComposableArchitecture
import Testing
import CoreLocation
@testable import Astar

struct MainMapFeatureTests {
  @Test
  @MainActor
  func testOnAppearAndLocationAuthorization() async {
    let authStream = AsyncStream.makeStream(of: CLAuthorizationStatus.self)
    let locationStream = AsyncStream.makeStream(of: CLLocationCoordinate2D.self)
    
    let store = TestStore(initialState: MainMapFeature.State()) {
      MainMapFeature()
    } withDependencies: {
      $0.locationManager.authorizationStatus = { authStream.stream }
      $0.locationManager.locationUpdates = { locationStream.stream }
      $0.locationManager.requestWhenInUseAuthorization = {}
      $0.locationManager.requestLocation = {}
    }
    
    await store.send(.onAppear)
    await store.receive(.requestLocation)

    authStream.continuation.yield(.authorizedWhenInUse)
    
    await store.receive(\.locationManager.didChangeAuthorization) {
      $0.authorizationStatus = .authorizedWhenInUse
    }
    
    let location = CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194)
    locationStream.continuation.yield(location)
    
    await store.receive(\.locationManager.didUpdateLocation) {
      $0.currentLocation = location
    }
    
    await store.receive(\.delegate.locationUpdated)
    
    authStream.continuation.finish()
    locationStream.continuation.finish()
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
        id: "1",
        emoji: "👨🏻",
        colorHex: "#FF0000",
        name: "Test Person",
        status: "Walking",
        age: 30,
        gender: "Male"
    )

    await store.send(.selectPerson(person)) {
      $0.sheet = .walker(MapWalkerSheetFeature.State(walker: person, status: person.status))
    }
  }
}
