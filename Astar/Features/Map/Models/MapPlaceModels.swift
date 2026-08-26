//
//  MapPlaceModels.swift
//  Astar
//
//  Created by Dimas Prihady Setyawan on 25/08/26.
//

import CloudKit
import CoreLocation
import Foundation
import SwiftUI

struct Person: Identifiable, Equatable, Sendable {
    let id: UUID
    let name: String
    /// Raw status string, matches `PersonStatus.rawValue`
    let status: String
    /// CloudKit record ID in the public DB — nil for sample/preview data
    let recordID: CKRecord.ID?

    init(
        id: UUID = UUID(),
        name: String,
        status: String,
        recordID: CKRecord.ID? = nil
    ) {
        self.id = id
        self.name = name
        self.status = status
        self.recordID = recordID
    }

    /// Typed status derived from the raw `status` string.
    var personStatus: PersonStatus {
        PersonStatus(rawValue: status) ?? .idle
    }
}

struct SavedPlace: Identifiable, Equatable, Sendable {
    let id: UUID
    let name: String
    let subtitle: String
    let iconName: String
    let distance: String?
    let coordinate: CLLocationCoordinate2D?

    init(
        id: UUID = UUID(),
        name: String,
        subtitle: String,
        iconName: String,
        distance: String? = nil,
        coordinate: CLLocationCoordinate2D? = nil
    ) {
        self.id = id
        self.name = name
        self.subtitle = subtitle
        self.iconName = iconName
        self.distance = distance
        self.coordinate = coordinate
    }
}

extension SavedPlace {
    var categoryColor: Color {
        SavedPlace.categoryColor(for: iconName)
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
            return Color(red: 0.25, green: 0.60, blue: 0.95) // Home: Sky Blue

        case "location.fill":
            return Color.blue // Current Location: Apple Blue

        default:
            return Color(red: 0.55, green: 0.62, blue: 0.82) // General/Address: Periwinkle Slate
        }
    }
}

enum MapSampleData {
    static let people: [Person] = [
        Person(name: "Awan", status: "Walking"),
        Person(name: "Royyan", status: "Idle"),
        Person(name: "Safa", status: "Idle"),
        Person(name: "Nadia", status: "Idle")
    ]

    static let savedPlaces: [SavedPlace] = [
        SavedPlace(name: "Home", subtitle: "Bendungan Hilir, South Jakarta", iconName: "house.fill"),
        SavedPlace(name: "Gym", subtitle: "Agora Mall, Central Jakarta", iconName: "figure.strengthtraining.traditional"),
        SavedPlace(name: "Office", subtitle: "Bendungan Hilir, South Jakarta", iconName: "building.2.fill")
    ]

    static let allSearchablePlaces: [SavedPlace] = [
        SavedPlace(name: "Home", subtitle: "Bendungan Hilir, South Jakarta", iconName: "house.fill", distance: "350 m"),
        SavedPlace(name: "Gym", subtitle: "Agora Mall, Central Jakarta", iconName: "figure.strengthtraining.traditional", distance: "450 m"),
        SavedPlace(name: "Office", subtitle: "Bendungan Hilir, South Jakarta", iconName: "building.2.fill", distance: "500 m"),
        SavedPlace(name: "Autograph Tower", subtitle: "Thamrin Nine, Jl. M.H. Thamrin No. 10, Central Jakarta", iconName: "building.2.fill", distance: "250 m"),
        SavedPlace(name: "Agora Mall", subtitle: "Jl. M.H. Thamrin No. 10, Central Jakarta", iconName: "bag.fill", distance: "450 m"),
        SavedPlace(name: "Grand Indonesia", subtitle: "Jl. M.H. Thamrin No. 1, Central Jakarta", iconName: "bag.fill", distance: "850 m"),
        SavedPlace(name: "Plaza Indonesia", subtitle: "Jl. M.H. Thamrin No. 28-30, Central Jakarta", iconName: "bag.fill", distance: "1.1 km"),
        SavedPlace(name: "Starbucks Reserve Sudirman", subtitle: "Menara Astra, Jl. Jend. Sudirman Kav 5-6", iconName: "cup.and.saucer.fill", distance: "600 m"),
        SavedPlace(name: "MRT Bundaran HI", subtitle: "Jl. M.H. Thamrin, Central Jakarta", iconName: "tram.fill", distance: "950 m"),
        SavedPlace(name: "Stasiun Sudirman", subtitle: "Jl. Kendal No. 1, Central Jakarta", iconName: "train.side.front.car", distance: "1.3 km"),
        SavedPlace(name: "Kopi Kenangan Bendungan Hilir", subtitle: "Jl. Bendungan Hilir No. 15, Central Jakarta", iconName: "cup.and.saucer.fill", distance: "400 m"),
        SavedPlace(name: "Gelora Bung Karno", subtitle: "Jl. Pintu Satu Senayan, Central Jakarta", iconName: "figure.run", distance: "2.4 km"),
        SavedPlace(name: "Hutan Kota GBK", subtitle: "Pintu Tujuh Senayan, Central Jakarta", iconName: "tree.fill", distance: "2.6 km"),
        SavedPlace(name: "Pacific Place", subtitle: "SCBD, Jl. Jend. Sudirman, South Jakarta", iconName: "building.fill", distance: "3.1 km"),
        SavedPlace(name: "Senayan City", subtitle: "Jl. Asia Afrika No. 19, South Jakarta", iconName: "bag.fill", distance: "3.8 km"),
        SavedPlace(name: "McDonald's Sarinah", subtitle: "Jl. M.H. Thamrin No. 11, Central Jakarta", iconName: "fork.knife", distance: "1.8 km"),
        SavedPlace(name: "Monumen Nasional", subtitle: "Gambir, Central Jakarta", iconName: "landmark.fill", distance: "4.2 km"),
        SavedPlace(name: "Blok M Hub", subtitle: "Jl. Panglima Polim, South Jakarta", iconName: "tram.fill", distance: "5.6 km"),
        SavedPlace(name: "Central Park Mall", subtitle: "Jl. Letjen S. Parman No. 28, West Jakarta", iconName: "bag.fill", distance: "6.8 km"),
        SavedPlace(name: "Celebrity Fitness FX Sudirman", subtitle: "FX Sudirman Fl. 6, Central Jakarta", iconName: "figure.strengthtraining.traditional", distance: "3.2 km")
    ]
}
