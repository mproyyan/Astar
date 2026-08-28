import ComposableArchitecture
import CoreLocation
import MapKit

@Reducer
struct MapSearchSheetFeature {
  @ObservableState
  struct State: Equatable {
    var searchQuery: String = ""
    var searchResults: [SavedPlace] = []
    var isLoading: Bool = false
    var userLocation: CLLocationCoordinate2D?
  }

  enum Action: Equatable {
    case searchQueryChanged(String)
    case searchResponse([SavedPlace])
    case clearSearchTapped
    case selectPlace(SavedPlace)
    case delegate(Delegate)

    @CasePathable
    enum Delegate: Equatable {
      case dismissed
    }
  }

  @Dependency(\.placeSearch) var placeSearch
  @Dependency(\.continuousClock) var clock

  var body: some Reducer<State, Action> {
    Reduce { state, action in
      switch action {
      case let .searchQueryChanged(query):
        state.searchQuery = query
        let cleanQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanQuery.isEmpty else {
          state.searchResults = []
          state.isLoading = false
          return .cancel(id: "searchDebounce")
        }

        state.isLoading = true
        let userLocation = state.userLocation

        return .run { send in
          try await clock.sleep(for: .milliseconds(300))
          let results = await placeSearch.searchPlaces(query: cleanQuery, userLocation: userLocation)
          await send(.searchResponse(results))
        }
        .cancellable(id: "searchDebounce", cancelInFlight: true)

      case let .searchResponse(results):
        state.isLoading = false
        state.searchResults = results
        return .none

      case .clearSearchTapped:
        state.searchQuery = ""
        state.searchResults = []
        state.isLoading = false
        return .concatenate(
          .cancel(id: "searchDebounce"),
          .send(.delegate(.dismissed))
        )

      case .selectPlace:
        // Handled by parent
        return .none

      case .delegate:
        return .none
      }
    }
  }
}
