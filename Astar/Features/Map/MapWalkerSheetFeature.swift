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
  }

  enum Action: Equatable {
    case dismissWalkerTapped
    case viewAllHistoryTapped
    case selectHistoryTrip(WalkerHistoryTrip)
    case dismissHistoryDetailTapped
    case dismissHistoryListTapped
    case exitTrackTapped
    case reachDestinationTapped
    
    case delegate(Delegate)
    
    enum Delegate: Equatable {
      case dismissed
    }
  }

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
        
      case .exitTrackTapped, .reachDestinationTapped:
        state.isDestinationReached = true
        return .none
        
      case .delegate:
        return .none
      }
    }
  }
}
