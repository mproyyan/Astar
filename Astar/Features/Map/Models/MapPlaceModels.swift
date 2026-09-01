//
//  MapPlaceModels.swift
//  Astar
//
//  Created by Dimas Prihady Setyawan on 25/08/26.
//

import CoreLocation
import Foundation
import MapKit
import SwiftUI

extension MKMultiPoint {
    var coordinates: [CLLocationCoordinate2D] {
        guard pointCount > 0 else { return [] }
        var coords = [CLLocationCoordinate2D](repeating: kCLLocationCoordinate2DInvalid, count: pointCount)
        getCoordinates(&coords, range: NSRange(location: 0, length: pointCount))
        return coords
    }
}

struct Person: Identifiable, Equatable, Sendable {
    let id: UUID
    let name: String
    let status: String
    var appleUserId: String?
    var cloudKitUserId: String?

    init(id: UUID = UUID(), name: String, status: String, appleUserId: String? = nil, cloudKitUserId: String? = nil) {
        self.id = id
        self.name = name
        self.status = status
        self.appleUserId = appleUserId
        self.cloudKitUserId = cloudKitUserId
    }

    static let mockJohnDoe = Person(
        id: UUID(uuidString: "00000000-0000-0000-0000-000000000001") ?? UUID(),
        name: "John Doe",
        status: "Idle"
    )

    static let mockDoeID = UUID(uuidString: "00000000-0000-0000-0000-000000000002") ?? UUID()

    static var mockDoe: Person {
        let status = DeveloperSettingsStorage.isDoeWalkingMockEnabled ? "Walking" : "Idle"
        return Person(
            id: mockDoeID,
            name: "Doe",
            status: status
        )
    }
}

struct SavedPlace: Identifiable, Equatable, Sendable, Codable {
    let id: UUID
    let name: String
    let subtitle: String
    let iconName: String
    let distance: String?
    let latitude: Double?
    let longitude: Double?
    var label: String?

    init(
        id: UUID = UUID(),
        name: String,
        subtitle: String,
        iconName: String,
        distance: String? = nil,
        coordinate: CLLocationCoordinate2D? = nil,
        latitude: Double? = nil,
        longitude: Double? = nil,
        label: String? = nil
    ) {
        self.id = id
        self.name = name
        self.subtitle = subtitle
        self.iconName = iconName
        self.distance = distance
        self.latitude = coordinate?.latitude ?? latitude
        self.longitude = coordinate?.longitude ?? longitude
        self.label = label
    }

    var coordinate: CLLocationCoordinate2D? {
        guard let lat = latitude, let lng = longitude else { return nil }
        return CLLocationCoordinate2D(latitude: lat, longitude: lng)
    }
}


extension SavedPlace {
    var isHome: Bool {
        label?.lowercased() == "home" || iconName == "house.fill" || name.lowercased() == "home"
    }

    var isOffice: Bool {
        label?.lowercased() == "office" || iconName == "briefcase.fill" || iconName == "building.2.fill" || name.lowercased() == "office"
    }

    var isCustom: Bool {
        !isHome && !isOffice
    }

    var resolvedIconName: String {
        let trimmed = iconName.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty || trimmed == "mappin.and.ellipse" {
            return "mappin.fill"
        }
        return trimmed
    }

    var categoryColor: Color {
        if isHome {
            return Color(red: 0.15, green: 0.75, blue: 0.85)
        } else if isOffice {
            return Color(red: 0.65, green: 0.48, blue: 0.35)
        } else if isCustom && (resolvedIconName == "mappin.fill" || resolvedIconName == "key.fill" || label != nil) {
            return Color(red: 0.98, green: 0.78, blue: 0.05)
        }
        return SavedPlace.categoryColor(for: resolvedIconName)
    }

