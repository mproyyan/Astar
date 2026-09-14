import ComposableArchitecture
import Foundation
import CloudKit

// MARK: - FetchConnectionsError
//
// Equatable, Sendable error wrapper for list-fetching failures.
// See `ConnectionActionError` in RequestTrustedPersonFeature.swift for the
// detailed rationale on why a custom type is needed here instead of bare `Error`.
struct FetchConnectionsError: Error, Equatable, Sendable {
    let message: String
}

// MARK: - TrustedPersonFeature
//
// The "parent" TCA Reducer that owns the Trusted Person screen.
// It coordinates between two child concerns:
//   1. The main list of connections (mutual + pending outgoing requests).
//   2. An optional child feature (`AddTrustedPersonFeature`) presented as a modal sheet.
//
// Parent-Child relationship in TCA:
//   TCA composes features hierarchically — like nesting React components where the
//   parent holds state and passes down slices. Here, `TrustedPersonFeature` is the
//   parent; `AddTrustedPersonFeature` is a child that lives inside `.destination`.
//
//   When the child emits a `.delegate` action, TCA "bubbles" it up to the parent
//   via the `.destination(.presented(.addParticipant(.delegate(...))))` action path.
@Reducer
struct TrustedPersonFeature {

  // MARK: State
  //
  // All observable data for the Trusted Person screen lives here.
  // Swift value-type structs give us free "snapshots" — useful for time-travel
  // debugging, undo stacks, and diffing (similar to Redux DevTools).
  @ObservableState
  struct State: Equatable {

      // MARK: Navigation / Destination State
      //
      // `@Presents` is a TCA property wrapper that marks this optional State as
      // a "navigation destination" managed by the reducer. When non-nil, a sheet
      // or navigation push is presented. When nil, it is dismissed.
      //
      // Python analogy: a `current_modal: Optional[ModalState]` field on your
      // ViewModel — setting it to None closes the modal; assigning a value opens it.
      //
      // `Destination.State?` is an Optional enum whose cases correspond to each
      // possible screen the user can navigate to from here.
      @Presents var destination: Destination.State?

      /// The full list of connection records fetched from CloudKit.
      var connections: [ConnectionProfile] = []

      /// `true` while a network request is in flight. Used to show a skeleton loader.
      var isLoading = false

      // MARK: Derived / Computed Properties
      //
      // Computed properties on `State` act like database VIEWS — they derive new
      // data from the canonical stored data without duplicating it.
      // Python analogy: `@property` decorated methods on a dataclass.

      /// Connections that appear in the main "trusted persons" list:
      ///   - Status "mutual": both sides have accepted.
      ///   - Status "request" initiated BY the current user: outgoing invite
      ///     (shown with "Invited" badge to indicate the request is pending acceptance).
      var mutualConnections: [ConnectionProfile] {
          let currentUserId = UserProfileStorage.load()?.recordID.recordName
          return connections.filter { 
              $0.connection.status == "mutual" ||
              ($0.connection.status == "request" && $0.connection.initiatedByRowID == currentUserId)
          }
      }

      /// Connections where someone ELSE invited the current user — shown in the
      /// "Requests" banner at the top of the screen.
      var requestConnections: [ConnectionProfile] {
          let currentUserId = UserProfileStorage.load()?.recordID.recordName
          return connections.filter {
              $0.connection.status == "request" && $0.connection.initiatedByRowID != currentUserId
          }
      }
  }

  // MARK: Action
  //
  // Every user gesture and every async result is represented as a named Action case.
  // Think of it as an exhaustive event log — like Kafka topics or Redux action types.
  enum Action: Equatable {
      /// Sent when the view appears; triggers fetching the connections list.
      case onAppear
      /// Async response from CloudKit with the fetched connections (or an error).
      case fetchConnectionsResponse(Result<[ConnectionProfile], FetchConnectionsError>)
      /// Routes all actions from child `Destination` features up to this reducer.
      case destination(PresentationAction<Destination.Action>)
      /// User tapped the "Requests" banner — navigate to the requests sub-screen.
      case requestSectionTapped
      /// User tapped "Add Participant" — present the `AddTrustedPersonFeature` sheet.
      case addParticipantTapped
      /// Delegate actions bubble UP to this feature's parent (e.g., ProfileFeature).
      case delegate(Delegate)
      /// Async result after attempting to send connection requests for added emails.
      case didAddPersonsResponse(Result<Bool, FetchConnectionsError>)

      // MARK: Delegate
      //
      // Delegate actions are how this feature notifies its parent of important events
      // without knowing who the parent is. The parent pattern-matches on these in
      // its own reducer body via `.destination(.presented(.trustedPerson(.delegate(...))))`.
      enum Delegate: Equatable {
          /// Tells the parent to navigate to the Requests screen, passing request data.
          case requestSectionTapped([ConnectionProfile])
      }
  }

  // MARK: Destination
  //
  // `Destination` is a nested `@Reducer` enum that lists ALL possible navigation
  // targets from this screen. Each case holds a child feature's State+Action.
  //
  // TCA uses this pattern instead of a bare `enum` so that:
  //   1. The reducer compiler plugin (`@Reducer`) generates proper `Equatable` conformances.
  //   2. `PresentationAction<Destination.Action>` can route child actions back up.
  //
  // Python analogy: a sum type (tagged union) where each variant carries a different
  // data payload — like `Union[AddTrustedPersonState, AnotherScreenState]`.
  @Reducer(state: .equatable, action: .equatable)
  enum Destination {
      /// The "Add Trusted Person" modal sheet.
      case addParticipant(AddTrustedPersonFeature)
  }

