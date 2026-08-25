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
  }

  enum Action: Equatable {
    case signOutButtonTapped
    case delegate(Delegate)

    enum Delegate: Equatable {
      case signedOut
    }
  }

  var body: some Reducer<State, Action> {
    Reduce { state, action in
      switch action {
      case .signOutButtonTapped:
        UserProfileStorage.clear()
        return .send(.delegate(.signedOut))

      case .delegate:
        return .none
      }
    }
  }
}
