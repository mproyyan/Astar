import Combine
import ComposableArchitecture
import CoreLocation
import Foundation
import MapKit
import SwiftUI

@Reducer
struct MainMapFeature {
  @ObservableState
  struct State: Equatable {
    // Location & Authorization
    var authorizationStatus: CLAuthorizationStatus = .notDetermined
    var currentLocation: CLLocationCoordinate2D?
    var isFollowingUser: Bool = true

    var activeRoute: MKRoute?
    var activePolyline: MKPolyline? = nil
    var isNavigating: Bool = false
    var isShowRouteGuide: Bool = DeveloperSettingsStorage.isShowRouteGuide
    var userWalkSessionID: String? = nil

    // Live Tracking related logic
    var activeWalkSessionID: String? = nil
    var activeParticipantID: String? = nil
    var trackedWalkerLocation: CLLocationCoordinate2D? = nil
    var trackedWalkerDestination: CLLocationCoordinate2D? = nil
    var trackedWalkerDestinationName: String? = nil
    var trackedWalkerRoute: MKRoute? = nil
    var trackedWalkerPolyline: MKPolyline? = nil
    var hasFittedTrackedWalker: Bool = false
    var isMockDoeWalking: Bool = false
    var mockDoeHistoryTrips: [WalkerHistoryTrip] = []

    var lastLoggedCoordinate: CLLocationCoordinate2D?
    var lastLoggedStreet: String = ""
    var lastLoggedIcon: String = "figure.walk"
    var savedPlaces: [SavedPlace] = SavedPlacesStorage.load()

    @Presents var sheet: MapSheetFeature.State?

    var isLocationAuthorized: Bool {
      authorizationStatus == .authorizedWhenInUse || authorizationStatus == .authorizedAlways
    }

    var isSearchActive: Bool {
      if case .search = sheet { return true }
      return false
    }
  }

  enum Action: Equatable {
    case onAppear
    case requestLocation
    case recenterTapped
    case delegate(Delegate)
    case locationManager(LocationManagerAction)

    case searchTapped
    case dismissSearch
    case selectPerson(Person)

    case savedPlacesUpdated([SavedPlace])
    case reloadSavedPlaces
    case selectSavedPlace(SavedPlace)

    case startAlwaysHomeNavigation
    case startDirectNavigation(destinationQuery: String)
    case directNavigationReady(destination: SavedPlace, destCoord: CLLocationCoordinate2D, originCoord: CLLocationCoordinate2D, originAddress: String, routeInfo: WalkingRouteInfo)

    case updateTrackingLocation(CLLocationCoordinate2D)
    case locationPingReceived(LocationPing)

    case sheet(PresentationAction<MapSheetFeature.Action>)

    case markTrackedWalkerFitted
    case setShowRouteGuide(Bool)
    case setTrackedWalkerRoute(MKRoute?)
    case setTrackedWalkerPolyline(MKPolyline?)
    case updateMockDoeStep(coordinate: CLLocationCoordinate2D, journeyLogEntries: [JourneyLogEntry])
    case mockDoeReachedDestination
    case resetDoeWalking

    enum Delegate: Equatable {
      case locationUpdated(CLLocationCoordinate2D)
      case walkerStatusChanged(id: UUID, newStatus: String)
      case companionStatusChanged(newStatus: String)
    }

    enum LocationManagerAction: Equatable {
      case didChangeAuthorization(CLAuthorizationStatus)
      case didUpdateLocation(CLLocationCoordinate2D)
      case didFailWithError(String)
    }
  }

  @Dependency(\.locationManager) var locationManager
  @Dependency(\.trackingClient) var trackingClient
  @Dependency(\.directionRoute) var directionRoute
  @Dependency(\.uuid) var uuid
  @Dependency(\.date.now) var now

