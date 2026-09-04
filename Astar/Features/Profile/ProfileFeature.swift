//
//  ProfileFeature.swift
//  Astar
//
//  Created by Muhammad Pandu Royyan on 24/08/26.
//

import ComposableArchitecture
import Foundation

@Reducer
struct ProfileFeature {
  @ObservableState
  struct State: Equatable {
    var userProfile: UserProfile? = UserProfileStorage.load()
    var isDevelopmentMode: Bool = DeveloperSettingsStorage.isDevelopmentMode
    var isShowRouteGuide: Bool = DeveloperSettingsStorage.isShowRouteGuide
    var isDoeWalkingMock: Bool = DeveloperSettingsStorage.isDoeWalkingMockEnabled
  }

  enum Action: Equatable {
    case onAppear
    case avatarLoaded(Data)
    case signOutButtonTapped
    case setDevelopmentMode(Bool)
    case setRouteGuide(Bool)
    case setDoeWalkingMock(Bool)
    case resetDoeWalkingSimulation
    case trustedPersonTapped
    case savedPlacesUpdated([SavedPlace])
    case delegate(Delegate)

    enum Delegate: Equatable {
      case signedOut
      case developmentModeChanged(Bool)
      case routeGuideChanged(Bool)
      case doeWalkingMockChanged(Bool)
      case trustedPersonTapped
      case restartDoeWalkingSimulation
      case savedPlacesUpdated([SavedPlace])
    }
  }

  var body: some Reducer<State, Action> {
    Reduce { state, action in
      switch action {
      case .onAppear:
        if state.userProfile == nil {
          state.userProfile = UserProfileStorage.load()
        }
        return .run { [profile = state.userProfile] send in
          if let avatar = await ContactPhotoClient.liveValue.fetchMeCardPhoto(profile?.email, profile?.name) {
            await send(.avatarLoaded(avatar))
          }
        }

      case let .avatarLoaded(avatar):
        if var profile = state.userProfile {
          profile.avatarData = avatar
          state.userProfile = profile
          UserProfileStorage.save(profile)
        }
        return .none

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

      case .trustedPersonTapped:
        return .send(.delegate(.trustedPersonTapped))

      case let .savedPlacesUpdated(places):
        return .send(.delegate(.savedPlacesUpdated(places)))

      case .delegate:
        return .none
      }
    }
  }
}
