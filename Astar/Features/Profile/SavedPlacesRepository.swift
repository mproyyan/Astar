//
//  SavedPlacesRepository.swift
//  Astar
//
//  Created by Safa Auliya Hidayat on 27/08/26.
//

import ComposableArchitecture
import Foundation

protocol SavedPlacesRepositoryProtocol: Sendable {
    func load(for userId: String) async -> [SavedPlace]
    func save(_ places: [SavedPlace], for userId: String) async
    func delete(id: UUID, for userId: String) async -> [SavedPlace]
    func updateLabel(id: UUID, newLabel: String, for userId: String) async -> [SavedPlace]
}

struct UserDefaultsSavedPlacesRepository: SavedPlacesRepositoryProtocol {
    init() {}

    func load(for userId: String) async -> [SavedPlace] {
        SavedPlacesStorage.load(for: userId)
    }

    func save(_ places: [SavedPlace], for userId: String) async {
        SavedPlacesStorage.save(places, for: userId)
    }

    func delete(id: UUID, for userId: String) async -> [SavedPlace] {
        var places = SavedPlacesStorage.load(for: userId)
        places.removeAll { $0.id == id }
        SavedPlacesStorage.save(places, for: userId)
        return places
    }

    func updateLabel(id: UUID, newLabel: String, for userId: String) async -> [SavedPlace] {
        var places = SavedPlacesStorage.load(for: userId)
        if let index = places.firstIndex(where: { $0.id == id }) {
            let existing = places[index]
            let trimmedLabel = newLabel.trimmingCharacters(in: .whitespacesAndNewlines)
            let iconName: String
            switch trimmedLabel.lowercased() {
            case "home": iconName = "house.fill"
            case "office", "work": iconName = "building.2.fill"
            default: iconName = existing.iconName.isEmpty ? "key.fill" : existing.iconName
            }
            places[index] = SavedPlace(
                id: existing.id,
                name: existing.name,
                subtitle: existing.subtitle,
                iconName: iconName,
                distance: existing.distance,
                latitude: existing.latitude,
                longitude: existing.longitude,
                label: trimmedLabel.isEmpty ? existing.label : trimmedLabel
            )
            SavedPlacesStorage.save(places, for: userId)
        }
        return places
    }
}

// MARK: - TCA Dependency Key
enum SavedPlacesRepositoryKey: DependencyKey {
    static let liveValue: any SavedPlacesRepositoryProtocol = UserDefaultsSavedPlacesRepository()
}

extension DependencyValues {
    var savedPlacesRepository: any SavedPlacesRepositoryProtocol {
        get { self[SavedPlacesRepositoryKey.self] }
        set { self[SavedPlacesRepositoryKey.self] = newValue }
    }
}
