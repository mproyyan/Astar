import ComposableArchitecture

@Reducer
struct MapWalkerSheetFeature {
  @ObservableState
  struct State: Equatable {
    var walker: Person
    var status: String
    var isDestinationReached: Bool = false
    var isViewingHistoryList: Bool = false
    var selectedHistoryTrip: WalkerHistoryTrip?
    var activeParticipantID: String? = nil

    // Dynamic fetching of tracking session
    var originPlaceName: String = "Autograph Tower"
    var originIconName: String = "briefcase.fill"
    var destinationPlaceName: String = "Home"
    var destinationIconName: String = "house.fill"
  }

  enum Action: Equatable {
    case dismissWalkerTapped
    case viewAllHistoryTapped
    case selectHistoryTrip(WalkerHistoryTrip)
    case dismissHistoryDetailTapped
    case dismissHistoryListTapped
    case exitTrackTapped
    case reachDestinationTapped

    case trackTapped
    case WalkSessionLoaded(WalkSession)
    case delegate(Delegate)

    enum Delegate: Equatable {
      case dismissed
      case trackingStarted(Person)
    }
  }

  @Dependency(\.trackingClient) var trackingClient

  var body: some Reducer<State, Action> {
    Reduce { state, action in
      switch action {
      case .dismissWalkerTapped:
        return .send(.delegate(.dismissed))
        
      case .viewAllHistoryTapped:
        state.isViewingHistoryList = true
        return .none
        
      case let .selectHistoryTrip(trip):
        state.selectedHistoryTrip = trip
        return .none
        
      case .dismissHistoryDetailTapped:
        state.selectedHistoryTrip = nil
        return .none
        
      case .dismissHistoryListTapped:
        state.isViewingHistoryList = false
        return .none
        
      case .trackTapped:
        return .run { [walker = state.walker] send in
            // Typically fetch walker's `activeWalkSessionRef` from CloudKit,
            // but since we mocked session IDs from WalkerRecordID, let's derive it and fetch.
            let walkerRecordID = "UserProfile_\(walker.id)_\(walker.name)"
            let sessionID = "WalkSession_Mock_\(walkerRecordID)" // Or use actual logic

            do {
                let session = try await trackingClient.getWalkSession(sessionID)
                await send(.WalkSessionLoaded(session))
            } catch {
                // If fetch fails, we default to sending delegate directly as mock
                await send(.delegate(.trackingStarted(walker)))
            }
        }

      case let .WalkSessionLoaded(session):
         state.originPlaceName = "Current Location"
         state.originIconName = "location.fill"
         state.destinationPlaceName = session.destinationName
         state.destinationIconName = "house.fill"
         return .send(.delegate(.trackingStarted(state.walker)))

      case .exitTrackTapped, .reachDestinationTapped:
        state.isDestinationReached = true
        return .none
        
      case .delegate:
        return .none
      }
    }
  }
}