  var body: some Reducer<State, Action> {
    Reduce { (state: inout State, action: Action) -> Effect<Action> in
      switch action {
      case .onAppear:
        state.savedPlaces = SavedPlacesStorage.load()
        return .merge(
          .send(.requestLocation),
          .run { send in
            for await status in await locationManager.authorizationStatus() {
              await send(.locationManager(.didChangeAuthorization(status)))
            }
          },
          .run { send in
            for await location in await locationManager.locationUpdates() {
              await send(.locationManager(.didUpdateLocation(location)))
            }
          },
          .run { send in
            for await error in await locationManager.errorUpdates() {
              await send(.locationManager(.didFailWithError(error.localizedDescription)))
            }
          }
        )

      case let .savedPlacesUpdated(places):
        state.savedPlaces = places
        return .none

      case .reloadSavedPlaces:
        state.savedPlaces = SavedPlacesStorage.load()
        return .none

      case let .selectSavedPlace(place):
        state.sheet = .direction(MapDirectionSheetFeature.State(destination: place))
        let currentLoc = state.currentLocation ?? CLLocationCoordinate2D(latitude: -6.2088, longitude: 106.8456)
        return .send(.sheet(.presented(.direction(.onAppear(currentLocation: currentLoc)))))

      case .requestLocation:
        return .run { _ in
          await locationManager.requestWhenInUseAuthorization()
          await locationManager.requestLocation()
        }

      case .recenterTapped:
        state.isFollowingUser = true
        return .run { _ in
          await locationManager.requestLocation()
        }

      case let .locationManager(.didChangeAuthorization(status)):
        state.authorizationStatus = status
        if status == .authorizedWhenInUse || status == .authorizedAlways {
          return .run { _ in
            await locationManager.requestLocation()
          }
        }
        return .none

      case let .locationManager(.didUpdateLocation(coordinate)):
        state.currentLocation = coordinate
        if state.isNavigating {
          // If we are actively walking, push location ping!
          let optionalSessionID = state.userWalkSessionID
          return .merge(
            .send(.delegate(.locationUpdated(coordinate))),
            .send(.updateTrackingLocation(coordinate)),
            .run { send in
                 if let sessionID = optionalSessionID {
                    // NOTE: Real implementation uses batching, but we push latest directly for simplicity based on prompt if no batched buffer
                    // Need to format Data correctly
                    let coordStruct = [coordinate.latitude, coordinate.longitude]
                    if let data = try? JSONEncoder().encode(coordStruct) {
                        try? await trackingClient.pushLocationPing(sessionID, data)
                    }
                 }
            }
          )
        }
        return .send(.delegate(.locationUpdated(coordinate)))

      case .locationManager(.didFailWithError):
        return .none

      case .searchTapped:
        state.sheet = .search(MapSearchSheetFeature.State(userLocation: state.currentLocation, savedPlaces: state.savedPlaces))
        return .none

      case .dismissSearch:
        state.sheet = nil
        return .none

      case let .selectPerson(person):
        let isReached = person.status.caseInsensitiveCompare("Arrived") == .orderedSame
                     || person.status.caseInsensitiveCompare("Reached Destination") == .orderedSame
                     || person.status.caseInsensitiveCompare("Finished") == .orderedSame
        var walkerState = MapWalkerSheetFeature.State(
          walker: person,
          status: person.status,
          isDestinationReached: isReached
        )
        if person.id == Person.mockDoeID || person.name == "Doe" {
          let isAtHome = MockDoeWalkSimulation.isNearHome(state.trackedWalkerLocation)
          let destName = isAtHome ? "Autograph Tower" : "Home"
          let destIcon = isAtHome ? "building.2.fill" : "house.fill"
          let origName = isAtHome ? "Home" : "Autograph Tower"
          let origIcon = isAtHome ? "house.fill" : "briefcase.fill"

          walkerState.destinationPlaceName = destName
          walkerState.destinationIconName = destIcon
          walkerState.trips = state.mockDoeHistoryTrips
          if isReached {
            walkerState.originPlaceName = origName
            walkerState.originIconName = origIcon
            let finalLog = MockDoeWalkSimulation.completedJourneyLog(isReturnTrip: isAtHome, now: now)
            walkerState.journeyLogEntries = finalLog
          } else {
            walkerState.originPlaceName = state.trackedWalkerLocation != nil ? (isAtHome ? "Home" : "Current Location") : origName
            walkerState.originIconName = isAtHome ? "house.fill" : (state.trackedWalkerLocation != nil ? "location.fill" : origIcon)
            walkerState.journeyLogEntries = MockDoeWalkSimulation.journeyLogFromStartToFinish(isReturnTrip: isAtHome, now: now)
            if state.activeWalkSessionID != nil {
              walkerState.activeParticipantID = state.activeWalkSessionID
            }
          }
        } else {
          walkerState.trips = WalkerSampleData.defaultTrips
        }
        state.sheet = .walker(walkerState)
        return .none

      case .startAlwaysHomeNavigation:
        let homePlace = state.savedPlaces.first(where: { $0.isHome }) ?? MapSampleData.savedPlaces.first(where: {
          $0.name.caseInsensitiveCompare("Home") == .orderedSame
        }) ?? SavedPlace(
          id: uuid(),
          name: "Home",
          subtitle: "Bendungan Hilir, South Jakarta",
          iconName: "house.fill",
          coordinate: CLLocationCoordinate2D(latitude: -6.2125, longitude: 106.8166)
        )

        state.isFollowingUser = true
        state.isNavigating = true
        state.activeWalkSessionID = nil
        state.trackedWalkerPolyline = nil
        state.trackedWalkerRoute = nil
        state.trackedWalkerDestination = nil

        let defaultOrigin = SavedPlace(
          id: uuid(),
          name: "Current Location",
          subtitle: "Locating current area...",
          iconName: "location.fill",
          coordinate: state.currentLocation
        )

        let directionState = MapDirectionSheetFeature.State(
          destination: homePlace,
          mode: .progress,
          originPlace: defaultOrigin,
          isCalculatingRoute: true,
          isNavigating: true
        )
        state.sheet = .direction(directionState)

        return .run { [homePlace] send in
          let originCoord = await locationManager.getCurrentLocation()
            ?? CLLocationCoordinate2D(latitude: -6.2088, longitude: 106.8456)

          async let originAddress = directionRoute.reverseGeocode(coordinate: originCoord)

          var destCoord = homePlace.coordinate
          if destCoord == nil {
            let searchReq = MKLocalSearch.Request()
            searchReq.naturalLanguageQuery = "Bendungan Hilir, Central Jakarta"
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

          await send(.directNavigationReady(
            destination: homePlace,
            destCoord: resolvedDest,
            originCoord: originCoord,
            originAddress: address,
            routeInfo: calculatedRoute
          ))
        }

      case let .startDirectNavigation(destinationQuery):
        let cleanQuery = destinationQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        let lowerQuery = cleanQuery.lowercased()

        let matchedPlace: SavedPlace
        if lowerQuery == "office" || lowerQuery == "work" {
          matchedPlace = state.savedPlaces.first(where: { $0.isOffice }) ?? MapSampleData.savedPlaces.first(where: { $0.name == "Office" }) ?? SavedPlace(
            name: "Office",
            subtitle: "Autograph Tower, Thamrin Nine, Central Jakarta",
            iconName: "building.2.fill",
            coordinate: CLLocationCoordinate2D(latitude: -6.1991, longitude: 106.8212)
          )
        } else if lowerQuery == "home" {
          matchedPlace = state.savedPlaces.first(where: { $0.isHome }) ?? MapSampleData.savedPlaces.first(where: { $0.name == "Home" }) ?? SavedPlace(
            name: "Home",
            subtitle: "Bendungan Hilir, South Jakarta",
            iconName: "house.fill",
            coordinate: CLLocationCoordinate2D(latitude: -6.2125, longitude: 106.8166)
          )
        } else {
          matchedPlace = state.savedPlaces.first(where: {
            $0.name.caseInsensitiveCompare(cleanQuery) == .orderedSame ||
            $0.name.localizedCaseInsensitiveContains(cleanQuery)
          }) ?? MapSampleData.allSearchablePlaces.first(where: {
            $0.name.caseInsensitiveCompare(cleanQuery) == .orderedSame ||
            $0.name.localizedCaseInsensitiveContains(cleanQuery)
          }) ?? SavedPlace(
            name: cleanQuery,
            subtitle: "Jakarta, Indonesia",
            iconName: "mappin.fill"
          )
        }

        state.isFollowingUser = true
        state.isNavigating = true
        state.activeWalkSessionID = nil
        state.trackedWalkerPolyline = nil
        state.trackedWalkerRoute = nil
        state.trackedWalkerDestination = nil

        let defaultOrigin = SavedPlace(
          id: uuid(),
          name: "Current Location",
          subtitle: "Locating current area...",
          iconName: "location.fill",
          coordinate: state.currentLocation
        )

        let directionState = MapDirectionSheetFeature.State(
          destination: matchedPlace,
          mode: .progress,
          originPlace: defaultOrigin,
          isCalculatingRoute: true,
          isNavigating: true
        )
        state.sheet = .direction(directionState)

        return .run { [matchedPlace, savedPlaces = state.savedPlaces] send in
          let originCoord = await locationManager.getCurrentLocation()
            ?? CLLocationCoordinate2D(latitude: -6.2088, longitude: 106.8456)

          async let originAddress = directionRoute.reverseGeocode(coordinate: originCoord)

          var destCoord = matchedPlace.coordinate
          if destCoord == nil {
            let lowerName = matchedPlace.name.lowercased()
            if lowerName == "home" {
              destCoord = savedPlaces.first(where: { $0.isHome })?.coordinate
                ?? CLLocationCoordinate2D(latitude: -6.2125, longitude: 106.8166)
            } else if lowerName == "office" || lowerName == "work" {
              destCoord = savedPlaces.first(where: { $0.isOffice })?.coordinate
                ?? CLLocationCoordinate2D(latitude: -6.1991, longitude: 106.8212)
            } else {
              let searchReq = MKLocalSearch.Request()
              searchReq.naturalLanguageQuery = matchedPlace.name
              let jabodetabekRegion = MKCoordinateRegion(
                center: originCoord,
                span: MKCoordinateSpan(latitudeDelta: 1.5, longitudeDelta: 1.5)
              )
              searchReq.region = jabodetabekRegion

              if let resp = try? await MKLocalSearch(request: searchReq).start(),
                 let firstItem = resp.mapItems.first {
                destCoord = firstItem.placemark.coordinate
              } else {
                let detailedReq = MKLocalSearch.Request()
                let cleanSub = matchedPlace.subtitle.trimmingCharacters(in: .whitespacesAndNewlines)
                detailedReq.naturalLanguageQuery = cleanSub.isEmpty ? matchedPlace.name : "\(matchedPlace.name) \(cleanSub)"
                detailedReq.region = jabodetabekRegion

                if let resp = try? await MKLocalSearch(request: detailedReq).start(),
                   let firstItem = resp.mapItems.first {
                  destCoord = firstItem.placemark.coordinate
                } else {
                  let geocoder = CLGeocoder()
                  let queryAddr = cleanSub.isEmpty ? matchedPlace.name : "\(matchedPlace.name), \(cleanSub)"
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

          await send(.directNavigationReady(
            destination: matchedPlace,
            destCoord: resolvedDest,
            originCoord: originCoord,
            originAddress: address,
            routeInfo: calculatedRoute
          ))
        }

      case let .directNavigationReady(destination, destCoord, originCoord, originAddress, routeInfo):
        state.currentLocation = originCoord
        state.activeRoute = routeInfo.route
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

        let updatedDest = SavedPlace(
          id: destination.id,
          name: destination.name,
          subtitle: destination.subtitle,
          iconName: destination.iconName,
          distance: routeInfo.distanceString,
          coordinate: destCoord,
          label: destination.label
        )

        let originPlace = SavedPlace(
          id: uuid(),
          name: "Current Location",
          subtitle: originAddress,
          iconName: "location.fill",
          coordinate: originCoord
        )

        let directionState = MapDirectionSheetFeature.State(
          destination: updatedDest,
          mode: .progress,
          originPlace: originPlace,
          activeRoute: routeInfo.route,
          walkingRouteInfo: routeInfo,
          isCalculatingRoute: false,
          isNavigating: true,
          isDestinationReached: false,
          journeyLogEntries: [currentEntry, startEntry]
        )
        state.sheet = .direction(directionState)
        state.lastLoggedCoordinate = originCoord
        state.lastLoggedStreet = streetName
        state.lastLoggedIcon = "figure.walk"
        return .none

      case let .updateTrackingLocation(newCoord):
        guard state.isNavigating, let sheet = state.sheet, case let .direction(directionState) = sheet, !directionState.isDestinationReached else {
          return .none
        }

        let destination = directionState.destination
        let userCL = CLLocation(latitude: newCoord.latitude, longitude: newCoord.longitude)

        // Check if arrived at destination (< 35m)
        if let destCoord = destination.coordinate {
          let destCL = CLLocation(latitude: destCoord.latitude, longitude: destCoord.longitude)
          if userCL.distance(from: destCL) <= 35.0 {
            let destTime = DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .short)
            let destEntry = JourneyLogEntry(
              landmarkName: "Destination: \(destination.name)",
              address: destination.subtitle,
              timeString: destTime,
              iconName: destination.iconName.isEmpty ? "house.fill" : destination.iconName,
              entryType: .destination,
              coordinate: destCoord
            )
            return .send(.sheet(.presented(.direction(.destinationReached(finalEntry: destEntry)))))
          }
        }

        // Check distance moved from last logged checkpoint
        if let lastCoord = state.lastLoggedCoordinate {
          let lastCL = CLLocation(latitude: lastCoord.latitude, longitude: lastCoord.longitude)
          let distMoved = userCL.distance(from: lastCL)

          if distMoved >= 60.0 {
            let previousStreet = state.lastLoggedStreet
            let previousIcon = state.lastLoggedIcon
            state.lastLoggedCoordinate = newCoord

            return .run { send in
              let landmarkInfo = await LandmarkDetector.detectNearbyLandmark(coordinate: newCoord)
              let timeStr = DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .short)

              let passedTitle = previousStreet.hasPrefix("Passed") || previousStreet.hasPrefix("Near") || previousStreet.hasPrefix("On")
                ? previousStreet
                : "Passed \(previousStreet)"

              let passedEntry = JourneyLogEntry(
                landmarkName: passedTitle,
                address: landmarkInfo.address,
                timeString: timeStr,
                iconName: previousIcon,
                entryType: .checkpoint,
                coordinate: lastCoord
              )

              let currentEntry = JourneyLogEntry(
                landmarkName: "Near \(landmarkInfo.name)",
                address: landmarkInfo.address,
                timeString: "Now",
                iconName: "location.fill",
                entryType: .currentLocation,
                coordinate: newCoord
              )

              await send(.sheet(.presented(.direction(.updateLocation(newCoord, newMilestones: [passedEntry, currentEntry])))))
            }
          }
        }
        return .none

      case let .sheet(.presented(.search(.selectPlace(place)))):
         state.sheet = .direction(MapDirectionSheetFeature.State(destination: place))
         let currentLoc = state.currentLocation ?? CLLocationCoordinate2D(latitude: -6.2088, longitude: 106.8456)
         return .send(.sheet(.presented(.direction(.onAppear(currentLocation: currentLoc)))))

      case let .setShowRouteGuide(isEnabled):
        state.isShowRouteGuide = isEnabled
        return .none

      case let .sheet(.presented(.direction(.delegate(delegateAction)))):
         switch delegateAction {
         case let .routeChanged(route, polyline):
            state.activeRoute = route
            state.activePolyline = polyline ?? route?.polyline
            return .none
         case let .navigationStarted(sessionID):
            state.isNavigating = true
            state.userWalkSessionID = sessionID
            state.activeWalkSessionID = nil
            state.trackedWalkerPolyline = nil
            state.trackedWalkerRoute = nil
            state.trackedWalkerDestination = nil
            if state.activeRoute == nil, let sheetRoute = state.sheet?.direction?.activeRoute {
              state.activeRoute = sheetRoute
            }
            if state.activePolyline == nil {
              state.activePolyline = state.activeRoute?.polyline ?? state.sheet?.direction?.walkingRouteInfo?.polyline
            }
            state.lastLoggedCoordinate = state.sheet?.direction?.journeyLogEntries.last?.coordinate ?? state.currentLocation
            state.lastLoggedStreet = "Current Area"
            state.lastLoggedIcon = "figure.walk"
            return .none
         case .navigationEnded:
            state.isNavigating = false
            state.userWalkSessionID = nil
            state.activeWalkSessionID = nil
            state.activeRoute = nil
            state.activePolyline = nil
            state.sheet = nil
            return .none
         }

      case .sheet(.presented(.search(.delegate(.dismissed)))):
         state.sheet = nil
         return .none

        case .sheet(.presented(.walker(.delegate(.dismissed)))):
           state.sheet = nil
           return .none

        case let .sheet(.presented(.walker(.delegate(.trackingStarted(walker, session))))):
           // Handle joining session
           let currentNow = now
           state.activeWalkSessionID = session.id
           state.trackedWalkerDestinationName = session.destinationName
           state.trackedWalkerDestination = CLLocationCoordinate2D(latitude: session.destinationLatitude, longitude: session.destinationLongitude)
           state.hasFittedTrackedWalker = false

             if session.id == "mock-doe-session" {
                let isReturn = session.destinationName == "Autograph Tower"
                let defaultOrigin = isReturn ? MockDoeWalkSimulation.destinationCoordinate : MockDoeWalkSimulation.originCoordinate
                let origin = state.trackedWalkerLocation ?? defaultOrigin
                let destination = CLLocationCoordinate2D(latitude: session.destinationLatitude, longitude: session.destinationLongitude)
                state.trackedWalkerLocation = origin

                if !state.isMockDoeWalking {
                   state.isMockDoeWalking = true
                   let initialLog = MockDoeWalkSimulation.journeyLog(
                       forProgress: 0.0,
                       currentCoord: origin,
                       startTime: currentNow,
                       now: currentNow,
                       isReturnTrip: isReturn
                   )
                   if case var .walker(walkerState) = state.sheet {
                       walkerState.journeyLogEntries = initialLog
                       state.sheet = .walker(walkerState)
                   }

                   return .run { send in
                       // Calculate route polyline for Doe to show on map
                       let routeInfo = await directionRoute.calculateWalkingRoute(origin: origin, destination: destination)
                       let fallbackPoly = isReturn ? MockDoeWalkSimulation.returnFallbackPolyline : MockDoeWalkSimulation.fallbackPolyline
                       let polyline = routeInfo.route?.polyline ?? fallbackPoly
                       await send(.setTrackedWalkerRoute(routeInfo.route))
                       await send(.setTrackedWalkerPolyline(polyline))

                       // Sample points strictly along the polyline so Doe follows the line exactly
                       let points = MockDoeWalkSimulation.samplePoints(from: polyline, targetCount: 10)
                       let startTime = Date()

                       for (index, point) in points.enumerated() {
                           if index > 0 {
                               try? await Task.sleep(nanoseconds: 1_800_000_000) // 1.8s per step
                           }
                           if Task.isCancelled { return }

                           let progress = Double(index) / Double(max(points.count - 1, 1))
                           let currentLog = MockDoeWalkSimulation.journeyLog(
                               forProgress: progress,
                               currentCoord: point,
                               startTime: startTime,
                               now: Date(),
                               isReturnTrip: isReturn
                           )

                           await send(.updateMockDoeStep(coordinate: point, journeyLogEntries: currentLog))

                           let data = try? JSONEncoder().encode([point.latitude, point.longitude])
                           let ping = LocationPing(
                               id: UUID().uuidString,
                               sessionRef: session.id,
                               encodedCoordinates: data != nil ? [data!] : [],
                               recordedAt: Date()
                           )
                           await send(.locationPingReceived(ping))
                       }

                       // Destination reached!
                       await send(.mockDoeReachedDestination)
                   }
                   .cancellable(id: "MockDoeWalkCancelID", cancelInFlight: true)
                } else {
                   // Simulation is ALREADY running in the background!
                   // Rejoining: calculate and show route polyline from Doe's current location to destination
                   return .run { send in
                       let routeInfo = await directionRoute.calculateWalkingRoute(origin: origin, destination: destination)
                       let fallbackPoly = isReturn ? MockDoeWalkSimulation.returnFallbackPolyline : MockDoeWalkSimulation.fallbackPolyline
                       let polyline = routeInfo.route?.polyline ?? fallbackPoly
                       await send(.setTrackedWalkerRoute(routeInfo.route))
                       await send(.setTrackedWalkerPolyline(polyline))
                   }
                }
             }

             return .run { send in
                 print("🔍 Starting tracking for walker. Session ID: \(session.id)")
                 if let profile = UserProfileStorage.load() {
                     let selfRecordID = "UserProfile_\(profile.appleUserId)_\(profile.cloudKitUserId)"
                         .replacingOccurrences(of: "[^a-zA-Z0-9]", with: "_", options: .regularExpression)

                     do {
                         print("👥 Joining session...")
                         let sessionParticipant = try await trackingClient.joinWalkSession(session.id, selfRecordID)
                         print("✅ Joined session: \(sessionParticipant.id)")

                         print("🔄 Updating user status to accompany...")
                         try await trackingClient.updateUserStatus(selfRecordID, "accompany", nil, session.id)

                         // And subscribe
                         print("🎣 Subscribing to location pings for session \(session.id)")
                         for try await ping in try await trackingClient.subscribeToLocationPings(session.id) {
                             print("📥 Stream yielded a ping block.")
                             await send(.locationPingReceived(ping))
                         }
                         print("❌ Stream ended for session \(session.id)")
                     } catch {
                         print("❌ Tracking failed with error: \(error)")
                     }
                 } else {
                     print("❌ User profile is nil. Cannot join tracking session!")
                 }
             }

         case let .setTrackedWalkerRoute(route):
            state.trackedWalkerRoute = route
            return .none

         case let .setTrackedWalkerPolyline(polyline):
            state.trackedWalkerPolyline = polyline
            return .none

         case let .updateMockDoeStep(coordinate, journeyLogEntries):
            state.trackedWalkerLocation = coordinate
            if case var .walker(walkerState) = state.sheet {
               walkerState.journeyLogEntries = journeyLogEntries
               state.sheet = .walker(walkerState)
            }
            return .none

         case .mockDoeReachedDestination:
            let currentNow = now
            let isReturn = state.trackedWalkerDestinationName == "Autograph Tower"
            let finalCoord = isReturn ? MockDoeWalkSimulation.originCoordinate : MockDoeWalkSimulation.destinationCoordinate
            state.isMockDoeWalking = false
            state.activeWalkSessionID = nil
            state.trackedWalkerPolyline = nil
            state.trackedWalkerRoute = nil
            state.trackedWalkerDestination = nil
            state.trackedWalkerLocation = finalCoord
            let finalLog = MockDoeWalkSimulation.completedJourneyLog(isReturnTrip: isReturn, now: currentNow)
            print("📝 [Mock Doe] Completed walking session logged with \(finalLog.count) checkpoints.")
            let completedTrip = MockDoeWalkSimulation.completedTrip(now: currentNow, isReturnTrip: isReturn)
            if !state.mockDoeHistoryTrips.contains(where: { $0.destinationName == completedTrip.destinationName && $0.dateString == completedTrip.dateString }) {
               state.mockDoeHistoryTrips.insert(completedTrip, at: 0)
            }
            if case var .walker(walkerState) = state.sheet {
               walkerState.isDestinationReached = true
               walkerState.activeParticipantID = nil
               walkerState.status = "Idle"
               walkerState.walker = Person(
                  id: walkerState.walker.id,
                  name: walkerState.walker.name,
                  status: "Idle",
                  appleUserId: walkerState.walker.appleUserId,
                  cloudKitUserId: walkerState.walker.cloudKitUserId
               )
               walkerState.journeyLogEntries = finalLog
               walkerState.trips = state.mockDoeHistoryTrips
               state.sheet = .walker(walkerState)
            }
            return .merge(
               .cancel(id: "MockDoeWalkCancelID"),
               .send(.delegate(.walkerStatusChanged(id: Person.mockDoeID, newStatus: "Idle"))),
               .send(.delegate(.companionStatusChanged(newStatus: "idle"))),
               .run { [trackingClient] _ in
                  if let profile = UserProfileStorage.load() {
                     let selfRecordID = "UserProfile_\(profile.appleUserId)_\(profile.cloudKitUserId)"
                        .replacingOccurrences(of: "[^a-zA-Z0-9]", with: "_", options: .regularExpression)
                     try? await trackingClient.updateUserStatus(selfRecordID, "idle", nil, nil)
                  }
               }
            )

         case .resetDoeWalking:
            state.isMockDoeWalking = false
            // Preserves state.trackedWalkerLocation at Doe's accurate location
            state.trackedWalkerDestination = nil
            state.trackedWalkerRoute = nil
            state.trackedWalkerPolyline = nil
            state.hasFittedTrackedWalker = false
            return .merge(
               .cancel(id: "MockDoeWalkCancelID"),
               .send(.delegate(.walkerStatusChanged(id: Person.mockDoeID, newStatus: "Walking")))
            )

         case .sheet(.presented(.walker(.delegate(.trackingEnded)))):
            state.activeWalkSessionID = nil
            state.trackedWalkerDestination = nil
            state.trackedWalkerRoute = nil
            state.trackedWalkerPolyline = nil
            return .merge(
               .send(.delegate(.companionStatusChanged(newStatus: "idle"))),
               .run { [trackingClient] _ in
                  if let profile = UserProfileStorage.load() {
                     let selfRecordID = "UserProfile_\(profile.appleUserId)_\(profile.cloudKitUserId)"
                        .replacingOccurrences(of: "[^a-zA-Z0-9]", with: "_", options: .regularExpression)
                     try? await trackingClient.updateUserStatus(selfRecordID, "idle", nil, nil)
                  }
               }
            )

         case let .sheet(.presented(.walker(.delegate(.walkerReachedDestination(walker))))):
            return .merge(
               .cancel(id: "MockDoeWalkCancelID"),
               .send(.mockDoeReachedDestination),
               .send(.delegate(.walkerStatusChanged(id: walker.id, newStatus: "Idle")))
            )

        case .markTrackedWalkerFitted:
           state.hasFittedTrackedWalker = true
           return .none

      case let .locationPingReceived(ping):
          print("📡 LocationPing received: \(ping.id) with \(ping.encodedCoordinates.count) points")
          if let firstData = ping.encodedCoordinates.first {
              do {
                  let coordStruct = try JSONDecoder().decode([Double].self, from: firstData)
                  print("📍 Decoded ping coordinate array: \(coordStruct)")
                  if coordStruct.count >= 2 {
                      // Note ping coordinates are often logged as [lat, lon] or [lon, lat] depending on the backend!
                      let lat = coordStruct[0]
                      let lon = coordStruct[1]
                      print("🏃 Walker tracking Location -> lat: \(lat), lon: \(lon)")

                      state.trackedWalkerLocation = CLLocationCoordinate2D(latitude: lat, longitude: lon)
                  }
              } catch {
                  print("❌ Failed mapping location ping data: \(error)")
              }
          }
          return .none

      case .sheet, .delegate, .updateTrackingLocation:
        return .none
      }
    }
    .ifLet(\.$sheet, action: \.sheet)

  }
}

// MARK: - Landmark Detector

@MainActor
private enum LandmarkDetector {
  static func detectNearbyLandmark(coordinate: CLLocationCoordinate2D) async -> (name: String, address: String, icon: String) {
    let geocoder = CLGeocoder()
    let location = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)

    var streetName = "Current Area"
    var fullAddress = "Jakarta, Indonesia"

    if let placemarks = try? await geocoder.reverseGeocodeLocation(location),
       let pm = placemarks.first {
      streetName = pm.thoroughfare ?? pm.subLocality ?? pm.name ?? "Current Area"
      let parts = [pm.thoroughfare, pm.subLocality, pm.locality, pm.administrativeArea].compactMap { $0 }.filter { !$0.isEmpty }
      fullAddress = parts.isEmpty ? (pm.name ?? "Central Jakarta") : parts.joined(separator: ", ")
    }

    // Query for POIs within immediate walking proximity (75m)
    let searchReq = MKLocalSearch.Request()
    searchReq.naturalLanguageQuery = streetName
    searchReq.resultTypes = [.pointOfInterest]
    searchReq.region = MKCoordinateRegion(center: coordinate, span: MKCoordinateSpan(latitudeDelta: 0.001, longitudeDelta: 0.001))

    if let resp = try? await MKLocalSearch(request: searchReq).start() {
      if let poi = resp.mapItems.first(where: {
        let poiCL = CLLocation(latitude: $0.placemark.coordinate.latitude, longitude: $0.placemark.coordinate.longitude)
        return poiCL.distance(from: location) <= 75.0
      }) {
        let poiName = poi.name ?? streetName
        let icon = PlaceSearchEngine.categoryIcon(for: poi.pointOfInterestCategory)
        return (name: poiName, address: fullAddress, icon: icon)
      }
    }

    return (name: streetName, address: fullAddress, icon: "figure.walk")
  }
}
