import ComposableArchitecture
import Testing
import Foundation
import CoreLocation
import MapKit
@testable import Astar

@Suite(.serialized)
struct RootFeatureTests {
  @Test
  @MainActor
  func testOnboardingToMainTransition() async {
    DeveloperSettingsStorage.isDevelopmentMode = false
    let mockProfile = UserProfile(
      appleUserId: "real-apple-123",
      cloudKitUserId: "real-ck-456",
      name: "John Apple",
      email: "john@apple.com"
    )

    let store = TestStore(initialState: RootFeature.State.onboarding(OnboardingFeature.State())) {
      RootFeature()
    } withDependencies: {
      $0.uuid = .incrementing
    }

    // When onboarding receives loggedIn, RootFeature transitions to main with userProfile
    await store.send(.onboarding(.delegate(.loggedIn(mockProfile)))) {
      var expected = MainFeature.State(userProfile: mockProfile)
      expected.isDevelopmentMode = false
      $0 = .main(expected)
    }
  }

  @Test
  @MainActor
  func testSignOutTransitionsBackToOnboarding() async {
    let mockProfile = UserProfile(
      appleUserId: "real-apple-123",
      cloudKitUserId: "real-ck-456",
      name: "John Apple",
      email: "john@apple.com"
    )

    let store = TestStore(initialState: RootFeature.State.main(MainFeature.State(userProfile: mockProfile))) {
      RootFeature()
    } withDependencies: {
      $0.uuid = .incrementing
    }

    // When user signs out via login delegate
    await store.send(.main(.login(.delegate(.signedOut)))) {
      $0 = .onboarding(OnboardingFeature.State())
    }
  }

  @Test
  @MainActor
  func testSignOutFromProfileTransitionsBackToOnboarding() async {
    let mockProfile = UserProfile(
      appleUserId: "real-apple-123",
      cloudKitUserId: "real-ck-456",
      name: "John Apple",
      email: "john@apple.com"
    )

    var mainState = MainFeature.State(userProfile: mockProfile)
    let profileID: StackElementID = 0
    mainState.path[id: profileID] = .profile(ProfileFeature.State(userProfile: mockProfile))

    let store = TestStore(initialState: RootFeature.State.main(mainState)) {
      RootFeature()
    } withDependencies: {
      $0.uuid = .incrementing
    }

    // When user taps sign out in Profile screen
    await store.send(.main(.path(.element(id: profileID, action: .profile(.delegate(.signedOut)))))) {
      $0 = .onboarding(OnboardingFeature.State())
    }
  }

  @Test
  @MainActor
  func testPendingDeepLinkExecutedAfterLogin() async {
    let mockProfile = UserProfile(
      appleUserId: "real-apple-123",
      cloudKitUserId: "real-ck-456",
      name: "John Apple",
      email: "john@apple.com"
    )

    var onboardingState = OnboardingFeature.State()
    onboardingState.pendingDeepLink = .alwaysHome

    let store = TestStore(initialState: RootFeature.State.onboarding(onboardingState)) {
      RootFeature()
    } withDependencies: {
      $0.uuid = .incrementing
      $0.directionRoute.reverseGeocode = { _ in "Current Location" }
      $0.directionRoute.calculateWalkingRoute = { _, _ in
        WalkingRouteInfo(travelTimeString: "12 min", etaString: "11.00 ETA", distanceString: "850 m", rawTravelTime: 720, rawDistanceMeters: 850, route: nil, fallbackPolyline: nil)
      }
    }
    store.exhaustivity = .off

    // Completing login executes the pending deep link
    await store.send(.onboarding(.delegate(.loggedIn(mockProfile)))) {
      var expected = MainFeature.State(userProfile: mockProfile)
      if case let .main(actual) = $0 {
        expected.isDevelopmentMode = actual.isDevelopmentMode
      }
      $0 = .main(expected)
    }

    await store.receive(\.main.map.startAlwaysHomeNavigation)
  }
}
