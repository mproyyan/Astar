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
    var isPeopleLoading: Bool = false
    var isDevelopmentMode: Bool = DeveloperSettingsStorage.isDevelopmentMode
    var isShowRouteGuide: Bool = DeveloperSettingsStorage.isShowRouteGuide
    var isDoeWalkingMock: Bool = DeveloperSettingsStorage.isDoeWalkingMockEnabled
    
    init(
      userProfile: UserProfile? = nil,
      isDevelopmentMode: Bool = DeveloperSettingsStorage.isDevelopmentMode,
      isShowRouteGuide: Bool = DeveloperSettingsStorage.isShowRouteGuide,
      isDoeWalkingMock: Bool = DeveloperSettingsStorage.isDoeWalkingMockEnabled
    ) {
      self.login = LoginFeature.State(userProfile: userProfile)
      self.isDevelopmentMode = isDevelopmentMode
      self.isShowRouteGuide = isShowRouteGuide
      self.isDoeWalkingMock = isDoeWalkingMock
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
    case incomingInvitationDismissed(participantRecordID: String)
    case invitationWalkerResolved(Person, isAccepted: Bool)

    enum Delegate: Equatable {
      case signedOut
    }
  }
  
  @Dependency(\.usersClient) var usersClient
  @Dependency(\.connectionsClient) var connectionsClient
  @Dependency(\.trackingClient) var trackingClient
  @Dependency(\.connectionsClient) var connectionsClient
  @Dependency(\.contactPhotoClient) var contactPhotoClient
  
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
        if let person = state.people.first(where: {
          let recID = "UserProfile_\($0.appleUserId ?? "")_\($0.cloudKitUserId ?? "")"
            .replacingOccurrences(of: "[^a-zA-Z0-9]", with: "_", options: .regularExpression)
          return recID == walkerRef || ($0.cloudKitUserId != nil && walkerRef.contains($0.cloudKitUserId!))
        }) {
          guard !state.map.isNavigating else { return .none }
          return .send(.map(.selectPerson(person)))
        }
        return .none

      case let .incomingInvitationDismissed(participantRecordID):
        return .run { [trackingClient] _ in
          do {
            let participant = try await trackingClient.fetchSessionParticipant(participantRecordID)
            guard !participant.sessionRef.isEmpty, !participant.companionRef.isEmpty else { return }
            _ = try await trackingClient.updateParticipantStatus(participant.sessionRef, participant.companionRef, "dismiss")
            print("🚫 [MainFeature] Updated participant \(participantRecordID) status to dismiss")
          } catch {
            print("⚠️ [MainFeature] Failed updating participant \(participantRecordID) to dismiss: \(error)")
          }
        }

      case let .incomingInvitationReceived(participantRecordID, isAccepted):
        let currentUser = state.login.userProfile
        let selfRecordID = currentUser.map {
          "UserProfile_\($0.appleUserId)_\($0.cloudKitUserId)"
            .replacingOccurrences(of: "[^a-zA-Z0-9]", with: "_", options: .regularExpression)
        }

        // Navigation Guard: If actively navigating as a walker, ignore incoming invitation events
        if state.map.isNavigating && state.map.userWalkSessionID != nil {
          print("⚠️ [MainFeature] Ignoring incomingInvitationReceived because user is navigating as walker.")
          return .none
        }

        return .run { [usersClient, trackingClient, connectionsClient, contactPhotoClient] send in
          do {
            let participant = try await trackingClient.fetchSessionParticipant(participantRecordID)
            guard !participant.sessionRef.isEmpty else { return }

            // Identity Guard: Current user must be the invited companion
            if let selfID = selfRecordID, !selfID.isEmpty {
              guard participant.companionRef == selfID else {
                print("ℹ️ [MainFeature] Ignoring invitation intended for companion \(participant.companionRef) (self: \(selfID))")
                return
              }
            }

            let session = try await trackingClient.getWalkSession(participant.sessionRef)
            guard !session.walkerRef.isEmpty else { return }

            // Identity Guard: Current user cannot be the walker of this session
            if let selfID = selfRecordID, !selfID.isEmpty {
              guard session.walkerRef != selfID else {
                print("ℹ️ [MainFeature] Ignoring invitation because current user is the walker (\(session.walkerRef))")
                return
              }
            }

            let walkerPerson = await Self.resolveWalkerPerson(
              walkerRef: session.walkerRef,
              usersClient: usersClient,
              connectionsClient: connectionsClient,
              contactPhotoClient: contactPhotoClient
            )
            await send(.invitationWalkerResolved(walkerPerson, isAccepted: isAccepted))
          } catch {
            print("⚠️ [MainFeature] Failed resolving incoming invitation \(participantRecordID): \(error)")
          }
        }

      case let .invitationWalkerResolved(walkerPerson, isAccepted):
        // Guard against overwriting sheet while actively navigating
        guard !state.map.isNavigating else {
          print("⚠️ [MainFeature] Ignoring invitationWalkerResolved because user is navigating.")
          return .none
        }
        let currentUser = state.login.userProfile ?? UserProfileStorage.load()
        if let user = currentUser {
          let selfPersonID = Person.stableID(appleUserId: user.appleUserId, cloudKitUserId: user.cloudKitUserId)
          if walkerPerson.id == selfPersonID || walkerPerson.appleUserId == user.appleUserId {
            print("⚠️ [MainFeature] Ignoring invitationWalkerResolved for self.")
            return .none
          }
        }

        let selectAction = Action.map(.selectPerson(walkerPerson))
        if isAccepted {
          return .concatenate(
            .send(selectAction),
            .send(.map(.sheet(.presented(.walker(.trackTapped)))))
          )
        } else {
          return .send(selectAction)
        }

      case .onAppear:
        state.isPeopleLoading = true
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
              for await notification in NotificationCenter.default.publisher(for: AppDelegate.walkInvitationDismissedNotification).values {
                guard !Task.isCancelled else { break }
                if let recordID = notification.userInfo?["recordID"] as? CKRecord.ID {
                  await send(.incomingInvitationDismissed(participantRecordID: recordID.recordName))
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
        return .run { [currentUser = state.login.userProfile, contactPhotoClient] send in
          do {
            guard let profile = UserProfileStorage.load() else {
              await send(.fetchPeopleResponse(.success([])))
              return
            }
            let connectionProfiles = try await connectionsClient.fetchConnections(profile.recordID)
            let mutualProfiles = connectionProfiles.filter { $0.connection.status == "mutual" }
            var people: [Person] = []
            for cp in mutualProfiles {
              let partnerProfile = cp.partnerProfile
              guard partnerProfile.appleUserId != currentUser?.appleUserId else { continue }
              var avatar = partnerProfile.avatarData
              if avatar == nil {
                avatar = await ContactPhotoClient.liveValue.fetchContactPhotoByEmail(partnerProfile.email)
              }
              if avatar == nil {
                avatar = await ContactPhotoClient.liveValue.fetchContactPhotoByName(partnerProfile.name)
              }
              let avatarImageName = partnerProfile.name == "Awan" ? "AwanAvatar" : nil
              people.append(Person(
                id: Person.stableID(appleUserId: profile.appleUserId, cloudKitUserId: profile.cloudKitUserId),
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
        state.isPeopleLoading = false
        return .none
        
      case .fetchPeopleResponse(.failure):
        if state.isDevelopmentMode {
          let doe = state.people.first(where: { $0.id == Person.mockDoeID }) ?? Person.mockDoe
          state.people = [doe]
        } else {
          state.people = []
        }
        state.map.people = state.people
        state.isPeopleLoading = false
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
        
      case .path(.element(id: let id, action: .profile(.delegate(.restartDoeWalkingSimulation)))):
        state.isDoeWalkingMock = true
        state.path[id: id, case: \.profile]?.isDoeWalkingMock = true
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

  static func resolveWalkerPerson(
    walkerRef: String,
    usersClient: UsersClient,
    connectionsClient: ConnectionsClient,
    contactPhotoClient: ContactPhotoClient
  ) async -> Person {
    await resolvePerson(
      recordRef: walkerRef,
      usersClient: usersClient,
      connectionsClient: connectionsClient,
      contactPhotoClient: contactPhotoClient,
      defaultStatus: "Walking"
    )
  }

  static func resolvePerson(
    recordRef: String,
    usersClient: UsersClient,
    connectionsClient: ConnectionsClient,
    contactPhotoClient: ContactPhotoClient,
    defaultStatus: String = "Accompanying"
  ) async -> Person {
    // 1. Check Mock Doe
    if recordRef == "mock-doe" || recordRef.localizedCaseInsensitiveContains("doe") {
      return Person.mockDoe
    }

    // 2. Direct CloudKit record lookup
    if let profile = try? await usersClient.fetchUserByRecordID(recordRef) {
      return await makePerson(from: profile, contactPhotoClient: contactPhotoClient, defaultStatus: defaultStatus)
    }

    // 3. Match against all users via sanitized ID
    if let allProfiles = try? await usersClient.fetchAllUsers() {
      for profile in allProfiles {
        let recID = "UserProfile_\(profile.appleUserId)_\(profile.cloudKitUserId)"
          .replacingOccurrences(of: "[^a-zA-Z0-9]", with: "_", options: .regularExpression)
        if recID == recordRef
            || (!profile.cloudKitUserId.isEmpty && recordRef.contains(profile.cloudKitUserId))
            || (!profile.appleUserId.isEmpty && recordRef.contains(profile.appleUserId)) {
          return await makePerson(from: profile, contactPhotoClient: contactPhotoClient, defaultStatus: defaultStatus)
        }
      }
    }

    // 4. Match against mutual connections
    if let currentUser = UserProfileStorage.load() {
      let selfRecordID = "UserProfile_\(currentUser.appleUserId)_\(currentUser.cloudKitUserId)"
        .replacingOccurrences(of: "[^a-zA-Z0-9]", with: "_", options: .regularExpression)
      if let connections = try? await connectionsClient.fetchConnections(CKRecord.ID(recordName: selfRecordID)) {
        for conn in connections {
          let partner = conn.partnerProfile
          let recID = "UserProfile_\(partner.appleUserId)_\(partner.cloudKitUserId)"
            .replacingOccurrences(of: "[^a-zA-Z0-9]", with: "_", options: .regularExpression)
          if recID == recordRef
              || (!partner.cloudKitUserId.isEmpty && recordRef.contains(partner.cloudKitUserId))
              || (!partner.appleUserId.isEmpty && recordRef.contains(partner.appleUserId)) {
            return await makePerson(from: partner, contactPhotoClient: contactPhotoClient, defaultStatus: defaultStatus)
          }
        }
      }
    }

    // 5. Fallback with cleaned display name if record is completely unreachable
    let fallbackName = recordRef.replacingOccurrences(of: "UserProfile_", with: "")
    return Person(
      name: fallbackName.isEmpty ? (defaultStatus == "Walking" ? "Walker" : "Companion") : fallbackName,
      status: defaultStatus,
      cloudKitUserId: recordRef
    )
  }

  static func makePerson(from profile: UserProfile, contactPhotoClient: ContactPhotoClient, defaultStatus: String = "Walking") async -> Person {
    var avatar = profile.avatarData
    if avatar == nil {
      avatar = await contactPhotoClient.fetchContactPhotoByEmail(profile.email)
    }
    if avatar == nil {
      avatar = await contactPhotoClient.fetchContactPhotoByName(profile.name)
    }
    let avatarImageName = profile.name == "Awan" ? "AwanAvatar" : nil
    return Person(
      id: Person.stableID(appleUserId: profile.appleUserId, cloudKitUserId: profile.cloudKitUserId),
      name: profile.name,
      status: Self.formatStatus(profile.status),
      appleUserId: profile.appleUserId,
      cloudKitUserId: profile.cloudKitUserId,
      email: profile.email,
      avatarData: avatar,
      avatarImageName: avatarImageName
    )
  }
}

// Ensure Error is Equatable for TCA testing if needed, or wrap in a custom error.
// We'll just define a naive wrapper if needed, but in TCA Result<T, Error> for Action requires Error to be castable.
