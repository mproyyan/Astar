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
  let name: String
  let email: String
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
        return .send(.delegate(.loggedIn(profile)))

      case let .appleSignInCompleted(credential):
        state.isLoading = true
        state.errorMessage = nil

        return .run { send in
          do {
            let profile = try await upsertUserProfile(with: credential)
            await UserProfileStorage.save(profile)
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

  let container = CKContainer(identifier: "iCloud.com.astar.trail")
  let database = container.publicCloudDatabase
  let cloudKitUserId = try await container.userRecordID().recordName
  let recordID = CKRecord.ID(recordName: userProfileRecordName(
    appleUserId: credential.appleUserId,
    cloudKitUserId: cloudKitUserId
  ))

  let existingRecord = try? await database.record(for: recordID)
  let record = existingRecord ?? CKRecord(recordType: "UserProfile", recordID: recordID)
  let storedProfile = UserProfileStorage.load()
  let existingName = (existingRecord?["name"] as? String)?.nilIfBlank
  let existingEmail = (existingRecord?["email"] as? String)?.nilIfBlank
  let name = credential.name?.nilIfBlank
    ?? existingName
    ?? storedProfile?.name.nilIfBlank
    ?? ""
  let email = credential.email?.nilIfBlank
    ?? existingEmail
    ?? storedProfile?.email.nilIfBlank
    ?? ""

  record["appleUserId"] = credential.appleUserId as CKRecordValue
  record["cloudKitUserId"] = cloudKitUserId as CKRecordValue
  record["name"] = name as CKRecordValue
  record["email"] = email as CKRecordValue

  _ = try await database.save(record)

  return UserProfile(
    appleUserId: credential.appleUserId,
    cloudKitUserId: cloudKitUserId,
    name: name,
    email: email
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
