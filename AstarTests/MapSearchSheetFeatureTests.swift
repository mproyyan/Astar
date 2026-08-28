import ComposableArchitecture
import Testing
import CoreLocation
@testable import Astar

struct MapSearchSheetFeatureTests {
  @Test
  @MainActor
  func testSearchQueryChangedEmpty() async {
    let store = TestStore(initialState: MapSearchSheetFeature.State()) {
      MapSearchSheetFeature()
    }

    await store.send(.searchQueryChanged(" ")) {
      $0.searchQuery = " "
      $0.searchResults = []
      $0.isLoading = false
    }
  }

  @Test
  @MainActor
  func testClearSearchTapped() async {
    var state = MapSearchSheetFeature.State()
    state.searchQuery = "Coffee"
    state.searchResults = [SavedPlace(name: "Coffee Shop", subtitle: "Here", iconName: "cup.and.saucer.fill", coordinate: nil)]

    let store = TestStore(initialState: state) {
      MapSearchSheetFeature()
    }

    await store.send(.clearSearchTapped) {
      $0.searchQuery = ""
      $0.searchResults = []
      $0.isLoading = false
    }

    await store.receive(.delegate(.dismissed))
  }
}
