//
//  MainScreenMapFeature.swift
//  Astar
//
//  Created by Muhammad Pandu Royyan on 24/08/26.
//

import CloudKit
import Combine
import ComposableArchitecture
import CoreLocation
import Foundation
import MapKit
import SwiftUI

@Reducer
struct MainScreenMapFeature {
  enum DirectionSheetMode: Equatable, Sendable {
    case directions
    case progress
    case journeyLog
  }

  @ObservableState
  struct State: Equatable {
    // Location & Authorization
    var authorizationStatus: CLAuthorizationStatus = .notDetermined
    var currentLocation: CLLocationCoordinate2D?
    var isFollowingUser: Bool = true

    // Search
    var isSearching: Bool = false
    var searchQuery: String = ""
    var searchResults: [SavedPlace] = []
    var isSearchLoading: Bool = false

    // Direction & Route
    var selectedDestination: SavedPlace?
    var originPlace: SavedPlace?
    var activeRoute: MKRoute?
    var walkingRouteInfo: WalkingRouteInfo?
    var isCalculatingRoute: Bool = false
    var directionMode: DirectionSheetMode = .directions

    // Live Journey Tracking
    var isNavigating: Bool = false
    var isDestinationReached: Bool = false
    var journeyLogEntries: [JourneyLogEntry] = []
    var lastLoggedCoordinate: CLLocationCoordinate2D?
    var lastLoggedStreet: String = ""
    var lastLoggedIcon: String = "figure.walk"

    // Guardian / Walker
    var selectedWalker: Person?
    var isWalkerDestinationReached: Bool = false
    var isViewingHistoryList: Bool = false
    var selectedHistoryTrip: WalkerHistoryTrip?

    // People (CloudKit public DB)
    var people: [Person] = []
    var companions: [Person] = []
    var currentUser: Person?
    var isPeopleLoading: Bool = false

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

    // Search Actions
    case searchTapped
    case searchQueryChanged(String)
    case searchResponse([SavedPlace])
    case clearSearchTapped

    // Direction Actions
    case selectPlace(SavedPlace)
    case routeCalculated(WalkingRouteInfo)
    case originResolved(SavedPlace)
    case startNavigationTapped
    case endJourneyTapped
    case cancelDirectionsTapped
    case journeyLogTapped
    case dismissJourneyLogTapped

    // Tracking Actions
    case updateTrackingLocation(CLLocationCoordinate2D)
    case newMilestoneDetected(passedEntry: JourneyLogEntry, currentEntry: JourneyLogEntry, coord: CLLocationCoordinate2D, street: String, icon: String)
    case destinationReached(finalEntry: JourneyLogEntry)

    // Walker Actions
    case selectPerson(Person)
    case dismissWalker
    case viewAllHistoryTapped
    case selectHistoryTrip(WalkerHistoryTrip)
    case dismissHistoryDetail
    case dismissHistoryList
    case exitTrackTapped
    case reachDestinationTapped

    // People CloudKit Actions
    case loadPeople
    case peopleLoaded([Person])
    case currentUserLoaded(Person)
    case companionsLoaded([Person])
    case becomeCompanionTapped(walkerRecordID: CKRecord.ID)
    case stopCompanionTapped
    case peopleError(String)

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
  @Dependency(\.placeSearch) var placeSearch
  @Dependency(\.directionRoute) var directionRoute
  @Dependency(\.cloudKitPeople) var cloudKitPeople
  @Dependency(\.continuousClock) var clock

