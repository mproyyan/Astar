/// ============================================================================
/// 📍 HARDWARE SENSOR ABSTRACTION & ACTOR ISOLATION (LocationManagerClient)
/// ============================================================================
///
/// 💡 COMPUTER SCIENCE CONCEPTS:
/// - **Hardware Abstraction Layer (HAL)**:
///   Wraps Apple's imperative, callback-heavy `CLLocationManager` behind a modern,
///   clean async/await interface (`AsyncStream`), shielding features from low-level OS quirks.
/// - **Actor Concurrency Model & Thread Confinement**:
///   `LocationManagerActor` enforces `@MainActor` thread-affinity. In computer systems, GPS
///   hardware delegate interrupts must be safely marshaled to the UI thread to prevent race
///   conditions and shared memory corruption.
/// - **Continuation-based Stream Bridge**:
///   Translates legacy delegate callbacks (`didUpdateLocations`) into an asynchronous stream
///   (`AsyncStream.Continuation.yield`), allowing consumers to consume GPS updates using standard
///   `for await coordinate in client.locationUpdates()` loops (just like Python's `async for`).
///
/// 🌍 REAL-LIFE ANALOGY:
///   Think of a water meter outside your house. Instead of you running out every second to read the
///   dials (busy polling), the meter has a digital wire (HAL) that beeps an internal buzzer
///   whenever fresh water flows (reactive stream). The actor is the master switchboard inside the
///   house ensuring only one person reads or turns off the valve at a time.
/// ============================================================================
import Foundation
import CoreLocation
import ComposableArchitecture

@DependencyClient
struct LocationManagerClient {
  var authorizationStatus: () async -> AsyncStream<CLAuthorizationStatus> = { .finished }
  var requestWhenInUseAuthorization: () async -> Void = { }
  var requestLocation: () async -> Void = { }
  var locationUpdates: () async -> AsyncStream<CLLocationCoordinate2D> = { .finished }
  var errorUpdates: () async -> AsyncStream<Error> = { .finished }
  var getCurrentLocation: () async -> CLLocationCoordinate2D? = { nil }
}

extension LocationManagerClient: DependencyKey {
  static let liveValue = Self.live()
  static let testValue = Self(
    authorizationStatus: { .finished },
    requestWhenInUseAuthorization: { },
    requestLocation: { },
    locationUpdates: { .finished },
    errorUpdates: { .finished },
    getCurrentLocation: { nil }
  )

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
      },
      getCurrentLocation: {
        await managerActor.getCurrentLocation()
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
final class LocationManagerActor: NSObject, CLLocationManagerDelegate {
  private let manager = CLLocationManager()
  private var authorizationContinuation: AsyncStream<CLAuthorizationStatus>.Continuation?
  private var locationContinuation: AsyncStream<CLLocationCoordinate2D>.Continuation?
  private var errorContinuation: AsyncStream<Error>.Continuation?

  override init() {
    super.init()
    manager.delegate = self
    manager.desiredAccuracy = kCLLocationAccuracyBest
    manager.distanceFilter = kCLDistanceFilterNone
    manager.allowsBackgroundLocationUpdates = true
    manager.showsBackgroundLocationIndicator = true
    manager.pausesLocationUpdatesAutomatically = false
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

  func getCurrentLocation() async -> CLLocationCoordinate2D? {
    if let location = self.manager.location?.coordinate {
      return location
    }
    requestLocation()
    for await coordinate in locationStream() {
      return coordinate
    }
    return nil
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
