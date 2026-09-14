//
//  LoginFeature.swift
//  Astar
//
//  Created by Muhammad Pandu Royyan on 24/08/26.
//

// MARK: - Imports
// `AuthenticationServices` provides the "Sign In with Apple" APIs (ASAuthorization, etc.).
// `CloudKit` is Apple's iCloud-backed database (analogous to Firebase Firestore, but tightly
//  integrated with the Apple ecosystem). Records live in "containers" and "databases".
// `ComposableArchitecture` (TCA) is the state-management framework – think of it like Redux
//  (action → reducer → new state) but written for Swift + SwiftUI.
// `Foundation` provides basic Swift utilities (JSONEncoder, UserDefaults, etc.).
import AuthenticationServices
import CloudKit
import ComposableArchitecture
import Foundation

// MARK: - AppleSignInCredential
/// A plain value type (Swift `struct`) that captures the relevant fields from Apple's
/// `ASAuthorizationAppleIDCredential` after a successful "Sign In with Apple" flow.
///
/// **Why a separate struct?**
/// `ASAuthorizationAppleIDCredential` is an Apple class (reference type). Wrapping its data
/// in a plain `struct` makes it:
///   - **Equatable**: easy to compare two credentials in tests or reducers.
///   - **Sendable**: safe to pass across Swift concurrency boundaries (actor isolation).
///   - Independent of Apple's SDK internals – great for testability.
///
/// **Python analogy**: Think of this like a plain `@dataclass` in Python that you create
/// after parsing an OAuth token response dictionary.
///
/// **Sign In with Apple flow**:
/// 1. The user taps "Sign In with Apple".
/// 2. iOS shows Face ID / Touch ID and the user consents.
/// 3. Apple returns an `ASAuthorization` object containing an `ASAuthorizationAppleIDCredential`.
/// 4. The credential contains:
///    - `user` – a stable, opaque user identifier (the "Apple User ID"). This is like a UUID
///      that uniquely identifies this user *for your app*. Apple never shares the real Apple ID.
///    - `fullName` – `PersonNameComponents?`. Only provided on the *very first* sign-in.
///      Subsequent sign-ins return `nil` for name and email – Apple's privacy design.
///    - `email` – Only provided on the first sign-in.
///
/// We store these three fields because they are the only user-facing identity data Apple gives us.
struct AppleSignInCredential: Equatable, Sendable {
  /// The opaque, stable identifier Apple assigns to this user for *this* app.
  /// It persists across sign-ins but differs between different apps from the same developer.
  let appleUserId: String
  /// The user's display name. `nil` on every sign-in after the first.
  let name: String?
  /// The user's email address. `nil` on every sign-in after the first.
  /// Apple may provide a relay address (e.g. `xyz@privaterelay.appleid.com`) if the user
  /// chose "Hide My Email". We treat both real and relay addresses the same.
  let email: String?
}

// MARK: - UserProfile
/// The canonical user data model used throughout the app after login.
///
/// This struct bridges two identity systems:
///   - **Apple ID** (`appleUserId`): provided by Sign In with Apple.
///   - **CloudKit User Record** (`cloudKitUserId`): every iCloud account has an invisible
///     "User Record" in CloudKit. Its `recordName` is a UUID-like string that is unique
///     per CloudKit container.
///
/// **Why both IDs?**
/// `appleUserId` proves the user is authenticated with Apple.
/// `cloudKitUserId` is needed to address CloudKit records. Keeping both lets us correlate
/// across systems and handle edge cases where they may diverge.
///
/// Conforms to:
///   - `Codable`: enables JSON serialisation to/from `UserDefaults` (local cache).
///   - `Equatable`: required by TCA – state diffing needs value equality.
///   - `Sendable`: safe to pass across Swift concurrency actor boundaries.
struct UserProfile: Codable, Equatable, Sendable {
  /// Stable Apple-issued opaque user identifier.
  let appleUserId: String
  /// The `recordName` of this user's CloudKit User Record (looks like a UUID).
  let cloudKitUserId: String
  /// Display name. `var` because it can be updated post-login (e.g. discovered via CloudKit).
  var name: String
  /// Email address (may be a relay). `var` for the same reason.
  var email: String
  /// Optional status message the user can set (e.g. "On my way home").
  var status: String?
  /// Optional raw PNG/JPEG bytes for the user's avatar image.
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
  
