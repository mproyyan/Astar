import CloudKit
import ComposableArchitecture
import Foundation

@DependencyClient
struct UsersClient {
    var fetchAllUsers: () async throws -> [UserProfile]
    
    var updateUserStatus: @Sendable (_ userId: String, _ status: String) async throws -> Void
}

extension UsersClient: DependencyKey {
    static let liveValue = Self.live()
    
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
                        let profile = UserProfile(
                            appleUserId: appleUserId,
                            cloudKitUserId: cloudKitUserId,
                            name: name,
                            email: email,
                            status: status
                        )
                        profiles.append(profile)
                    }
                }
                return profiles
            },
            updateUserStatus: { userId, status in
                let database = CKContainer.default().publicCloudDatabase
                let predicate = NSPredicate(format: "cloudKitUserId == %@ OR appleUserId == %@", userId, userId)
                let query = CKQuery(recordType: "UserProfile", predicate: predicate)
                
                let (matchResults, _) = try await database.records(matching: query)
                guard let firstResult = matchResults.first?.1,
                      case let .success(record) = firstResult else { return }
                
                record["Status"] = status
                try await database.save(record)
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
