//
//  RootFeature.swift
//  Astar
//
//  Created by Muhammad Pandu Royyan on 24/08/26.
//

import ComposableArchitecture
import Foundation

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
    case openURL(URL)
    case handleDeepLink(DeepLink)

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
        ._printChanges()
    }

    Reduce { state, action in
      switch action {
      case .appDelegate(.didFinishLaunching):
        guard let profile = UserProfileStorage.load() else { return .none }
        state = .main(MainFeature.State(userProfile: profile))
        return .none

      case let .openURL(url):
        guard let deepLink = DeepLink.parse(url: url) else { return .none }
        return .send(.handleDeepLink(deepLink))

      case let .handleDeepLink(deepLink):
        switch deepLink {
        case .alwaysHome:
          switch state {
          case .main:
            return .send(.main(.map(.startAlwaysHomeNavigation)))
          case var .onboarding(onboardingState):
            onboardingState.pendingDeepLink = .alwaysHome
            state = .onboarding(onboardingState)
            return .none
          }

        case let .navigate(destination):
          switch state {
          case .main:
            return .send(.main(.map(.startDirectNavigation(destinationQuery: destination))))
          case var .onboarding(onboardingState):
            onboardingState.pendingDeepLink = .navigate(destination: destination)
            state = .onboarding(onboardingState)
            return .none
          }
        }

      case let .onboarding(.delegate(.appleSignInCompleted(credential))):
        let pending: DeepLink? = if case let .onboarding(onboardingState) = state { onboardingState.pendingDeepLink } else { nil }
        state = .main(MainFeature.State())
        if case .alwaysHome = pending {
          return .merge(
            .send(.main(.login(.appleSignInCompleted(credential)))),
            .send(.main(.map(.startAlwaysHomeNavigation)))
          )
        } else if case let .navigate(destination) = pending {
          return .merge(
            .send(.main(.login(.appleSignInCompleted(credential)))),
            .send(.main(.map(.startDirectNavigation(destinationQuery: destination))))
          )
        }
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