  /// Computed property that generates a CloudKit-safe record name.
  ///
  /// CloudKit `CKRecord.ID` record names must only contain alphanumeric characters
  /// and underscores. We concatenate both IDs and sanitise any forbidden characters.
  ///
  /// **How it works** (functional pipeline – Python analogy: `map` + `join`):
  /// ```swift
  /// "UserProfile_abc123_def456"
  ///   .map { ch in ch.isLetter || ch.isNumber ? ch : "_" }  // sanitise each char
  ///   .map(String.init)   // convert each Character to a single-char String
  ///   .joined()           // concatenate all single-char Strings back to one String
  /// ```
  /// The result is deterministic: the same two IDs always produce the same record name,
  /// which lets us do an upsert (fetch → create if missing → save) without duplicates.
  var recordName: String {
    "UserProfile_\(appleUserId)_\(cloudKitUserId)"
      .map { character in
        character.isLetter || character.isNumber ? character : "_"
      }
      .map(String.init)
      .joined()
  }
  
  /// A typed CloudKit record identifier derived from `recordName`.
  /// `CKRecord.ID` wraps the string name and optionally a zone; here we use the default zone.
  /// This is the primary key used to fetch/save the corresponding CloudKit record.
  var recordID: CKRecord.ID {
    CKRecord.ID(recordName: recordName)
  }
}

// MARK: - LoginError
/// A lightweight, equatable error wrapper.
///
/// TCA Actions must conform to `Equatable` so the framework can diff them.
/// Swift's built-in `Error` protocol does *not* require `Equatable`, so we wrap the
/// error message in our own struct. This is a common TCA idiom.
///
/// **Python analogy**: Like defining `class LoginError(Exception): pass` with an
/// explicit `__eq__` based on the message string.
struct LoginError: Error, Equatable, Sendable {
  let message: String
}

// MARK: - UserProfileStorage
/// A namespace (caseless enum) for reading/writing `UserProfile` to `UserDefaults`.
///
/// **Why a caseless `enum` instead of a `class` or `struct`?**
/// A caseless `enum` cannot be instantiated, making it a pure namespace – it groups
/// related static functions without implying any object identity. This is idiomatic Swift
/// for utility namespaces (similar to Python's module-level functions in a dedicated module).
///
/// `UserDefaults` is an on-device key-value store (think of it like a persistent `dict`
/// backed by a `.plist` file). It is appropriate for small blobs like a user profile.
/// For larger/relational data you'd use CoreData, SQLite, or CloudKit directly.
enum UserProfileStorage {
  /// The key under which the profile is stored in `UserDefaults`.
  static let key = "user_profile"

  /// Attempts to decode a `UserProfile` from `UserDefaults`.
  /// Returns `nil` if no data is stored or decoding fails (e.g. schema changed).
  ///
  /// Uses `JSONDecoder` – analogous to `json.loads()` in Python, but type-safe via
  /// `Codable` (Swift's serialisation protocol). The `try?` swallows decode errors and
  /// returns `nil` instead of propagating them.
  static func load() -> UserProfile? {
    guard let data = UserDefaults.standard.data(forKey: key) else { return nil }
    return try? JSONDecoder().decode(UserProfile.self, from: data)
  }

  /// Encodes the profile to JSON and writes it to `UserDefaults`.
  /// Silently does nothing if encoding fails (edge case – all fields are standard types).
  static func save(_ profile: UserProfile) {
    guard let data = try? JSONEncoder().encode(profile) else { return }
    UserDefaults.standard.set(data, forKey: key)
  }

  /// Removes the stored profile, effectively logging the user out on the next cold start.
  static func clear() {
    UserDefaults.standard.removeObject(forKey: key)
  }
}