  var body: some Reducer<State, Action> {
    Reduce { state, action in
      switch action {
      case .onAppear:
        return .merge(
          .send(.requestLocation),
          .send(.loadPeople),
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

      // MARK: - Search Logic
      case .searchTapped:
        state.isSearching = true
        state.searchResults = []
        return .none

      case let .searchQueryChanged(query):
        state.searchQuery = query
        let cleanQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanQuery.isEmpty else {
          state.searchResults = []
          state.isSearchLoading = false
          return .cancel(id: "searchDebounce")
        }

        state.isSearchLoading = true
        let userLocation = state.currentLocation

        return .run { send in
          try await clock.sleep(for: .milliseconds(300))
          let results = await placeSearch.searchPlaces(cleanQuery, userLocation)
          await send(.searchResponse(results))
        }
        .cancellable(id: "searchDebounce", cancelInFlight: true)

      case let .searchResponse(results):
        state.isSearchLoading = false
        state.searchResults = results
        return .none

      case .clearSearchTapped:
        state.searchQuery = ""
        state.searchResults = []
        state.isSearchLoading = false
        state.isSearching = false
        return .cancel(id: "searchDebounce")

      // MARK: - Direction Logic
      case let .selectPlace(place):
        state.isSearching = false
        state.searchQuery = ""
        state.searchResults = []
        state.selectedDestination = place
        state.directionMode = .directions
        state.isCalculatingRoute = true
        state.isNavigating = false
        state.isDestinationReached = false

        let originCoord = state.currentLocation ?? CLLocationCoordinate2D(latitude: -6.2088, longitude: 106.8456)
        state.originPlace = SavedPlace(
          name: "Current Location",
          subtitle: "Locating current area...",
          iconName: "location.fill",
          coordinate: originCoord
        )

        return .run { [place] send in
          // 1. Reverse geocode origin
          async let originAddress = directionRoute.reverseGeocode(originCoord)

          // 2. Resolve destination coordinate if nil
          var destCoord = place.coordinate
          if destCoord == nil {
            let searchReq = MKLocalSearch.Request()
            searchReq.naturalLanguageQuery = "\(place.name) \(place.subtitle)"
            if let resp = try? await MKLocalSearch(request: searchReq).start(),
               let firstItem = resp.mapItems.first {
              destCoord = firstItem.placemark.coordinate
            } else {
              destCoord = CLLocationCoordinate2D(latitude: -6.2088, longitude: 106.8456)
            }
          }
          let resolvedDest = destCoord ?? CLLocationCoordinate2D(latitude: -6.2088, longitude: 106.8456)

          // 3. Calculate walking route
          async let routeInfo = directionRoute.calculateWalkingRoute(originCoord, resolvedDest)

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
        return .none

      case .startNavigationTapped:
        guard state.selectedDestination != nil else { return .none }
        state.isNavigating = true
        state.isDestinationReached = false
        state.activeRoute = nil // Dismiss preview polyline on start
        state.directionMode = .progress

        let originCoord = state.currentLocation ?? CLLocationCoordinate2D(latitude: -6.2088, longitude: 106.8456)
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

        // Strictly real points only (No predictions!)
        state.journeyLogEntries = [currentEntry, startEntry]
        state.lastLoggedCoordinate = originCoord
        state.lastLoggedStreet = streetName
        state.lastLoggedIcon = "figure.walk"

        // Sync status to CloudKit public DB
        guard let userRecordID = state.currentUser?.recordID,
              let destination = state.selectedDestination
        else { return .none }

        return .run { [userRecordID, destination] send in
          do {
            try await cloudKitPeople.startJourney(userRecordID, destination)
            let updatedPeople = try await cloudKitPeople.fetchAllPeople()
            await send(.peopleLoaded(updatedPeople))
          } catch {
            await send(.peopleError(error.localizedDescription))
          }
        }

      case .endJourneyTapped, .cancelDirectionsTapped:
        let userRecordID = state.currentUser?.recordID
        state.selectedDestination = nil
        state.activeRoute = nil
        state.walkingRouteInfo = nil
        state.originPlace = nil
        state.directionMode = .directions
        state.isNavigating = false
        state.isDestinationReached = false
        state.journeyLogEntries = []
        state.lastLoggedCoordinate = nil
        state.lastLoggedStreet = ""
        state.lastLoggedIcon = "figure.walk"

        guard let recordID = userRecordID else { return .none }
        return .run { [recordID] send in
          do {
            try await cloudKitPeople.endJourney(recordID)
            let updatedPeople = try await cloudKitPeople.fetchAllPeople()
            await send(.peopleLoaded(updatedPeople))
            await send(.companionsLoaded([]))
          } catch {
            await send(.peopleError(error.localizedDescription))
          }
        }

      case .journeyLogTapped:
        state.directionMode = .journeyLog
        return .none

      case .dismissJourneyLogTapped:
        state.directionMode = .progress
        return .none

      // MARK: - Live Tracking Logic
      case let .updateTrackingLocation(newCoord):
        guard state.isNavigating, !state.isDestinationReached, let destination = state.selectedDestination else {
          return .none
        }

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
            return .send(.destinationReached(finalEntry: destEntry))
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

              await send(.newMilestoneDetected(
                passedEntry: passedEntry,
                currentEntry: currentEntry,
                coord: newCoord,
                street: landmarkInfo.name,
                icon: landmarkInfo.icon
              ))
            }
          }
        }
        return .none

      case let .newMilestoneDetected(passedEntry, currentEntry, coord, street, icon):
        state.lastLoggedCoordinate = coord
        state.lastLoggedStreet = street
        state.lastLoggedIcon = icon

        // Remove previous live current location
        state.journeyLogEntries.removeAll(where: { $0.entryType == .currentLocation })
        // Insert passed checkpoint into history
        state.journeyLogEntries.insert(passedEntry, at: 0)
        // Add new live current location at the top
        state.journeyLogEntries.insert(currentEntry, at: 0)
        return .none

      case let .destinationReached(finalEntry):
        state.isDestinationReached = true
        state.journeyLogEntries.removeAll(where: { $0.entryType == .currentLocation })
        state.journeyLogEntries.insert(finalEntry, at: 0)
        return .none

      // MARK: - Walker Actions
      case let .selectPerson(person):
        state.selectedWalker = person
        state.isWalkerDestinationReached = false
        state.isViewingHistoryList = false
        state.selectedHistoryTrip = nil
        return .none

      case .dismissWalker:
        state.selectedWalker = nil
        state.isWalkerDestinationReached = false
        state.isViewingHistoryList = false
        state.selectedHistoryTrip = nil
        return .none

      case .viewAllHistoryTapped:
        state.isViewingHistoryList = true
        return .none

      case let .selectHistoryTrip(trip):
        state.selectedHistoryTrip = trip
        return .none

      case .dismissHistoryDetail:
        state.selectedHistoryTrip = nil
        return .none

      case .dismissHistoryList:
        state.isViewingHistoryList = false
        return .none

      case .exitTrackTapped, .reachDestinationTapped:
        state.isWalkerDestinationReached = true
        return .none

      // MARK: - People CloudKit Logic

      case .loadPeople:
        state.isPeopleLoading = true
        return .run { send in
          do {
            let people = try await cloudKitPeople.fetchAllPeople()
            await send(.peopleLoaded(people))
          } catch {
            await send(.peopleError(error.localizedDescription))
          }
        }

      case let .peopleLoaded(people):
        state.isPeopleLoading = false
        state.people = people
        return .none

      case let .currentUserLoaded(user):
        state.currentUser = user
        // Refresh companions if user is already walking
        guard let recordID = user.recordID,
              user.personStatus == .walking
        else { return .none }
        return .run { [recordID] send in
          do {
            let companions = try await cloudKitPeople.fetchCompanions(recordID)
            await send(.companionsLoaded(companions))
          } catch {
            await send(.peopleError(error.localizedDescription))
          }
        }

      case let .companionsLoaded(companions):
        state.companions = companions
        return .none

      case let .becomeCompanionTapped(walkerRecordID):
        guard let myRecordID = state.currentUser?.recordID else { return .none }
        return .run { [myRecordID, walkerRecordID] send in
          do {
            try await cloudKitPeople.becomeCompanion(myRecordID, walkerRecordID)
            let updatedPeople = try await cloudKitPeople.fetchAllPeople()
            await send(.peopleLoaded(updatedPeople))
            let companions = try await cloudKitPeople.fetchCompanions(walkerRecordID)
            await send(.companionsLoaded(companions))
          } catch {
            await send(.peopleError(error.localizedDescription))
          }
        }

      case .stopCompanionTapped:
        guard let myRecordID = state.currentUser?.recordID else { return .none }
        return .run { [myRecordID] send in
          do {
            try await cloudKitPeople.stopCompanion(myRecordID)
            let updatedPeople = try await cloudKitPeople.fetchAllPeople()
            await send(.peopleLoaded(updatedPeople))
            await send(.companionsLoaded([]))
          } catch {
            await send(.peopleError(error.localizedDescription))
          }
        }

      case let .peopleError(message):
        state.isPeopleLoading = false
        // Log error; in production, surface to user if needed
        print("[CloudKitPeople] Error: \(message)")
        return .none

      case .delegate:
        return .none
      }
    }
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

// MARK: - LocationManager Client

@DependencyClient
struct LocationManagerClient {
  var authorizationStatus: () async -> AsyncStream<CLAuthorizationStatus> = { .finished }
  var requestWhenInUseAuthorization: () async -> Void
  var requestLocation: () async -> Void
  var locationUpdates: () async -> AsyncStream<CLLocationCoordinate2D> = { .finished }
  var errorUpdates: () async -> AsyncStream<Error> = { .finished }
}

extension LocationManagerClient: DependencyKey {
  static let liveValue = Self.live()

