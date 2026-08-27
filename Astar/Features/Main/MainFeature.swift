import ComposableArchitecture
import Foundation

@Reducer
struct MainFeature {
  @Reducer(state: .equatable, action: .equatable)
  enum Path {
    case profile(ProfileFeature)
  }

  @ObservableState
  struct State: Equatable {
    var login: LoginFeature.State = .init()
    var map: MainMapFeature.State = .init()
    var path = StackState<Path.State>()

    init(userProfile: UserProfile? = nil) {
      self.login = LoginFeature.State(userProfile: userProfile)
    }
  }

  enum Action: Equatable {
    case login(LoginFeature.Action)
    case map(MainMapFeature.Action)
    case path(StackActionOf<Path>)
    case profileButtonTapped
  }

  var body: some Reducer<State, Action> {
    Scope(state: \.login, action: \.login) {
      LoginFeature()
    }

    Scope(state: \.map, action: \.map) {
      MainMapFeature()
    }

    Reduce { state, action in
      switch action {
      case .profileButtonTapped:
        let profileState = ProfileFeature.State(userProfile: state.login.userProfile)
        state.path.append(.profile(profileState))
        return .none

      case .path(.element(id: _, action: .profile(.delegate(.signedOut)))):
        return .send(.login(.signOutButtonTapped))

      case .login:
        return .none

      case .map:
        return .none

      case .path:
        return .none
      }
    }
    .forEach(\.path, action: \.path)
  }
}


