//
//  MapSheetSearchContent.swift
//  Astar
//
//  Created by Dimas Prihady Setyawan on 25/08/26.
//

import CoreLocation
import SwiftUI

struct MapSheetSearchContent: View {
    @Binding var isSearching: Bool
    @Binding var searchText: String
    @Binding var selectedDetent: PresentationDetent
    var userLocation: CLLocationCoordinate2D? = nil
    var onSelectPlace: ((SavedPlace) -> Void)? = nil
    @FocusState private var isSearchFieldFocused: Bool
    @State private var searchResults: [SavedPlace] = []
    @State private var isSearchingPlaces = false

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
            } else if isSearchingPlaces && searchResults.isEmpty {
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
            } else if searchResults.isEmpty {
                NoResultsView(searchText: searchText)
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
        .task(id: searchText) {
            let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !query.isEmpty else {
                searchResults = []
                isSearchingPlaces = false
                return
            }

            isSearchingPlaces = true
            try? await Task.sleep(for: .milliseconds(300))
            guard !Task.isCancelled else { return }

            let results = await PlaceSearchService.searchPlaces(query: query, userLocation: userLocation)
            guard !Task.isCancelled else { return }

            searchResults = results
            isSearchingPlaces = false
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