  static func live() -> Self {
    let managerActor = LocationManagerActor()

    return Self(
      authorizationStatus: {
        await MainActor.run { managerActor.authorizationStream() }
      },
      requestWhenInUseAuthorization: {
        await MainActor.run { managerActor.requestWhenInUseAuthorization() }
      },
      requestLocation: {
        await MainActor.run { managerActor.requestLocation() }
      },
      locationUpdates: {
        await MainActor.run { managerActor.locationStream() }
      },
      errorUpdates: {
        await MainActor.run { managerActor.errorStream() }
      }
    )
  }
}

extension DependencyValues {
  var locationManager: LocationManagerClient {
    get { self[LocationManagerClient.self] }
    set { self[LocationManagerClient.self] = newValue }
  }
}

@MainActor
private final class LocationManagerActor: NSObject, CLLocationManagerDelegate {
  private let manager = CLLocationManager()
  private var authorizationContinuation: AsyncStream<CLAuthorizationStatus>.Continuation?
  private var locationContinuation: AsyncStream<CLLocationCoordinate2D>.Continuation?
  private var errorContinuation: AsyncStream<Error>.Continuation?

  override init() {
    super.init()
    manager.delegate = self
    manager.desiredAccuracy = kCLLocationAccuracyBest
    manager.distanceFilter = 10
  }

