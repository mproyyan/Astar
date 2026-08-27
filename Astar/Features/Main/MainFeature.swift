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
    var people: [Person] = []

    init(userProfile: UserProfile? = nil) {
      self.login = LoginFeature.State(userProfile: userProfile)
    }
  }

  enum Action: Equatable {
    case onAppear
    case fetchPeopleResponse(Result<[Person], FetchUsersError>)
    case login(LoginFeature.Action)
    case map(MainMapFeature.Action)
    case path(StackActionOf<Path>)
    case profileButtonTapped
  }

  @Dependency(\.usersClient) var usersClient

  var body: some Reducer<State, Action> {
    Scope(state: \.login, action: \.login) {
      LoginFeature()
    }

    Scope(state: \.map, action: \.map) {
      MainMapFeature()
    }

    Reduce { state, action in
      switch action {
      case .onAppear:
        return .run { [currentUser = state.login.userProfile] send in
          do {
            let profiles = try await usersClient.fetchAllUsers()
            let people = profiles
              .filter { $0.appleUserId != currentUser?.appleUserId }
              .map { Person(id: UUID(), name: $0.name, status: ($0.status == nil || $0.status?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == true) ? "Idle" : $0.status!, appleUserId: $0.appleUserId, cloudKitUserId: $0.cloudKitUserId) }
            await send(.fetchPeopleResponse(.success(people)))
          } catch {
            await send(.fetchPeopleResponse(.failure(FetchUsersError(error: error))))
          }
        } // We ignore errors for now, or you can add error handling

      case let .fetchPeopleResponse(.success(people)):
        state.people = people
        return .none

      case .fetchPeopleResponse(.failure):
        return .none

      case .profileButtonTapped:
        let profileState = ProfileFeature.State(userProfile: state.login.userProfile)
        state.path.append(.profile(profileState))
        return .none

      case .path(.element(id: _, action: .profile(.delegate(.signedOut)))):
        return .send(.login(.signOutButtonTapped))
        
      case let .login(.delegate(.loggedIn(user))):
        // If they log in, fetch the people to refresh logic
        return .send(.onAppear)
        
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

// Ensure Error is Equatable for TCA testing if needed, or wrap in a custom error.
// We'll just define a naive wrapper if needed, but in TCA Result<T, Error> for Action requires Error to be castable.