    static func categoryColor(for iconName: String) -> Color {
        switch iconName {
        case "fork.knife", "cup.and.saucer.fill", "takeoutbag.and.cup.and.straw.fill":
            return Color(red: 0.98, green: 0.58, blue: 0.16) // Food & Dining: Orange

        case "bag.fill", "cart.fill", "basket.fill":
            return Color(red: 0.98, green: 0.73, blue: 0.12) // Shopping: Amber/Yellow

        case "tram.fill", "train.side.front.car", "bus.fill", "airplane", "ferry.fill":
            return Color(red: 0.92, green: 0.34, blue: 0.55) // Transit: Pink/Magenta

        case "figure.strengthtraining.traditional", "figure.run", "figure.pool.swim", "sportscourt.fill":
            return Color(red: 0.18, green: 0.72, blue: 0.78) // Sports/Fitness: Teal

        case "tree.fill", "leaf.fill", "mountain.2.fill":
            return Color(red: 0.28, green: 0.72, blue: 0.40) // Parks/Nature: Green

        case "wineglass.fill", "theatermasks.fill", "popcorn.fill", "music.note":
            return Color(red: 0.65, green: 0.35, blue: 0.85) // Nightlife: Purple

        case "cross.case.fill", "cross.fill", "pills.fill":
            return Color(red: 0.92, green: 0.28, blue: 0.28) // Health: Red

        case "bed.double.fill":
            return Color(red: 0.38, green: 0.45, blue: 0.85) // Hotel: Indigo

        case "graduationcap.fill", "landmark.fill", "book.fill":
            return Color(red: 0.62, green: 0.45, blue: 0.35) // Landmarks/Education: Brown

        case "fuelpump.fill", "ev.charger.fill", "car.fill", "wrench.and.screwdriver.fill":
            return Color(red: 0.20, green: 0.55, blue: 0.95) // Services/Auto: Blue

        case "house.fill":
            return Color(red: 0.15, green: 0.75, blue: 0.85) // Home: Cyan/Teal (Figma)

        case "briefcase.fill", "building.2.fill", "building.fill":
            return Color(red: 0.65, green: 0.48, blue: 0.35) // Office: Warm Brown (Figma)

        case "key.fill":
            return Color(red: 0.98, green: 0.78, blue: 0.05) // Custom/Key: Bright Yellow (Figma)

        case "mappin.fill", "mappin.circle.fill", "mappin.and.ellipse":
            return Color(red: 0.92, green: 0.25, blue: 0.20) // Search Pin: Red (Figma)

        case "location.fill":
            return Color.blue // Current Location: Apple Blue

        default:
            return Color(red: 0.92, green: 0.25, blue: 0.20) // Default Search Map Pin: Red (Figma)
        }
    }
}

enum MockDoeWalkSimulation {
    static let originCoordinate = CLLocationCoordinate2D(latitude: -6.1991, longitude: 106.8230)
    static let destinationCoordinate = CLLocationCoordinate2D(latitude: -6.2125, longitude: 106.8166)
    static let destinationName = "Home"

    static let waypoints: [CLLocationCoordinate2D] = [
        CLLocationCoordinate2D(latitude: -6.1991, longitude: 106.8230), // Autograph Tower (Thamrin Nine)
        CLLocationCoordinate2D(latitude: -6.2018, longitude: 106.8223), // Dukuh Atas
        CLLocationCoordinate2D(latitude: -6.2052, longitude: 106.8208), // Jl. Jend. Sudirman
        CLLocationCoordinate2D(latitude: -6.2084, longitude: 106.8194), // JPO Phinisi / Karet
        CLLocationCoordinate2D(latitude: -6.2110, longitude: 106.8179), // Jl. Bendungan Hilir
        CLLocationCoordinate2D(latitude: -6.2125, longitude: 106.8166)  // Home (Destination)
    ]

    static let fallbackPolyline: MKPolyline = {
        var coords = waypoints
        return MKPolyline(coordinates: &coords, count: coords.count)
    }()

    static var returnWaypoints: [CLLocationCoordinate2D] {
        waypoints.reversed()
    }

    static let returnFallbackPolyline: MKPolyline = {
        var coords = returnWaypoints
        return MKPolyline(coordinates: &coords, count: coords.count)
    }()

    static func isNearHome(_ coordinate: CLLocationCoordinate2D?) -> Bool {
        guard let coordinate else { return false }
        let loc1 = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        let homeLoc = CLLocation(latitude: destinationCoordinate.latitude, longitude: destinationCoordinate.longitude)
        return loc1.distance(from: homeLoc) < 150
    }

