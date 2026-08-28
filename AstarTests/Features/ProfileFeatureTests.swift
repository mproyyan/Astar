import ComposableArchitecture
import Testing
import Foundation
@testable import Astar

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
}
