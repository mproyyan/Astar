//
//  OnboardingFeature.swift
//  Astar
//
//  Created by Muhammad Pandu Royyan on 24/08/26.
//

import ComposableArchitecture
import Foundation

struct GlossaryItem: Equatable, Identifiable {
    let id = UUID()
    let term: String
    let definition: String
}

enum PageBody: Equatable {
    case paragraph(String)
    case glossary([GlossaryItem])
}

struct OnboardingContent: Equatable, Identifiable {
  let id = UUID()
  let title: String
//  let description: String
    let body: PageBody
  let imageName: String
}

@Reducer
struct OnboardingFeature {
  @ObservableState
  struct State: Equatable {
    var currentIndex = 0
    var pendingDeepLink: DeepLink? = nil
    var contents: [OnboardingContent] = [
      OnboardingContent(
        title: "WalkGuard",
        body: .paragraph("Never feel alone. Trail keeps your trusted person updated in real time, so you can stay aware of your surroundings without checking your phone."),
        imageName: "figure.walk.motion"
      ),
      OnboardingContent(
        title: "Walker & Guardian",
        body: .glossary([
            GlossaryItem(term: "Walker", definition: "The person commuting on foot. Your journey is shared through your iPhone or Apple Watch."),
            GlossaryItem(term: "Companion", definition: "Your trusted person. You can assign your Companion in your profile so they can actively watch your journey and get notified when you arrive."),
        ]),
        imageName: "person.3.fill"
      ),
      OnboardingContent(
        title: "Default Place",
        body: .paragraph("Add frequent stops like Home or Work to your profile. This helps Trail instantly recognize your usual routes without manual typing."),
        imageName: "house.fill"
      )
    ]
  }

  enum Action: Equatable {
    case onAppear
    case onDisappear
    case timerTicked
    case setIndex(Int)
    case appleSignInCompleted(AppleSignInCredential)
    case delegate(Delegate)

    enum Delegate: Equatable {
      case appleSignInCompleted(AppleSignInCredential)
    }
  }

  @Dependency(\.continuousClock) var clock

  var body: some Reducer<State, Action> {
    Reduce { state, action in
      switch action {
      case .onAppear:
        return .run { send in
          for await _ in await self.clock.timer(interval: .seconds(3)) {
            await send(.timerTicked)
          }
        }
        .cancellable(id: "cancel_timer", cancelInFlight: true)

      case .onDisappear:
        return .cancel(id: "cancel_timer")

      case .timerTicked:
        state.currentIndex = (state.currentIndex + 1) % state.contents.count
        return .none

      case let .setIndex(index):
        state.currentIndex = index
        return .concatenate(
          .cancel(id: "cancel_timer"),
          .run { send in
            for await _ in await self.clock.timer(interval: .seconds(3)) {
              await send(.timerTicked)
            }
          }
          .cancellable(id: "cancel_timer", cancelInFlight: true)
        )

      case let .appleSignInCompleted(credential):
        return .send(.delegate(.appleSignInCompleted(credential)))

      case .delegate:
        return .none
      }
    }
  }
}
