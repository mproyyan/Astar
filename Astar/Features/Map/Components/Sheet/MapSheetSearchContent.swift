import ComposableArchitecture
import CoreLocation
import SwiftUI

struct MapSheetSearchContent: View {
    @Bindable var store: StoreOf<MapSearchSheetFeature>
    @Binding var selectedDetent: PresentationDetent
    var onSelectPlace: ((SavedPlace) -> Void)? = nil
    @FocusState private var isSearchFieldFocused: Bool

    private var searchTextBinding: Binding<String> {
        Binding(
            get: { store.searchQuery },
            set: { store.send(.searchQueryChanged($0)) }
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack(spacing: 12) {
                ActiveSearchBarView(
                    searchText: searchTextBinding,
                    isFocused: $isSearchFieldFocused
                )

                CancelSearchButton {
                    store.send(.clearSearchTapped)
                    withAnimation(.easeInOut(duration: 0.25)) {
                        selectedDetent = .fraction(0.42)
                    }
                }
            }
            .padding(.top, 8)

            if store.searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                SavedPlacesCard(
                    title: "Saved",
                    places: MapSampleData.savedPlaces,
                    onSelectPlace: { place in
                        store.send(.selectPlace(place))
                        onSelectPlace?(place)
                    }
                )
            } else if store.isLoading && store.searchResults.isEmpty {
                VStack(spacing: 14) {
                    ProgressView()
                        .padding(.top, 24)

                    Text("Searching nearby places...")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 24)
                .background(.white, in: .rect(cornerRadius: 24))
                .overlay {
                    RoundedRectangle(cornerRadius: 24)
                        .stroke(Color.primary.opacity(0.06), lineWidth: 1)
                }
            } else if store.searchResults.isEmpty {
                NoResultsView(searchText: store.searchQuery)
            } else {
                SearchResultsCard(
                    places: store.searchResults,
                    onSelectPlace: { place in
                        store.send(.selectPlace(place))
                        onSelectPlace?(place)
                    }
                )
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16)
        .padding(.top, 12)
        .onAppear {
            isSearchFieldFocused = true
        }
    }
}