  // MARK: Dependencies
  @Dependency(\.connectionsClient) var connectionsClient
  @Dependency(\.usersClient) var usersClient

  // MARK: Reducer Body
  //
  // `body` composes the main `Reduce` logic with `.ifLet` for the optional
  // child destination. This is TCA's operator for integrating optional child reducers.
  var body: some Reducer<State, Action> {
    Reduce { state, action in
      switch action {

      // -------------------------------------------------------------------------
      // MARK: Data Fetching
      // -------------------------------------------------------------------------

      // On appear, fetch all connections for the current user from CloudKit.
      // Guard returns early (`.none` = no effect) if no user profile is loaded.
      case .onAppear:
          guard let profile = UserProfileStorage.load() else { return .none }
          state.isLoading = true
          // `.run` spawns an async Task — analogous to `asyncio.ensure_future(coro())`.
          return .run { send in
              do {
                  let connections = try await connectionsClient.fetchConnections(profile.recordID)
                  await send(.fetchConnectionsResponse(.success(connections)))
              } catch {
                  await send(.fetchConnectionsResponse(.failure(FetchConnectionsError(message: error.localizedDescription))))
              }
          }

      // Success: store connections and stop the loading indicator.
      case let .fetchConnectionsResponse(.success(connections)):
          state.isLoading = false
          state.connections = connections
          return .none

      // Failure: stop loading. A future improvement could surface an error alert.
      case .fetchConnectionsResponse(.failure):
          state.isLoading = false
          return .none

      // -------------------------------------------------------------------------
      // MARK: Navigation
      // -------------------------------------------------------------------------

      // Forward the request list to the parent via a delegate action.
      // `.send` creates an Effect that immediately dispatches another action —
      // like calling `dispatch(anotherAction)` inside a Redux thunk.
      case .requestSectionTapped:
          return .send(.delegate(.requestSectionTapped(state.requestConnections)))

      // Present the "Add Participant" sheet by setting `destination` to a non-nil value.
      // Setting a `@Presents` property to non-nil is analogous to `setModalVisible(true)`
      // in React Native — SwiftUI observes the change and presents the sheet.
      case .addParticipantTapped:
          state.destination = .addParticipant(AddTrustedPersonFeature.State())
          return .none

      // -------------------------------------------------------------------------
      // MARK: Child → Parent Communication (Delegate Pattern)
      // -------------------------------------------------------------------------
      //
      // This case pattern-matches a deeply nested action path:
      //   destination → presented → addParticipant → delegate → didAddPersons([emails])
      //
      // TCA synthesizes this nested path automatically from the `@Reducer` enum.
      // It is the Swift compile-time-safe equivalent of Python's:
      //   if action.type == "destination/presented/addParticipant/delegate/didAddPersons":
      //       emails = action.payload
      //
      // When the child feature fires `.delegate(.didAddPersons(emails))`, TCA wraps
      // it in successive `PresentationAction.presented(...)` wrappers as it bubbles up.
      case let .destination(.presented(.addParticipant(.delegate(.didAddPersons(emails))))):
          guard let profile = UserProfileStorage.load() else { return .none }
          state.isLoading = true
          // Async effect: for each email, look up the user record in CloudKit,
          // then send a connection request. Sequential iteration inside a single Task.
          return .run { send in
              do {
                  for email in emails {
                      print("Fetching user by email: \(email)")
                      if let partner = try await usersClient.fetchUserByEmail(email) {
                          print("Found partner user: \(partner.name), sending request...")
                          try await connectionsClient.sendRequest(profile.recordID, partner.recordID)
                          print("Request successfully saved to CloudKit!")
                      } else {
                          print("Partner user with email \(email) not found.")
                      }
                  }
                  await send(.didAddPersonsResponse(.success(true)))
              } catch {
                  print("Error occurred while adding person: \(error)")
                  await send(.didAddPersonsResponse(.failure(FetchConnectionsError(message: error.localizedDescription))))
              }
          }

      // After successfully sending all requests, refresh the list to reflect new state.
      // Sending `.onAppear` reuses the existing fetch logic — DRY principle.
      case .didAddPersonsResponse(.success):
          return .send(.onAppear) // Refresh the list

      case .didAddPersonsResponse(.failure):
          state.isLoading = false
          return .none

      // Catch-all for all other destination actions (e.g., sheet dismissed without
      // selecting, child actions the parent doesn't need to act on).
      case .destination:
          return .none

      // Delegate actions are handled by THIS feature's parent, not here.
      // The reducer must still list the case to satisfy the exhaustive switch.
      case .delegate:
          return .none
      }
    }
    // -------------------------------------------------------------------------
    // MARK: Child Reducer Integration
    // -------------------------------------------------------------------------
    //
    // `.ifLet(\.$destination, action: \.destination)` hooks in the child reducers
    // for all cases of `Destination`. When `state.destination` is `.addParticipant`,
    // the `AddTrustedPersonFeature` reducer also runs on matching actions.
    //
    // Python analogy: calling `child_reducer(child_state, child_action)` inside
    // the parent reducer, but TCA does it automatically via this operator.
    .ifLet(\.$destination, action: \.destination)
  }
}
