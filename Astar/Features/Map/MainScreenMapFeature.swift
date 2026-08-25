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
  }

  enum Action: Equatable {
    case onAppear
    case requestLocation
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
        return .run { send in
          for await status in await locationManager.authorizationStatus() {
            await send(.locationManager(.didChangeAuthorization(status)))
          }
        }
        .merge(with: .run { send in
          for await location in await locationManager.locationUpdates() {
            await send(.locationManager(.didUpdateLocation(location)))
          }
        })
        .merge(with: .run { send in
          for await error in await locationManager.errorUpdates() {
            await send(.locationManager(.didFailWithError(error.localizedDescription)))
          }
        })

      case .requestLocation:
        return .run { [status = state.authorizationStatus] _ in
          switch status {
          case .notDetermined:
            await locationManager.requestWhenInUseAuthorization()
          case .authorizedAlways, .authorizedWhenInUse:
            await locationManager.requestLocation()
          default:
            break
          }
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
    let locationDelegate = LocationDelegate()
    let manager = CLLocationManager()
    manager.delegate = locationDelegate
    manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
    manager.distanceFilter = 25
    
    return Self(
      authorizationStatus: {
        AsyncStream { continuation in
          continuation.yield(manager.authorizationStatus)
          locationDelegate.onAuthorizationChange = { status in
            continuation.yield(status)
          }
        }
      },
      requestWhenInUseAuthorization: { manager.requestWhenInUseAuthorization() },
      requestLocation: { 
        manager.requestLocation()
        manager.startUpdatingLocation()
      },
      locationUpdates: {
        AsyncStream { continuation in
          locationDelegate.onLocationUpdate = { location in
            continuation.yield(location)
          }
        }
      },
      errorUpdates: {
        AsyncStream { continuation in
          locationDelegate.onError = { error in
            continuation.yield(error)
          }
        }
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

private final class LocationDelegate: NSObject, CLLocationManagerDelegate {
  var onAuthorizationChange: ((CLAuthorizationStatus) -> Void)?
  var onLocationUpdate: ((CLLocationCoordinate2D) -> Void)?
  var onError: ((Error) -> Void)?

  func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
    onAuthorizationChange?(manager.authorizationStatus)
  }

  func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
    guard let location = locations.last else { return }
    onLocationUpdate?(location.coordinate)
  }

  func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
    onError?(error)
  }
}

// Equatable support for CLLocationCoordinate2D
extension CLLocationCoordinate2D: Equatable {
  public static func == (lhs: CLLocationCoordinate2D, rhs: CLLocationCoordinate2D) -> Bool {
    lhs.latitude == rhs.latitude && lhs.longitude == rhs.longitude
  }
}
