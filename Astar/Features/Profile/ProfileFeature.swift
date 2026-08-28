//
//  ProfileFeature.swift
//  Astar
//
//  Created by Muhammad Pandu Royyan on 24/08/26.
//

import ComposableArchitecture

@Reducer
struct ProfileFeature {
  @ObservableState
  struct State: Equatable {
    var userProfile: UserProfile?
    var isDevelopmentMode: Bool = DeveloperSettingsStorage.isDevelopmentMode
    var isShowRouteGuide: Bool = DeveloperSettingsStorage.isShowRouteGuide
    var isDoeWalkingMock: Bool = DeveloperSettingsStorage.isDoeWalkingMockEnabled
  }

  enum Action: Equatable {
    case signOutButtonTapped
    case setDevelopmentMode(Bool)
    case setRouteGuide(Bool)
    case setDoeWalkingMock(Bool)
    case resetDoeWalkingSimulation
    case delegate(Delegate)

    enum Delegate: Equatable {
      case signedOut
      case developmentModeChanged(Bool)
      case routeGuideChanged(Bool)
      case doeWalkingMockChanged(Bool)
      case restartDoeWalkingSimulation
    }
  }

  var body: some Reducer<State, Action> {
    Reduce { state, action in
      switch action {
      case .signOutButtonTapped:
        UserProfileStorage.clear()
        return .send(.delegate(.signedOut))

      case let .setDevelopmentMode(enabled):
        state.isDevelopmentMode = enabled
        DeveloperSettingsStorage.isDevelopmentMode = enabled
        return .send(.delegate(.developmentModeChanged(enabled)))

      case let .setRouteGuide(enabled):
        state.isShowRouteGuide = enabled
        DeveloperSettingsStorage.isShowRouteGuide = enabled
        return .send(.delegate(.routeGuideChanged(enabled)))

      case let .setDoeWalkingMock(enabled):
        state.isDoeWalkingMock = enabled
        DeveloperSettingsStorage.isDoeWalkingMockEnabled = enabled
        return .send(.delegate(.doeWalkingMockChanged(enabled)))

      case .resetDoeWalkingSimulation:
        return .send(.delegate(.restartDoeWalkingSimulation))

      case .delegate:
        return .none
      }
    }
  }
}