    static func samplePoints(from polyline: MKPolyline, targetCount: Int = 10) -> [CLLocationCoordinate2D] {
        let allCoords = polyline.coordinates
        guard allCoords.count >= 2 else {
            return allCoords.isEmpty ? waypoints : allCoords
        }
        guard targetCount > 1 else { return [allCoords[0]] }

        var distances: [Double] = [0.0]
        for i in 1..<allCoords.count {
            let p1 = CLLocation(latitude: allCoords[i-1].latitude, longitude: allCoords[i-1].longitude)
            let p2 = CLLocation(latitude: allCoords[i].latitude, longitude: allCoords[i].longitude)
            distances.append(distances.last! + p2.distance(from: p1))
        }
        let totalDistance = distances.last ?? 0.0
        guard totalDistance > 0 else { return Array(repeating: allCoords[0], count: targetCount) }

        var sampled: [CLLocationCoordinate2D] = []
        for i in 0..<targetCount {
            let targetDist = (Double(i) / Double(targetCount - 1)) * totalDistance
            var segmentIdx = 0
            while segmentIdx < distances.count - 2 && distances[segmentIdx + 1] < targetDist {
                segmentIdx += 1
            }
            let segStartDist = distances[segmentIdx]
            let segEndDist = distances[segmentIdx + 1]
            let segLen = segEndDist - segStartDist
            let ratio = segLen > 0 ? (targetDist - segStartDist) / segLen : 0.0

            let c1 = allCoords[segmentIdx]
            let c2 = allCoords[segmentIdx + 1]
            let lat = c1.latitude + (c2.latitude - c1.latitude) * ratio
            let lon = c1.longitude + (c2.longitude - c1.longitude) * ratio
            sampled.append(CLLocationCoordinate2D(latitude: lat, longitude: lon))
        }
        return sampled
    }

    struct CheckpointDef: Sendable {
        let landmarkName: String
        let address: String
        let iconName: String
        let coordinate: CLLocationCoordinate2D
    }

    static let checkpointDefs: [CheckpointDef] = [
        CheckpointDef(
            landmarkName: "Start: Autograph Tower",
            address: "Jl. M.H. Thamrin No. 10, Central Jakarta",
            iconName: "figure.walk.motion",
            coordinate: originCoordinate
        ),
        CheckpointDef(
            landmarkName: "Passed Dukuh Atas",
            address: "Jl. Jend. Sudirman, Central Jakarta",
            iconName: "tram.fill",
            coordinate: waypoints[1]
        ),
        CheckpointDef(
            landmarkName: "Passed Jl. Jend. Sudirman",
            address: "Central Jakarta",
            iconName: "figure.walk",
            coordinate: waypoints[2]
        ),
        CheckpointDef(
            landmarkName: "Passed JPO Phinisi",
            address: "Karet Sudirman, Central Jakarta",
            iconName: "figure.walk",
            coordinate: waypoints[3]
        ),
        CheckpointDef(
            landmarkName: "Passed Jl. Bendungan Hilir",
            address: "Central Jakarta",
            iconName: "figure.walk",
            coordinate: waypoints[4]
        ),
        CheckpointDef(
            landmarkName: "Destination: Home",
            address: "Bendungan Hilir, South Jakarta",
            iconName: "house.fill",
            coordinate: destinationCoordinate
        )
    ]

