import ComposableArchitecture
import CoreLocation
import Foundation
import SwiftUI

@Reducer
struct MapWalkerSheetFeature {
  @ObservableState
  struct State: Equatable {
    var walker: Person
    var status: String
    var isDestinationReached: Bool = false
    var isViewingHistoryList: Bool = false
    var isViewingJourneyLog: Bool = false
    var selectedHistoryTrip: WalkerHistoryTrip?
    var activeParticipantID: String? = nil

    // Dynamic fetching of tracking session
    var originPlaceName: String = "Autograph Tower"
    var originIconName: String = "briefcase.fill"
    var destinationPlaceName: String = "Home"
    var destinationIconName: String = "house.fill"

    var journeyLogEntries: [JourneyLogEntry] = []
    var trips: [WalkerHistoryTrip] = WalkerSampleData.defaultTrips

    // var isIdleOrAccompany: Bool {
    //   status.caseInsensitiveCompare("Idle") == .orderedSame
    //     || status.caseInsensitiveCompare("accompany") == .orderedSame
    // }
    var isIdleOrAccompany: Bool {
    let lower = status.lowercased()
    return lower == "idle" || lower == "accompany" || lower == "accompanying"
}

  }

  enum Action: Equatable {
    case dismissWalkerTapped
    case viewAllHistoryTapped
    case selectHistoryTrip(WalkerHistoryTrip)
    case dismissHistoryDetailTapped
    case dismissHistoryListTapped
    case exitTrackTapped
    case reachDestinationTapped
    case journeyLogTapped
    case dismissJourneyLogTapped
    case updateJourneyLog([JourneyLogEntry])

    case trackTapped
    case WalkSessionLoaded(WalkSession)
    case delegate(Delegate)

    @CasePathable
    enum Delegate: Equatable {
      case dismissed
      case trackingStarted(Person, WalkSession)
      case trackingEnded
      case walkerReachedDestination(Person)
    }
  }

  @Dependency(\.trackingClient) var trackingClient
  @Dependency(\.date.now) var now

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
        if state.walker.name == "Doe" || state.walker.name == "John Doe" || state.walker.id == Person.mockDoeID {
          let isReturn = state.destinationPlaceName == "Autograph Tower" || state.originPlaceName == "Home"
          let destName = isReturn ? "Autograph Tower" : MockDoeWalkSimulation.destinationName
          let destCoord = isReturn ? MockDoeWalkSimulation.originCoordinate : MockDoeWalkSimulation.destinationCoordinate
          let session = WalkSession(
            id: "mock-doe-session",
            walkerRef: "mock-doe",
            status: "active",
            destinationName: destName,
            destinationLatitude: destCoord.latitude,
            destinationLongitude: destCoord.longitude,
            routePolyline: nil,
            startedAt: now,
            endedAt: nil,
            currentCoordinate: nil,
            lastPingAt: now
          )
          return .send(.WalkSessionLoaded(session))
        }

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
         if state.walker.name == "Doe" || state.walker.id == Person.mockDoeID {
           if session.destinationName == "Autograph Tower" {
             state.originPlaceName = "Home"
             state.originIconName = "house.fill"
             state.destinationPlaceName = "Autograph Tower"
             state.destinationIconName = "building.2.fill"
           } else {
             state.originPlaceName = "Autograph Tower"
             state.originIconName = "briefcase.fill"
             state.destinationPlaceName = "Home"
             state.destinationIconName = "house.fill"
           }
         } else {
           state.originPlaceName = "Current Location"
           state.originIconName = "location.fill"
           state.destinationPlaceName = session.destinationName
           state.destinationIconName = "house.fill"
         }
         return .send(.delegate(.trackingStarted(state.walker, session)))

      case .exitTrackTapped:
        state.activeParticipantID = nil
        return .send(.delegate(.trackingEnded))

      case .reachDestinationTapped:
        state.isDestinationReached = true
        state.activeParticipantID = nil
        state.status = "Idle"
        state.walker = Person(
          id: state.walker.id,
          name: state.walker.name,
          status: "Idle",
          appleUserId: state.walker.appleUserId,
          cloudKitUserId: state.walker.cloudKitUserId
        )
        if state.walker.name == "Doe" || state.walker.id == Person.mockDoeID {
          let isReturn = state.destinationPlaceName == "Autograph Tower"
          let finalLog = MockDoeWalkSimulation.completedJourneyLog(isReturnTrip: isReturn, now: now)
          state.journeyLogEntries = finalLog
          let trip = MockDoeWalkSimulation.completedTrip(now: now, isReturnTrip: isReturn)
          if !state.trips.contains(where: { $0.destinationName == state.destinationPlaceName && $0.dateString.hasPrefix("Today") }) {
            state.trips.insert(trip, at: 0)
          }
        }
        return .send(.delegate(.walkerReachedDestination(state.walker)))

      case .journeyLogTapped:
        state.isViewingJourneyLog = true
        return .none

      case .dismissJourneyLogTapped:
        state.isViewingJourneyLog = false
        return .none

      case let .updateJourneyLog(entries):
        state.journeyLogEntries = entries
        return .none

      case .delegate:
        return .none
      }
    }
  }
}
