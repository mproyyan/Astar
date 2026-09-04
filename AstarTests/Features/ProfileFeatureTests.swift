import ComposableArchitecture
import CoreLocation
import Foundation
import MapKit
import Testing
@testable import Astar

struct MockSavedPlacesRepository: SavedPlacesRepositoryProtocol {
  var loadHandler: @Sendable (String) async -> [SavedPlace] = { _ in [] }
  var saveHandler: @Sendable ([SavedPlace], String) async -> Void = { _, _ in }
  var deleteHandler: @Sendable (UUID, String) async -> [SavedPlace] = { _, _ in [] }
  var updateLabelHandler: @Sendable (UUID, String, String) async -> [SavedPlace] = { _, _, _ in [] }

  func load(for userId: String) async -> [SavedPlace] { await loadHandler(userId) }
  func save(_ places: [SavedPlace], for userId: String) async { await saveHandler(places, userId) }
  func delete(id: UUID, for userId: String) async -> [SavedPlace] { await deleteHandler(id, userId) }
  func updateLabel(id: UUID, newLabel: String, for userId: String) async -> [SavedPlace] { await updateLabelHandler(id, newLabel, userId) }
}

@Suite(.serialized)
struct ProfileFeatureTests {
  @Test
  @MainActor
  func testSetDevelopmentMode() async {
    let store = TestStore(initialState: ProfileFeature.State(isDevelopmentMode: false)) {
      ProfileFeature()
    }

    await store.send(.setDevelopmentMode(true)) {
      $0.isDevelopmentMode = true
    }
    await store.receive(.delegate(.developmentModeChanged(true)))
    #expect(DeveloperSettingsStorage.isDevelopmentMode == true)

    await store.send(.setDevelopmentMode(false)) {
      $0.isDevelopmentMode = false
    }
    await store.receive(.delegate(.developmentModeChanged(false)))
    #expect(DeveloperSettingsStorage.isDevelopmentMode == false)
  }

  @Test
  @MainActor
  func testSetRouteGuide() async {
    let store = TestStore(initialState: ProfileFeature.State(isShowRouteGuide: true)) {
      ProfileFeature()
    }

    await store.send(.setRouteGuide(false)) {
      $0.isShowRouteGuide = false
    }
    await store.receive(.delegate(.routeGuideChanged(false)))
    #expect(DeveloperSettingsStorage.isShowRouteGuide == false)

    await store.send(.setRouteGuide(true)) {
      $0.isShowRouteGuide = true
    }
    await store.receive(.delegate(.routeGuideChanged(true)))
    #expect(DeveloperSettingsStorage.isShowRouteGuide == true)
  }

  @Test
  @MainActor
  func testSetDoeWalkingMock() async {
    let store = TestStore(initialState: ProfileFeature.State(isDoeWalkingMock: true)) {
      ProfileFeature()
    }

    await store.send(.setDoeWalkingMock(false)) {
      $0.isDoeWalkingMock = false
    }
    await store.receive(.delegate(.doeWalkingMockChanged(false)))
    #expect(DeveloperSettingsStorage.isDoeWalkingMockEnabled == false)

    await store.send(.setDoeWalkingMock(true)) {
      $0.isDoeWalkingMock = true
    }
    await store.receive(.delegate(.doeWalkingMockChanged(true)))
    #expect(DeveloperSettingsStorage.isDoeWalkingMockEnabled == true)

    await store.send(.resetDoeWalkingSimulation)
    await store.receive(.delegate(.restartDoeWalkingSimulation))
  }

