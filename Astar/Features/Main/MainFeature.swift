import CloudKit
import Combine
import ComposableArchitecture
import Foundation

@Reducer
struct MainFeature {
  @Reducer(state: .equatable, action: .equatable)
  enum Path {
    case profile(ProfileFeature)
    case trustedPerson(TrustedPersonFeature)
    case requestTrustedPerson(RequestTrustedPersonFeature)
    case savedPlaces(SavedPlacesFeature)
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
    case refreshPeople
    case fetchPeopleResponse(Result<[Person], FetchUsersError>)
    case profileButtonTapped
    case savedPlacesHeaderTapped
    case login(LoginFeature.Action)
    case map(MainMapFeature.Action)
    case path(StackActionOf<Path>)
    case delegate(Delegate)
    case handleAcceptedInvitation(String)
    case incomingInvitationReceived(participantRecordID: String, isAccepted: Bool)
    case invitationWalkerResolved(Person, isAccepted: Bool)

    enum Delegate: Equatable {
      case signedOut
    }
  }
  
  @Dependency(\.usersClient) var usersClient
  @Dependency(\.trackingClient) var trackingClient
  
  var body: some Reducer<State, Action> {
    Scope(state: \.login, action: \.login) {
      LoginFeature()
    }
    
    Scope(state: \.map, action: \.map) {
      MainMapFeature()
    }
    
    Reduce { state, action in
      switch action {
      case let .handleAcceptedInvitation(walkerRef):
        let prefix = "UserProfile_"
        let ids = walkerRef.replacingOccurrences(of: prefix, with: "").components(separatedBy: "_")
        if ids.count >= 2 {
            let appleUserId = ids[0]
            let cloudKitUserId = ids[1...].joined(separator: "_")
            if let person = state.people.first(where: { $0.appleUserId == appleUserId && $0.cloudKitUserId == cloudKitUserId }) {
                return .send(.map(.selectPerson(person)))
            } else if let person = state.people.first(where: { $0.cloudKitUserId == cloudKitUserId }) {
                return .send(.map(.selectPerson(person)))
            }
        }
        return .none

      case let .incomingInvitationReceived(participantRecordID, isAccepted):
        return .run { [usersClient, trackingClient] send in
          do {
            let participant = try await trackingClient.fetchSessionParticipant(participantRecordID)
            guard !participant.sessionRef.isEmpty else { return }
            let session = try await trackingClient.getWalkSession(participant.sessionRef)
            guard !session.walkerRef.isEmpty else { return }

            let prefix = "UserProfile_"
            let ids = session.walkerRef.replacingOccurrences(of: prefix, with: "").components(separatedBy: "_")
            if ids.count >= 2 {
              let appleUserId = ids[0]
              let cloudKitUserId = ids[1...].joined(separator: "_")
              let profiles = (try? await usersClient.fetchAllUsers()) ?? []
              if let matchedProfile = profiles.first(where: { $0.appleUserId == appleUserId || $0.cloudKitUserId == cloudKitUserId }) {
                let walkerPerson = Person(
                  name: matchedProfile.name,
                  status: Self.formatStatus(matchedProfile.status),
                  appleUserId: matchedProfile.appleUserId,
                  cloudKitUserId: matchedProfile.cloudKitUserId,
                  email: matchedProfile.email,
                  avatarData: matchedProfile.avatarData
                )
                await send(.invitationWalkerResolved(walkerPerson, isAccepted: isAccepted))
                return
              }
            }

            let walkerPerson = Person(name: "Walker", status: "Walking", cloudKitUserId: session.walkerRef)
            await send(.invitationWalkerResolved(walkerPerson, isAccepted: isAccepted))
          } catch {
            print("⚠️ [MainFeature] Failed resolving incoming invitation \(participantRecordID): \(error)")
          }
        }

      case let .invitationWalkerResolved(walkerPerson, isAccepted):
        let selectAction = Action.map(.selectPerson(walkerPerson))
        if isAccepted {
          return .merge(
            .send(selectAction),
            .send(.map(.sheet(.presented(.walker(.trackTapped)))))
          )
        } else {
          return .send(selectAction)
        }

      case .onAppear:
        let currentUser = state.login.userProfile ?? UserProfileStorage.load()
        return .run { [trackingClient] send in
          // 1. Setup invitation subscription for companion
          if let profile = currentUser {
            let selfRecordID = "UserProfile_\(profile.appleUserId)_\(profile.cloudKitUserId)"
              .replacingOccurrences(of: "[^a-zA-Z0-9]", with: "_", options: .regularExpression)
            do {
              try await trackingClient.setupInvitationSubscription(selfRecordID)
              print("✅ [MainFeature] setupInvitationSubscription registered for \(selfRecordID)")
            } catch {
              print("⚠️ [MainFeature] setupInvitationSubscription failed: \(error)")
            }
          }

          // 2. Initial fetch
          await send(.refreshPeople)

          // 3. Listen for push notification events and periodic refresh
          await withTaskGroup(of: Void.self) { group in
            group.addTask {
              for await notification in NotificationCenter.default.publisher(for: AppDelegate.walkInvitationNotification).values {
                guard !Task.isCancelled else { break }
                if let recordID = notification.userInfo?["recordID"] as? CKRecord.ID {
                  await send(.incomingInvitationReceived(participantRecordID: recordID.recordName, isAccepted: false))
                }
              }
            }

            group.addTask {
              for await notification in NotificationCenter.default.publisher(for: AppDelegate.walkInvitationAcceptedNotification).values {
                guard !Task.isCancelled else { break }
                if let recordID = notification.userInfo?["recordID"] as? CKRecord.ID {
                  await send(.incomingInvitationReceived(participantRecordID: recordID.recordName, isAccepted: true))
                }
              }
            }

            group.addTask {
              while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 6_000_000_000)
                guard !Task.isCancelled else { break }
                await send(.refreshPeople)
              }
            }
          }
        }

      case .refreshPeople:
        return .run { [currentUser = state.login.userProfile] send in
          do {
            let profiles = try await usersClient.fetchAllUsers()
            var people: [Person] = []
            for profile in profiles.filter({ $0.appleUserId != currentUser?.appleUserId }) {
              var avatar = profile.avatarData
              if avatar == nil {
                avatar = await ContactPhotoClient.liveValue.fetchContactPhotoByEmail(profile.email)
              }
              if avatar == nil {
                avatar = await ContactPhotoClient.liveValue.fetchContactPhotoByName(profile.name)
              }
              let avatarImageName = profile.name == "Awan" ? "AwanAvatar" : nil
              people.append(Person(
                id: UUID(),
                name: profile.name,
                status: Self.formatStatus(profile.status),
                appleUserId: profile.appleUserId,
                cloudKitUserId: profile.cloudKitUserId,
                email: profile.email,
                avatarData: avatar,
                avatarImageName: avatarImageName
              ))
            }
            await send(.fetchPeopleResponse(.success(people)))
          } catch {
            await send(.fetchPeopleResponse(.failure(FetchUsersError(error: error))))
          }
        }

      case let .fetchPeopleResponse(.success(incomingPeople)):
        // Merge or update while preserving existing IDs to avoid SwiftUI list flickering
        var updatedPeople: [Person] = []
        for person in incomingPeople {
          if let existing = state.people.first(where: { ($0.appleUserId != nil && $0.appleUserId == person.appleUserId) || ($0.cloudKitUserId != nil && $0.cloudKitUserId == person.cloudKitUserId) }) {
            updatedPeople.append(Person(
              id: existing.id,
              name: person.name,
              status: person.status,
              appleUserId: person.appleUserId,
              cloudKitUserId: person.cloudKitUserId,
              email: person.email ?? existing.email,
              avatarData: person.avatarData ?? existing.avatarData,
              avatarImageName: person.avatarImageName ?? existing.avatarImageName
            ))
          } else {
            updatedPeople.append(person)
          }
        }

        if state.isDevelopmentMode {
          let doe = state.people.first(where: { $0.id == Person.mockDoeID }) ?? Person.mockDoe
          state.people = [doe] + updatedPeople.filter { $0.id != Person.mockDoeID }
        } else {
          state.people = updatedPeople.filter { $0.id != Person.mockDoeID }
        }
        state.map.people = state.people
        return .none
        
      case .fetchPeopleResponse(.failure):
        if state.isDevelopmentMode {
          let doe = state.people.first(where: { $0.id == Person.mockDoeID }) ?? Person.mockDoe
          state.people = [doe]
        } else {
          state.people = []
        }
        state.map.people = state.people
        return .none
        
      case .profileButtonTapped:
        let userProfile = state.login.userProfile ?? UserProfileStorage.load()
        let profileState = ProfileFeature.State(
          userProfile: userProfile,
          isDevelopmentMode: state.isDevelopmentMode,
          isShowRouteGuide: state.isShowRouteGuide,
          isDoeWalkingMock: state.isDoeWalkingMock
        )
        state.path.append(.profile(profileState))
        return .none

      case .savedPlacesHeaderTapped:
        let userId = state.login.userProfile?.appleUserId ?? "default_user"
        state.path.append(.savedPlaces(SavedPlacesFeature.State(userId: userId)))
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
        
      case .path(.element(id: _, action: .profile(.delegate(.trustedPersonTapped)))):
        state.path.append(.trustedPerson(TrustedPersonFeature.State()))
        return .none
        
      case let .path(.element(id: _, action: .trustedPerson(.delegate(.requestSectionTapped(requests))))):
        state.path.append(.requestTrustedPerson(RequestTrustedPersonFeature.State(requests: requests)))
        return .none
        
      case .path(.element(id: _, action: .profile(.delegate(.signedOut)))):
        state.path.removeAll()
        state.login.userProfile = nil
        UserProfileStorage.clear()
        return .none

      case let .path(.element(id: _, action: .profile(.delegate(.savedPlacesUpdated(places))))):
        return .send(.map(.savedPlacesUpdated(places)))

      case .login(.delegate(.signedOut)):
        state.path.removeAll()
        state.login.userProfile = nil
        UserProfileStorage.clear()
        return .none

      case .login(.delegate(.loggedIn)):
        return .send(.onAppear)
        
      case .login:
        return .none        

      case .delegate:
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

  static func formatStatus(_ raw: String?) -> String {
    guard let trimmed = raw?.trimmingCharacters(in: .whitespacesAndNewlines), !trimmed.isEmpty else {
      return "Idle"
    }
    let lower = trimmed.lowercased()
    if lower == "walking" {
      return "Walking"
    } else if lower == "idle" {
      return "Idle"
    } else if lower == "accompany" || lower == "accompanying" {
      return "Accompanying"
    }
    return trimmed.capitalized
  }
}

// Ensure Error is Equatable for TCA testing if needed, or wrap in a custom error.
// We'll just define a naive wrapper if needed, but in TCA Result<T, Error> for Action requires Error to be castable.
