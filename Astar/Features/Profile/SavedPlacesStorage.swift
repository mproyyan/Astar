//
//  SavedPlacesStorage.swift
//  Astar
//
//  Created by Safa Auliya Hidayat on 27/08/26.
//

import Foundation

enum SavedPlacesStorage {
    private static let repository = UserDefaultsSavedPlacesRepository()

    /// Loads saved places for a specific user ID
    static func load(for userId: String) -> [SavedPlace] {
        let userKey = "saved_places_\(userId)"
        guard let data = UserDefaults.standard.data(forKey: userKey) else { return [] }
        return (try? JSONDecoder().decode([SavedPlace].self, from: data)) ?? []
    }

    /// Saves places array for a specific user ID
    static func save(_ places: [SavedPlace], for userId: String) {
        let userKey = "saved_places_\(userId)"
        guard let data = try? JSONEncoder().encode(places) else { return }
        UserDefaults.standard.set(data, forKey: userKey)
    }

    /// Clears saved places for a specific user ID
    static func clear(for userId: String) {
        let userKey = "saved_places_\(userId)"
        UserDefaults.standard.removeObject(forKey: userKey)
    }
}