  @Test
  @MainActor
  func testMainFeatureDevelopmentModeToggle() async {
    DeveloperSettingsStorage.isDevelopmentMode = false
    DeveloperSettingsStorage.isShowRouteGuide = true
    DeveloperSettingsStorage.isDoeWalkingMockEnabled = true
    let store = TestStore(initialState: MainFeature.State()) {
      MainFeature()
    } withDependencies: {
      $0.usersClient.fetchAllUsers = { [] }
    }

    #expect(store.state.isDevelopmentMode == false)
    #expect(store.state.people.isEmpty)
    #expect(store.state.isShowRouteGuide == true)
    #expect(store.state.map.isShowRouteGuide == true)

    // Open profile
    await store.send(.profileButtonTapped) {
      $0.path.append(.profile(ProfileFeature.State(userProfile: nil, isDevelopmentMode: false, isShowRouteGuide: true, isDoeWalkingMock: true)))
    }

    // Toggle dev mode to true
    let profileID = store.state.path.ids.first!
    await store.send(.path(.element(id: profileID, action: .profile(.setDevelopmentMode(true))))) {
      $0.path[id: profileID, case: \.profile]?.isDevelopmentMode = true
    }
    await store.receive(.path(.element(id: profileID, action: .profile(.delegate(.developmentModeChanged(true)))))) {
      $0.isDevelopmentMode = true
      $0.people = [Person.mockDoe]
    }

    // Toggle Doe walking mock to false
    await store.send(.path(.element(id: profileID, action: .profile(.setDoeWalkingMock(false))))) {
      $0.path[id: profileID, case: \.profile]?.isDoeWalkingMock = false
    }
    await store.receive(.path(.element(id: profileID, action: .profile(.delegate(.doeWalkingMockChanged(false)))))) {
      $0.isDoeWalkingMock = false
      $0.people = [Person(id: Person.mockDoeID, name: "Doe", status: "Idle")]
    }

    // Restart Doe walking simulation
    await store.send(.path(.element(id: profileID, action: .profile(.resetDoeWalkingSimulation))))
    await store.receive(.path(.element(id: profileID, action: .profile(.delegate(.restartDoeWalkingSimulation))))) {
      $0.isDoeWalkingMock = true
      $0.people = [Person(id: Person.mockDoeID, name: "Doe", status: "Walking")]
    }
    await store.receive(.map(.resetDoeWalking))
    await store.receive(.map(.delegate(.walkerStatusChanged(id: Person.mockDoeID, newStatus: "Walking"))))

    // Toggle dev mode to false
    await store.send(.path(.element(id: profileID, action: .profile(.setDevelopmentMode(false))))) {
      $0.path[id: profileID, case: \.profile]?.isDevelopmentMode = false
    }
    await store.receive(.path(.element(id: profileID, action: .profile(.delegate(.developmentModeChanged(false)))))) {
      $0.isDevelopmentMode = false
      $0.people = []
    }

    // Toggle route guide to false
    await store.send(.path(.element(id: profileID, action: .profile(.setRouteGuide(false))))) {
      $0.path[id: profileID, case: \.profile]?.isShowRouteGuide = false
    }
    await store.receive(.path(.element(id: profileID, action: .profile(.delegate(.routeGuideChanged(false)))))) {
      $0.isShowRouteGuide = false
      $0.map.isShowRouteGuide = false
    }
  }

  @Test
  @MainActor
  func testSavedPlacesFeatureSearchAndSelect() async {
    let mockPlace = SavedPlace(
      name: "Grand Indonesia",
      subtitle: "Jl. M.H. Thamrin No. 1, Central Jakarta",
      iconName: "bag.fill",
      coordinate: CLLocationCoordinate2D(latitude: -6.1950, longitude: 106.8230)
    )

    let store = TestStore(initialState: SavedPlacesFeature.State(userId: "test_user")) {
      SavedPlacesFeature()
    } withDependencies: {
      $0.placeSearch.searchPlaces = { _, _ in [mockPlace] }
      $0.locationManager.getCurrentLocation = { CLLocationCoordinate2D(latitude: -6.2088, longitude: 106.8456) }
      $0.continuousClock = ImmediateClock()
    }

    await store.send(SavedPlacesFeature.Action.addPlaceButtonTapped(nil)) {
      $0.isAddingPlace = true
      $0.pinStep = .chooseLocation
    }

    await store.send(SavedPlacesFeature.Action.searchQueryChanged("Grand")) {
      $0.searchQuery = "Grand"
      $0.isLoading = true
    }

    await store.receive(SavedPlacesFeature.Action.searchResponse([mockPlace])) {
      $0.isLoading = false
      $0.searchResults = [mockPlace]
    }

    await store.send(SavedPlacesFeature.Action.selectPlaceSearchResult(mockPlace)) {
      $0.selectedPlaceForLabel = mockPlace
      $0.customLabel = "Grand Indonesia"
      $0.pinStep = .renamePlace
    }

    await store.send(SavedPlacesFeature.Action.customLabelChanged("Rumah Awan")) {
      $0.customLabel = "Rumah Awan"
    }

    await store.send(SavedPlacesFeature.Action.backToChooseLocationTapped) {
      $0.pinStep = .chooseLocation
    }
  }