// MARK: - LoginFeature (TCA Reducer)
/// The TCA Reducer that manages the entire authentication lifecycle.
///
/// **TCA mental model** (for Python/CS readers):
/// Think of TCA like Redux or the Elm architecture:
///   - **State**: an immutable snapshot of all data (a `struct` — value type, like a Python
///     frozen dataclass or namedtuple). The framework detects changes via `Equatable`.
///   - **Action**: a discriminated union (Swift `enum`) describing *what happened*
///     (analogous to Redux action objects `{ type: "LOGIN_SUCCESS", payload: ... }`).
///   - **Reducer**: a pure function `(State, Action) -> (State, Effect)` that computes the
///     next state and optionally returns side-effectful `Effect`s.
///   - **Effect**: represents async work (network calls, timers). TCA wraps Swift's
///     structured concurrency (`async/await`) inside `Effect.run`.
///
/// The `@Reducer` macro generates boilerplate conformances and wires the `body` property.
@Reducer
struct LoginFeature {

  // MARK: State
  /// The complete observable state for the login screen.
  ///
  /// `@ObservableState` is a TCA macro that makes every stored property observable by SwiftUI.
  /// Under the hood it uses Swift's `Observation` framework (similar to how `@Published`
  /// works with `ObservableObject`, but more granular – only views that read a specific
  /// property re-render when that property changes).
  ///
  /// All properties are value types (`struct`, `String`, `Bool`, `Data`), so the state
  /// is always a complete, copyable snapshot. This is TCA's immutability guarantee –
  /// no shared mutable reference can corrupt state from a background thread.
  @ObservableState
  struct State: Equatable {
    /// The currently authenticated user. `nil` means the user is logged out.
    var userProfile: UserProfile?
    /// `true` while an async login network call is in-flight. Drives a loading spinner in the UI.
    var isLoading = false
    /// Non-nil when an error should be displayed to the user.
    var errorMessage: String?
  }

  // MARK: Action
  /// Every possible event that can mutate `LoginFeature.State`.
  ///
  /// Swift `enum` with associated values is the canonical representation of an
  /// **Algebraic Data Type** (specifically a Sum Type / Tagged Union).
  /// In Python terms: imagine `Union[LoadStoredUser, AvatarLoaded, ProfileUpdated, ...]`
  /// where each variant carries different payload types.
  ///
  /// The naming convention follows TCA's recommended style:
  ///   - User-initiated events: `verbNounVerbed` (e.g. `signOutButtonTapped`)
  ///   - System/async responses: `nounVerbed` (e.g. `loginResponse`, `avatarLoaded`)
  ///   - Child reducer events: `childFeatureName(ChildFeature.Action)` (e.g. `login(...)`)
  enum Action: Equatable {
    /// Triggered on app launch (or after sign-out) to restore a persisted session.
    case loadStoredUser
    /// Fired when an avatar image has been asynchronously fetched.
    case avatarLoaded(Data)
    /// Fired when name/email/avatar have been refreshed from CloudKit identity.
    case profileUpdated(UserProfile)
    /// Fired by the view after a successful "Sign In with Apple" authorization.
    /// Carries the sanitised credential extracted from `ASAuthorizationAppleIDCredential`.
    case appleSignInCompleted(AppleSignInCredential)
    /// The async result of `upsertUserProfile`. Uses Swift's `Result<Success, Failure>`
    /// type – identical to `Result[UserProfile, LoginError]` in Python `typing`.
    case loginResponse(Result<UserProfile, LoginError>)
    /// User tapped the sign-out button.
    case signOutButtonTapped
    /// **Delegate actions** – outbound events bubbled up to the parent reducer.
    /// This is TCA's pattern for child-to-parent communication (analogous to a callback
    /// or event emitter in Python). The parent listens for `.delegate(...)` actions and
    /// reacts accordingly without the child knowing anything about the parent.
    case delegate(Delegate)

    /// Typed events that this feature broadcasts to its parent.
    enum Delegate: Equatable {
      /// Emitted whenever a fully-resolved `UserProfile` is available (login or refresh).
      case loggedIn(UserProfile)
      /// Emitted after a successful sign-out.
      case signedOut
    }
  }