  func authorizationStream() -> AsyncStream<CLAuthorizationStatus> {
    AsyncStream { continuation in
      self.authorizationContinuation = continuation
      continuation.yield(self.manager.authorizationStatus)
    }
  }

  func locationStream() -> AsyncStream<CLLocationCoordinate2D> {
    AsyncStream { continuation in
      self.locationContinuation = continuation
      if let location = self.manager.location {
        continuation.yield(location.coordinate)
      }
    }
  }

  func errorStream() -> AsyncStream<Error> {
    AsyncStream { continuation in
      self.errorContinuation = continuation
    }
  }

  func requestWhenInUseAuthorization() {
    if manager.authorizationStatus == .notDetermined {
      manager.requestWhenInUseAuthorization()
    }
  }

  func requestLocation() {
    let status = manager.authorizationStatus
    if status == .notDetermined {
      manager.requestWhenInUseAuthorization()
    } else if status == .authorizedWhenInUse || status == .authorizedAlways {
      manager.requestLocation()
      manager.startUpdatingLocation()
    }
  }

  func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
    authorizationContinuation?.yield(manager.authorizationStatus)
    if manager.authorizationStatus == .authorizedWhenInUse || manager.authorizationStatus == .authorizedAlways {
      manager.requestLocation()
      manager.startUpdatingLocation()
    }
  }

  func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
    guard let location = locations.last else { return }
    locationContinuation?.yield(location.coordinate)
  }

  func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
    errorContinuation?.yield(error)
  }
}

// MARK: - PlaceSearch Client

@DependencyClient
struct PlaceSearchClient: Sendable {
  var searchPlaces: @Sendable (_ query: String, _ userLocation: CLLocationCoordinate2D?) async -> [SavedPlace] = { _, _ in [] }
}

