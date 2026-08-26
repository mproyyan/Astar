//
//  JourneyTrackingManager.swift
//  Astar
//
//  Created by Dimas Prihady Setyawan on 26/08/26.
//

import CoreLocation
import Foundation
import MapKit
import SwiftUI

@MainActor
@Observable
final class JourneyTrackingManager {
    var origin: SavedPlace?
    var destination: SavedPlace?
    var startPositionEntry: JourneyLogEntry?
    var currentLocationEntry: JourneyLogEntry?
    var visitedCheckpoints: [JourneyLogEntry] = []
    var isDestinationReached: Bool = false

    private var lastLoggedCoordinate: CLLocationCoordinate2D?
    private var lastLoggedStreet: String = ""

    var currentEntries: [JourneyLogEntry] {
        if isDestinationReached, let destination {
            let destTime = DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .short)
            let destEntry = JourneyLogEntry(
                landmarkName: "Destination: \(destination.name)",
                address: destination.subtitle,
                timeString: destTime,
                iconName: destination.iconName.isEmpty ? "house.fill" : destination.iconName,
                entryType: .destination,
                coordinate: destination.coordinate
            )
            return [destEntry] + visitedCheckpoints + (startPositionEntry.map { [$0] } ?? [])
        } else {
            var list: [JourneyLogEntry] = []
            if let current = currentLocationEntry {
                list.append(current)
            }
            list.append(contentsOf: visitedCheckpoints)
            if let start = startPositionEntry {
                list.append(start)
            }
            return list
        }
    }

    func startTracking(origin: SavedPlace, destination: SavedPlace, userLocation: CLLocationCoordinate2D?) async {
        self.origin = origin
        self.destination = destination
        self.isDestinationReached = false
        self.visitedCheckpoints = []

        let startCoord = userLocation ?? origin.coordinate ?? CLLocationCoordinate2D(latitude: -6.2088, longitude: 106.8456)
        let startTimeString = DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .short)

        let startAddress = await DirectionRouteService.reverseGeocode(coordinate: startCoord)
        let startEntry = JourneyLogEntry(
            landmarkName: "Start Position",
            address: startAddress,
            timeString: startTimeString,
            iconName: "figure.walk.motion",
            entryType: .start,
            coordinate: startCoord
        )
        self.startPositionEntry = startEntry
        self.lastLoggedCoordinate = startCoord

        let streetName = startAddress.components(separatedBy: ",").first?.trimmingCharacters(in: .whitespaces) ?? "Current Road"
        let currentEntry = JourneyLogEntry(
            landmarkName: "Near \(streetName)",
            address: startAddress,
            timeString: "Now",
            iconName: "location.fill",
            entryType: .currentLocation,
            coordinate: startCoord
        )
        self.currentLocationEntry = currentEntry
        self.lastLoggedStreet = streetName
    }

    func updateLocation(_ newCoordinate: CLLocationCoordinate2D) async {
        guard !isDestinationReached, let destination else { return }

        let userCL = CLLocation(latitude: newCoordinate.latitude, longitude: newCoordinate.longitude)

        // Check if destination reached (< 35m)
        if let destCoord = destination.coordinate {
            let destCL = CLLocation(latitude: destCoord.latitude, longitude: destCoord.longitude)
            if userCL.distance(from: destCL) <= 35.0 {
                isDestinationReached = true
                return
            }
        }

        // Check distance from last logged checkpoint
        if let lastCoord = lastLoggedCoordinate {
            let lastCL = CLLocation(latitude: lastCoord.latitude, longitude: lastCoord.longitude)
            let distanceMoved = userCL.distance(from: lastCL)

            if distanceMoved >= 60.0 {
                let newAddress = await DirectionRouteService.reverseGeocode(coordinate: newCoordinate)
                let streetName = newAddress.components(separatedBy: ",").first?.trimmingCharacters(in: .whitespaces) ?? "Road"
                let timeString = DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .short)

                // Archive previous current location as visited checkpoint
                let passedName = lastLoggedStreet.isEmpty ? "Passed \(streetName)" : (lastLoggedStreet.hasPrefix("Passed") ? lastLoggedStreet : "Passed \(lastLoggedStreet)")
                let passedEntry = JourneyLogEntry(
                    landmarkName: passedName,
                    address: newAddress,
                    timeString: timeString,
                    iconName: "figure.walk",
                    entryType: .checkpoint,
                    coordinate: lastCoord
                )
                visitedCheckpoints.insert(passedEntry, at: 0)

                // Set new live current location
                currentLocationEntry = JourneyLogEntry(
                    landmarkName: "Near \(streetName)",
                    address: newAddress,
                    timeString: "Now",
                    iconName: "location.fill",
                    entryType: .currentLocation,
                    coordinate: newCoordinate
                )

                lastLoggedCoordinate = newCoordinate
                lastLoggedStreet = streetName
            }
        }
    }

    func reset() {
        origin = nil
        destination = nil
        startPositionEntry = nil
        currentLocationEntry = nil
        visitedCheckpoints = []
        isDestinationReached = false
        lastLoggedCoordinate = nil
        lastLoggedStreet = ""
    }
}