  // MARK: Reducer Body
  /// The reducer's body. TCA allows composing multiple `Reducer`s with `body`.
  /// Here we use a single `Reduce` closure – the heart of TCA: given a current `state`
  /// and an incoming `action`, mutate `state` in place and return an `Effect` (or `.none`).
  ///
  /// **Mutation is in-place** (using `inout` under the hood), but the framework snapshots
  /// state before and after to detect changes and drive SwiftUI diff updates.
  /// From a Python perspective: treat `state` like a mutable dictionary, but every
  /// mutation is recorded and rolled back on error or compared for equality.
  var body: some Reducer<State, Action> {
    Reduce { state, action in
      switch action {

      // -----------------------------------------------------------------------
      // MARK: .loadStoredUser
      // -----------------------------------------------------------------------
      case .loadStoredUser:
        // Try to restore a previously saved profile from UserDefaults.
        // `guard let` is Swift's early-exit pattern: if `load()` returns nil, we
        // immediately return `.none` (no side effects). Python equivalent:
        //   `if profile := UserProfileStorage.load(): ...  else: return`
        guard let profile = UserProfileStorage.load() else { return .none }
        state.userProfile = profile

        // `Effect.run` launches a Swift async task on a background executor.
        // The `send` closure is the only way to feed new Actions back into the store
        // from async code – it is the TCA equivalent of dispatching Redux actions
        // from a middleware thunk.
        //
        // `[profile]` is a Swift capture list: we capture `profile` by value so
        // the closure holds an independent copy even if `state.userProfile` changes.
        return .run { [profile] send in
          // Immediately notify the parent that we have a cached user so the UI
          // can render without waiting for the CloudKit refresh below.
          await send(.delegate(.loggedIn(profile)))

          // Proactively verify & resolve genuine Apple Account identity
          // CloudKit's `CKContainer` is the top-level CloudKit namespace tied to
          // the app's bundle ID. `container.userRecordID()` returns the CloudKit
          // User Record ID for the currently signed-in iCloud account.
          // `try? await` means: attempt the async throwing call; if it throws,
          // return nil instead of propagating the error (silent failure).
          let container = CKContainer.default()
          var resolvedName = profile.name
          var resolvedEmail = profile.email

          // `container.userIdentity(forUserRecordID:)` looks up the user's
          // discovered identity (name / email) stored in CloudKit's user index.
          // This is more reliable than relying on the Apple credential alone because
          // Apple only provides name/email on the *first* sign-in.
          if let userRecordID = try? await container.userRecordID(),
             let userIdentity = try? await container.userIdentity(forUserRecordID: userRecordID) {
            // `nameComponents` is `PersonNameComponents?` – a structured name object
            // (givenName, familyName, etc.). We format it into a display string.
            if let components = userIdentity.nameComponents {
              let discoveredName = PersonNameComponentsFormatter().string(from: components).trimmingCharacters(in: .whitespacesAndNewlines)
              // Only override the stored name if it was a placeholder ("User" or empty)
              // to avoid overwriting a user-customised name.
              if !discoveredName.isEmpty && (resolvedName == "User" || resolvedName.isEmpty) {
                resolvedName = discoveredName
              }
            }
            // `lookupInfo?.emailAddress` – `lookupInfo` is `CKUserIdentity.LookupInfo?`
            // which contains the email / phone used to find this user in CloudKit.
            if let discoveredEmail = userIdentity.lookupInfo?.emailAddress?.trimmingCharacters(in: .whitespacesAndNewlines), !discoveredEmail.isEmpty && resolvedEmail.isEmpty {
              resolvedEmail = discoveredEmail
            }
          }

          // Attempt to fetch a contacts-style avatar from the device's address book
          // or iCloud contacts for the resolved email/name combination.
          let avatar = await ContactPhotoClient.liveValue.fetchMeCardPhoto(resolvedEmail, resolvedName)

          // Only dispatch `.profileUpdated` if something actually changed – avoids
          // unnecessary re-renders and spurious UserDefaults writes.
          if avatar != profile.avatarData || resolvedName != profile.name || resolvedEmail != profile.email {
            var updated = profile
            updated.name = resolvedName
            updated.email = resolvedEmail
            updated.avatarData = avatar
            await send(.profileUpdated(updated))
          }
        }

      // -----------------------------------------------------------------------
      // MARK: .avatarLoaded
      // -----------------------------------------------------------------------
      // Handles the case where only the avatar data changed (e.g. fetched separately).
      // In-place mutation of a Swift value-type struct:
      //   `if var profile = state.userProfile` is an "optional binding with copy" –
      //   `profile` is a mutable copy of the optional's inner value. Mutations to
      //   `profile` do NOT affect `state.userProfile` until we re-assign it.
      case let .avatarLoaded(avatarData):
        if var profile = state.userProfile {
          profile.avatarData = avatarData
          state.userProfile = profile
          UserProfileStorage.save(profile)
          // `.send` creates a synchronous, in-flight action dispatch. Unlike `.run`,
          // it does not involve async work – it just enqueues the action immediately.
          return .send(.delegate(.loggedIn(profile)))
        }
        return .none

      // -----------------------------------------------------------------------
      // MARK: .profileUpdated
      // -----------------------------------------------------------------------
      /// Handles a refreshed profile (name / email / avatar may have changed).
      /// Always persists to UserDefaults and notifies the parent.
      case let .profileUpdated(updatedProfile):
        state.userProfile = updatedProfile
        UserProfileStorage.save(updatedProfile)
        return .send(.delegate(.loggedIn(updatedProfile)))

      // -----------------------------------------------------------------------
      // MARK: .appleSignInCompleted
      // -----------------------------------------------------------------------
      // Entry point for a fresh "Sign In with Apple" attempt.
      // The view delivers an `AppleSignInCredential` constructed from Apple's SDK.
      case let .appleSignInCompleted(credential):
        state.isLoading = true
        state.errorMessage = nil

        // `Effect.run` launches the async upsert. The `do/catch` maps Swift errors
        // to our typed `LoginError`, maintaining equatability in the action enum.
        return .run { send in
          do {
            // `upsertUserProfile` is the heavy-lifting function below: it talks to
            // CloudKit to create or update the UserProfile record and returns the
            // resolved profile.
            let profile = try await upsertUserProfile(with: credential)
            UserProfileStorage.save(profile)
            await send(.loginResponse(.success(profile)))
          } catch {
            // `error.localizedDescription` gives a human-readable error string.
            // We wrap it in `LoginError` to keep `Action` equatable.
            await send(.loginResponse(.failure(LoginError(message: error.localizedDescription))))
          }
        }

      // -----------------------------------------------------------------------
      // MARK: .loginResponse (success)
      // -----------------------------------------------------------------------
      case let .loginResponse(.success(profile)):
        state.isLoading = false
        state.userProfile = profile
        // Bubble up to the parent so the app can navigate away from the login screen.
        return .send(.delegate(.loggedIn(profile)))

      // -----------------------------------------------------------------------
      // MARK: .loginResponse (failure)
      // -----------------------------------------------------------------------
      case let .loginResponse(.failure(error)):
        state.isLoading = false
        state.errorMessage = error.message
        return .none

      // -----------------------------------------------------------------------
      // MARK: .signOutButtonTapped
      // -----------------------------------------------------------------------
      case .signOutButtonTapped:
        // Clear the persisted profile and reset all state fields to their defaults.
        // This is the "logout" path – the parent will react to `.delegate(.signedOut)`
        // and navigate back to the login/onboarding screen.
        UserProfileStorage.clear()
        state.userProfile = nil
        state.errorMessage = nil
        state.isLoading = false
        return .send(.delegate(.signedOut))

      // -----------------------------------------------------------------------
      // MARK: .delegate
      // -----------------------------------------------------------------------
      // Delegate actions are *outbound* events. The child reducer itself does nothing
      // with them – they are intercepted at the parent level.
      // Returning `.none` here is correct: the child just emits and forgets.
      case .delegate:
        return .none
      }
    }
  }
}

