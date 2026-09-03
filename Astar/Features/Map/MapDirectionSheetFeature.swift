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

    var watchingPeople: [Person] = []
    var journeyLogEntries: [JourneyLogEntry] = []
  }

  enum Action: Equatable {
    case onAppear(currentLocation: CLLocationCoordinate2D?)
    case setWatchingPeople([Person])
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
      case let .setWatchingPeople(people):
        state.watchingPeople = people
        return .none

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
        let originPlaceCopy = state.originPlace
        return .run { send in
            // Call TrackingClient to start WalkSession
            if let userProfile = UserProfileStorage.load() {
                let userRecordID = "UserProfile_\(userProfile.appleUserId)_\(userProfile.cloudKitUserId)"
                  .replacingOccurrences(of: "[^a-zA-Z0-9]", with: "_", options: .regularExpression)

                let destLat = destinationCopy.coordinate?.latitude ?? -6.2088
                let destLon = destinationCopy.coordinate?.longitude ?? 106.8456
                
                let currentLat = originPlaceCopy?.coordinate?.latitude ?? -6.2088
                let currentLon = originPlaceCopy?.coordinate?.longitude ?? 106.8456
                let initialData = (try? JSONEncoder().encode([currentLat, currentLon])) ?? Data()

                do {
                    let session = try await trackingClient.startWalkSession(userRecordID, destinationCopy.name, destLat, destLon, nil, initialData)

                    // Update user status
                    try await trackingClient.updateUserStatus(userRecordID, "walking", session.id, nil)

                    await send(.delegate(.navigationStarted(sessionID: session.id)))
                    return
                } catch {
                    // Suppress error for now in UI based on design, but it will fail silently if cloudkit dies
                }
            }

            await send(.delegate(.navigationStarted(sessionID: nil)))
        }

      case .endJourneyTapped, .cancelDirectionsTapped:
        return .run { send in
            if let userProfile = UserProfileStorage.load() {
                let userRecordID = "UserProfile_\(userProfile.appleUserId)_\(userProfile.cloudKitUserId)"
                  .replacingOccurrences(of: "[^a-zA-Z0-9]", with: "_", options: .regularExpression)

                do {
                    // Revert status to Idle
                    try await trackingClient.updateUserStatus(userRecordID, "idle", nil, nil)
                } catch { }
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
