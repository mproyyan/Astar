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
    var isDevelopmentMode: Bool = DeveloperSettingsStorage.isDevelopmentMode

    var journeyLogEntries: [JourneyLogEntry] = []
  }

  enum Action: Equatable {
    case onAppear(currentLocation: CLLocationCoordinate2D?)
    case routeCalculated(WalkingRouteInfo)
    case originResolved(SavedPlace)
    case destinationResolved(CLLocationCoordinate2D)
    
    case startNavigationTapped(currentLocation: CLLocationCoordinate2D?)
    case endJourneyTapped
    case cancelDirectionsTapped
    
    case journeyLogTapped
    case dismissJourneyLogTapped
    case simulateArrivalTapped

    // Updates from parent
    case updateLocation(CLLocationCoordinate2D, newMilestones: [JourneyLogEntry])
    case destinationReached(finalEntry: JourneyLogEntry)
    
    case delegate(Delegate)
    
    enum Delegate: Equatable {
      case routeChanged(MKRoute?, MKPolyline?)
      case navigationStarted(sessionID: String?)
      case navigationEnded
    }
  }

  @Dependency(\.directionRoute) var directionRoute
  @Dependency(\.trackingClient) var trackingClient
  @Dependency(\.uuid) var uuid

  var body: some Reducer<State, Action> {
    Reduce { state, action in
      switch action {
      case let .onAppear(currentLocation):
        state.isCalculatingRoute = true
        let originCoord = currentLocation ?? CLLocationCoordinate2D(latitude: -6.2088, longitude: 106.8456)
        
        state.originPlace = SavedPlace(
          id: uuid(),
          name: "Current Location",
          subtitle: "Locating current area...",
          iconName: "location.fill",
          coordinate: originCoord
        )

        return .run { [destination = state.destination] send in
          async let originAddress = directionRoute.reverseGeocode(coordinate: originCoord)

          var destCoord = destination.coordinate
          if destCoord == nil {
            let query: String
            let lowerName = destination.name.lowercased()
            if lowerName == "home" {
              query = "Bendungan Hilir, Central Jakarta"
            } else if lowerName == "office" || lowerName == "work" {
              query = "Autograph Tower, Thamrin Nine, Central Jakarta"
            } else if lowerName == "gym" {
              query = "Agora Mall, Thamrin Nine, Central Jakarta"
            } else {
              query = "\(destination.name) \(destination.subtitle)"
            }

            let searchReq = MKLocalSearch.Request()
            searchReq.naturalLanguageQuery = query
            if let resp = try? await MKLocalSearch(request: searchReq).start(),
               let firstItem = resp.mapItems.first {
              destCoord = firstItem.placemark.coordinate
            } else {
              destCoord = CLLocationCoordinate2D(latitude: -6.2125, longitude: 106.8166)
            }
          }
          let resolvedDest = destCoord ?? CLLocationCoordinate2D(latitude: -6.2125, longitude: 106.8166)

          async let routeInfo = directionRoute.calculateWalkingRoute(origin: originCoord, destination: resolvedDest)

          let (address, calculatedRoute) = await (originAddress, routeInfo)

          let resolvedOrigin = SavedPlace(
            id: uuid(),
            name: "Current Location",
            subtitle: address,
            iconName: "location.fill",
            coordinate: originCoord
          )

          await send(.originResolved(resolvedOrigin))
          await send(.destinationResolved(resolvedDest))
          await send(.routeCalculated(calculatedRoute))
        }

      case let .originResolved(origin):
        state.originPlace = origin
        return .none

      case let .destinationResolved(destCoord):
        state.destination = SavedPlace(
          id: state.destination.id,
          name: state.destination.name,
          subtitle: state.destination.subtitle,
          iconName: state.destination.iconName,
          distance: state.destination.distance,
          coordinate: destCoord
        )
        return .none

      case let .routeCalculated(routeInfo):
        state.walkingRouteInfo = routeInfo
        state.activeRoute = routeInfo.route
        state.isCalculatingRoute = false
        if let destCoord = routeInfo.route?.polyline.points() {
          // coordinate is preserved on destination
        }
        return .send(.delegate(.routeChanged(routeInfo.route, routeInfo.polyline)))

      case let .startNavigationTapped(currentLocation):
        state.isNavigating = true
        state.isDestinationReached = false
        if state.activeRoute == nil {
          state.activeRoute = state.walkingRouteInfo?.route
        }
        state.mode = .progress

        let originCoord = currentLocation ?? CLLocationCoordinate2D(latitude: -6.2088, longitude: 106.8456)
        let originAddress = state.originPlace?.subtitle ?? "Current Location"
        let streetName = originAddress.components(separatedBy: ",").first?.trimmingCharacters(in: .whitespaces) ?? "Current Area"
        let startTimeString = DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .short)

        let startEntry = JourneyLogEntry(
          id: uuid(),
          landmarkName: "Start Position",
          address: originAddress,
          timeString: startTimeString,
          iconName: "figure.walk.motion",
          entryType: .start,
          coordinate: originCoord
        )

        let currentEntry = JourneyLogEntry(
          id: uuid(),
          landmarkName: "Near \(streetName)",
          address: originAddress,
          timeString: "Now",
          iconName: "location.fill",
          entryType: .currentLocation,
          coordinate: originCoord
        )

        state.journeyLogEntries = [currentEntry, startEntry]

        let destinationCopy = state.destination
        return .run { send in
            // Call TrackingClient to start WalkSession.
            if let userProfile = UserProfileStorage.load() {
                let userRecordID = "UserProfile_\(userProfile.appleUserId)_\(userProfile.cloudKitUserId)"
                  .replacingOccurrences(of: "[^a-zA-Z0-9]", with: "_", options: .regularExpression)

                let destLat = destinationCopy.coordinate?.latitude ?? -6.2088
                let destLon = destinationCopy.coordinate?.longitude ?? 106.8456
                print("[CloudKit Debug] Starting journey with userRecordID=\(userRecordID), destination=\(destinationCopy.name), lat=\(destLat), lon=\(destLon)")

                do {
                    let session = try await trackingClient.startWalkSession(userRecordID, destinationCopy.name, destLat, destLon, nil)
                    print("[CloudKit Debug] startWalkSession succeeded with sessionID=\(session.id)")

                    // Update user status.
                    try await trackingClient.updateUserStatus(userRecordID, "walking", session.id, nil)
                    print("[CloudKit Debug] updateUserStatus walking succeeded for userRecordID=\(userRecordID)")

                    await send(.delegate(.navigationStarted(sessionID: session.id)))
                    return
                } catch {
                    print("[CloudKit Debug] Starting journey CloudKit writes failed: \(error)")
                }
            } else {
                print("[CloudKit Debug] Cannot start CloudKit journey because UserProfileStorage.load() returned nil.")
            }

            await send(.delegate(.navigationStarted(sessionID: nil)))
        }

      case .endJourneyTapped, .cancelDirectionsTapped:
        return .run { send in
            if let userProfile = UserProfileStorage.load() {
                let userRecordID = "UserProfile_\(userProfile.appleUserId)_\(userProfile.cloudKitUserId)"
                  .replacingOccurrences(of: "[^a-zA-Z0-9]", with: "_", options: .regularExpression)

                do {
                    // Revert status to Idle.
                    try await trackingClient.updateUserStatus(userRecordID, "idle", nil, nil)
                    print("[CloudKit Debug] updateUserStatus idle succeeded for userRecordID=\(userRecordID)")
                } catch {
                    print("[CloudKit Debug] updateUserStatus idle failed for userRecordID=\(userRecordID): \(error)")
                }
            } else {
                print("[CloudKit Debug] Cannot end CloudKit journey because UserProfileStorage.load() returned nil.")
            }
            await send(.delegate(.navigationEnded))
        }

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

      case .simulateArrivalTapped:
        state.isDestinationReached = true
        state.journeyLogEntries.removeAll(where: { $0.entryType == .currentLocation })
        let destName = state.destination.name
        let destSubtitle = state.destination.subtitle
        let destTime = DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .short)
        let destEntry = JourneyLogEntry(
          id: uuid(),
          landmarkName: "Destination: \(destName)",
          address: destSubtitle,
          timeString: destTime,
          iconName: state.destination.iconName.isEmpty ? "house.fill" : state.destination.iconName,
          entryType: .destination,
          coordinate: state.destination.coordinate
        )
        if state.journeyLogEntries.count <= 1 {
          let intermediateEntry = JourneyLogEntry(
            id: uuid(),
            landmarkName: "Passed Jl. M.H. Thamrin",
            address: "Central Jakarta",
            timeString: destTime,
            iconName: "figure.walk",
            entryType: .checkpoint,
            coordinate: nil
          )
          state.journeyLogEntries.insert(intermediateEntry, at: 0)
        }
        state.journeyLogEntries.insert(destEntry, at: 0)
        return .none

      case .delegate:
        return .none
      }
    }
  }
}
