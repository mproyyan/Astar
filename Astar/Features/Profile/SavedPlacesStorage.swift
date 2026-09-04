import Foundation
import CoreLocation

enum SavedPlacesStorage {
    static let defaultUserId = "default_user"
    static let savedPlacesDidChangeNotification = Notification.Name("SavedPlacesDidChangeNotification")

    static let defaultHomeId = UUID(uuidString: "00000000-0000-0000-0001-000000000001")!
    static let defaultOfficeId = UUID(uuidString: "00000000-0000-0000-0001-000000000002")!

    static var defaultInitialPlaces: [SavedPlace] {
        [
            SavedPlace(
                id: defaultHomeId,
                name: "Bendungan Hilir",
                subtitle: "Bendungan Hilir, South Jakarta",
                iconName: "house.fill",
                distance: "350 m",
                coordinate: CLLocationCoordinate2D(latitude: -6.2125, longitude: 106.8166),
                label: "Home"
            ),
            SavedPlace(
                id: defaultOfficeId,
                name: "Autograph Tower",
                subtitle: "Thamrin Nine, Central Jakarta",
                iconName: "building.2.fill",
                distance: "250 m",
                coordinate: CLLocationCoordinate2D(latitude: -6.1991, longitude: 106.8212),
                label: "Office"
            )
        ]
    }

    private static var currentEffectiveUserId: String {
        if let appleId = UserProfileStorage.load()?.appleUserId, !appleId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return appleId
        }
        return defaultUserId
    }

    /// Loads saved places for a specific user ID
    static func load(for userId: String = defaultUserId) -> [SavedPlace] {
        let rawId = userId.trimmingCharacters(in: .whitespacesAndNewlines)
        let effectiveId = rawId.isEmpty || rawId == defaultUserId ? currentEffectiveUserId : rawId
        let userKey = "saved_places_\(effectiveId)"
        guard let data = UserDefaults.standard.data(forKey: userKey),
              let places = try? JSONDecoder().decode([SavedPlace].self, from: data),
              !places.isEmpty else {
            // Check fallback default_user key
            if effectiveId != defaultUserId,
               let fallbackData = UserDefaults.standard.data(forKey: "saved_places_\(defaultUserId)"),
               let fallbackPlaces = try? JSONDecoder().decode([SavedPlace].self, from: fallbackData),
               !fallbackPlaces.isEmpty {
                return fallbackPlaces
            }
            return defaultInitialPlaces
        }
        return places
    }

    /// Saves places array for a specific user ID
    static func save(_ places: [SavedPlace], for userId: String = defaultUserId) {
        let rawId = userId.trimmingCharacters(in: .whitespacesAndNewlines)
        let effectiveId = rawId.isEmpty || rawId == defaultUserId ? currentEffectiveUserId : rawId
        let userKey = "saved_places_\(effectiveId)"
        guard let data = try? JSONEncoder().encode(places) else { return }
        UserDefaults.standard.set(data, forKey: userKey)
        if effectiveId != defaultUserId {
            UserDefaults.standard.set(data, forKey: "saved_places_\(defaultUserId)")
        }
        NotificationCenter.default.post(name: savedPlacesDidChangeNotification, object: places)
    }

    /// Clears saved places for a specific user ID
    static func clear(for userId: String = defaultUserId) {
        let rawId = userId.trimmingCharacters(in: .whitespacesAndNewlines)
        let effectiveId = rawId.isEmpty || rawId == defaultUserId ? currentEffectiveUserId : rawId
        let userKey = "saved_places_\(effectiveId)"
        UserDefaults.standard.removeObject(forKey: userKey)
        if effectiveId != defaultUserId {
            UserDefaults.standard.removeObject(forKey: "saved_places_\(defaultUserId)")
        }
        NotificationCenter.default.post(name: savedPlacesDidChangeNotification, object: nil)
    }
}
