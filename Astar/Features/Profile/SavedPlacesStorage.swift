import Foundation
import CoreLocation

/// ============================================================================
/// 📍 PERSISTENT STORAGE: SAVED PLACES (Home & Office)
/// ============================================================================
///
/// 💡 TEORI & ANALOGI PYTHON / COMPUTER SCIENCE:
/// - Menerapkan **Data Access Object (DAO) / Active Record Pattern**:
///   Menyediakan fungsi CRUD statis (`load`, `save`, `clear`) yang mengabstraksikan
///   serialisasi JSON biner ke `UserDefaults`.
/// - Mendukung multi-user namespace (setiap Apple User ID memiliki key database terpisah:
///   `saved_places_<appleUserId>`).
/// - Reaktivitas berbasis Pub/Sub: Setiap mutasi data memancarkan
///   `NotificationCenter.default.post(name: savedPlacesDidChangeNotification)`
///   sehingga UI yang sedang menampilkan daftar tempat favorit langsung ter-update.
/// ============================================================================
enum SavedPlacesStorage {
    static let defaultUserId = "default_user"
    static let savedPlacesDidChangeNotification = Notification.Name("SavedPlacesDidChangeNotification")

    // ID Deterministik untuk lokasi default Home dan Office
    static let defaultHomeId = UUID(uuidString: "00000000-0000-0000-0001-000000000001")!
    static let defaultOfficeId = UUID(uuidString: "00000000-0000-0000-0001-000000000002")!

    /// Nilai benih (Seed Data) awal saat aplikasi baru dipasang
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

    /// Membaca array tempat tersimpan dari disk lokal:
    static func load(for userId: String = defaultUserId) -> [SavedPlace] {
        let rawId = userId.trimmingCharacters(in: .whitespacesAndNewlines)
        let effectiveId = rawId.isEmpty || rawId == defaultUserId ? currentEffectiveUserId : rawId
        let userKey = "saved_places_\(effectiveId)"
        guard let data = UserDefaults.standard.data(forKey: userKey),
              let places = try? JSONDecoder().decode([SavedPlace].self, from: data),
              !places.isEmpty else {
            // Cek data cadangan default_user jika namespace spesifik kosong
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

    /// Menyimpan array tempat ke disk lokal dan memancarkan notifikasi perubahan:
    static func save(_ places: [SavedPlace], for userId: String = defaultUserId) {
        let rawId = userId.trimmingCharacters(in: .whitespacesAndNewlines)
        let effectiveId = rawId.isEmpty || rawId == defaultUserId ? currentEffectiveUserId : rawId
        let userKey = "saved_places_\(effectiveId)"
        guard let data = try? JSONEncoder().encode(places) else { return }
        UserDefaults.standard.set(data, forKey: userKey)
        if effectiveId != defaultUserId {
            UserDefaults.standard.set(data, forKey: "saved_places_\(defaultUserId)")
        }
        // Kirim event agar UI merender ulang daftar lokasi tersimpan
        NotificationCenter.default.post(name: savedPlacesDidChangeNotification, object: places)
    }

    /// Menghapus seluruh data lokasi tersimpan:
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
