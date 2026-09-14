import ComposableArchitecture
import CoreLocation
import MapKit

/// ============================================================================
/// 📑 BOTTOM SHEET ENUM REDUCER (MapSheetFeature)
/// ============================================================================
///
/// 💡 TEORI & ANALOGI PYTHON / COMPUTER SCIENCE:
/// - Menggunakan fitur canggih macro TCA `@Reducer(state: .equatable, action: .equatable)`
///   pada sebuah Enum (Algebraic Sum Type).
/// - **Mutual Exclusivity Principle**:
///   Layar peta hanya bisa menampilkan SATU jenis bottom sheet pada satu waktu:
///   1. `.search`: Pengguna sedang mencari tempat / mengetik query.
///   2. `.direction`: Pengguna sedang melihat rute atau aktif bernavigasi.
///   3. `.walker`: Pengguna sedang melihat info profil seorang pejalan kaki.
/// - Model enum ini secara matematis mencegah *bug tumpang-tindih modal* (impossible states).
/// ============================================================================
@Reducer(state: .equatable, action: .equatable)
enum MapSheetFeature {
  case search(MapSearchSheetFeature)
  case direction(MapDirectionSheetFeature)
  case walker(MapWalkerSheetFeature)
}
