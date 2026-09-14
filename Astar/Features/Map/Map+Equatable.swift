import MapKit
import CoreLocation

// MARK: - CLLocationCoordinate2D Equatable Conformance
//
// ── Why this file exists ──────────────────────────────────────────────────────
// `CLLocationCoordinate2D` is a plain C struct (latitude: Double, longitude: Double)
// defined by Apple's CoreLocation framework.  Because Apple owns it, we cannot add
// a stored property or change its definition – we can only extend it.
//
// Swift's value-equality protocol `Equatable` is analogous to Python's `__eq__`.
// Without it, you cannot compare two coordinates with `==`, which breaks:
//   • TCA's `State: Equatable` requirement (the store uses equality to decide
//     whether to re-render the UI – similar to React's shouldComponentUpdate).
//   • SwiftUI's diffing engine.
//   • Unit-test assertions like `XCTAssertEqual(coord1, coord2)`.
//
// ── What @retroactive means ───────────────────────────────────────────────────
// `@retroactive` (Swift 5.7+) is a compiler annotation that says:
//   "I know I'm adding a protocol conformance to a type I don't own.
//    I take responsibility for any future conflicts if Apple adds it themselves."
// In Python terms, this is like monkey-patching a class from an external library
// by replacing its `__eq__` method – it works, but you own the risk.
//
// ── Why a custom == instead of Hashable ──────────────────────────────────────
// We only need equality here (not hashing), so `Equatable` is sufficient.
// Two GPS coordinates are equal iff both their latitude AND longitude match exactly.
// Floating-point equality on coordinates is acceptable because we're comparing
// values that come from the same CLLocation object or were assigned programmatically –
// not results of floating-point arithmetic that could drift.

extension CLLocationCoordinate2D: @retroactive Equatable {

    /// Returns `true` when both coordinates share identical latitude **and** longitude.
    ///
    /// - Parameters:
    ///   - lhs: Left-hand side coordinate (e.g. the stored `State` value).
    ///   - rhs: Right-hand side coordinate (e.g. a newly received GPS reading).
    /// - Returns: `Bool` – `true` only when both components match.
    ///
    /// **CS analogy:** Like Python's `__eq__` on a `(lat, lon)` named-tuple:
    /// ```python
    /// def __eq__(self, other):
    ///     return self.latitude == other.latitude and self.longitude == other.longitude
    /// ```
    public static func == (lhs: CLLocationCoordinate2D, rhs: CLLocationCoordinate2D) -> Bool {
        lhs.latitude == rhs.latitude && lhs.longitude == rhs.longitude
    }
}
