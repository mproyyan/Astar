import Foundation
import CoreLocation
import MapKit
import ComposableArchitecture

// MARK: - WalkingRouteInfo
//
// A plain value type (struct) that carries all the information the UI needs
// to display a walking route — formatted strings for display, raw numbers for
// computation, and the optional map overlay.
//
// 🐍 Python analogy: think of this as a frozen dataclass —
//   @dataclasses.dataclass(frozen=True)
//   class WalkingRouteInfo: ...
//
// WHY a struct?
//   Swift structs are *value types*: each assignment creates a full copy, like
//   Python's immutable tuples. There is no shared mutable state and no aliasing
//   bugs. Classes are *reference types* (like Python objects) — they share state.
//   TCA strongly favors structs for state so that SwiftUI can efficiently diff
//   before/after values.
//
// Equatable — lets TCA's reducer compare "did state change?" without a custom
//   __eq__ method; the compiler generates field-by-field equality automatically.
//
// Sendable — marks the type as safe to pass across Swift concurrency boundaries
//   (actor boundaries, Task closures, etc.). In Python terms it's like saying
//   "this object is picklable / thread-safe to share".
struct WalkingRouteInfo: Equatable, Sendable {
  // Human-readable travel time, e.g. "12 min" or "1 hr 5 min".
  var travelTimeString: String

  // Formatted ETA clock string, e.g. "14.35 ETA".
  var etaString: String

  // Human-readable distance, e.g. "850 m" or "3.2 km".
  var distanceString: String

  // Raw travel time in seconds — used for calculations (e.g. sorting, ETA).
  var rawTravelTime: TimeInterval

  // Raw distance in metres — ditto.
  var rawDistanceMeters: Double

  // The actual MKRoute returned by Apple Maps (contains the real road polyline
  // and step-by-step directions). Optional because we might fall back to a
  // straight-line estimate if the network is unavailable.
  var route: MKRoute?

  // A straight-line MKPolyline used when no real route is available.
  // Only one of route or fallbackPolyline will be non-nil at a time.
  var fallbackPolyline: MKPolyline?

  // A computed property — like a Python @property.
  // Prefers the real route's polyline; falls back to the straight-line estimate.
  // The `??` operator is Swift's nil-coalescing (Python: `a or b`).
  var polyline: MKPolyline? {
    route?.polyline ?? fallbackPolyline
  }
}

// MARK: - DirectionRouteClient (TCA Dependency)
//
// @DependencyClient is a macro from the swift-dependencies library (part of TCA).
// It auto-generates:
//   • A memberwise initialiser where every closure has a default that crashes
//     with a clear message if called without being registered ("unimplemented").
//   • Conformance boilerplate for the dependency system.
//
// 🐍 Python analogy: think of @DependencyClient like abc.ABC — it defines an
//   *interface* (abstract base class) that lists capabilities without
//   implementing them. The live/test/preview values are concrete implementations.
//
// WHY closures instead of a protocol?
//   Closures make it trivial to swap implementations at call-site:
//     withDependencies { $0.directionRoute.reverseGeocode = { _ in "Mocked" } } operation: { ... }
//   This is the TCA pattern for dependency injection — similar to Python's
//   unittest.mock.patch but type-safe and composable.
//
// Sendable — the struct itself must be Sendable because TCA passes dependencies
//   across actor boundaries. Swift enforces that all stored closures are also
//   @Sendable (see below).
@DependencyClient
struct DirectionRouteClient: Sendable {
  // Converts a GPS coordinate into a human-readable address string.
  // `@Sendable` on the closure means it is safe to call from any concurrency
  // context (Task, actor method, etc.). Without @Sendable Swift would warn that
  // you might capture mutable state from one thread and use it on another.
  //
  // `async` means callers must `await` this — it suspends the current Task
  // (like Python's `await asyncio.coroutine()`), freeing the thread for other work.
  //
  // Default value: returns "Current Location" — the macro replaces this with a
  // crash-on-call stub, but we provide a sensible no-op for previews/tests.
  var reverseGeocode: @Sendable (_ coordinate: CLLocationCoordinate2D) async -> String = { _ in "Current Location" }

  // Computes walking route info between two GPS coordinates.
  // Returns a WalkingRouteInfo with formatted strings + optional MKRoute.
  // Default produces a hard-coded stub useful in SwiftUI Previews.
  var calculateWalkingRoute: @Sendable (_ origin: CLLocationCoordinate2D, _ destination: CLLocationCoordinate2D) async -> WalkingRouteInfo = { _, _ in
    WalkingRouteInfo(travelTimeString: "12 min", etaString: "11.00 ETA", distanceString: "850 m", rawTravelTime: 720, rawDistanceMeters: 850, route: nil, fallbackPolyline: nil)
  }
}