extension PlaceSearchClient: DependencyKey {
  static let liveValue = Self(
    searchPlaces: { query, userLocation in
      await PlaceSearchEngine.searchPlaces(query: query, userLocation: userLocation)
    }
  )
  static let testValue = Self()
}

extension DependencyValues {
  var placeSearch: PlaceSearchClient {
    get { self[PlaceSearchClient.self] }
    set { self[PlaceSearchClient.self] = newValue }
  }
}

@MainActor
enum PlaceSearchEngine {
  private struct ScoredPlace {
    let place: SavedPlace
    let score: Double
    let distanceMeters: Double
  }

  static func searchPlaces(
    query: String,
    userLocation: CLLocationCoordinate2D?
  ) async -> [SavedPlace] {
    let cleanQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !cleanQuery.isEmpty else { return [] }

    let center = userLocation ?? CLLocationCoordinate2D(latitude: -6.2088, longitude: 106.8456)
    let searchRegion = MKCoordinateRegion(
      center: center,
      span: MKCoordinateSpan(latitudeDelta: 0.5, longitudeDelta: 0.5)
    )

    var liveResults: [SavedPlace] = []
    var seenKeys = Set<String>()

    // 1. Direct MKLocalSearch
    let searchRequest = MKLocalSearch.Request()
    searchRequest.naturalLanguageQuery = cleanQuery
    searchRequest.resultTypes = [.pointOfInterest, .address]
    searchRequest.region = searchRegion

    if let directResponse = try? await MKLocalSearch(request: searchRequest).start() {
      for item in directResponse.mapItems {
        if let place = convertMapItemToSavedPlace(item: item, userLocation: userLocation, cleanQuery: cleanQuery) {
          let dedupKey = "\(place.name.lowercased())_\(place.subtitle.lowercased())"
          if !seenKeys.contains(dedupKey) {
            seenKeys.insert(dedupKey)
            liveResults.append(place)
          }
        }
      }
    }

    // 2. Fetch completions from MKLocalSearchCompleter for street/address matches
    let completer = SearchCompleterEngine()
    let completions = await completer.getCompletions(query: cleanQuery, region: searchRegion)

    await withTaskGroup(of: SavedPlace?.self) { group in
      for completion in completions.prefix(12) {
        group.addTask { @MainActor in
          let compRequest = MKLocalSearch.Request(completion: completion)
          compRequest.resultTypes = [.pointOfInterest, .address]
          compRequest.region = searchRegion

          if let compResponse = try? await MKLocalSearch(request: compRequest).start(),
             let firstItem = compResponse.mapItems.first {
            return convertMapItemToSavedPlace(item: firstItem, userLocation: userLocation, cleanQuery: completion.title)
          }

          let icon = completion.subtitle.localizedCaseInsensitiveContains("station") ? "tram.fill" :
                     completion.subtitle.localizedCaseInsensitiveContains("restaurant") || completion.subtitle.localizedCaseInsensitiveContains("food") ? "fork.knife" :
                     completion.subtitle.localizedCaseInsensitiveContains("mall") || completion.subtitle.localizedCaseInsensitiveContains("shop") ? "bag.fill" : "mappin.and.ellipse"

          return SavedPlace(
            name: completion.title,
            subtitle: completion.subtitle.isEmpty ? "Jakarta, Indonesia" : completion.subtitle,
            iconName: icon,
            distance: nil,
            coordinate: nil
          )
        }
      }

      for await maybePlace in group {
        if let place = maybePlace {
          let dedupKey = "\(place.name.lowercased())_\(place.subtitle.lowercased())"
          if !seenKeys.contains(dedupKey) {
            seenKeys.insert(dedupKey)
            liveResults.append(place)
          }
        }
      }
    }

    // 3. Merge with local searchable places
    let localMatches = fallbackSearch(query: cleanQuery, userLocation: userLocation)
    for local in localMatches {
      let dedupKey = "\(local.name.lowercased())_\(local.subtitle.lowercased())"
      if !seenKeys.contains(dedupKey) {
        seenKeys.insert(dedupKey)
        liveResults.append(local)
      }
    }

    return rankResults(places: liveResults, query: cleanQuery, userLocation: userLocation)
  }