    static let returnCheckpointDefs: [CheckpointDef] = [
        CheckpointDef(
            landmarkName: "Start: Home",
            address: "Bendungan Hilir, South Jakarta",
            iconName: "house.fill",
            coordinate: destinationCoordinate
        ),
        CheckpointDef(
            landmarkName: "Passed Jl. Bendungan Hilir",
            address: "Central Jakarta",
            iconName: "figure.walk",
            coordinate: waypoints[4]
        ),
        CheckpointDef(
            landmarkName: "Passed JPO Phinisi",
            address: "Karet Sudirman, Central Jakarta",
            iconName: "figure.walk",
            coordinate: waypoints[3]
        ),
        CheckpointDef(
            landmarkName: "Passed Jl. Jend. Sudirman",
            address: "Central Jakarta",
            iconName: "figure.walk",
            coordinate: waypoints[2]
        ),
        CheckpointDef(
            landmarkName: "Passed Dukuh Atas",
            address: "Jl. Jend. Sudirman, Central Jakarta",
            iconName: "tram.fill",
            coordinate: waypoints[1]
        ),
        CheckpointDef(
            landmarkName: "Destination: Autograph Tower",
            address: "Jl. M.H. Thamrin No. 10, Central Jakarta",
            iconName: "building.2.fill",
            coordinate: originCoordinate
        )
    ]

    static func journeyLog(
        forProgress progress: Double,
        currentCoord: CLLocationCoordinate2D,
        startTime: Date,
        now: Date,
        isReturnTrip: Bool = false
    ) -> [JourneyLogEntry] {
        if progress >= 1.0 {
            return completedJourneyLog(isReturnTrip: isReturnTrip, now: now)
        }

        let defs = isReturnTrip ? returnCheckpointDefs : checkpointDefs
        let startStr = DateFormatter.localizedString(from: startTime, dateStyle: .none, timeStyle: .short)
        let numCheckpoints = defs.count
        let passedCount = Int((progress * Double(numCheckpoints - 1)).rounded(.down))

        let currentLandmark: String
        let currentAddress: String
        if passedCount == 0 {
            currentLandmark = isReturnTrip ? "Near Home" : "Near Autograph Tower"
            currentAddress = defs[0].address
        } else {
            let def = defs[min(passedCount, defs.count - 2)]
            currentLandmark = def.landmarkName.replacingOccurrences(of: "Passed ", with: "Near ")
            currentAddress = def.address
        }

        let currentEntry = JourneyLogEntry(
            id: UUID(),
            landmarkName: currentLandmark,
            address: currentAddress,
            timeString: "Now",
            iconName: "location.fill",
            entryType: .currentLocation,
            coordinate: currentCoord
        )

        var entries: [JourneyLogEntry] = [currentEntry]

        if passedCount >= 1 {
            for i in stride(from: min(passedCount, defs.count - 2), through: 1, by: -1) {
                let def = defs[i]
                entries.append(
                    JourneyLogEntry(
                        id: UUID(),
                        landmarkName: def.landmarkName,
                        address: def.address,
                        timeString: startStr,
                        iconName: def.iconName,
                        entryType: .checkpoint,
                        coordinate: def.coordinate
                    )
                )
            }
        }

        entries.append(
            JourneyLogEntry(
                id: UUID(),
                landmarkName: defs[0].landmarkName,
                address: defs[0].address,
                timeString: startStr,
                iconName: defs[0].iconName,
                entryType: .start,
                coordinate: defs[0].coordinate
            )
        )

        return entries
    }

    static let completedTripID = UUID(uuidString: "00000000-0000-0000-0002-000000000099")!
    static let returnCompletedTripID = UUID(uuidString: "00000000-0000-0000-0002-000000000098")!
    static let currentLocEntryID = UUID(uuidString: "00000000-0000-0000-0002-000000000000")!
    static let destinationEntryID = UUID(uuidString: "00000000-0000-0000-0002-000000000001")!
    static let benhilEntryID = UUID(uuidString: "00000000-0000-0000-0002-000000000002")!
    static let phinisiEntryID = UUID(uuidString: "00000000-0000-0000-0002-000000000003")!
    static let sudirmanEntryID = UUID(uuidString: "00000000-0000-0000-0002-000000000004")!
    static let dukuhAtasEntryID = UUID(uuidString: "00000000-0000-0000-0002-000000000005")!
    static let autographEntryID = UUID(uuidString: "00000000-0000-0000-0002-000000000006")!

