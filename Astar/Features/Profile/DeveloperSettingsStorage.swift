//
//  DeveloperSettingsStorage.swift
//  Astar
//

import Foundation

/// ============================================================================
/// ⚙️ DEVELOPER & DEBUG SETTINGS STORAGE
/// ============================================================================
///
/// 💡 TEORI & ANALOGI PYTHON / COMPUTER SCIENCE:
/// - Menggunakan penyimpanan pasangan kunci-nilai (Key-Value Store) lokal `UserDefaults`
///   (mirip dengan file konfigurasi .ini / .env atau modul `shelve` di Python).
/// - Menggunakan Swift **Computed Properties** dengan `get` dan `set` untuk
///   mengakses disk secara transparan.
/// - Fitur mock penting: `isDoeWalkingMockEnabled` memungkinkan simulasi walker virtual
///   bergerak di peta tanpa developer harus keluar ruangan menguji GPS fisik.
/// ============================================================================
enum DeveloperSettingsStorage {
  static let isDevModeKey = "is_development_mode_enabled"
  static let isShowRouteGuideKey = "is_show_route_guide_enabled"
  static let isDoeWalkingMockKey = "is_doe_walking_mock_enabled"

  /// Flag mode developer (menampilkan banner/tombol inspeksi tambahan):
  static var isDevelopmentMode: Bool {
    get {
      UserDefaults.standard.bool(forKey: isDevModeKey)
    }
    set {
      UserDefaults.standard.set(newValue, forKey: isDevModeKey)
    }
  }

  /// Flag menampilkan garis petunjuk belokan rute di peta:
  static var isShowRouteGuide: Bool {
    get {
      if UserDefaults.standard.object(forKey: isShowRouteGuideKey) == nil {
        return true
      }
      return UserDefaults.standard.bool(forKey: isShowRouteGuideKey)
    }
    set {
      UserDefaults.standard.set(newValue, forKey: isShowRouteGuideKey)
    }
  }

  /// Flag simulasi pergerakan pejalan kaki virtual (John Doe Mock):
  static var isDoeWalkingMockEnabled: Bool {
    get {
      if UserDefaults.standard.object(forKey: isDoeWalkingMockKey) == nil {
        return true
      }
      return UserDefaults.standard.bool(forKey: isDoeWalkingMockKey)
    }
    set {
      UserDefaults.standard.set(newValue, forKey: isDoeWalkingMockKey)
    }
  }
}
