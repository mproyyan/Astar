//
//  DirectionJourneyLogModels.swift
//  Astar
//
//  Created by Dimas Prihady Setyawan on 25/08/26.
//

import Foundation

enum JourneyLogEntryType: Equatable, Sendable {
    case start
    case destination
    case currentLocation
    case checkpoint
}

struct JourneyLogEntry: Identifiable, Equatable, Sendable {
    let id: UUID
    let landmarkName: String
    let address: String
    let timeString: String
    let iconName: String
    let entryType: JourneyLogEntryType

    init(
        id: UUID = UUID(),
        landmarkName: String,
        address: String,
        timeString: String,
        iconName: String = "mappin.and.ellipse",
        entryType: JourneyLogEntryType = .checkpoint
    ) {
        self.id = id
        self.landmarkName = landmarkName
        self.address = address
        self.timeString = timeString
        self.iconName = iconName
        self.entryType = entryType
    }
}

enum JourneyLogSampleData {
    static let inProgressEntries: [JourneyLogEntry] = [
        JourneyLogEntry(
            landmarkName: "Near Plaza Indonesia",
            address: "Jl. M.H. Thamrin No. 28-30, Central Jakarta",
            timeString: "9:45 PM",
            iconName: "location.fill",
            entryType: .currentLocation
        ),
        JourneyLogEntry(
            landmarkName: "Passed Grand Indonesia",
            address: "Jl. M.H. Thamrin No. 1, Central Jakarta",
            timeString: "9:38 PM",
            iconName: "figure.walk",
            entryType: .checkpoint
        ),
        JourneyLogEntry(
            landmarkName: "Checkpoint MRT Bundaran HI",
            address: "Jl. M.H. Thamrin, Central Jakarta",
            timeString: "9:24 PM",
            iconName: "tram.fill",
            entryType: .checkpoint
        ),
        JourneyLogEntry(
            landmarkName: "Start Position",
            address: "Bendungan Hilir, South Jakarta",
            timeString: "9:10 PM",
            iconName: "figure.walk.motion",
            entryType: .start
        )
    ]

    static let doneEntries: [JourneyLogEntry] = [
        JourneyLogEntry(
            landmarkName: "Destination: Home",
            address: "Bendungan Hilir, South Jakarta",
            timeString: "9:50 PM",
            iconName: "house.fill",
            entryType: .destination
        ),
        JourneyLogEntry(
            landmarkName: "Near Plaza Indonesia",
            address: "Jl. M.H. Thamrin No. 28-30, Central Jakarta",
            timeString: "9:45 PM",
            iconName: "figure.walk",
            entryType: .checkpoint
        ),
        JourneyLogEntry(
            landmarkName: "Passed Grand Indonesia",
            address: "Jl. M.H. Thamrin No. 1, Central Jakarta",
            timeString: "9:38 PM",
            iconName: "figure.walk",
            entryType: .checkpoint
        ),
        JourneyLogEntry(
            landmarkName: "Checkpoint MRT Bundaran HI",
            address: "Jl. M.H. Thamrin, Central Jakarta",
            timeString: "9:24 PM",
            iconName: "tram.fill",
            entryType: .checkpoint
        ),
        JourneyLogEntry(
            landmarkName: "Start Position",
            address: "Bendungan Hilir, South Jakarta",
            timeString: "9:10 PM",
            iconName: "figure.walk.motion",
            entryType: .start
        )
    ]

    static var defaultEntries: [JourneyLogEntry] {
        inProgressEntries
    }
}