    static func completedTrip(
        id: UUID? = nil,
        now: Date = Date(),
        tripIndex: Int = 0,
        isReturnTrip: Bool = false
    ) -> WalkerHistoryTrip {
        let finalLog = completedJourneyLog(isReturnTrip: isReturnTrip, now: now)
        let resolvedID = id ?? (isReturnTrip ? returnCompletedTripID : completedTripID)
        let destName = isReturnTrip ? "Office" : "Home"
        let destIcon = isReturnTrip ? "building.2.fill" : "house.fill"
        let iconColor: Color = isReturnTrip ? Color(red: 0.35, green: 0.34, blue: 0.84) : .blue
        return WalkerHistoryTrip(
            id: resolvedID,
            destinationName: destName,
            iconName: destIcon,
            iconColor: iconColor,
            dateString: "Today, " + DateFormatter.localizedString(from: now, dateStyle: .none, timeStyle: .short),
            durationString: "18 min",
            distanceString: "1.9 km",
            checkpoints: finalLog
        )
    }

    static func journeyLogFromStartToFinish(isReturnTrip: Bool = false, now: Date = Date()) -> [JourneyLogEntry] {
        return completedJourneyLog(isReturnTrip: isReturnTrip, now: now)
    }

    static func completedJourneyLog(isReturnTrip: Bool = false, now: Date = Date()) -> [JourneyLogEntry] {
        let timeStr = DateFormatter.localizedString(from: now, dateStyle: .none, timeStyle: .short)
        let earlierTimeStr = DateFormatter.localizedString(from: now.addingTimeInterval(-15 * 60), dateStyle: .none, timeStyle: .short)

        if isReturnTrip {
            return [
                JourneyLogEntry(
                    id: autographEntryID,
                    landmarkName: "Destination: Autograph Tower",
                    address: "Jl. M.H. Thamrin No. 10, Central Jakarta",
                    timeString: timeStr,
                    iconName: "building.2.fill",
                    entryType: .destination,
                    coordinate: originCoordinate
                ),
                JourneyLogEntry(
                    id: dukuhAtasEntryID,
                    landmarkName: "Passed Dukuh Atas",
                    address: "Jl. Jend. Sudirman, Central Jakarta",
                    timeString: timeStr,
                    iconName: "tram.fill",
                    entryType: .checkpoint,
                    coordinate: waypoints[1]
                ),
                JourneyLogEntry(
                    id: sudirmanEntryID,
                    landmarkName: "Passed Jl. Jend. Sudirman",
                    address: "Central Jakarta",
                    timeString: timeStr,
                    iconName: "figure.walk",
                    entryType: .checkpoint,
                    coordinate: waypoints[2]
                ),
                JourneyLogEntry(
                    id: phinisiEntryID,
                    landmarkName: "Passed JPO Phinisi",
                    address: "Karet Sudirman, Central Jakarta",
                    timeString: earlierTimeStr,
                    iconName: "figure.walk",
                    entryType: .checkpoint,
                    coordinate: waypoints[3]
                ),
                JourneyLogEntry(
                    id: benhilEntryID,
                    landmarkName: "Passed Jl. Bendungan Hilir",
                    address: "Central Jakarta",
                    timeString: earlierTimeStr,
                    iconName: "figure.walk",
                    entryType: .checkpoint,
                    coordinate: waypoints[4]
                ),
                JourneyLogEntry(
                    id: destinationEntryID,
                    landmarkName: "Start: Home",
                    address: "Bendungan Hilir, South Jakarta",
                    timeString: earlierTimeStr,
                    iconName: "house.fill",
                    entryType: .start,
                    coordinate: destinationCoordinate
                )
            ]
        }

        return [
            JourneyLogEntry(
                id: destinationEntryID,
                landmarkName: "Destination: Home",
                address: "Bendungan Hilir, South Jakarta",
                timeString: timeStr,
                iconName: "house.fill",
                entryType: .destination,
                coordinate: destinationCoordinate
            ),
            JourneyLogEntry(
                id: benhilEntryID,
                landmarkName: "Passed Jl. Bendungan Hilir",
                address: "Central Jakarta",
                timeString: timeStr,
                iconName: "figure.walk",
                entryType: .checkpoint,
                coordinate: waypoints[4]
            ),
            JourneyLogEntry(
                id: phinisiEntryID,
                landmarkName: "Passed JPO Phinisi",
                address: "Karet Sudirman, Central Jakarta",
                timeString: timeStr,
                iconName: "figure.walk",
                entryType: .checkpoint,
                coordinate: waypoints[3]
            ),
            JourneyLogEntry(
                id: sudirmanEntryID,
                landmarkName: "Passed Jl. Jend. Sudirman",
                address: "Central Jakarta",
                timeString: earlierTimeStr,
                iconName: "figure.walk",
                entryType: .checkpoint,
                coordinate: waypoints[2]
            ),
            JourneyLogEntry(
                id: dukuhAtasEntryID,
                landmarkName: "Passed Dukuh Atas",
                address: "Jl. Jend. Sudirman, Central Jakarta",
                timeString: earlierTimeStr,
                iconName: "tram.fill",
                entryType: .checkpoint,
                coordinate: waypoints[1]
            ),
            JourneyLogEntry(
                id: autographEntryID,
                landmarkName: "Start: Autograph Tower",
                address: "Jl. M.H. Thamrin No. 10, Central Jakarta",
                timeString: earlierTimeStr,
                iconName: "figure.walk.motion",
                entryType: .start,
                coordinate: originCoordinate
            )
        ]
    }
}

