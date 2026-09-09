//
//  OnboardingFeature.swift
//  Astar
//
//  Created by Muhammad Pandu Royyan on 24/08/26.
//

import ComposableArchitecture
import Foundation

struct GlossaryItem: Equatable, Identifiable {
    var id: String { term }
    let term: String
    let definition: String
}

enum PageBody: Equatable {
    case paragraph(String)
    case glossary([GlossaryItem])
}

struct OnboardingContent: Equatable, Identifiable {
  var id: String { title }
  let title: String
  let body: PageBody
  let imageName: String
}

@Reducer
struct OnboardingFeature {
  @ObservableState
  struct State: Equatable {
    var currentIndex = 0
    var pendingDeepLink: DeepLink? = nil
    var login: LoginFeature.State = .init()
      var contents: [OnboardingContent] = [
          OnboardingContent(
              title: "Trail",
              body: .paragraph(
                  "Stay Connected. Trail keeps your trusted person updated in real time."
              ),
              imageName: "figure.walk.motion"
          ),

          OnboardingContent(
              title: "Stay Connected Along the Way",
              body: .glossary([
                  GlossaryItem(
                      term: "Walker",
                      definition: "The person making the journey. They share their journey with a trusted person."
                  ),
                  GlossaryItem(
                      term: "Trusted Person",
                      definition: "Someone the walker trusts to accompany their journey. They can follow the journey and receive updates."
                  ),
                  GlossaryItem(
                      term: "Companion",
                      definition: "The trusted person following the journey. They can receive updates and know when the walker arrives."
                  )
              ]),
              imageName: "person.2.fill"
          ),

          OnboardingContent(
              title: "Set Your Default Locations",
              body: .paragraph(
                  "Add places like Home, Work, or Campus so you can choose them faster when starting a journey."
              ),
              imageName: "house.fill"
          )
      ]
  }

  enum Action: Equatable {
    case onAppear
    case onDisappear
    case timerTicked
    case setIndex(Int)
    case login(LoginFeature.Action)
    case delegate(Delegate)

    enum Delegate: Equatable {
      case loggedIn(UserProfile)
    }
  }

  @Dependency(\.continuousClock) var clock

  var body: some Reducer<State, Action> {
    Scope(state: \.login, action: \.login) {
      LoginFeature()
    }

    Reduce { state, action in
      switch action {
      case .onAppear:
          return .none
        .cancellable(id: "cancel_timer", cancelInFlight: true)

      case .onDisappear:
          return .none

      case .timerTicked:
          return .none
          
      case let .setIndex(index):
          state.currentIndex = index
          return .none

      case let .login(.delegate(.loggedIn(profile))):
        return .send(.delegate(.loggedIn(profile)))

      case .login:
        return .none

      case .delegate:
        return .none
      }
    }
  }
}
