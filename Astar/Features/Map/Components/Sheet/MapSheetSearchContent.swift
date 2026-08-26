//
//  MapSheetSearchContent.swift
//  Astar
//
//  Created by Dimas Prihady Setyawan on 25/08/26.
//

import ComposableArchitecture
import CoreLocation
import SwiftUI

struct MapSheetSearchContent: View {
    @Bindable var store: StoreOf<MainFeature>
    @Binding var selectedDetent: PresentationDetent
    var onSelectPlace: ((SavedPlace) -> Void)? = nil
    @FocusState private var isSearchFieldFocused: Bool

    private var searchTextBinding: Binding<String> {
        Binding(
            get: { store.map.searchQuery },
            set: { store.send(.map(.searchQueryChanged($0))) }
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
                    store.send(.map(.clearSearchTapped))
                    withAnimation(.easeInOut(duration: 0.25)) {
                        selectedDetent = .fraction(0.42)
                    }
                }
            }
            .padding(.top, 8)

            if store.map.searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                SavedPlacesCard(
                    title: "Saved",
                    places: MapSampleData.savedPlaces,
                    onSelectPlace: { place in
                        onSelectPlace?(place)
                    }
                )
            } else if store.map.isSearchLoading && store.map.searchResults.isEmpty {
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
            } else if store.map.searchResults.isEmpty {
                NoResultsView(searchText: store.map.searchQuery)
            } else {
                SearchResultsCard(
                    places: store.map.searchResults,
                    onSelectPlace: { place in
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

#Preview {
    @Previewable @State var selectedDetent: PresentationDetent = .large

    MapSheetSearchContent(
        store: Store(initialState: MainFeature.State()) {
            MainFeature()
        },
        selectedDetent: $selectedDetent
    )
}