  private static func convertMapItemToSavedPlace(
    item: MKMapItem,
    userLocation: CLLocationCoordinate2D?,
    cleanQuery: String
  ) -> SavedPlace? {
    let placemark = item.placemark
    let name = item.name ?? placemark.name ?? cleanQuery

    let addressParts = [
      placemark.subThoroughfare,
      placemark.thoroughfare,
      placemark.subLocality,
      placemark.locality,
      placemark.administrativeArea
    ].compactMap { $0 }.filter { !$0.isEmpty }

    let subtitle: String
    if !addressParts.isEmpty {
      subtitle = addressParts.joined(separator: ", ")
    } else if let title = placemark.title, title != name {
      subtitle = title
    } else {
      subtitle = placemark.country ?? "Unknown Location"
    }

    var distanceString: String? = nil
    if let userLocation {
      let userCL = CLLocation(latitude: userLocation.latitude, longitude: userLocation.longitude)
      let itemCL = CLLocation(latitude: placemark.coordinate.latitude, longitude: placemark.coordinate.longitude)
      let distanceMeters = userCL.distance(from: itemCL)

      if distanceMeters < 1000 {
        distanceString = "\(Int(distanceMeters)) m"
      } else {
        distanceString = String(format: "%.1f km", distanceMeters / 1000.0)
      }
    }

    let icon = categoryIcon(for: item.pointOfInterestCategory)

    return SavedPlace(
      name: name,
      subtitle: subtitle,
      iconName: icon,
      distance: distanceString,
      coordinate: placemark.coordinate
    )
  }

  private static func rankResults(
    places: [SavedPlace],
    query: String,
    userLocation: CLLocationCoordinate2D?
  ) -> [SavedPlace] {
    let lowerQuery = query.lowercased()
    let userCL = userLocation.map { CLLocation(latitude: $0.latitude, longitude: $0.longitude) }

    let scored = places.map { place -> ScoredPlace in
      let lowerName = place.name.lowercased()
      let lowerSubtitle = place.subtitle.lowercased()

      var score: Double = 0

      if lowerName == lowerQuery {
        score += 1000
      } else if lowerName.hasPrefix(lowerQuery) {
        score += 500
      } else if lowerName.contains(lowerQuery) {
        score += 250
      } else if lowerSubtitle.contains(lowerQuery) {
        score += 100
      } else {
        score += 10
      }

      var distMeters: Double = Double.infinity
      if let userCL, let coord = place.coordinate {
        let placeCL = CLLocation(latitude: coord.latitude, longitude: coord.longitude)
        distMeters = userCL.distance(from: placeCL)
        let proximityBonus = max(0.0, 150.0 - (distMeters / 100.0))
        score += proximityBonus
      }

      return ScoredPlace(place: place, score: score, distanceMeters: distMeters)
    }

    return scored
      .sorted { lhs, rhs in
        if abs(lhs.score - rhs.score) > 1.0 {
          return lhs.score > rhs.score
        }
        return lhs.distanceMeters < rhs.distanceMeters
      }
      .map(\.place)
  }

  private static func fallbackSearch(query: String, userLocation: CLLocationCoordinate2D?) -> [SavedPlace] {
    MapSampleData.allSearchablePlaces.filter {
      $0.name.localizedStandardContains(query) || $0.subtitle.localizedStandardContains(query)
    }
  }

  static func categoryIcon(for category: MKPointOfInterestCategory?) -> String {
    guard let category else { return "mappin.and.ellipse" }
    switch category {
    case .restaurant, .foodMarket:
      return "fork.knife"
    case .cafe, .bakery:
      return "cup.and.saucer.fill"
    case .store:
      return "bag.fill"
    case .fitnessCenter:
      return "figure.strengthtraining.traditional"
    case .publicTransport:
      return "tram.fill"
    case .airport:
      return "airplane"
    case .hotel:
      return "bed.double.fill"
    case .hospital, .pharmacy:
      return "cross.case.fill"
    case .park, .nationalPark:
      return "tree.fill"
    case .school, .university:
      return "graduationcap.fill"
    case .landmark:
      return "landmark.fill"
    case .nightlife:
      return "wineglass.fill"
    case .gasStation, .evCharger:
      return "fuelpump.fill"
    default:
      return "mappin.and.ellipse"
    }
  }
}