// MARK: - upsertUserProfile
/// Creates or updates the user's CloudKit `UserProfile` record using the Apple credential.
///
/// **"Upsert" = Update + Insert**: fetch the existing record if it exists; if not, create
/// a new one. This is the standard pattern for idempotent writes (safe to call multiple times).
///
/// **CloudKit Architecture Recap**:
/// - `CKContainer`: the top-level namespace (maps to your app's iCloud entitlement).
/// - `publicCloudDatabase`: a cloud database readable by *all* users of your app (no iCloud
///   sign-in required to read, but sign-in required to write). Contrast with
///   `privateCloudDatabase` (per-user, invisible to others).
/// - `CKRecord`: a dictionary-like object stored in CloudKit (analogous to a Firestore document
///   or a DynamoDB item). Each record has a `recordType` (like a table name) and dynamic fields.
/// - `CKRecord.ID`: the primary key for a record, built from a `recordName` string.
///
/// **Name / Email Resolution Priority** (waterfall fallback pattern):
/// ```
/// 1. Apple credential (only available on first sign-in)
/// 2. CloudKit UserIdentity (discovered from iCloud account)
/// 3. Existing CloudKit record fields (from a previous sign-in)
/// 4. Previously stored local profile (same Apple user only)
/// 5. Hardcoded fallback ("User" / "")
/// ```
/// The `??` chain in Swift is equivalent to Python's `or` short-circuit chaining:
/// `name = a or b or c or "User"`
///
/// - Parameter credential: The sanitised Apple sign-in credential.
/// - Returns: A fully resolved `UserProfile` ready to use in the app.
/// - Throws: Any `CKError` from CloudKit (e.g. network unavailable, quota exceeded).
private func upsertUserProfile(with credential: AppleSignInCredential) async throws -> UserProfile {
  // Instantiating `ASAuthorizationAppleIDProvider` is not strictly needed here
  // (its result is discarded), but it signals intent and keeps the import used.
  _ = ASAuthorizationAppleIDProvider()

  // Obtain references to the CloudKit container and its public database.
  let container = CKContainer.default()
  let database = container.publicCloudDatabase

  // `container.userRecordID()` is an async call that fetches the record ID of the
  // current iCloud user's "User Record" – Apple's canonical CloudKit identity for
  // this device. It throws if the user is not signed into iCloud.
  let userRecordID = try await container.userRecordID()
  // `recordName` on the User Record ID is a UUID-like string unique per CloudKit container.
  let cloudKitUserId = userRecordID.recordName

  // Build the deterministic record ID for our app-level UserProfile record.
  let recordID = CKRecord.ID(recordName: userProfileRecordName(
    appleUserId: credential.appleUserId,
    cloudKitUserId: cloudKitUserId
  ))

  // 1. Discover authentic name and email from CloudKit UserIdentity if missing from credential
  // `CKUserIdentity` contains name components and the lookup info (email/phone) associated
  // with the iCloud account. This is independent from the Apple credential and may contain
  // richer or more current data.
  var discoveredName: String?
  var discoveredEmail: String?
  if let userIdentity = try? await container.userIdentity(forUserRecordID: userRecordID) {
    if let components = userIdentity.nameComponents {
      // `nilIfBlank` is our custom `String` extension (defined below) that returns `nil`
      // for empty / whitespace-only strings. Prevents storing "" as a name.
      discoveredName = PersonNameComponentsFormatter().string(from: components).nilIfBlank
    }
    discoveredEmail = userIdentity.lookupInfo?.emailAddress?.nilIfBlank
  }

  // 2. Attempt to fetch the existing CloudKit record (nil if this is first sign-in).
  //    `try?` means: if the fetch fails (record doesn't exist, network error), return nil.
  let existingRecord = try? await database.record(for: recordID)

  // `??` (nil-coalescing): if `existingRecord` is non-nil, use it; else create a new record.
  // This is the "upsert" logic: we mutate the existing record to preserve metadata
  // (like `creationDate`), or create a fresh one if it doesn't exist.
  let record = existingRecord ?? CKRecord(recordType: "UserProfile", recordID: recordID)

  // Load any locally cached profile so we can fall back to its name/email if needed.
  let storedProfile = UserProfileStorage.load()
  // Only use the stored profile's data if it belongs to the *same* Apple user.
  // This guards against re-using a previous user's data after a device handoff.
  let isSameStoredUser = storedProfile?.appleUserId == credential.appleUserId

  // Extract name/email from the existing CloudKit record (nil if record is new).
  // The cast `as? String` is Swift's safe downcast from `CKRecordValue` (an Any-like type).
  let existingName = (existingRecord?["name"] as? String)?.nilIfBlank
  let existingEmail = (existingRecord?["email"] as? String)?.nilIfBlank

  // Resolve the display name using the waterfall priority chain.
  // `credential.name?.nilIfBlank` – optional chain: call `nilIfBlank` only if name is non-nil.
  let name = credential.name?.nilIfBlank
    ?? discoveredName
    ?? existingName
    ?? (isSameStoredUser ? storedProfile?.name.nilIfBlank : nil)
    ?? "User"   // Final fallback: a generic placeholder.

  // Resolve email with the same priority chain.
  let email = credential.email?.nilIfBlank
    ?? discoveredEmail
    ?? existingEmail
    ?? (isSameStoredUser ? storedProfile?.email.nilIfBlank : nil)
    ?? ""       // Final fallback: empty string (email may be unknown/hidden).

  // 3. Attempt to fetch an avatar photo from contacts for this user.
  var avatarData: Data? = nil
  if let photo = await ContactPhotoClient.liveValue.fetchMeCardPhoto(email, name) {
    avatarData = photo
  } else if let existingAvatarData = existingRecord?["avatarData"] as? Data {
    // Fall back to the previously stored avatar in CloudKit.
    avatarData = existingAvatarData
  }

  // 4. Write all resolved fields into the CloudKit record.
  //    CKRecord uses subscript syntax (like a Python dict) for field access.
  //    The `as CKRecordValue` cast is required because CloudKit's storage type is
  //    `CKRecordValue` (a protocol). Swift's type system needs the explicit cast here.
  record["appleUserId"] = credential.appleUserId as CKRecordValue
  record["cloudKitUserId"] = cloudKitUserId as CKRecordValue
  record["name"] = name as CKRecordValue
  record["email"] = email as CKRecordValue
  // For optional fields we either set the value or explicitly set nil (removes the field).
  if let avatarData {
    record["avatarData"] = avatarData as CKRecordValue
  } else {
    record["avatarData"] = nil
  }

  // 5. Persist the record to CloudKit. `try?` means we proceed even if the save fails
  //    (e.g. offline). The app will still work with the locally built profile.
  _ = try? await database.save(record)

  // 6. Return a fully-resolved `UserProfile` value type (not the CloudKit record).
  //    The app uses `UserProfile` everywhere; `CKRecord` is only used for I/O.
  //    Note: "Status" uses a capital S – this matches whatever field name was used
  //    when the record was originally created in CloudKit.
  return UserProfile(
    appleUserId: credential.appleUserId,
    cloudKitUserId: cloudKitUserId,
    name: name,
    email: email,
    status: existingRecord?["Status"] as? String,
    avatarData: avatarData
  )
}

