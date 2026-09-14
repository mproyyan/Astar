import CloudKit
import ComposableArchitecture
import Foundation

// MARK: - UsersClient (TCA Dependency)
//
// This struct is the TCA *dependency interface* for all user-data operations.
// It is the Swift/TCA equivalent of a Python service class:
//
//   class UsersService(abc.ABC):
//       @abc.abstractmethod
//       async def fetch_all_users(self) -> list[UserProfile]: ...
//
// @DependencyClient macro (from swift-dependencies / TCA):
//   • Generates unimplemented stubs for every closure property. Calling a stub
//     crashes with a descriptive message, making accidentally-untested paths
//     immediately visible — similar to raising NotImplementedError in Python.
//   • Generates a memberwise initialiser so you can partially override only the
//     closures you need in tests.
//
// Sendable:
//   The struct is marked Sendable so the Swift concurrency checker knows it is
//   safe to pass across actor boundaries (e.g. from a background Task into a
//   @MainActor reducer). Think of it as "this value is thread-safe to share" —
//   the compiler verifies this at compile time, unlike Python's threading module
//   where thread-safety is a programmer's responsibility enforced by convention.
@DependencyClient
struct UsersClient: Sendable {

  // @Sendable on a closure means the closure itself is safe to call from any
  // concurrency context — it cannot capture mutable state that would cause
  // data races. This is enforced by the Swift compiler.
  //
  // `async throws` means callers must:
  //   1. `await` — suspend until the CloudKit network call completes.
  //   2. `try`   — handle possible errors (network failure, permission denied, etc.)
  //
  // 🐍 Python: equivalent to `async def fetch_all_users() -> list[UserProfile]`
  //   where the function is a coroutine that can raise exceptions.
  var fetchAllUsers: @Sendable () async throws -> [UserProfile]

  // Looks up a single user by their email address.
  // Returns Optional<UserProfile> (written `UserProfile?`) — like Python's
  //   `Optional[UserProfile]` or returning `None` if not found.
  var fetchUserByEmail: @Sendable (_ email: String) async throws -> UserProfile?

  // Looks up a single user by their CloudKit Record ID string.
  var fetchUserByRecordID: @Sendable (_ recordID: String) async throws -> UserProfile?
}

// MARK: - DependencyKey Conformance
//
// TCA's dependency container is a key-value store keyed by type. Every dependency
// must expose three values:
//   • liveValue   — real implementation for the production app.
//   • testValue   — safe stub for unit tests (won't hit the network).
//   • previewValue — (optional) stub for SwiftUI Previews.
//
// 🐍 Python analogy: this is a dependency-injection registry, similar to
//   FastAPI's `app.dependency_overrides[real_service] = mock_service`.
extension UsersClient: DependencyKey {

  // liveValue delegates to a factory function `live()` so we can keep the
  // closure bodies readable without nesting everything inside `static let`.
  static let liveValue = Self.live()

  // testValue provides safe no-op implementations:
  //   fetchAllUsers returns an empty list (like `return []` in Python tests).
  //   fetchUserByEmail/ByRecordID return nil — "user not found" without a DB call.
  // Using these in tests ensures no CloudKit traffic during CI runs.
  static let testValue = Self(
    fetchAllUsers: { [] },
    fetchUserByEmail: { _ in nil },
    fetchUserByRecordID: { _ in nil }
  )

