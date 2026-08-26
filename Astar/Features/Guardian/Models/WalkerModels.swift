//
//  WalkerModels.swift
//  Astar
//
//  Created by Dimas Prihady Setyawan on 25/08/26.
//

import SwiftUI

enum WalkerStatus: String, CaseIterable, Identifiable, Sendable {
    case available = "Available"
    case notMoving = "Not Moving"
    case noResponse = "No Response"

    var id: String { rawValue }

    var iconName: String {
        switch self {
        case .available:
            return "figure.walk"
        case .notMoving:
            return "figure.stand"
        case .noResponse:
            return "exclamationmark.circle.fill"
        }
    }

    var color: Color {
        switch self {
        case .available:
            return Color(red: 0.20, green: 0.78, blue: 0.35)
        case .notMoving:
            return Color(red: 1.0, green: 0.80, blue: 0.0)
        case .noResponse:
            return Color(red: 1.0, green: 0.23, blue: 0.19)
        }
    }
}

struct WalkerProfile: Identifiable, Equatable, Sendable {
    let id: UUID
    let name: String
    let locationSubtitle: String
    let timeAgo: String
    let originPlaceName: String
    let originIconName: String
    let destinationPlaceName: String
    let destinationIconName: String
    let status: WalkerStatus
    let recentLocations: [JourneyLogEntry]

    init(
        id: UUID = UUID(),
        name: String,
        locationSubtitle: String,
        timeAgo: String,
        originPlaceName: String,
        originIconName: String = "briefcase.fill",
        destinationPlaceName: String,
        destinationIconName: String = "house.fill",
        status: WalkerStatus = .available,
        recentLocations: [JourneyLogEntry]
    ) {
        self.id = id
        self.name = name
        self.locationSubtitle = locationSubtitle
        self.timeAgo = timeAgo
        self.originPlaceName = originPlaceName
        self.originIconName = originIconName
        self.destinationPlaceName = destinationPlaceName
        self.destinationIconName = destinationIconName
        self.status = status
        self.recentLocations = recentLocations
    }
}

struct WalkerHistoryTrip: Identifiable, Equatable, Sendable {
    let id: UUID
    let destinationName: String
    let iconName: String
    let iconColor: Color
    let dateString: String
    let durationString: String
    let distanceString: String
    let checkpoints: [JourneyLogEntry]

    init(
        id: UUID = UUID(),
        destinationName: String,
        iconName: String,
        iconColor: Color,
        dateString: String = "21 August 2026, 18:30",
        durationString: String = "21 min",
        distanceString: String = "3,6 km",
        checkpoints: [JourneyLogEntry] = WalkerSampleData.defaultHistoryCheckpoints
    ) {
        self.id = id
        self.destinationName = destinationName
        self.iconName = iconName
        self.iconColor = iconColor
        self.dateString = dateString
        self.durationString = durationString
        self.distanceString = distanceString
        self.checkpoints = checkpoints
    }
}

struct WalkerHistorySection: Identifiable, Equatable, Sendable {
    let id: UUID
    let title: String
    let trips: [WalkerHistoryTrip]

    init(id: UUID = UUID(), title: String, trips: [WalkerHistoryTrip]) {
        self.id = id
        self.title = title
        self.trips = trips
    }
}

enum WalkerSampleData {
    static let awanLocations: [JourneyLogEntry] = [
        JourneyLogEntry(
            landmarkName: "Near Plaza Indonesia",
            address: "Walking north on Jl. M.H. Thamrin",
            timeString: "9:45 PM",
            iconName: "building.fill",
            entryType: .currentLocation
        ),
        JourneyLogEntry(
            landmarkName: "Near Grand Indonesia",
            address: "Heading toward Bundaran HI",
            timeString: "9:39 PM",
            iconName: "building.2.fill",
            entryType: .checkpoint
        ),
        JourneyLogEntry(
            landmarkName: "UOB Plaza",
            address: "Walking east to Jl. M.H. Thamrin",
            timeString: "9:33 PM",
            iconName: "building.fill",
            entryType: .checkpoint
        ),
        JourneyLogEntry(
            landmarkName: "Autograph Tower",
            address: "Started journey",
            timeString: "9:30 PM",
            iconName: "mappin.fill",
            entryType: .start
        )
    ]

    static let defaultHistoryCheckpoints: [JourneyLogEntry] = [
        JourneyLogEntry(
            landmarkName: "Destination",
            address: "Reached destination",
            timeString: "9:45 PM",
            iconName: "house.fill",
            entryType: .destination
        ),
        JourneyLogEntry(
            landmarkName: "Near Plaza Indonesia",
            address: "Walking north on Jl. M.H. Thamrin",
            timeString: "9:45 PM",
            iconName: "building.fill",
            entryType: .checkpoint
        ),
        JourneyLogEntry(
            landmarkName: "Near Plaza Indonesia",
            address: "Walking north on Jl. M.H. Thamrin",
            timeString: "9:45 PM",
            iconName: "building.fill",
            entryType: .checkpoint
        ),
        JourneyLogEntry(
            landmarkName: "Near Plaza Indonesia",
            address: "Walking north on Jl. M.H. Thamrin",
            timeString: "9:45 PM",
            iconName: "building.fill",
            entryType: .checkpoint
        ),
        JourneyLogEntry(
            landmarkName: "Start position",
            address: "Started journey",
            timeString: "9:45 PM",
            iconName: "mappin.fill",
            entryType: .start
        )
    ]

    static let defaultWalker = WalkerProfile(
        name: "Awan",
        locationSubtitle: "Central Jakarta, Jakarta",
        timeAgo: "1 Min Ago",
        originPlaceName: "Autograph Tower",
        originIconName: "briefcase.fill",
        destinationPlaceName: "Home",
        destinationIconName: "house.fill",
        status: .available,
        recentLocations: awanLocations
    )

    static let defaultTrips: [WalkerHistoryTrip] = [
        WalkerHistoryTrip(
            destinationName: "Home",
            iconName: "house.fill",
            iconColor: Color(red: 0.0, green: 0.48, blue: 1.0),
            dateString: "21 August 2026, 18:30",
            durationString: "21 min",
            distanceString: "3,6 km"
        ),
        WalkerHistoryTrip(
            destinationName: "Gym",
            iconName: "figure.strengthtraining.traditional",
            iconColor: Color(red: 1.0, green: 0.80, blue: 0.0),
            dateString: "21 August 2026, 18:30",
            durationString: "21 min",
            distanceString: "3,6 km"
        ),
        WalkerHistoryTrip(
            destinationName: "Office",
            iconName: "building.2.fill",
            iconColor: Color(red: 0.35, green: 0.34, blue: 0.84),
            dateString: "21 August 2026, 18:30",
            durationString: "21 min",
            distanceString: "3,6 km"
        )
    ]

    static let defaultHistorySections: [WalkerHistorySection] = [
        WalkerHistorySection(title: "Today", trips: defaultTrips),
        WalkerHistorySection(title: "This Week", trips: defaultTrips)
    ]
}
