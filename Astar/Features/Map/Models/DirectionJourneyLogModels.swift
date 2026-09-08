//
//  DirectionJourneyLogModels.swift
//  Astar
//
//  Created by Dimas Prihady Setyawan on 25/08/26.
//

import CoreLocation
import Foundation

enum JourneyLogEntryType: String, Equatable, Sendable, Codable {
    case start
    case destination
    case currentLocation
    case checkpoint
}

struct JourneyLogEntry: Identifiable, Equatable, Sendable, Codable {
    let id: UUID
    let landmarkName: String
    let address: String
    let timeString: String
    let iconName: String
    let entryType: JourneyLogEntryType
    var coordinate: CLLocationCoordinate2D?
    
    enum CodingKeys: String, CodingKey {
        case id, landmarkName, address, timeString, iconName, entryType, latitude, longitude
    }

    init(
        id: UUID = UUID(),
        landmarkName: String,
        address: String,
        timeString: String,
        iconName: String = "mappin.fill",
        entryType: JourneyLogEntryType = .checkpoint,
        coordinate: CLLocationCoordinate2D? = nil
    ) {
        self.id = id
        self.landmarkName = landmarkName
        self.address = address
        self.timeString = timeString
        self.iconName = iconName
        self.entryType = entryType
        self.coordinate = coordinate
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        landmarkName = try container.decode(String.self, forKey: .landmarkName)
        address = try container.decode(String.self, forKey: .address)
        timeString = try container.decode(String.self, forKey: .timeString)
        iconName = try container.decode(String.self, forKey: .iconName)
        entryType = try container.decode(JourneyLogEntryType.self, forKey: .entryType)
        
        let lat = try container.decodeIfPresent(Double.self, forKey: .latitude)
        let lon = try container.decodeIfPresent(Double.self, forKey: .longitude)
        if let lat = lat, let lon = lon {
            coordinate = CLLocationCoordinate2D(latitude: lat, longitude: lon)
        } else {
            coordinate = nil
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(landmarkName, forKey: .landmarkName)
        try container.encode(address, forKey: .address)
        try container.encode(timeString, forKey: .timeString)
        try container.encode(iconName, forKey: .iconName)
        try container.encode(entryType, forKey: .entryType)
        
        if let coord = coordinate {
            try container.encode(coord.latitude, forKey: .latitude)
            try container.encode(coord.longitude, forKey: .longitude)
        }
    }

    static func == (lhs: JourneyLogEntry, rhs: JourneyLogEntry) -> Bool {
        lhs.id == rhs.id &&
        lhs.landmarkName == rhs.landmarkName &&
        lhs.address == rhs.address &&
        lhs.timeString == rhs.timeString &&
        lhs.iconName == rhs.iconName &&
        lhs.entryType == rhs.entryType &&
        lhs.coordinate?.latitude == rhs.coordinate?.latitude &&
        lhs.coordinate?.longitude == rhs.coordinate?.longitude
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
