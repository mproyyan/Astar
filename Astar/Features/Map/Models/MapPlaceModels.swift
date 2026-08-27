//
//  MapPlaceModels.swift
//  Astar
//
//  Created by Dimas Prihady Setyawan on 25/08/26.
//

import CoreLocation
import Foundation
import SwiftUI

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
