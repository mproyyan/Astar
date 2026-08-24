import ComposableArchitecture
import Foundation

@Reducer
struct MainFeature {
  @ObservableState
  struct State: Equatable {
    var login: LoginFeature.State = .init()
    var map: MainScreenMapFeature.State = .init()
    
    init(userProfile: UserProfile? = nil) {
      self.login = LoginFeature.State(userProfile: userProfile)
    }
  }

  enum Action: Equatable {
    case login(LoginFeature.Action)
    case map(MainScreenMapFeature.Action)
  }

  var body: some Reducer<State, Action> {
    Scope(state: \.login, action: \.login) {
      LoginFeature()
    }
    
    Scope(state: \.map, action: \.map) {
      MainScreenMapFeature()
    }
  }
}
