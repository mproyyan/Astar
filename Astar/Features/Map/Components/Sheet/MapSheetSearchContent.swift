//
//  MapSheetSearchContent.swift
//  Astar
//
//  Created by Dimas Prihady Setyawan on 25/08/26.
//

import SwiftUI

struct MapSheetSearchContent: View {
    @Binding var isSearching: Bool
    @Binding var searchText: String
    @Binding var selectedDetent: PresentationDetent
    var onSelectPlace: ((SavedPlace) -> Void)? = nil
    @FocusState private var isSearchFieldFocused: Bool

    private var searchResults: [SavedPlace] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        if query.isEmpty {
            return []
        }
        let matched = MapSampleData.allSearchablePlaces.filter { place in
            place.name.localizedStandardContains(query) || place.subtitle.localizedStandardContains(query)
        }
        if !matched.isEmpty {
            return matched
        }
        // Dynamic mock search results for any query typed by the user
        let cleanQuery = query.capitalized
        return [
            SavedPlace(
                name: cleanQuery,
                subtitle: "\(cleanQuery), Central Jakarta, Indonesia",
                iconName: "mappin.and.ellipse",
                distance: "300 m"
            ),
            SavedPlace(
                name: "\(cleanQuery) Hub & Mall",
                subtitle: "Jl. Jend. Sudirman Kav 21, South Jakarta",
                iconName: "bag.fill",
                distance: "1.2 km"
            ),
            SavedPlace(
                name: "\(cleanQuery) Station",
                subtitle: "Transit Line 1, Central Jakarta",
                iconName: "tram.fill",
                distance: "2.4 km"
            )
        ]
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack(spacing: 12) {
                ActiveSearchBarView(
                    searchText: $searchText,
                    isFocused: $isSearchFieldFocused
                )

                CancelSearchButton {
                    withAnimation(.easeInOut(duration: 0.25)) {
                        searchText = ""
                        isSearching = false
                        selectedDetent = .fraction(0.42)
                    }
                }
            }
            .padding(.top, 8)

            if searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                SavedPlacesCard(
                    title: "Saved",
                    places: MapSampleData.savedPlaces,
                    onSelectPlace: onSelectPlace
                )
            } else {
                SearchResultsCard(
                    places: searchResults,
                    onSelectPlace: onSelectPlace
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
    @Previewable @State var isSearching = true
    @Previewable @State var searchText = ""
    @Previewable @State var selectedDetent: PresentationDetent = .large

    MapSheetSearchContent(
        isSearching: $isSearching,
        searchText: $searchText,
        selectedDetent: $selectedDetent
    )
}
