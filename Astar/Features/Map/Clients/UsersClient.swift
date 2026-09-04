import CloudKit
import ComposableArchitecture
import Foundation

@DependencyClient
struct UsersClient {
  var fetchAllUsers: () async throws -> [UserProfile]
  var fetchUserByEmail: (_ email: String) async throws -> UserProfile?
}

extension UsersClient: DependencyKey {
  static let liveValue = Self.live()
  static let testValue = Self(fetchAllUsers: { [] }, fetchUserByEmail: { _ in nil })

  static func live() -> Self {
    return Self(
      fetchAllUsers: {
        let container = CKContainer.default()
        let database = container.publicCloudDatabase
        let query = CKQuery(recordType: "UserProfile", predicate: NSPredicate(value: true))
        let (matchResults, _) = try await database.records(matching: query)
        
        var profiles: [UserProfile] = []
        for matchResult in matchResults {
            if case let .success(record) = matchResult.1,
               let appleUserId = record["appleUserId"] as? String,
               let cloudKitUserId = record["cloudKitUserId"] as? String,
               let name = record["name"] as? String,
               let email = record["email"] as? String {
                let status = record["Status"] as? String
                let avatarData = record["avatarData"] as? Data
                let profile = UserProfile(
                    appleUserId: appleUserId,
                    cloudKitUserId: cloudKitUserId,
                    name: name,
                    email: email,
                    status: status,
                    avatarData: avatarData
                )
                profiles.append(profile)
            }
        }
        return profiles
      },
      fetchUserByEmail: { email in
        let container = CKContainer.default()
        let database = container.publicCloudDatabase
        let query = CKQuery(recordType: "UserProfile", predicate: NSPredicate(format: "email == %@", email))
        let (matchResults, _) = try await database.records(matching: query)

        if let match = matchResults.first,
           case let .success(record) = match.1,
           let appleUserId = record["appleUserId"] as? String,
           let cloudKitUserId = record["cloudKitUserId"] as? String,
           let name = record["name"] as? String,
           let recordEmail = record["email"] as? String, recordEmail == email {
            let status = record["Status"] as? String
            let avatarData = record["avatarData"] as? Data
            return UserProfile(
                appleUserId: appleUserId,
                cloudKitUserId: cloudKitUserId,
                name: name,
                email: recordEmail,
                status: status,
                avatarData: avatarData
            )
        }
        return nil
      }
    )
  }
}

extension DependencyValues {
  var usersClient: UsersClient {
    get { self[UsersClient.self] }
    set { self[UsersClient.self] = newValue }
  }
}
