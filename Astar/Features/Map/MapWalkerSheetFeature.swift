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
            // When track is tapped, we join the active walk session.
            // Wait, we need to know what session the walker is currently on.
            // Since MapWalkerSheetFeature doesn't know the exact session ID without making a fetch,
            // we should probably query the UserProfile of the walker and get `activeWalkSessionRef`
            // But to keep it simple and fulfill the requiremenets, let's assume we can fetch it
            // or pass it in. For simplicity, we just trigger Delegate and let MainMap do it, Or we can do it here!
            await send(.delegate(.trackingStarted(walker)))
        }

      case .exitTrackTapped, .reachDestinationTapped:
        state.isDestinationReached = true
        return .none
        
      case .delegate:
        return .none
      }
    }
  }
}
