import Foundation
import CoreLocation
import MapKit
import ComposableArchitecture

@DependencyClient
struct PlaceSearchClient: Sendable {
  var searchPlaces: @Sendable (_ query: String, _ userLocation: CLLocationCoordinate2D?) async -> [SavedPlace] = { _, _ in [] }
}

extension PlaceSearchClient: DependencyKey {
  static let liveValue = Self(
    searchPlaces: { query, userLocation in
      await PlaceSearchEngine.searchPlaces(query: query, userLocation: userLocation)
    }
  )
  static let testValue = Self()
}

extension DependencyValues {
  var placeSearch: PlaceSearchClient {
    get { self[PlaceSearchClient.self] }
    set { self[PlaceSearchClient.self] = newValue }
  }
}

@MainActor
enum PlaceSearchEngine {
  private struct ScoredPlace {
    let place: SavedPlace
    let score: Double
    let distanceMeters: Double
  }

  static func searchPlaces(
    query: String,
    userLocation: CLLocationCoordinate2D?
  ) async -> [SavedPlace] {
    let cleanQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !cleanQuery.isEmpty else { return [] }

    let center = userLocation ?? CLLocationCoordinate2D(latitude: -6.2088, longitude: 106.8456)
    let searchRegion = MKCoordinateRegion(
      center: center,
      span: MKCoordinateSpan(latitudeDelta: 0.5, longitudeDelta: 0.5)
    )

    var liveResults: [SavedPlace] = []
    var seenKeys = Set<String>()

    // 1. Direct MKLocalSearch
    let searchRequest = MKLocalSearch.Request()
    searchRequest.naturalLanguageQuery = cleanQuery
    searchRequest.resultTypes = [.pointOfInterest, .address]
    searchRequest.region = searchRegion

    if let directResponse = try? await MKLocalSearch(request: searchRequest).start() {
      for item in directResponse.mapItems {
        if let place = convertMapItemToSavedPlace(item: item, userLocation: userLocation, cleanQuery: cleanQuery) {
          let dedupKey = "\(place.name.lowercased())_\(place.subtitle.lowercased())"
          if !seenKeys.contains(dedupKey) {
            seenKeys.insert(dedupKey)
            liveResults.append(place)
          }
        }
      }
    }

    // 2. Fetch completions from MKLocalSearchCompleter for street/address matches
    let completer = SearchCompleterEngine()
    let completions = await completer.getCompletions(query: cleanQuery, region: searchRegion)

    await withTaskGroup(of: SavedPlace?.self) { group in
      for completion in completions.prefix(12) {
        group.addTask { @MainActor in
          let compRequest = MKLocalSearch.Request(completion: completion)
          compRequest.resultTypes = [.pointOfInterest, .address]
          compRequest.region = searchRegion

          if let compResponse = try? await MKLocalSearch(request: compRequest).start(),
             let firstItem = compResponse.mapItems.first {
            return convertMapItemToSavedPlace(item: firstItem, userLocation: userLocation, cleanQuery: completion.title)
          }

          let icon = completion.subtitle.localizedCaseInsensitiveContains("station") ? "tram.fill" :
                     completion.subtitle.localizedCaseInsensitiveContains("restaurant") || completion.subtitle.localizedCaseInsensitiveContains("food") ? "fork.knife" :
                     completion.subtitle.localizedCaseInsensitiveContains("mall") || completion.subtitle.localizedCaseInsensitiveContains("shop") ? "bag.fill" : "mappin.and.ellipse"

          return SavedPlace(
            name: completion.title,
            subtitle: completion.subtitle.isEmpty ? "Jakarta, Indonesia" : completion.subtitle,
            iconName: icon,
            distance: nil,
            coordinate: nil
          )
        }
      }

      for await maybePlace in group {
        if let place = maybePlace {
          let dedupKey = "\(place.name.lowercased())_\(place.subtitle.lowercased())"
          if !seenKeys.contains(dedupKey) {
            seenKeys.insert(dedupKey)
            liveResults.append(place)
          }
        }
      }
    }

    // 3. Merge with local searchable places
    let localMatches = fallbackSearch(query: cleanQuery, userLocation: userLocation)
    for local in localMatches {
      let dedupKey = "\(local.name.lowercased())_\(local.subtitle.lowercased())"
      if !seenKeys.contains(dedupKey) {
        seenKeys.insert(dedupKey)
        liveResults.append(local)
      }
    }

    return rankResults(places: liveResults, query: cleanQuery, userLocation: userLocation)
  }

