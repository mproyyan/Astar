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
    var isDevelopmentMode: Bool = DeveloperSettingsStorage.isDevelopmentMode
    var isShowRouteGuide: Bool = DeveloperSettingsStorage.isShowRouteGuide
    var isDoeWalkingMock: Bool = DeveloperSettingsStorage.isDoeWalkingMockEnabled

    init(userProfile: UserProfile? = nil) {
      self.login = LoginFeature.State(userProfile: userProfile)
    }
  }

  enum Action: Equatable {
    case onAppear
    case fetchPeopleResponse(Result<[Person], FetchUsersError>)
    case profileButtonTapped
    case login(LoginFeature.Action)
    case map(MainMapFeature.Action)
    case path(StackActionOf<Path>)
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
        if state.isDevelopmentMode {
          state.people = [Person.mockDoe] + people
        } else {
          state.people = people
        }
        return .none

      case .fetchPeopleResponse(.failure):
        if state.isDevelopmentMode {
          state.people = [Person.mockDoe]
        } else {
          state.people = []
        }
        return .none

      case .profileButtonTapped:
        let profileState = ProfileFeature.State(
          userProfile: state.login.userProfile,
          isDevelopmentMode: state.isDevelopmentMode,
          isShowRouteGuide: state.isShowRouteGuide,
          isDoeWalkingMock: state.isDoeWalkingMock
        )
        state.path.append(.profile(profileState))
        return .none

      case let .path(.element(id: _, action: .profile(.delegate(.developmentModeChanged(isEnabled))))):
        state.isDevelopmentMode = isEnabled
        if isEnabled {
          if !state.people.contains(where: { $0.id == Person.mockDoeID }) {
            state.people.insert(Person.mockDoe, at: 0)
          }
        } else {
          state.people.removeAll(where: { $0.id == Person.mockDoeID })
        }
        return .none

      case let .path(.element(id: _, action: .profile(.delegate(.routeGuideChanged(isEnabled))))):
        state.isShowRouteGuide = isEnabled
        state.map.isShowRouteGuide = isEnabled
        return .none

      case let .path(.element(id: _, action: .profile(.delegate(.doeWalkingMockChanged(isEnabled))))):
        state.isDoeWalkingMock = isEnabled
        if state.isDevelopmentMode {
          let newStatus = isEnabled ? "Walking" : "Idle"
          if let idx = state.people.firstIndex(where: { $0.id == Person.mockDoeID }) {
            state.people[idx] = Person(id: Person.mockDoeID, name: "Doe", status: newStatus)
          } else {
            state.people.insert(Person(id: Person.mockDoeID, name: "Doe", status: newStatus), at: 0)
          }
        }
        return .none

      case .path(.element(id: _, action: .profile(.delegate(.restartDoeWalkingSimulation)))):
        state.isDoeWalkingMock = true
        if let idx = state.people.firstIndex(where: { $0.id == Person.mockDoeID }) {
          state.people[idx] = Person(id: Person.mockDoeID, name: "Doe", status: "Walking")
        }
        return .send(.map(.resetDoeWalking))

      case .path(.element(id: _, action: .profile(.delegate(.signedOut)))):
        return .send(.login(.signOutButtonTapped))

      case .login:
        return .none

      case let .map(.delegate(.walkerStatusChanged(id, newStatus))):
        if let idx = state.people.firstIndex(where: { $0.id == id }) {
          let person = state.people[idx]
          state.people[idx] = Person(
            id: person.id,
            name: person.name,
            status: newStatus,
            appleUserId: person.appleUserId,
            cloudKitUserId: person.cloudKitUserId
          )
        }
        return .none

      case let .map(.delegate(.companionStatusChanged(newStatus))):
        state.login.userProfile?.status = newStatus
        if var profile = UserProfileStorage.load() {
          profile.status = newStatus
          UserProfileStorage.save(profile)
        }
        for i in 0..<state.people.count {
          if state.people[i].status.caseInsensitiveCompare("accompany") == .orderedSame {
            let p = state.people[i]
            state.people[i] = Person(
              id: p.id,
              name: p.name,
              status: "Idle",
              appleUserId: p.appleUserId,
              cloudKitUserId: p.cloudKitUserId
            )
          }
        }
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
