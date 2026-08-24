//
//  RootFeature.swift
//  Astar
//
//  Created by Muhammad Pandu Royyan on 24/08/26.
//

import ComposableArchitecture

@Reducer
struct RootFeature {
  @ObservableState
  enum State: Equatable {
    case onboarding(OnboardingFeature.State)
    case loggedIn(LoginFeature.State)
  }

  enum Action: Equatable {
    case onboarding(OnboardingFeature.Action)
    case loggedIn(LoginFeature.Action)
    case appDelegate(AppDelegateAction)

    enum AppDelegateAction: Equatable {
      case didFinishLaunching
    }
  }

  var body: some Reducer<State, Action> {
    Scope(state: \.onboarding, action: \.onboarding) {
      OnboardingFeature()
    }
    
    Scope(state: \.loggedIn, action: \.loggedIn) {
      LoginFeature()
    }

    Reduce { state, action in
      switch action {
      case .appDelegate(.didFinishLaunching):
        guard let profile = UserProfileStorage.load() else { return .none }
        state = .loggedIn(LoginFeature.State(userProfile: profile))
        return .none

      case let .onboarding(.delegate(.appleSignInCompleted(credential))):
        state = .loggedIn(LoginFeature.State())
        return .send(.loggedIn(.appleSignInCompleted(credential)))

      case let .loggedIn(.delegate(.loggedIn(profile))):
        state = .loggedIn(LoginFeature.State(userProfile: profile))
        return .none

      case .loggedIn(.delegate(.signedOut)):
        state = .onboarding(OnboardingFeature.State())
        return .none

      case .onboarding, .loggedIn:
        return .none
      }
    }
  }
}
