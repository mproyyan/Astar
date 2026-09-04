//
//  LoginFeature.swift
//  Astar
//
//  Created by Muhammad Pandu Royyan on 24/08/26.
//

import AuthenticationServices
import CloudKit
import ComposableArchitecture
import Foundation

struct AppleSignInCredential: Equatable, Sendable {
  let appleUserId: String
  let name: String?
  let email: String?
}

struct UserProfile: Codable, Equatable, Sendable {
  let appleUserId: String
  let cloudKitUserId: String
  var name: String
  var email: String
  var status: String?
  var avatarData: Data?

  init(
    appleUserId: String,
    cloudKitUserId: String,
    name: String,
    email: String,
    status: String? = nil,
    avatarData: Data? = nil
  ) {
    self.appleUserId = appleUserId
    self.cloudKitUserId = cloudKitUserId
    self.name = name
    self.email = email
    self.status = status
    self.avatarData = avatarData
  }
  
  var recordName: String {
    "UserProfile_\(appleUserId)_\(cloudKitUserId)"
      .map { character in
        character.isLetter || character.isNumber ? character : "_"
      }
      .map(String.init)
      .joined()
  }
  
  var recordID: CKRecord.ID {
    CKRecord.ID(recordName: recordName)
  }
}

struct LoginError: Error, Equatable, Sendable {
  let message: String
}

enum UserProfileStorage {
  static let key = "user_profile"

  static func load() -> UserProfile? {
    guard let data = UserDefaults.standard.data(forKey: key) else { return nil }
    return try? JSONDecoder().decode(UserProfile.self, from: data)
  }

  static func save(_ profile: UserProfile) {
    guard let data = try? JSONEncoder().encode(profile) else { return }
    UserDefaults.standard.set(data, forKey: key)
  }

  static func clear() {
    UserDefaults.standard.removeObject(forKey: key)
  }
}

@Reducer
struct LoginFeature {
  @ObservableState
  struct State: Equatable {
    var userProfile: UserProfile?
    var isLoading = false
    var errorMessage: String?
  }

  enum Action: Equatable {
    case loadStoredUser
    case avatarLoaded(Data)
    case profileUpdated(UserProfile)
    case appleSignInCompleted(AppleSignInCredential)
    case loginResponse(Result<UserProfile, LoginError>)
    case signOutButtonTapped
    case delegate(Delegate)

    enum Delegate: Equatable {
      case loggedIn(UserProfile)
      case signedOut
    }
  }

  var body: some Reducer<State, Action> {
    Reduce { state, action in
      switch action {
      case .loadStoredUser:
        guard let profile = UserProfileStorage.load() else { return .none }
        state.userProfile = profile
        return .run { [profile] send in
          await send(.delegate(.loggedIn(profile)))

          // Proactively verify & resolve genuine Apple Account identity
          let container = CKContainer.default()
          var resolvedName = profile.name
          var resolvedEmail = profile.email

          if let userRecordID = try? await container.userRecordID(),
             let userIdentity = try? await container.userIdentity(forUserRecordID: userRecordID) {
            if let components = userIdentity.nameComponents {
              let discoveredName = PersonNameComponentsFormatter().string(from: components).trimmingCharacters(in: .whitespacesAndNewlines)
              if !discoveredName.isEmpty && (resolvedName == "User" || resolvedName.isEmpty) {
                resolvedName = discoveredName
              }
            }
            if let discoveredEmail = userIdentity.lookupInfo?.emailAddress?.trimmingCharacters(in: .whitespacesAndNewlines), !discoveredEmail.isEmpty && resolvedEmail.isEmpty {
              resolvedEmail = discoveredEmail
            }
          }

          let avatar = await ContactPhotoClient.liveValue.fetchMeCardPhoto(resolvedEmail, resolvedName)
          if avatar != profile.avatarData || resolvedName != profile.name || resolvedEmail != profile.email {
            var updated = profile
            updated.name = resolvedName
            updated.email = resolvedEmail
            updated.avatarData = avatar
            await send(.profileUpdated(updated))
          }
        }

      case let .avatarLoaded(avatarData):
        if var profile = state.userProfile {
          profile.avatarData = avatarData
          state.userProfile = profile
          UserProfileStorage.save(profile)
          return .send(.delegate(.loggedIn(profile)))
        }
        return .none

      case let .profileUpdated(updatedProfile):
        state.userProfile = updatedProfile
        UserProfileStorage.save(updatedProfile)
        return .send(.delegate(.loggedIn(updatedProfile)))

      case let .appleSignInCompleted(credential):
        state.isLoading = true
        state.errorMessage = nil

        return .run { send in
          do {
            let profile = try await upsertUserProfile(with: credential)
            UserProfileStorage.save(profile)
            await send(.loginResponse(.success(profile)))
          } catch {
            await send(.loginResponse(.failure(LoginError(message: error.localizedDescription))))
          }
        }

      case let .loginResponse(.success(profile)):
        state.isLoading = false
        state.userProfile = profile
        return .send(.delegate(.loggedIn(profile)))

      case let .loginResponse(.failure(error)):
        state.isLoading = false
        state.errorMessage = error.message
        return .none

      case .signOutButtonTapped:
        UserProfileStorage.clear()
        state.userProfile = nil
        state.errorMessage = nil
        state.isLoading = false
        return .send(.delegate(.signedOut))

      case .delegate:
        return .none
      }
    }
  }
}

