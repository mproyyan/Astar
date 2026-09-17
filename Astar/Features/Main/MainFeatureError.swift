/// ============================================================================
/// ⚠️ STRONGLY TYPED ERROR DOMAIN (MainFeatureError)
/// ============================================================================
///
/// 💡 COMPUTER SCIENCE CONCEPTS:
/// - **Algebraic Error Handling & Boundary Sanitization**:
///   In distributed architectures, raw network exceptions (`NSError`, `CKError`) contain
///   unserialized memory pointers or OS-specific codes. Wrapping them into an Equatable, Sendable
///   struct creates an immutable boundary that can safely traverse concurrency domains and be
///   asserted in automated unit tests.
///
/// 🌍 REAL-LIFE ANALOGY:
///   Think of a foreign customs border. Raw cargo from an overseas ship may contain unpredictable
///   foreign labeling. The customs inspector repacks and seals it into a standardized, certified
///   box with an unambiguous inspection label before allowing it into domestic warehouses.
/// ============================================================================
import Foundation

struct FetchUsersError: Error, Equatable, Sendable {
    let message: String
    init(error: Error) {
        self.message = error.localizedDescription
    }
}