  private static func convertMapItemToSavedPlace(
    item: MKMapItem,
    userLocation: CLLocationCoordinate2D?,
    cleanQuery: String
  ) -> SavedPlace? {
    let placemark = item.placemark
    let name = item.name ?? placemark.name ?? cleanQuery

    let addressParts = [
      placemark.subThoroughfare,
      placemark.thoroughfare,
      placemark.subLocality,
      placemark.locality,
      placemark.administrativeArea
    ].compactMap { $0 }.filter { !$0.isEmpty }

    let subtitle: String
    if !addressParts.isEmpty {
      subtitle = addressParts.joined(separator: ", ")
    } else if let title = placemark.title, title != name {
      subtitle = title
    } else {
      subtitle = placemark.country ?? "Unknown Location"
    }

    var distanceString: String? = nil
    if let userLocation {
      let userCL = CLLocation(latitude: userLocation.latitude, longitude: userLocation.longitude)
      let itemCL = CLLocation(latitude: placemark.coordinate.latitude, longitude: placemark.coordinate.longitude)
      let distanceMeters = userCL.distance(from: itemCL)

      if distanceMeters < 1000 {
        distanceString = "\(Int(distanceMeters)) m"
      } else {
        distanceString = String(format: "%.1f km", distanceMeters / 1000.0)
      }
    }

    let icon = categoryIcon(for: item.pointOfInterestCategory)

    return SavedPlace(
      name: name,
      subtitle: subtitle,
      iconName: icon,
      distance: distanceString,
      coordinate: placemark.coordinate
    )
  }

  private static func rankResults(
    places: [SavedPlace],
    query: String,
    userLocation: CLLocationCoordinate2D?
  ) -> [SavedPlace] {
    let lowerQuery = query.lowercased()
    let userCL = userLocation.map { CLLocation(latitude: $0.latitude, longitude: $0.longitude) }

    let scored = places.map { place -> ScoredPlace in
      let lowerName = place.name.lowercased()
      let lowerSubtitle = place.subtitle.lowercased()

      var score: Double = 0

      if lowerName == lowerQuery {
        score += 1000
      } else if lowerName.hasPrefix(lowerQuery) {
        score += 500
      } else if lowerName.contains(lowerQuery) {
        score += 250
      } else if lowerSubtitle.contains(lowerQuery) {
        score += 100
      } else {
        score += 10
      }

      var distMeters: Double = Double.infinity
      if let userCL, let coord = place.coordinate {
        let placeCL = CLLocation(latitude: coord.latitude, longitude: coord.longitude)
        distMeters = userCL.distance(from: placeCL)
        let proximityBonus = max(0.0, 150.0 - (distMeters / 100.0))
        score += proximityBonus
      }

      return ScoredPlace(place: place, score: score, distanceMeters: distMeters)
    }

    return scored
      .sorted { lhs, rhs in
        if abs(lhs.score - rhs.score) > 1.0 {
          return lhs.score > rhs.score
        }
        return lhs.distanceMeters < rhs.distanceMeters
      }
      .map(\.place)
  }

  private static func fallbackSearch(query: String, userLocation: CLLocationCoordinate2D?) -> [SavedPlace] {
    MapSampleData.allSearchablePlaces.filter {
      $0.name.localizedStandardContains(query) || $0.subtitle.localizedStandardContains(query)
    }
  }

  static func categoryIcon(for category: MKPointOfInterestCategory?) -> String {
    guard let category else { return "mappin.and.ellipse" }
    switch category {
    case .restaurant, .foodMarket:
      return "fork.knife"
    case .cafe, .bakery:
      return "cup.and.saucer.fill"
    case .store:
      return "bag.fill"
    case .fitnessCenter:
      return "figure.strengthtraining.traditional"
    case .publicTransport:
      return "tram.fill"
    case .airport:
      return "airplane"
    case .hotel:
      return "bed.double.fill"
    case .hospital, .pharmacy:
      return "cross.case.fill"
    case .park, .nationalPark:
      return "tree.fill"
    case .school, .university:
      return "graduationcap.fill"
    case .landmark:
      return "landmark.fill"
    case .nightlife:
      return "wineglass.fill"
    case .gasStation, .evCharger:
      return "fuelpump.fill"
    default:
      return "mappin.and.ellipse"
    }
  }
}

@MainActor
final class SearchCompleterEngine: NSObject, MKLocalSearchCompleterDelegate {
  private let completer = MKLocalSearchCompleter()
  private var continuation: CheckedContinuation<[MKLocalSearchCompletion], Never>?

  override init() {
    super.init()
    completer.delegate = self
    completer.resultTypes = [.address, .pointOfInterest]
  }

  func getCompletions(query: String, region: MKCoordinateRegion) async -> [MKLocalSearchCompletion] {
    completer.region = region
    completer.queryFragment = query

    return await withCheckedContinuation { continuation in
      self.continuation = continuation
      Task { @MainActor in
        try? await Task.sleep(for: .milliseconds(800))
        if let cont = self.continuation {
          self.continuation = nil
          cont.resume(returning: self.completer.results)
        }
      }
    }
  }

  func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
    if let cont = continuation {
      continuation = nil
      cont.resume(returning: completer.results)
    }
  }

  func completer(_ completer: MKLocalSearchCompleter, didFailWithError error: Error) {
    if let cont = continuation {
      continuation = nil
      cont.resume(returning: [])
    }
  }
}
