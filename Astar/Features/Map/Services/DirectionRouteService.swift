//
//  DirectionRouteService.swift
//  Astar
//
//  Created by Dimas Prihady Setyawan on 26/08/26.
//

import CoreLocation
import Foundation
import MapKit

struct WalkingRouteInfo: Equatable, Sendable {
    var travelTimeString: String
    var etaString: String
    var distanceString: String
    var rawTravelTime: TimeInterval
    var rawDistanceMeters: Double
    var route: MKRoute?
}

@MainActor
enum DirectionRouteService {
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
            // Fallback to geodesic estimation
        }

        let originCL = CLLocation(latitude: origin.latitude, longitude: origin.longitude)
        let destCL = CLLocation(latitude: destination.latitude, longitude: destination.longitude)
        let dist = originCL.distance(from: destCL)
        let estTime = (dist * 1.25) / 1.25 // average pedestrian speed ~4.5 km/h

        return formatRouteInfo(travelTime: estTime, distanceMeters: dist, route: nil)
    }

    static func generateJourneyLogEntries(
        origin: SavedPlace,
        destination: SavedPlace,
        route: MKRoute?,
        startTime: Date = Date()
    ) async -> [JourneyLogEntry] {
        let totalDuration = route?.expectedTravelTime ?? 720
        var entries: [JourneyLogEntry] = []

        let timeFormatter = DateFormatter()
        timeFormatter.dateFormat = "h:mm a"

        // 1. Destination Entry (Top)
        let destTime = startTime.addingTimeInterval(totalDuration)
        entries.append(
            JourneyLogEntry(
                landmarkName: "Destination: \(destination.name)",
                address: destination.subtitle,
                timeString: timeFormatter.string(from: destTime),
                iconName: destination.iconName.isEmpty ? "mappin.and.ellipse" : destination.iconName,
                entryType: .destination
            )
        )

        // 2. Extract Intermediate Checkpoints from Route Steps
        if let route = route {
            let significantSteps = route.steps.filter {
                !$0.instructions.isEmpty && $0.distance > 10
            }

            let maxCheckpoints = 3
            let stepCount = significantSteps.count

            if stepCount > 0 {
                let strideCount = max(1, stepCount / maxCheckpoints)
                for i in stride(from: min(stepCount - 1, strideCount * 2), through: strideCount, by: -strideCount) {
                    let step = significantSteps[i]
                    let cleanInstruction = step.instructions
                        .replacingOccurrences(of: "Turn right onto ", with: "On ")
                        .replacingOccurrences(of: "Turn left onto ", with: "On ")
                        .replacingOccurrences(of: "Head ", with: "Along ")
                        .replacingOccurrences(of: "Continue onto ", with: "Passed ")

                    let fraction = Double(i) / Double(stepCount)
                    let stepTime = startTime.addingTimeInterval(totalDuration * fraction)

                    let icon: String
                    if cleanInstruction.localizedCaseInsensitiveContains("station") || cleanInstruction.localizedCaseInsensitiveContains("mrt") {
                        icon = "tram.fill"
                    } else if cleanInstruction.localizedCaseInsensitiveContains("mall") || cleanInstruction.localizedCaseInsensitiveContains("plaza") {
                        icon = "bag.fill"
                    } else {
                        icon = "figure.walk"
                    }

                    let landmarkName = cleanInstruction.hasPrefix("Passed") || cleanInstruction.hasPrefix("On") || cleanInstruction.hasPrefix("Along")
                        ? cleanInstruction
                        : "Passed \(cleanInstruction)"

                    entries.append(
                        JourneyLogEntry(
                            landmarkName: landmarkName,
                            address: destination.subtitle,
                            timeString: timeFormatter.string(from: stepTime),
                            iconName: icon,
                            entryType: .checkpoint
                        )
                    )
                }
            }
        }

        // Fallback default checkpoints if route had minimal steps
        if entries.count == 1 {
            let midTime = startTime.addingTimeInterval(totalDuration * 0.5)
            entries.append(
                JourneyLogEntry(
                    landmarkName: "Passed \(destination.name) Area",
                    address: destination.subtitle,
                    timeString: timeFormatter.string(from: midTime),
                    iconName: "figure.walk",
                    entryType: .checkpoint
                )
            )
        }

        // 3. Start Position Entry (Bottom)
        entries.append(
            JourneyLogEntry(
                landmarkName: "Start Position",
                address: origin.subtitle,
                timeString: timeFormatter.string(from: startTime),
                iconName: "figure.walk.motion",
                entryType: .start
            )
        )

        return entries
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
