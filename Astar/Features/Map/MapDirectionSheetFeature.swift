import ComposableArchitecture
import CoreLocation
import MapKit

@Reducer
struct MapDirectionSheetFeature {
  enum Mode: Equatable, Sendable {
    case directions
    case progress
    case journeyLog
  }

  @ObservableState
  struct State: Equatable {
    var destination: SavedPlace
    var mode: Mode = .directions
    
    var originPlace: SavedPlace?
    var activeRoute: MKRoute?
    var walkingRouteInfo: WalkingRouteInfo?
    var isCalculatingRoute: Bool = false
    
    var isNavigating: Bool = false
    var isDestinationReached: Bool = false
    
    var journeyLogEntries: [JourneyLogEntry] = []
  }

  enum Action: Equatable {
    case onAppear(currentLocation: CLLocationCoordinate2D?)
    case routeCalculated(WalkingRouteInfo)
    case originResolved(SavedPlace)
    
    case startNavigationTapped(currentLocation: CLLocationCoordinate2D?)
    case endJourneyTapped
    case cancelDirectionsTapped
    
    case journeyLogTapped
    case dismissJourneyLogTapped
    
    // Updates from parent
    case updateLocation(CLLocationCoordinate2D, newMilestones: [JourneyLogEntry])
    case destinationReached(finalEntry: JourneyLogEntry)
    
    case delegate(Delegate)
    
    enum Delegate: Equatable {
      case routeChanged(MKRoute?)
      case navigationStarted
      case navigationEnded
    }
  }

  @Dependency(\.directionRoute) var directionRoute

  var body: some Reducer<State, Action> {
    Reduce { state, action in
      switch action {
      case let .onAppear(currentLocation):
        state.isCalculatingRoute = true
        let originCoord = currentLocation ?? CLLocationCoordinate2D(latitude: -6.2088, longitude: 106.8456)
        
        state.originPlace = SavedPlace(
          name: "Current Location",
          subtitle: "Locating current area...",
          iconName: "location.fill",
          coordinate: originCoord
        )

        return .run { [destination = state.destination] send in
          async let originAddress = directionRoute.reverseGeocode(coordinate: originCoord)

          var destCoord = destination.coordinate
          if destCoord == nil {
            let searchReq = MKLocalSearch.Request()
            searchReq.naturalLanguageQuery = "\(destination.name) \(destination.subtitle)"
            if let resp = try? await MKLocalSearch(request: searchReq).start(),
               let firstItem = resp.mapItems.first {
              destCoord = firstItem.placemark.coordinate
            } else {
              destCoord = CLLocationCoordinate2D(latitude: -6.2088, longitude: 106.8456)
            }
          }
          let resolvedDest = destCoord ?? CLLocationCoordinate2D(latitude: -6.2088, longitude: 106.8456)

          async let routeInfo = directionRoute.calculateWalkingRoute(origin: originCoord, destination: resolvedDest)

          let (address, calculatedRoute) = await (originAddress, routeInfo)

          let resolvedOrigin = SavedPlace(
            name: "Current Location",
            subtitle: address,
            iconName: "location.fill",
            coordinate: originCoord
          )

          await send(.originResolved(resolvedOrigin))
          await send(.routeCalculated(calculatedRoute))
        }

      case let .originResolved(origin):
        state.originPlace = origin
        return .none

      case let .routeCalculated(routeInfo):
        state.walkingRouteInfo = routeInfo
        state.activeRoute = routeInfo.route
        state.isCalculatingRoute = false
        return .send(.delegate(.routeChanged(routeInfo.route)))

      case let .startNavigationTapped(currentLocation):
        state.isNavigating = true
        state.isDestinationReached = false
        state.activeRoute = nil
        state.mode = .progress

        let originCoord = currentLocation ?? CLLocationCoordinate2D(latitude: -6.2088, longitude: 106.8456)
        let originAddress = state.originPlace?.subtitle ?? "Current Location"
        let streetName = originAddress.components(separatedBy: ",").first?.trimmingCharacters(in: .whitespaces) ?? "Current Area"
        let startTimeString = DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .short)

        let startEntry = JourneyLogEntry(
          landmarkName: "Start Position",
          address: originAddress,
          timeString: startTimeString,
          iconName: "figure.walk.motion",
          entryType: .start,
          coordinate: originCoord
        )

        let currentEntry = JourneyLogEntry(
          landmarkName: "Near \(streetName)",
          address: originAddress,
          timeString: "Now",
          iconName: "location.fill",
          entryType: .currentLocation,
          coordinate: originCoord
        )

        state.journeyLogEntries = [currentEntry, startEntry]
        return .merge(
          .send(.delegate(.routeChanged(nil))),
          .send(.delegate(.navigationStarted))
        )

      case .endJourneyTapped, .cancelDirectionsTapped:
        return .send(.delegate(.navigationEnded))

      case .journeyLogTapped:
        state.mode = .journeyLog
        return .none

      case .dismissJourneyLogTapped:
        state.mode = .progress
        return .none

      case let .updateLocation(_, newMilestones):
        // Remove previous live current location
        state.journeyLogEntries.removeAll(where: { $0.entryType == .currentLocation })
        
        for milestone in newMilestones {
           state.journeyLogEntries.insert(milestone, at: 0)
        }
        return .none

      case let .destinationReached(finalEntry):
        state.isDestinationReached = true
        state.journeyLogEntries.removeAll(where: { $0.entryType == .currentLocation })
        state.journeyLogEntries.insert(finalEntry, at: 0)
        return .none
        
      case .delegate:
        return .none
      }
    }
  }
}
