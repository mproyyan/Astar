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
    case main(MainFeature.State)
  }

  enum Action: Equatable {
    case onboarding(OnboardingFeature.Action)
    case main(MainFeature.Action)
    case appDelegate(AppDelegateAction)

    enum AppDelegateAction: Equatable {
      case didFinishLaunching
    }
  }

  var body: some Reducer<State, Action> {
    Scope(state: \.onboarding, action: \.onboarding) {
      OnboardingFeature()
    }
    
    Scope(state: \.main, action: \.main) {
      MainFeature()
    }

    Reduce { state, action in
      switch action {
      case .appDelegate(.didFinishLaunching):
        guard let profile = UserProfileStorage.load() else { return .none }
        state = .main(MainFeature.State(userProfile: profile))
        return .none

      case let .onboarding(.delegate(.appleSignInCompleted(credential))):
        state = .main(MainFeature.State())
        return .send(.main(.login(.appleSignInCompleted(credential))))

      case let .main(.login(.delegate(.loggedIn(profile)))):
        state = .main(MainFeature.State(userProfile: profile))
        return .none

      case .main(.login(.delegate(.signedOut))):
        state = .onboarding(OnboardingFeature.State())
        return .none

      case .onboarding, .main:
        return .none
      }
    }
  }
}