// MARK: - DependencyKey Conformance
//
// TCA's dependency system uses a key-value store. Every dependency type must
// declare:
//   • liveValue  — real implementation used in the running app.
//   • testValue  — safe stub used in unit tests (won't make network calls, etc.).
//   • previewValue (optional) — stub for SwiftUI Previews.
//
// This is the *Registry* pattern — identical to registering a service in a
// dependency-injection container (e.g. FastAPI's Depends, or a DI framework).
extension DirectionRouteClient: DependencyKey {
  // liveValue wires each closure to the actual engine implementation.
  // The closures are thin forwarders; all real logic lives in DirectionRouteEngine.
  static let liveValue = Self(
    reverseGeocode: { coordinate in
      await DirectionRouteEngine.reverseGeocode(coordinate: coordinate)
    },
    calculateWalkingRoute: { origin, destination in
      await DirectionRouteEngine.calculateWalkingRoute(from: origin, to: destination)
    }
  )

  // testValue uses the @DependencyClient-generated stubs (they crash if called
  // unexpectedly, making missing test setup easy to detect).
  static let testValue = Self()
}

// MARK: - DependencyValues Registration
//
// This extension adds a named accessor (`directionRoute`) to the global
// DependencyValues store. It's similar to adding a key to a Python dict-like
// singleton, but type-safe.
//
// Usage inside a TCA Reducer:
//   @Dependency(\.directionRoute) var directionRoute
extension DependencyValues {
  var directionRoute: DirectionRouteClient {
    get { self[DirectionRouteClient.self] }
    set { self[DirectionRouteClient.self] = newValue }
  }
}

// MARK: - DirectionRouteEngine (Implementation Detail)
//
// @MainActor — this annotation confines the entire enum to the *main actor*.
//
// 🐍 Python analogy for Actor model vs threading.Lock:
//   Python uses locks to protect shared state:
//     lock = threading.Lock()
//     with lock:
//         shared_data += 1
//   Swift Actors are a higher-level abstraction: the runtime ensures only ONE
//   piece of code runs inside an actor at a time, without you managing a lock
//   explicitly. Crossing an actor boundary requires `await`.
//
// @MainActor is a *global actor* — a singleton actor that is tied to the main
// thread. Apple's UI framework (UIKit/SwiftUI) and CoreLocation/MapKit APIs
// *must* be called from the main thread. Marking this enum @MainActor tells
// the Swift compiler to enforce that — any call from a background context will
// require an explicit `await MainActor.run { ... }`.
//
// WHY an enum with no cases?
//   Swift `enum` with only `static` members is a common pattern for a namespace
//   that cannot be instantiated — like a Python module or a class with only
//   @staticmethod members and a private __init__.
//
// `private` — the engine is an implementation detail; only liveValue should use it.
@MainActor
private enum DirectionRouteEngine {

  // MARK: reverseGeocode
  //
  // Converts a raw GPS coordinate (latitude/longitude) into a human-readable
  // address string using Apple's CLGeocoder API.
  //
  // `async` — CLGeocoder.reverseGeocodeLocation is a network call; `async` lets
  // the Swift runtime suspend this Task while waiting, like Python's
  //   result = await asyncio.get_event_loop().run_in_executor(None, geocoder.reverse)
  static func reverseGeocode(coordinate: CLLocationCoordinate2D) async -> String {
    let geocoder = CLGeocoder()
    let location = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)