  // MARK: live() factory
  //
  // Returns a `Self` (UsersClient) with every closure wired to CloudKit.
  // Keeping this in a static func (rather than inline in `liveValue`) makes
  // the code readable and allows future parameterization (e.g. injecting a
  // custom CKContainer for multi-tenant scenarios).
  static func live() -> Self {
    return Self(

      // ── fetchAllUsers ───────────────────────────────────────────────────────
      // Queries ALL records of type "UserProfile" from CloudKit's public database.
      //
      // CloudKit is Apple's hosted NoSQL database, analogous to Firebase Firestore
      // or DynamoDB. Records are dictionary-like objects (similar to Python dicts)
      // keyed by string field names.
      //
      // 🐍 Python analogy (using boto3/DynamoDB):
      //   results = await dynamodb.scan(TableName="UserProfile")
      //   profiles = [UserProfile(**item) for item in results["Items"]]
      fetchAllUsers: {
        let container = CKContainer.default()
        let database = container.publicCloudDatabase

        // CKQuery is analogous to a SQL SELECT or NoSQL filter expression.
        // NSPredicate(value: true) means "match every record" — no WHERE clause.
        let query = CKQuery(recordType: "UserProfile", predicate: NSPredicate(value: true))

        // `try await` — suspends the current Task until CloudKit returns results.
        // The result is a tuple: ([(CKRecord.ID, Result<CKRecord, Error>)], cursor).
        // We ignore the cursor (pagination token) with `_`.
        let (matchResults, _) = try await database.records(matching: query)

        var profiles: [UserProfile] = []
        for matchResult in matchResults {
          // matchResult is a tuple: (CKRecord.ID, Result<CKRecord, Error>).
          // `if case let .success(record) = matchResult.1` pattern-matches the
          // Result enum's success case — like Python's:
          //   match result:
          //       case Ok(record): ...
          if case let .success(record) = matchResult.1,
             let appleUserId = record["appleUserId"] as? String,
             let cloudKitUserId = record["cloudKitUserId"] as? String,
             let name = record["name"] as? String,
             let email = record["email"] as? String {
            // Optional fields — `as? String` returns nil if the field is missing
            // or the wrong type (like Python's dict.get("key")).
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

      // ── fetchUserByEmail ────────────────────────────────────────────────────
      // Queries CloudKit for a UserProfile record matching a specific email.
      //
      // NSPredicate(format: "email == %@", email) is the CloudKit filter syntax —
      // analogous to SQL: WHERE email = 'user@example.com'
      // Or in Python (SQLAlchemy): session.query(User).filter_by(email=email).first()
      fetchUserByEmail: { email in
        let container = CKContainer.default()
        let database = container.publicCloudDatabase
        let query = CKQuery(recordType: "UserProfile", predicate: NSPredicate(format: "email == %@", email))
        let (matchResults, _) = try await database.records(matching: query)

        // We only need the first matching record (email should be unique).
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
        // No matching record found — return nil (Python: return None).
        return nil
      },

      // ── fetchUserByRecordID ─────────────────────────────────────────────────
      // Fetches a single CloudKit record directly by its record ID (primary key).
      // This is faster than a query because CloudKit can look up by key directly —
      // analogous to a DynamoDB GetItem by partition key, or Redis GET.
      //
      // Unlike the query-based methods above, a direct record fetch throws if the
      // record doesn't exist, so we wrap it in do/catch and return nil on failure.
      fetchUserByRecordID: { recordID in
        let container = CKContainer.default()
        let database = container.publicCloudDatabase
        do {
          // CKRecord.ID wraps the string primary key so CloudKit knows which
          // record store (zone) and record name to look up.
          let record = try await database.record(for: CKRecord.ID(recordName: recordID))

          // `?? ""` is nil-coalescing with a default — like Python's
          // record.get("appleUserId", "")
          let appleUserId = record["appleUserId"] as? String ?? ""
          let cloudKitUserId = record["cloudKitUserId"] as? String ?? ""
          let name = record["name"] as? String ?? ""
          let email = record["email"] as? String ?? ""
          let status = record["Status"] as? String
          let avatarData = record["avatarData"] as? Data
          return UserProfile(
            appleUserId: appleUserId,
            cloudKitUserId: cloudKitUserId,
            name: name,
            email: email,
            status: status,
            avatarData: avatarData
          )
        } catch {
          // Record not found or network error — treat as "user not found".
          return nil
        }
      }
    )
  }
}

// MARK: - DependencyValues Registration
//
// This extension adds the `usersClient` key to TCA's global dependency store.
// Inside any TCA Reducer you can then write:
//   @Dependency(\.usersClient) var usersClient
// and the system automatically injects liveValue in production, testValue in tests.
//
// This is the Swift equivalent of a Python DI container entry:
//   container.register(UsersClient, factory=lambda: UsersClientLive())
extension DependencyValues {
  var usersClient: UsersClient {
    get { self[UsersClient.self] }
    set { self[UsersClient.self] = newValue }
  }
}