@MainActor
private final class SearchCompleterEngine: NSObject, MKLocalSearchCompleterDelegate {
  private let completer = MKLocalSearchCompleter()
  private var continuation: CheckedContinuation<[MKLocalSearchCompletion], Never>?

  override init() {
    super.init()
    completer.delegate = self
    completer.resultTypes = [.address, .pointOfInterest]
  }

  func getCompletions(query: String, region: MKCoordinateRegion) async -> [MKLocalSearchCompletion] {
    completer.region = region
    completer.queryFragment = query

    return await withCheckedContinuation { continuation in
      self.continuation = continuation
      Task { @MainActor in
        try? await Task.sleep(for: .milliseconds(800))
        if let cont = self.continuation {
          self.continuation = nil
          cont.resume(returning: self.completer.results)
        }
      }
    }
  }

  func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
    if let cont = continuation {
      continuation = nil
      cont.resume(returning: completer.results)
    }
  }

  func completer(_ completer: MKLocalSearchCompleter, didFailWithError error: Error) {
    if let cont = continuation {
      continuation = nil
      cont.resume(returning: [])
    }
  }
}

// MARK: - DirectionRoute Client

struct WalkingRouteInfo: Equatable, Sendable {
  var travelTimeString: String
  var etaString: String
  var distanceString: String
  var rawTravelTime: TimeInterval
  var rawDistanceMeters: Double
  var route: MKRoute?
}

@DependencyClient
struct DirectionRouteClient: Sendable {
  var reverseGeocode: @Sendable (_ coordinate: CLLocationCoordinate2D) async -> String = { _ in "Current Location" }
  var calculateWalkingRoute: @Sendable (_ origin: CLLocationCoordinate2D, _ destination: CLLocationCoordinate2D) async -> WalkingRouteInfo = { _, _ in
    WalkingRouteInfo(travelTimeString: "12 min", etaString: "11.00 ETA", distanceString: "850 m", rawTravelTime: 720, rawDistanceMeters: 850)
  }
}

extension DirectionRouteClient: DependencyKey {
  static let liveValue = Self(
    reverseGeocode: { coordinate in
      await DirectionRouteEngine.reverseGeocode(coordinate: coordinate)
    },
    calculateWalkingRoute: { origin, destination in
      await DirectionRouteEngine.calculateWalkingRoute(from: origin, to: destination)
    }
  )
  static let testValue = Self()
}

extension DependencyValues {
  var directionRoute: DirectionRouteClient {
    get { self[DirectionRouteClient.self] }
    set { self[DirectionRouteClient.self] = newValue }
  }
}

@MainActor
private enum DirectionRouteEngine {
  static func reverseGeocode(coordinate: CLLocationCoordinate2D) async -> String {
    let geocoder = CLGeocoder()
    let location = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)

