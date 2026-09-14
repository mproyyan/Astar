import MapKit
import CoreLocation
import ComposableArchitecture

// MARK: - MKRoute Equatable Conformance
//
// ── Why MKRoute needs manual Equatable ───────────────────────────────────────
// `MKRoute` is an Objective-C class (reference type / heap object) from MapKit.
// In Swift, reference types inherit identity equality (`===`) by default – two
// variables are "equal" only if they point to the *same object in memory*.
// That is too strict for TCA: after a route is recalculated, MapKit returns a
// brand-new `MKRoute` object even if the path didn't change, so identity-based
// equality would always report "changed" and trigger unnecessary re-renders.
//
// Python analogy:
//   ```python
//   # Python's default == on objects is identity (like Swift's ===):
//   route1 is route2   # True only if same object
//   # We want value equality – similar to overriding __eq__ in Python:
//   def __eq__(self, other):
//       return self.name == other.name and self.distance == other.distance ...
//   ```
//
// ── Value semantics vs Reference semantics ────────────────────────────────────
// • Swift structs  = Value types  (like Python namedtuples / dataclasses).
//   Copying a struct gives an independent copy – mutating one doesn't affect the other.
// • Swift classes  = Reference types (like regular Python objects).
//   Two variables can point to the same object; mutation through one is visible via the other.
//
// TCA's `State` must be a VALUE type (struct) so the reducer can compare
// old vs new state cheaply.  When State contains reference types like `MKRoute`,
// we must teach Swift how to compare them by value – hence this conformance.
//
// ── Why these three fields? ───────────────────────────────────────────────────
// `name`, `distance`, and `expectedTravelTime` together uniquely identify a
// walking route in practice.  Using all three avoids false positives (two routes
// with the same name but different lengths) while keeping the comparison O(1).
//
// ── @retroactive ─────────────────────────────────────────────────────────────
// Same rationale as Map+Equatable.swift: we don't own MKRoute (Apple does),
// so Swift requires the `@retroactive` annotation to acknowledge the risk of
// conflict if Apple later adds their own Equatable conformance.

extension MKRoute: @retroactive Equatable {

    /// Value-based equality for `MKRoute`.
    ///
    /// Two routes are considered equal when their human-readable `name`,
    /// total walking `distance` (in metres), and `expectedTravelTime`
    /// (in seconds) all match.
    ///
    /// - Note: `polyline` equality is intentionally omitted because comparing
    ///   the raw geometry (hundreds of GPS points) is expensive and unnecessary
    ///   for UI diffing purposes.
    public static func == (lhs: MKRoute, rhs: MKRoute) -> Bool {
        return lhs.name == rhs.name && lhs.distance == rhs.distance && lhs.expectedTravelTime == rhs.expectedTravelTime
    }
}