private func upsertUserProfile(with credential: AppleSignInCredential) async throws -> UserProfile {
  _ = ASAuthorizationAppleIDProvider()

  let container = CKContainer.default()
  let database = container.publicCloudDatabase
  let userRecordID = try await container.userRecordID()
  let cloudKitUserId = userRecordID.recordName
  let recordID = CKRecord.ID(recordName: userProfileRecordName(
    appleUserId: credential.appleUserId,
    cloudKitUserId: cloudKitUserId
  ))

  // 1. Discover authentic name and email from CloudKit UserIdentity if missing from credential
  var discoveredName: String?
  var discoveredEmail: String?
  if let userIdentity = try? await container.userIdentity(forUserRecordID: userRecordID) {
    if let components = userIdentity.nameComponents {
      discoveredName = PersonNameComponentsFormatter().string(from: components).nilIfBlank
    }
    discoveredEmail = userIdentity.lookupInfo?.emailAddress?.nilIfBlank
  }

  let existingRecord = try? await database.record(for: recordID)
  let record = existingRecord ?? CKRecord(recordType: "UserProfile", recordID: recordID)
  let storedProfile = UserProfileStorage.load()
  let isSameStoredUser = storedProfile?.appleUserId == credential.appleUserId
  let existingName = (existingRecord?["name"] as? String)?.nilIfBlank
  let existingEmail = (existingRecord?["email"] as? String)?.nilIfBlank

  let name = credential.name?.nilIfBlank
    ?? discoveredName
    ?? existingName
    ?? (isSameStoredUser ? storedProfile?.name.nilIfBlank : nil)
    ?? "User"
  let email = credential.email?.nilIfBlank
    ?? discoveredEmail
    ?? existingEmail
    ?? (isSameStoredUser ? storedProfile?.email.nilIfBlank : nil)
    ?? ""

  var avatarData: Data? = nil
  if let photo = await ContactPhotoClient.liveValue.fetchMeCardPhoto(email, name) {
    avatarData = photo
  } else if let existingAvatarData = existingRecord?["avatarData"] as? Data {
    avatarData = existingAvatarData
  }

  record["appleUserId"] = credential.appleUserId as CKRecordValue
  record["cloudKitUserId"] = cloudKitUserId as CKRecordValue
  record["name"] = name as CKRecordValue
  record["email"] = email as CKRecordValue
  if let avatarData {
    record["avatarData"] = avatarData as CKRecordValue
  } else {
    record["avatarData"] = nil
  }

  _ = try? await database.save(record)

  return UserProfile(
    appleUserId: credential.appleUserId,
    cloudKitUserId: cloudKitUserId,
    name: name,
    email: email,
    status: existingRecord?["Status"] as? String,
    avatarData: avatarData
  )
}

private func userProfileRecordName(appleUserId: String, cloudKitUserId: String) -> String {
  "UserProfile_\(appleUserId)_\(cloudKitUserId)"
    .map { character in
      character.isLetter || character.isNumber ? character : "_"
    }
    .map(String.init)
    .joined()
}

private extension String {
  var nilIfBlank: String? {
    let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
    return trimmed.isEmpty ? nil : trimmed
  }
}
