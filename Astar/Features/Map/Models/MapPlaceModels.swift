//
//  MapPlaceModels.swift
//  Astar
//
//  Created by Dimas Prihady Setyawan on 25/08/26.
//

import Foundation

struct Person: Identifiable, Equatable, Sendable {
    let id: UUID
    let name: String
    let status: String

    init(id: UUID = UUID(), name: String, status: String) {
        self.id = id
        self.name = name
        self.status = status
    }
}

struct SavedPlace: Identifiable, Equatable, Sendable {
    let id: UUID
    let name: String
    let subtitle: String
    let iconName: String

    init(id: UUID = UUID(), name: String, subtitle: String, iconName: String) {
        self.id = id
        self.name = name
        self.subtitle = subtitle
        self.iconName = iconName
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
        SavedPlace(name: "Home", subtitle: "Bendungan Hilir, South Jakarta", iconName: "house.fill"),
        SavedPlace(name: "Gym", subtitle: "Agora Mall, Central Jakarta", iconName: "figure.strengthtraining.traditional"),
        SavedPlace(name: "Office", subtitle: "Bendungan Hilir, South Jakarta", iconName: "building.2.fill"),
        SavedPlace(name: "Agora Mall", subtitle: "Jl. M.H. Thamrin No. 10, Central Jakarta", iconName: "bag.fill"),
        SavedPlace(name: "Grand Indonesia", subtitle: "Jl. M.H. Thamrin No. 1, Central Jakarta", iconName: "bag.fill"),
        SavedPlace(name: "Plaza Indonesia", subtitle: "Jl. M.H. Thamrin No. 28-30, Central Jakarta", iconName: "bag.fill"),
        SavedPlace(name: "Senayan City", subtitle: "Jl. Asia Afrika No. 19, South Jakarta", iconName: "bag.fill"),
        SavedPlace(name: "Pacific Place", subtitle: "SCBD, Jl. Jend. Sudirman, South Jakarta", iconName: "building.fill"),
        SavedPlace(name: "Gelora Bung Karno", subtitle: "Jl. Pintu Satu Senayan, Central Jakarta", iconName: "figure.run"),
        SavedPlace(name: "Monumen Nasional", subtitle: "Gambir, Central Jakarta", iconName: "landmark.fill"),
        SavedPlace(name: "MRT Bundaran HI", subtitle: "Jl. M.H. Thamrin, Central Jakarta", iconName: "tram.fill"),
        SavedPlace(name: "Stasiun Sudirman", subtitle: "Jl. Kendal No. 1, Central Jakarta", iconName: "train.side.front.car"),
        SavedPlace(name: "Kopi Kenangan Bendungan Hilir", subtitle: "Jl. Bendungan Hilir No. 15, Central Jakarta", iconName: "cup.and.saucer.fill")
    ]
}
