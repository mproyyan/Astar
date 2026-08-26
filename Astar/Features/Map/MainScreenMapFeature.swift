//
//  MainScreenMapFeature.swift
//  Astar
//
//  Created by Muhammad Pandu Royyan on 24/08/26.
//

import Combine
import ComposableArchitecture
import CoreLocation
import Foundation

@Reducer
struct MainScreenMapFeature {
  @ObservableState
  struct State: Equatable {
    var authorizationStatus: CLAuthorizationStatus = .notDetermined
    var currentLocation: CLLocationCoordinate2D?
    var isFollowingUser: Bool = true

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
        return .send(.delegate(.locationUpdated(coordinate)))

      case .locationManager(.didFailWithError):
        return .none

      case .delegate:
        return .none
      }
    }
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

// Equatable support for CLLocationCoordinate2D
extension CLLocationCoordinate2D: @retroactive Equatable {
  public static func == (lhs: CLLocationCoordinate2D, rhs: CLLocationCoordinate2D) -> Bool {
    lhs.latitude == rhs.latitude && lhs.longitude == rhs.longitude
  }
}
