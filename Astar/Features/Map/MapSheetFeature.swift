import ComposableArchitecture
import CoreLocation
import MapKit

@Reducer(state: .equatable, action: .equatable)
enum MapSheetFeature {
  case search(MapSearchSheetFeature)
  case direction(MapDirectionSheetFeature)
  case walker(MapWalkerSheetFeature)
}