// MARK: - userProfileRecordName
/// Generates a sanitised CloudKit record name from the two user IDs.
///
/// This is a pure function (no side effects, same output for same inputs) – equivalent
/// to a Python function that applies a character-level `map` and joins the result.
///
/// CloudKit record names must match `[a-zA-Z0-9_]`. We replace everything else with `_`.
/// This function mirrors `UserProfile.recordName` so both produce identical keys.
private func userProfileRecordName(appleUserId: String, cloudKitUserId: String) -> String {
  "UserProfile_\(appleUserId)_\(cloudKitUserId)"
    .map { character in
      character.isLetter || character.isNumber ? character : "_"
    }
    .map(String.init)
    .joined()
}

// MARK: - String Extension: nilIfBlank
/// A private extension on `String` that returns `nil` for empty or whitespace-only strings.
///
/// **Why `private extension`?**
/// Scoping the extension to this file prevents polluting the global `String` API surface.
/// It is only needed for the login logic above.
///
/// **Usage pattern**: Called with optional chaining to short-circuit blank values in the
/// fallback waterfall: `someOptionalString?.nilIfBlank ?? fallback`.
///
/// **Python analogy**: `s.strip() or None` – strips whitespace and returns None if falsy.
private extension String {
  var nilIfBlank: String? {
    let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
    return trimmed.isEmpty ? nil : trimmed
  }
}
