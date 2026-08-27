import ComposableArchitecture
import Foundation

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
      case trackingStarted(Person, WalkSession)
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
        let destinationPlaceName = state.destinationPlaceName
        return .run { [walker = state.walker] send in
            // Fetch walker's `activeWalkSessionRef` from CloudKit Profile
            let appleUID = walker.appleUserId ?? "applemock"
            let cloudUID = walker.cloudKitUserId ?? "cloudmock"
            let walkerRecordID = "UserProfile_\(appleUID)_\(cloudUID)"
                .replacingOccurrences(of: "[^a-zA-Z0-9]", with: "_", options: .regularExpression)

            do {
                if let sessionID = try await trackingClient.getWalkerActiveSessionID(walkerRecordID) {
                    let session = try await trackingClient.getWalkSession(sessionID)
                    await send(.WalkSessionLoaded(session))
                } else {
                    print("Walker isn't actively navigating (no active WalkSession)")
                }
            } catch {
                print("Failed tracking walker: \(error)")
            }
        }

      case let .WalkSessionLoaded(session):
         state.activeParticipantID = session.id
         state.originPlaceName = "Current Location"
         state.originIconName = "location.fill"
         state.destinationPlaceName = session.destinationName
         state.destinationIconName = "house.fill"
         return .send(.delegate(.trackingStarted(state.walker, session)))

      case .exitTrackTapped, .reachDestinationTapped:
        state.isDestinationReached = true
        return .none
        
      case .delegate:
        return .none
      }
    }
  }
}
