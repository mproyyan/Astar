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
    var isNavigating: Bool = false

    var lastLoggedCoordinate: CLLocationCoordinate2D?
    var lastLoggedStreet: String = ""
    var lastLoggedIcon: String = "figure.walk"

    @Presents var sheet: MapSheetFeature.State?

    var isLocationAuthorized: Bool {
      authorizationStatus == .authorizedWhenInUse || authorizationStatus == .authorizedAlways
    }
  }

  enum Action: Equatable {
    case onAppear
    case requestLocation
    case recenterTapped
    case delegate(Delegate)
    case locationManager(LocationManagerAction)

    case searchTapped
    case selectPerson(Person)

    case startAlwaysHomeNavigation
    case startDirectNavigation(destinationQuery: String)
    case directNavigationReady(destination: SavedPlace, destCoord: CLLocationCoordinate2D, originCoord: CLLocationCoordinate2D, originAddress: String, routeInfo: WalkingRouteInfo)

    case updateTrackingLocation(CLLocationCoordinate2D)

    case sheet(PresentationAction<MapSheetFeature.Action>)

    enum Delegate: Equatable {
      case locationUpdated(CLLocationCoordinate2D)
    }

    enum LocationManagerAction: Equatable {
      case didChangeAuthorization(CLAuthorizationStatus)
      case didUpdateLocation(CLLocationCoordinate2D)
      case didFailWithError(String)
    }
  }

  @Dependency(\.locationManager) var locationManager
  @Dependency(\.directionRoute) var directionRoute
  @Dependency(\.uuid) var uuid
  @Dependency(\.date.now) var now

  var body: some Reducer<State, Action> {
    Reduce { state, action in
      switch action {
      case .onAppear:
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
          return .merge(
            .send(.delegate(.locationUpdated(coordinate))),
            .send(.updateTrackingLocation(coordinate))
          )
        }
        return .send(.delegate(.locationUpdated(coordinate)))

      case .locationManager(.didFailWithError):
        return .none

      case .searchTapped:
        state.sheet = .search(MapSearchSheetFeature.State(userLocation: state.currentLocation))
        return .none

      case let .selectPerson(person):
        state.sheet = .walker(MapWalkerSheetFeature.State(walker: person, status: person.status))
        return .none

      case .startAlwaysHomeNavigation:
        let homePlace = MapSampleData.savedPlaces.first(where: {
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

        let targetQuery: String
        if lowerQuery == "office" || lowerQuery == "work" {
          targetQuery = "Autograph Tower"
        } else {
          targetQuery = cleanQuery
        }

        let matchedPlace = MapSampleData.allSearchablePlaces.first(where: {
          $0.name.caseInsensitiveCompare(targetQuery) == .orderedSame ||
          $0.name.localizedCaseInsensitiveContains(targetQuery)
        }) ?? MapSampleData.savedPlaces.first(where: {
          $0.name.caseInsensitiveCompare(targetQuery) == .orderedSame
        }) ?? SavedPlace(
          name: targetQuery,
          subtitle: "Jakarta, Indonesia",
          iconName: "mappin.and.ellipse"
        )

        state.isFollowingUser = true
        state.isNavigating = true

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

        return .run { [matchedPlace] send in
          let originCoord = await locationManager.getCurrentLocation()
            ?? CLLocationCoordinate2D(latitude: -6.2088, longitude: 106.8456)

          async let originAddress = directionRoute.reverseGeocode(coordinate: originCoord)

          var destCoord = matchedPlace.coordinate
          if destCoord == nil {
            let query: String
            let lowerName = matchedPlace.name.lowercased()
            if lowerName == "office" || lowerName == "work" || lowerName.contains("autograph") {
              query = "Autograph Tower, Thamrin Nine, Central Jakarta"
            } else if lowerName == "home" {
              query = "Bendungan Hilir, Central Jakarta"
            } else if lowerName == "gym" || lowerName.contains("agora") {
              query = "Agora Mall, Thamrin Nine, Central Jakarta"
            } else {
              query = "\(matchedPlace.name) \(matchedPlace.subtitle)"
            }

            let searchReq = MKLocalSearch.Request()
            searchReq.naturalLanguageQuery = query
            if let resp = try? await MKLocalSearch(request: searchReq).start(),
               let firstItem = resp.mapItems.first {
              destCoord = firstItem.placemark.coordinate
            } else {
              destCoord = CLLocationCoordinate2D(latitude: -6.1991, longitude: 106.8212)
            }
          }
          let resolvedDest = destCoord ?? CLLocationCoordinate2D(latitude: -6.1991, longitude: 106.8212)

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
        state.activeRoute = nil
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
          coordinate: destCoord
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
          activeRoute: nil,
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
         if let currentLoc = state.currentLocation {
            return .send(.sheet(.presented(.direction(.onAppear(currentLocation: currentLoc)))))
         }
         return .none

      case let .sheet(.presented(.direction(.delegate(delegateAction)))):
         switch delegateAction {
         case let .routeChanged(route):
            state.activeRoute = route
            return .none
         case .navigationStarted:
            state.isNavigating = true
            state.activeRoute = nil // clear polyline
            state.lastLoggedCoordinate = state.sheet?.direction?.journeyLogEntries.last?.coordinate ?? state.currentLocation
            state.lastLoggedStreet = "Current Area"
            state.lastLoggedIcon = "figure.walk"
            return .none
         case .navigationEnded:
            state.isNavigating = false
            state.activeRoute = nil
            state.sheet = nil
            return .none
         }

      case .sheet(.presented(.walker(.delegate(.dismissed)))):
         state.sheet = nil
         return .none

      case .sheet, .delegate:
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