    do {
      // `try await` — this can throw (network error) AND suspend (async).
      // Equivalent to Python's: placemarks = await geocoder.reverse(location)
      let placemarks = try await geocoder.reverseGeocodeLocation(location)

      // `guard let` — unwraps an Optional and exits the current scope if nil.
      // Python equivalent: if not placemarks: return "Current Location"
      guard let placemark = placemarks.first else {
        return "Current Location"
      }

      // Build an array of address components, skipping nil/empty parts.
      // `compactMap { $0 }` is like Python's filter(None, iterable).
      let components = [
        placemark.thoroughfare ?? placemark.subThoroughfare,
        placemark.subLocality ?? placemark.locality,
        placemark.administrativeArea
      ].compactMap { $0 }.filter { !$0.isEmpty }

      // Join available components, falling back to placemark name or a default.
      return components.isEmpty ? (placemark.name ?? "Central Jakarta") : components.joined(separator: ", ")
    } catch {
      // Network failure or API error — return a safe fallback string.
      return "Central Jakarta, Indonesia"
    }
  }

  // MARK: calculateWalkingRoute
  //
  // Attempts to compute a walking route between two coordinates with a three-tier
  // fallback strategy:
  //   1. Walking directions from Apple Maps (preferred — real footpaths).
  //   2. Automobile directions (used when walking route is unavailable, e.g.
  //      very long distances or highway-only roads; walking time is estimated).
  //   3. Straight-line distance (pure math, no network) as a last resort.
  //
  // This mirrors a common Python pattern:
  //   try:
  //       result = await maps_api.walking(origin, dest)
  //   except RoutingError:
  //       result = await maps_api.driving(origin, dest)
  //   if not result:
  //       result = haversine(origin, dest)
  static func calculateWalkingRoute(
    from origin: CLLocationCoordinate2D,
    to destination: CLLocationCoordinate2D
  ) async -> WalkingRouteInfo {

    // ── Tier 1: Walking Directions ────────────────────────────────────────────
    // Build an MKDirections request for walking transport.
    // MKMapItem wraps a coordinate + placemark for Apple Maps routing.
    let request = MKDirections.Request()
    request.source = MKMapItem(placemark: MKPlacemark(coordinate: origin))
    request.destination = MKMapItem(placemark: MKPlacemark(coordinate: destination))
    request.transportType = .walking

    // `try?` converts a thrown error into nil — we handle failure by trying the
    // next tier, so we don't need the error details here.
    if let directions = try? await MKDirections(request: request).calculate(),
       let route = directions.routes.first {
      return formatRouteInfo(
        travelTime: route.expectedTravelTime,
        distanceMeters: route.distance,
        route: route
      )
    }

    // ── Tier 2: Automobile Directions (Walking time estimated) ────────────────
    // Walking routes fail for very long distances (>~10 km in Indonesia) or
    // when the route crosses highways. We fall back to the car route geometry
    // and re-estimate walking time at average pedestrian speed (~1.25 m/s = 4.5 km/h).
    let autoRequest = MKDirections.Request()
    autoRequest.source = MKMapItem(placemark: MKPlacemark(coordinate: origin))
    autoRequest.destination = MKMapItem(placemark: MKPlacemark(coordinate: destination))
    autoRequest.transportType = .automobile

    if let autoResponse = try? await MKDirections(request: autoRequest).calculate(),
       let autoRoute = autoResponse.routes.first {
      // Estimate realistic walking time based on the actual road route distance (approx 1.25 m/s)
      let walkTime = autoRoute.distance / 1.25
      return formatRouteInfo(
        travelTime: walkTime,
        distanceMeters: autoRoute.distance,
        route: autoRoute
      )
    }

    // ── Tier 3: Straight-line Fallback (no network required) ─────────────────
    // CLLocation.distance(from:) computes the Haversine distance — the great-
    // circle distance between two GPS points, like:
    //   import geopy.distance
    //   geopy.distance.distance(origin, dest).meters
    // We build a two-point MKPolyline (a straight line on the map) as a visual
    // placeholder for the missing route geometry.
    let originCL = CLLocation(latitude: origin.latitude, longitude: origin.longitude)
    let destCL = CLLocation(latitude: destination.latitude, longitude: destination.longitude)
    let dist = originCL.distance(from: destCL)
    let estTime = dist / 1.25

    // `&coords` passes the array as a C-compatible pointer — MKPolyline's
    // initialiser is a bridged Objective-C API that takes a raw C array.
    var coords = [origin, destination]
    let fallbackPolyline = MKPolyline(coordinates: &coords, count: coords.count)

    return formatRouteInfo(
      travelTime: estTime,
      distanceMeters: dist,
      route: nil,
      fallbackPolyline: fallbackPolyline
    )
  }

  // MARK: formatRouteInfo (private helper)
  //
  // A pure formatting function — given raw numeric data it produces a
  // WalkingRouteInfo with human-readable strings.
  //
  // 🐍 Python analogy: this is a pure function in the functional-programming
  //   sense — same inputs always produce the same outputs, no side effects.
  //   It's like a Reducer in Redux / TCA: (State, Action) -> State, here
  //   (travelTime, distance, route) -> WalkingRouteInfo.
  private static func formatRouteInfo(
    travelTime: TimeInterval,   // seconds (Double)
    distanceMeters: Double,
    route: MKRoute?,
    fallbackPolyline: MKPolyline? = nil  // default parameter, like Python's def f(x=None)
  ) -> WalkingRouteInfo {

    // ── Travel Time String ────────────────────────────────────────────────────
    // ceil rounds up so "0 min" never appears; max(1, ...) ensures at least "1 min".
    let minutes = Int(ceil(travelTime / 60.0))
    let timeString: String
    if minutes < 60 {
      timeString = "\(max(1, minutes)) min"
    } else {
      let hrs = minutes / 60
      let remMins = minutes % 60           // modulo — same as Python's %
      timeString = "\(hrs) hr\(hrs > 1 ? "s" : "") \(remMins) min"
    }

    // ── ETA String ───────────────────────────────────────────────────────────
    // Adds the travel time to "now" then formats it.
    // Python equivalent: (datetime.now() + timedelta(seconds=travelTime)).strftime("%H.%M")
    let etaDate = Date().addingTimeInterval(travelTime)
    let formatter = DateFormatter()
    formatter.dateFormat = "HH.mm"
    let etaString = "\(formatter.string(from: etaDate)) ETA"

    // ── Distance String ───────────────────────────────────────────────────────
    // Display sub-kilometre distances in metres, larger distances in km (1 dp).
    let distanceString: String
    if distanceMeters < 1000 {
      distanceString = "\(Int(distanceMeters)) m"
    } else {
      distanceString = String(format: "%.1f km", distanceMeters / 1000.0)
    }

    // Assemble and return the value type. Because WalkingRouteInfo is a struct,
    // this is a stack allocation — no heap allocation, no reference counting.
    return WalkingRouteInfo(
      travelTimeString: timeString,
      etaString: etaString,
      distanceString: distanceString,
      rawTravelTime: travelTime,
      rawDistanceMeters: distanceMeters,
      route: route,
      fallbackPolyline: fallbackPolyline
    )
  }
}
