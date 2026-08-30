import Foundation
import CoreLocation
import MapKit
import ComposableArchitecture

struct WalkingRouteInfo: Equatable, Sendable {
  var travelTimeString: String
  var etaString: String
  var distanceString: String
  var rawTravelTime: TimeInterval
  var rawDistanceMeters: Double
  var route: MKRoute?
  var fallbackPolyline: MKPolyline?

  var polyline: MKPolyline? {
    route?.polyline ?? fallbackPolyline
  }
}

@DependencyClient
struct DirectionRouteClient: Sendable {
  var reverseGeocode: @Sendable (_ coordinate: CLLocationCoordinate2D) async -> String = { _ in "Current Location" }
  var calculateWalkingRoute: @Sendable (_ origin: CLLocationCoordinate2D, _ destination: CLLocationCoordinate2D) async -> WalkingRouteInfo = { _, _ in
    WalkingRouteInfo(travelTimeString: "12 min", etaString: "11.00 ETA", distanceString: "850 m", rawTravelTime: 720, rawDistanceMeters: 850, route: nil, fallbackPolyline: nil)
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
    // 1. First, attempt walking directions
    let request = MKDirections.Request()
    request.source = MKMapItem(placemark: MKPlacemark(coordinate: origin))
    request.destination = MKMapItem(placemark: MKPlacemark(coordinate: destination))
    request.transportType = .walking

    if let directions = try? await MKDirections(request: request).calculate(),
       let route = directions.routes.first {
      return formatRouteInfo(
        travelTime: route.expectedTravelTime,
        distanceMeters: route.distance,
        route: route
      )
    }

    // 2. Walking route unavailable (e.g. distance > 10 km like Cibubur, or highways).
    // Attempt automobile directions to get the real road polyline from Apple Maps.
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

    // 3. Fallback if Apple Maps has no network or completely fails:
    let originCL = CLLocation(latitude: origin.latitude, longitude: origin.longitude)
    let destCL = CLLocation(latitude: destination.latitude, longitude: destination.longitude)
    let dist = originCL.distance(from: destCL)
    let estTime = dist / 1.25

    var coords = [origin, destination]
    let fallbackPolyline = MKPolyline(coordinates: &coords, count: coords.count)

    return formatRouteInfo(
      travelTime: estTime,
      distanceMeters: dist,
      route: nil,
      fallbackPolyline: fallbackPolyline
    )
  }

  private static func formatRouteInfo(
    travelTime: TimeInterval,
    distanceMeters: Double,
    route: MKRoute?,
    fallbackPolyline: MKPolyline? = nil
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
      route: route,
      fallbackPolyline: fallbackPolyline
    )
  }
}
