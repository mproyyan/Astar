import ComposableArchitecture
import Foundation
import CloudKit

// MARK: - ConnectionActionError
//
// A lightweight, concrete error type used to carry failure messages through TCA's
// `Result<Success, Failure>` pattern.
//
// Why a custom error instead of `Error`?
//   TCA `Action` enums must conform to `Equatable` (so the test framework can compare
//   them). Swift's built-in `Error` protocol is NOT Equatable, so we wrap the
//   error message in a plain struct that IS Equatable.
//
//   Python analogy: raising a typed exception subclass (`class ConnectionActionError(Exception): ...`)
//   so callers can catch it specifically rather than catching bare `Exception`.
//
// `Sendable` means instances of this type can safely cross actor (thread) boundaries —
// the Swift concurrency equivalent of making a Python object safe for use in
// multi-threaded asyncio tasks.
struct ConnectionActionError: Error, Equatable, Sendable {
    let message: String
}

// MARK: - RequestTrustedPersonFeature
//
// TCA Reducer that manages the "Incoming Connection Requests" screen.
// Users see pending requests and can either CONFIRM (accept) or DELETE (reject) them.
//
// Data flow summary:
//   1. Parent feature populates `state.requests` before pushing this screen.
//   2. User taps Confirm/Delete → View sends Action → Reducer fires async Effect.
//   3. Async Effect calls `connectionsClient` (the CloudKit dependency).
//   4. Result is sent back as `.confirmResponse` or `.deleteResponse`.
//   5. On success, the request is removed from `state.requests` → UI updates.
@Reducer
struct RequestTrustedPersonFeature {

  // MARK: State
  //
  // Minimal state: just the list of pending connection requests to display.
  // Each `ConnectionProfile` bundles a `Connection` record (status, IDs) with
  // the partner's `UserProfile` (name, email).
  //
  // `@ObservableState` makes every property trigger SwiftUI re-renders on change.
  @ObservableState
  struct State: Equatable {
      /// The list of incoming (pending) connection requests shown on screen.
      /// When a request is accepted or rejected, the corresponding entry is
      /// removed from this array, and the row disappears from the UI.
      var requests: [ConnectionProfile] = []
  }

  // MARK: Action
  //
  // Six actions represent the complete lifecycle of this screen:
  //   User intent actions (triggered by button taps):
  //     .confirmTapped  → accept a pending request
  //     .deleteTapped   → reject a pending request
  //   Response actions (triggered by async effects):
  //     .confirmResponse → outcome of the confirm network call
  //     .deleteResponse  → outcome of the delete network call
  //
  // Using `Result<String, ConnectionActionError>` as associated values is TCA's
  // idiomatic way to model async outcomes — analogous to:
  //   Python: `(success_id, None)` vs `(None, error)` tuples, or
  //           `concurrent.futures.Future` resolved vs rejected states.
  enum Action: Equatable {
      /// User tapped "Confirm" on a request. `String` is the connection's CloudKit record ID.
      case confirmTapped(String)
      /// User tapped "Delete" on a request. `String` is the connection's CloudKit record ID.
      case deleteTapped(String)

      /// Async response after attempting to confirm (accept) a request.
      /// `.success(connectionID)` → the record was updated on CloudKit.
      /// `.failure(error)`        → something went wrong (network, permission, etc.).
      case confirmResponse(Result<String, ConnectionActionError>)

      /// Async response after attempting to delete a request.
      case deleteResponse(Result<String, ConnectionActionError>)
  }

  // MARK: Dependencies
  //
  // `@Dependency` injects `connectionsClient` — a live CloudKit client in production
  // and a mock/stub in tests. This is Dependency Inversion (the 'D' in SOLID):
  // the reducer depends on the ABSTRACTION (`connectionsClient` protocol/interface),
  // not on the concrete CloudKit implementation.
  //
  // Python analogy: injecting a `connections_repo` parameter into a service class
  // instead of hardcoding `CloudKitConnectionsRepo()` inside the class.
  @Dependency(\.connectionsClient) var connectionsClient

  // MARK: Reducer Body
  var body: some Reducer<State, Action> {
    Reduce { state, action in
      switch action {

      // User confirmed (accepted) a request.
      // `.run { send in ... }` is TCA's async effect wrapper — it's like
      // `asyncio.create_task(...)` in Python. The closure runs in a Swift
      // structured-concurrency Task off the main thread.
      case let .confirmTapped(connectionID):
          return .run { send in
              do {
                  // `try await` is Swift's equivalent of `await` in Python's asyncio,
                  // but also handles thrown exceptions (Swift's checked errors).
                  try await connectionsClient.updateStatus(connectionID, "mutual")
                  // On success, send the response action back to the store.
                  await send(.confirmResponse(.success(connectionID)))
              } catch {
                  // Wrap the thrown error into our Equatable type and send failure.
                  await send(.confirmResponse(.failure(ConnectionActionError(message: error.localizedDescription))))
              }
          }

      // User deleted (rejected) a request. Same async pattern as confirmTapped.
      case let .deleteTapped(connectionID):
          return .run { send in
              do {
                  try await connectionsClient.deleteConnection(connectionID)
                  await send(.deleteResponse(.success(connectionID)))
              } catch {
                  await send(.deleteResponse(.failure(ConnectionActionError(message: error.localizedDescription))))
              }
          }

      // Confirm succeeded: remove the request from the list so the row disappears.
      // Pattern-matching with `.success(let connectionID)` is Swift's equivalent of
      // Python's `match result: case Ok(id): ...` in hypothetical match syntax.
      case let .confirmResponse(.success(connectionID)):
          state.requests.removeAll { $0.connection.id == connectionID }
          return .none

      // Confirm failed: for now we silently swallow the error.
      // A production app would likely set an error message in state to show an alert.
      case .confirmResponse(.failure):
          return .none

      // Delete succeeded: remove the rejected request from the list.
      case let .deleteResponse(.success(connectionID)):
          state.requests.removeAll { $0.connection.id == connectionID }
          return .none

      // Delete failed: silently ignored (same caveat as confirmResponse failure).
      case .deleteResponse(.failure):
          return .none
      }
    }
  }
}