  @Test
  @MainActor
  func testSavedPlacesFeatureSaveHomeAndCustomPlace() async {
    let homePlace = SavedPlace(
      name: "Jl Kebon Sirih 1",
      subtitle: "Bendungan Hilir, South Jakarta",
      iconName: "mappin.fill",
      coordinate: CLLocationCoordinate2D(latitude: -6.2125, longitude: 106.8166)
    )

    let mockRepo = MockSavedPlacesRepository()
    let store = TestStore(initialState: SavedPlacesFeature.State(userId: "test_user")) {
      SavedPlacesFeature()
    } withDependencies: {
      $0.savedPlacesRepository = mockRepo
    }

    // 1. Change Home Location via changeLocationTapped
    await store.send(SavedPlacesFeature.Action.changeLocationTapped(homePlace, .home)) {
      $0.targetPresetForAdd = .home
      $0.isAddingPlace = true
      $0.pinStep = .renamePlace
      $0.selectedPlaceForLabel = homePlace
      $0.customLabel = "Jl Kebon Sirih 1"
      $0.editingPlaceId = homePlace.id
    }

    let newHomePlace = SavedPlace(
      name: "Jl Kebon Sirih 2",
      subtitle: "Bendungan Hilir, South Jakarta",
      iconName: "mappin.fill",
      coordinate: CLLocationCoordinate2D(latitude: -6.2130, longitude: 106.8170)
    )

    await store.send(SavedPlacesFeature.Action.selectPlaceSearchResult(newHomePlace)) {
      $0.selectedPlaceForLabel = newHomePlace
      $0.pinStep = .renamePlace
    }

    await store.send(SavedPlacesFeature.Action.confirmSavePlace) {
      $0.isAddingPlace = false
      $0.pinStep = .chooseLocation
      $0.selectedPlaceForLabel = nil
      $0.editingPlaceId = nil
      $0.places = [
        SavedPlace(
          id: homePlace.id,
          name: "Jl Kebon Sirih 2",
          subtitle: "Bendungan Hilir, South Jakarta",
          iconName: "house.fill",
          distance: nil,
          coordinate: newHomePlace.coordinate,
          label: "Jl Kebon Sirih 1"
        )
      ]
    }

    await store.receive(SavedPlacesFeature.Action.delegate(.savedPlacesUpdated(store.state.places)))
    #expect(store.state.homePlace?.name == "Jl Kebon Sirih 2")
    #expect(store.state.homePlace?.coordinate?.latitude == -6.2130)
    #expect(store.state.homePlace?.isHome == true)
  }

  @Test
  @MainActor
  func testMainFeatureSavedPlacesMirroring() async {
    let customPlaces = [
      SavedPlace(
        name: "Home",
        subtitle: "Bendungan Hilir, South Jakarta",
        iconName: "house.fill",
        coordinate: CLLocationCoordinate2D(latitude: -6.2125, longitude: 106.8166),
        label: "Home"
      ),
      SavedPlace(
        name: "Rumah Awan",
        subtitle: "Jalan Kebon Sirih, Central Jakarta",
        iconName: "mappin.fill",
        coordinate: CLLocationCoordinate2D(latitude: -6.1830, longitude: 106.8280),
        label: "Rumah Awan"
      )
    ]

    let store = TestStore(initialState: MainFeature.State()) {
      MainFeature()
    } withDependencies: {
      $0.usersClient.fetchAllUsers = { [] }
    }

    // Open profile
    await store.send(.profileButtonTapped) {
      $0.path.append(.profile(ProfileFeature.State(userProfile: nil, isDevelopmentMode: false, isShowRouteGuide: false, isDoeWalkingMock: false)))
    }

    let profileID = store.state.path.ids.first!
    await store.send(.path(.element(id: profileID, action: .profile(.savedPlacesUpdated(customPlaces)))))
    await store.receive(.path(.element(id: profileID, action: .profile(.delegate(.savedPlacesUpdated(customPlaces))))))
    await store.receive(.map(.savedPlacesUpdated(customPlaces))) {
      $0.map.savedPlaces = customPlaces
    }

    #expect(store.state.map.savedPlaces.count == 2)
    #expect(store.state.map.savedPlaces.last?.name == "Rumah Awan")
    #expect(store.state.map.savedPlaces.last?.isCustom == true)
  }
}