enum MapSampleData {
    static var people: [Person] {
        let basePeople = [
            Person(name: "Awan", status: "Walking"),
            Person(name: "Royyan", status: "Idle"),
            Person(name: "Safa", status: "Idle"),
            Person(name: "Nadia", status: "Idle")
        ]
        if DeveloperSettingsStorage.isDevelopmentMode {
            return [Person.mockDoe] + basePeople
        } else {
            return basePeople
        }
    }

    static let savedPlaces: [SavedPlace] = [
        SavedPlace(
            name: "Home",
            subtitle: "Bendungan Hilir, South Jakarta",
            iconName: "house.fill",
            coordinate: CLLocationCoordinate2D(latitude: -6.2125, longitude: 106.8166)
        ),
        SavedPlace(
            name: "Gym",
            subtitle: "Agora Mall, Central Jakarta",
            iconName: "figure.strengthtraining.traditional",
            coordinate: CLLocationCoordinate2D(latitude: -6.1990, longitude: 106.8216)
        ),
        SavedPlace(
            name: "Office",
            subtitle: "Autograph Tower, Thamrin Nine, Central Jakarta",
            iconName: "building.2.fill",
            coordinate: CLLocationCoordinate2D(latitude: -6.1991, longitude: 106.8212)
        )
    ]

