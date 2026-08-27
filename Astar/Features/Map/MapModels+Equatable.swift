import MapKit
import CoreLocation
import ComposableArchitecture

extension MKRoute: @retroactive Equatable {
    public static func == (lhs: MKRoute, rhs: MKRoute) -> Bool {
        return lhs.name == rhs.name && lhs.distance == rhs.distance && lhs.expectedTravelTime == rhs.expectedTravelTime
    }
}
