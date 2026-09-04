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

    var currentSessionID: String?
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

    // Added: Simulates sending motionless ping to watch
    case sendSafetyPingToWatch

    // Updates from parent
    case updateLocation(CLLocationCoordinate2D, newMilestones: [JourneyLogEntry])
    case destinationReached(finalEntry: JourneyLogEntry)
    case watchMessageReceived(WatchActionMessage)
    case _navigationStartedInternal(sessionID: String?)

    case delegate(Delegate)
    
    enum Delegate: Equatable {
      case routeChanged(MKRoute?, MKPolyline?)
      case navigationStarted(sessionID: String?)
      case navigationEnded
    }
  }

  @Dependency(\.directionRoute) var directionRoute
  @Dependency(\.trackingClient) var trackingClient
  @Dependency(\.watchConnectivity) var watchConnectivity
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
          await watchConnectivity.activateSession()
          async let originAddress = directionRoute.reverseGeocode(coordinate: originCoord)

          var destCoord = destination.coordinate
          if destCoord == nil {
            let lowerName = destination.name.lowercased()
            if lowerName == "home" {
              destCoord = SavedPlacesStorage.load().first(where: { $0.isHome })?.coordinate
                ?? CLLocationCoordinate2D(latitude: -6.2125, longitude: 106.8166)
            } else if lowerName == "office" || lowerName == "work" {
              destCoord = SavedPlacesStorage.load().first(where: { $0.isOffice })?.coordinate
                ?? CLLocationCoordinate2D(latitude: -6.1991, longitude: 106.8212)
            } else {
              // 1. Regional search for destination name
              let searchReq = MKLocalSearch.Request()
              searchReq.naturalLanguageQuery = destination.name
              let jabodetabekRegion = MKCoordinateRegion(
                center: originCoord,
                span: MKCoordinateSpan(latitudeDelta: 1.5, longitudeDelta: 1.5)
              )
              searchReq.region = jabodetabekRegion

              if let resp = try? await MKLocalSearch(request: searchReq).start(),
                 let firstItem = resp.mapItems.first {
                destCoord = firstItem.placemark.coordinate
              } else {
                // 2. Detailed search with name + subtitle
                let detailedReq = MKLocalSearch.Request()
                let cleanSub = destination.subtitle.trimmingCharacters(in: .whitespacesAndNewlines)
                detailedReq.naturalLanguageQuery = cleanSub.isEmpty ? destination.name : "\(destination.name) \(cleanSub)"
                detailedReq.region = jabodetabekRegion

                if let resp = try? await MKLocalSearch(request: detailedReq).start(),
                   let firstItem = resp.mapItems.first {
                  destCoord = firstItem.placemark.coordinate
                } else {
                  // 3. CoreLocation forward geocoding on name/subtitle
                  let geocoder = CLGeocoder()
                  let queryAddr = cleanSub.isEmpty ? destination.name : "\(destination.name), \(cleanSub)"
                  if let placemarks = try? await geocoder.geocodeAddressString(queryAddr),
                     let loc = placemarks.first?.location?.coordinate {
                    destCoord = loc
                  } else if !cleanSub.isEmpty,
                            let placemarks = try? await geocoder.geocodeAddressString(cleanSub),
                            let loc = placemarks.first?.location?.coordinate {
                    destCoord = loc
                  }
                }
              }
            }
          }
          let resolvedDest = destCoord ?? originCoord

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
        let mergedEffect: Effect<Action> = .send(.delegate(.routeChanged(routeInfo.route, routeInfo.polyline)))
        if state.isNavigating {
            return .merge(mergedEffect, syncWatchEffect(state: state))
        }
        return mergedEffect

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
        let originPlaceCopy = state.originPlace
        let watchSyncEffect = syncWatchEffect(state: state)

        return .merge(
            watchSyncEffect,
            .run { send in
                // Call TrackingClient to start WalkSession
                await watchConnectivity.activateSession()
                if let userProfile = UserProfileStorage.load() {
                    let userRecordID = "UserProfile_\(userProfile.appleUserId)_\(userProfile.cloudKitUserId)"
                      .replacingOccurrences(of: "[^a-zA-Z0-9]", with: "_", options: .regularExpression)

                    let destLat = destinationCopy.coordinate?.latitude ?? -6.2088
                    let destLon = destinationCopy.coordinate?.longitude ?? 106.8456

                    let currentLat = originPlaceCopy?.coordinate?.latitude ?? -6.2088
                    let currentLon = originPlaceCopy?.coordinate?.longitude ?? 106.8456
                    let initialData = (try? JSONEncoder().encode([currentLat, currentLon])) ?? Data()

                    do {
                        await watchConnectivity.activateSession()
                        let session = try await trackingClient.startWalkSession(userRecordID, destinationCopy.name, destLat, destLon, nil, initialData)

                        // Update user status
                        try await trackingClient.updateUserStatus(userRecordID, "walking", session.id, nil)

                        await send(._navigationStartedInternal(sessionID: session.id))
                        return
                    } catch {
                        // Suppress error for now in UI based on design, but it will fail silently if cloudkit dies
                    }
                }

                await watchConnectivity.activateSession()
                await send(._navigationStartedInternal(sessionID: nil))
            },
            .run { send in
                for await message in await watchConnectivity.messageStream() {
                    await send(.watchMessageReceived(message))
                }
            }
        )

      case let ._navigationStartedInternal(sessionID):
        state.currentSessionID = sessionID
        return .send(.delegate(.navigationStarted(sessionID: sessionID)))

      case .endJourneyTapped, .cancelDirectionsTapped:
        let isDone = action == .endJourneyTapped
        let watchState = WatchDirectionState(
            destinationName: isDone ? state.destination.name : "",
            eta: "--.--",
            estimatedTime: "--",
            totalDistance: "--",
            isDone: isDone,
            watchingPeople: [ WatchPerson(name: "Awan", status: "Tracking") ]
        )
        return .run { [currentSessionID = state.currentSessionID] send in
            if let userProfile = UserProfileStorage.load() {
                let userRecordID = "UserProfile_\(userProfile.appleUserId)_\(userProfile.cloudKitUserId)"
                  .replacingOccurrences(of: "[^a-zA-Z0-9]", with: "_", options: .regularExpression)

                do {
                    // Revert status to Idle
                    try await trackingClient.updateUserStatus(userRecordID, "idle", nil, nil)

                    if let sid = currentSessionID {
                        try await trackingClient.logWalkEvent(
                            sid,
                            "journey_ended",
                            isDone ? "Journey ended safely" : "Journey cancelled",
                            0.0,
                            0.0
                        )
                    }
                } catch { }
            }
            try? await watchConnectivity.updateState(watchState)
            await send(.delegate(.navigationEnded))
        }

      case .sendSafetyPingToWatch:
        return .run { _ in
            try? await watchConnectivity.sendMessage(.areYouSafe(message: "We noticed you haven't moved in a while. Are you safe?"))
        }

      case let .watchMessageReceived(message):
        let sid = state.currentSessionID
        let loc = state.journeyLogEntries.first?.coordinate
        let lat = loc?.latitude ?? 0.0
        let lon = loc?.longitude ?? 0.0

        return .run { send in
            guard let sid = sid else { return }
            switch message {
            case .imSafe:
                try? await trackingClient.logWalkEvent(sid, "safety_response", "Walker marked themselves as SAFE.", lat, lon)
            case .needHelp:
                try? await trackingClient.logWalkEvent(sid, "emergency", "Walker NEEDS HELP!", lat, lon)
            default:
                break
            }
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
        return syncWatchEffect(state: state)

      case let .destinationReached(finalEntry):
        state.isDestinationReached = true
        state.journeyLogEntries.removeAll(where: { $0.entryType == .currentLocation })
        state.journeyLogEntries.insert(finalEntry, at: 0)
        return syncWatchEffect(state: state)

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
        return syncWatchEffect(state: state)

      case .delegate:
        return .none
      }
    }
  }

  private func syncWatchEffect(state: State) -> Effect<Action> {
      let watchState = WatchDirectionState(
          destinationName: state.destination.name,
          eta: state.walkingRouteInfo?.etaString ?? "--.--",
          estimatedTime: state.walkingRouteInfo?.travelTimeString ?? "--",
          totalDistance: state.walkingRouteInfo?.distanceString ?? "--",
          isDone: state.isDestinationReached,
          watchingPeople: [ WatchPerson(name: "Awan", status: "Tracking") ] // Mock watching person
      )
      return .run { _ in
          try? await watchConnectivity.updateState(watchState)
      }
  }
}