    static let allSearchablePlaces: [SavedPlace] = [
        SavedPlace(name: "Home", subtitle: "Bendungan Hilir, South Jakarta", iconName: "house.fill", distance: "350 m", coordinate: CLLocationCoordinate2D(latitude: -6.2125, longitude: 106.8166)),
        SavedPlace(name: "Gym", subtitle: "Agora Mall, Central Jakarta", iconName: "figure.strengthtraining.traditional", distance: "450 m", coordinate: CLLocationCoordinate2D(latitude: -6.1990, longitude: 106.8216)),
        SavedPlace(name: "Office", subtitle: "Autograph Tower, Thamrin Nine, Central Jakarta", iconName: "building.2.fill", distance: "250 m", coordinate: CLLocationCoordinate2D(latitude: -6.1991, longitude: 106.8212)),
        SavedPlace(name: "Autograph Tower", subtitle: "Thamrin Nine, Jl. M.H. Thamrin No. 10, Central Jakarta", iconName: "building.2.fill", distance: "250 m", coordinate: CLLocationCoordinate2D(latitude: -6.1991, longitude: 106.8212)),
        SavedPlace(name: "Agora Mall", subtitle: "Jl. M.H. Thamrin No. 10, Central Jakarta", iconName: "bag.fill", distance: "450 m", coordinate: CLLocationCoordinate2D(latitude: -6.1990, longitude: 106.8216)),
        SavedPlace(name: "Grand Indonesia", subtitle: "Jl. M.H. Thamrin No. 1, Central Jakarta", iconName: "bag.fill", distance: "850 m", coordinate: CLLocationCoordinate2D(latitude: -6.1950, longitude: 106.8200)),
        SavedPlace(name: "Plaza Indonesia", subtitle: "Jl. M.H. Thamrin No. 28-30, Central Jakarta", iconName: "bag.fill", distance: "1.1 km", coordinate: CLLocationCoordinate2D(latitude: -6.1930, longitude: 106.8217)),
        SavedPlace(name: "Starbucks Reserve Sudirman", subtitle: "Menara Astra, Jl. Jend. Sudirman Kav 5-6", iconName: "cup.and.saucer.fill", distance: "600 m", coordinate: CLLocationCoordinate2D(latitude: -6.2088, longitude: 106.8219)),
        SavedPlace(name: "MRT Bundaran HI", subtitle: "Jl. M.H. Thamrin, Central Jakarta", iconName: "tram.fill", distance: "950 m", coordinate: CLLocationCoordinate2D(latitude: -6.1935, longitude: 106.8230)),
        SavedPlace(name: "Stasiun Sudirman", subtitle: "Jl. Kendal No. 1, Central Jakarta", iconName: "train.side.front.car", distance: "1.3 km", coordinate: CLLocationCoordinate2D(latitude: -6.2023, longitude: 106.8236)),
        SavedPlace(name: "Kopi Kenangan Bendungan Hilir", subtitle: "Jl. Bendungan Hilir No. 15, Central Jakarta", iconName: "cup.and.saucer.fill", distance: "400 m", coordinate: CLLocationCoordinate2D(latitude: -6.2132, longitude: 106.8158)),
        SavedPlace(name: "Gelora Bung Karno", subtitle: "Jl. Pintu Satu Senayan, Central Jakarta", iconName: "figure.run", distance: "2.4 km", coordinate: CLLocationCoordinate2D(latitude: -6.2185, longitude: 106.8018)),
        SavedPlace(name: "Hutan Kota GBK", subtitle: "Pintu Tujuh Senayan, Central Jakarta", iconName: "tree.fill", distance: "2.6 km", coordinate: CLLocationCoordinate2D(latitude: -6.2230, longitude: 106.8065)),
        SavedPlace(name: "Pacific Place", subtitle: "SCBD, Jl. Jend. Sudirman, South Jakarta", iconName: "building.fill", distance: "3.1 km", coordinate: CLLocationCoordinate2D(latitude: -6.2248, longitude: 106.8098)),
        SavedPlace(name: "Senayan City", subtitle: "Jl. Asia Afrika No. 19, South Jakarta", iconName: "bag.fill", distance: "3.8 km", coordinate: CLLocationCoordinate2D(latitude: -6.2272, longitude: 106.7974)),
        SavedPlace(name: "McDonald's Sarinah", subtitle: "Jl. M.H. Thamrin No. 11, Central Jakarta", iconName: "fork.knife", distance: "1.8 km", coordinate: CLLocationCoordinate2D(latitude: -6.1876, longitude: 106.8242)),
        SavedPlace(name: "Monumen Nasional", subtitle: "Gambir, Central Jakarta", iconName: "landmark.fill", distance: "4.2 km", coordinate: CLLocationCoordinate2D(latitude: -6.1754, longitude: 106.8272)),
        SavedPlace(name: "Blok M Hub", subtitle: "Jl. Panglima Polim, South Jakarta", iconName: "tram.fill", distance: "5.6 km", coordinate: CLLocationCoordinate2D(latitude: -6.2443, longitude: 106.7979)),
        SavedPlace(name: "Central Park Mall", subtitle: "Jl. Letjen S. Parman No. 28, West Jakarta", iconName: "bag.fill", distance: "6.8 km", coordinate: CLLocationCoordinate2D(latitude: -6.1774, longitude: 106.7907)),
        SavedPlace(name: "Celebrity Fitness FX Sudirman", subtitle: "FX Sudirman Fl. 6, Central Jakarta", iconName: "figure.strengthtraining.traditional", distance: "3.2 km", coordinate: CLLocationCoordinate2D(latitude: -6.2250, longitude: 106.8042))
    ]
}