    do {
      let placemarks = try await geocoder.reverseGeocodeLocation(location)
      guard let placemark = placemarks.first else {
        return "Current Location"
      }
      let components = [
        placemark.thoroughfare ?? placemark.subThoroughfare,
        placemark.subLocality ?? placemark.locality,
        placemark.administrativeArea
      ].compactMap { $0 }.filter { !$0.isEmpty }

      return components.isEmpty ? (placemark.name ?? "Central Jakarta") : components.joined(separator: ", ")
    } catch {
      return "Central Jakarta, Indonesia"
    }
  }

  static func calculateWalkingRoute(
    from origin: CLLocationCoordinate2D,
    to destination: CLLocationCoordinate2D
  ) async -> WalkingRouteInfo {
    let request = MKDirections.Request()
    request.source = MKMapItem(placemark: MKPlacemark(coordinate: origin))
    request.destination = MKMapItem(placemark: MKPlacemark(coordinate: destination))
    request.transportType = .walking

    do {
      let directions = MKDirections(request: request)
      let response = try await directions.calculate()
      if let route = response.routes.first {
        return formatRouteInfo(
          travelTime: route.expectedTravelTime,
          distanceMeters: route.distance,
          route: route
        )
      }
    } catch {
      // Fallback
    }

    let originCL = CLLocation(latitude: origin.latitude, longitude: origin.longitude)
    let destCL = CLLocation(latitude: destination.latitude, longitude: destination.longitude)
    let dist = originCL.distance(from: destCL)
    let estTime = (dist * 1.25) / 1.25

    return formatRouteInfo(travelTime: estTime, distanceMeters: dist, route: nil)
  }

  private static func formatRouteInfo(
    travelTime: TimeInterval,
    distanceMeters: Double,
    route: MKRoute?
  ) -> WalkingRouteInfo {
    let minutes = Int(ceil(travelTime / 60.0))
    let timeString: String
    if minutes < 60 {
      timeString = "\(max(1, minutes)) min"
    } else {
      let hrs = minutes / 60
      let remMins = minutes % 60
      timeString = "\(hrs) hr\(hrs > 1 ? "s" : "") \(remMins) min"
    }

    let etaDate = Date().addingTimeInterval(travelTime)
    let formatter = DateFormatter()
    formatter.dateFormat = "HH.mm"
    let etaString = "\(formatter.string(from: etaDate)) ETA"

    let distanceString: String
    if distanceMeters < 1000 {
      distanceString = "\(Int(distanceMeters)) m"
    } else {
      distanceString = String(format: "%.1f km", distanceMeters / 1000.0)
    }

    return WalkingRouteInfo(
      travelTimeString: timeString,
      etaString: etaString,
      distanceString: distanceString,
      rawTravelTime: travelTime,
      rawDistanceMeters: distanceMeters,
      route: route
    )
  }
}

// Equatable support for CLLocationCoordinate2D
extension CLLocationCoordinate2D: @retroactive Equatable {
  public static func == (lhs: CLLocationCoordinate2D, rhs: CLLocationCoordinate2D) -> Bool {
    lhs.latitude == rhs.latitude && lhs.longitude == rhs.longitude
  }
}

// MARK: - CloudKitPeople Client

@DependencyClient
struct CloudKitPeopleClient: Sendable {
  var fetchAllPeople: @Sendable () async throws -> [Person] = { [] }
  var startJourney: @Sendable (
    _ personRecordID: CKRecord.ID,
    _ destination: SavedPlace
  ) async throws -> Void = { _, _ in }
  var endJourney: @Sendable (
    _ personRecordID: CKRecord.ID
  ) async throws -> Void = { _ in }
  var becomeCompanion: @Sendable (
    _ companionRecordID: CKRecord.ID,
    _ walkerRecordID: CKRecord.ID
  ) async throws -> Void = { _, _ in }
  var stopCompanion: @Sendable (
    _ companionRecordID: CKRecord.ID
  ) async throws -> Void = { _ in }
  var fetchCompanions: @Sendable (
    _ walkerRecordID: CKRecord.ID
  ) async throws -> [Person] = { _ in [] }
}

extension CloudKitPeopleClient: DependencyKey {
  static let liveValue = Self(
    fetchAllPeople: {
      try await CloudKitPeopleEngine.fetchAllPeople()
    },
    startJourney: { personRecordID, destination in
      try await CloudKitPeopleEngine.startJourney(
        personRecordID: personRecordID,
        destination: destination
      )
    },
    endJourney: { personRecordID in
      try await CloudKitPeopleEngine.endJourney(personRecordID: personRecordID)
    },
    becomeCompanion: { companionRecordID, walkerRecordID in
      try await CloudKitPeopleEngine.becomeCompanion(
        companionRecordID: companionRecordID,
        walkerRecordID: walkerRecordID
      )
    },
    stopCompanion: { companionRecordID in
      try await CloudKitPeopleEngine.stopCompanion(
        companionRecordID: companionRecordID
      )
    },
    fetchCompanions: { walkerRecordID in
      try await CloudKitPeopleEngine.fetchCompanions(walkerRecordID: walkerRecordID)
    }
  )

  static let testValue = Self()
}

extension DependencyValues {
  var cloudKitPeople: CloudKitPeopleClient {
    get { self[CloudKitPeopleClient.self] }
    set { self[CloudKitPeopleClient.self] = newValue }
  }
}
