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
    @FocusState private var isSearchFieldFocused: Bool

    private var searchResults: [SavedPlace] {
        if searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return []
        }
        return MapSampleData.allSearchablePlaces.filter { place in
            place.name.localizedStandardContains(searchText) || place.subtitle.localizedStandardContains(searchText)
        }
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
                        selectedDetent = .fraction(0.45)
                    }
                }
            }
            .padding(.top, 8)

            if searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                SavedPlacesCard(
                    title: "Saved",
                    places: MapSampleData.savedPlaces
                )
            } else if searchResults.isEmpty {
                NoResultsView(searchText: searchText)
            } else {
                SavedPlacesCard(
                    title: "Search Results",
                    places: searchResults
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

private struct ActiveSearchBarView: View {
    @Binding var searchText: String
    @FocusState.Binding var isFocused: Bool

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.body.weight(.semibold))
                .foregroundStyle(.secondary)

            TextField("Search Place", text: $searchText)
                .font(.body)
                .focused($isFocused)
                .autocorrectionDisabled()

            if !searchText.isEmpty {
                Button {
                    searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.body)
                        .foregroundStyle(.tertiary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Clear text")
            } else {
                Image(systemName: "mic")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 16)
        .frame(height: 40)
        .background(.white, in: .capsule)
        .overlay {
            Capsule()
                .stroke(Color.primary.opacity(0.08), lineWidth: 1)
        }
    }
}

private struct CancelSearchButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "xmark")
                .font(.body.weight(.semibold))
                .foregroundStyle(.primary)
                .frame(width: 40, height: 40)
        }
        .buttonStyle(.plain)
        .glassEffect(.regular.interactive(), in: .circle)
        .accessibilityLabel("Cancel search")
    }
}

private struct SavedPlacesCard: View {
    let title: String
    let places: [SavedPlace]

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 4) {
                Text(title)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.primary)

                if title == "Saved" {
                    Image(systemName: "chevron.right")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
            }

            VStack(spacing: 0) {
                ForEach(places.enumerated(), id: \.element.id) { index, place in
                    SavedPlaceRow(
                        place: place,
                        isFirst: index == 0,
                        isLast: index == places.count - 1
                    )

                    if index < places.count - 1 {
                        Divider()
                            .padding(.leading, 52)
                            .opacity(0.5)
                    }
                }
            }
            .padding(.horizontal, 14)
            .background(.white, in: .rect(cornerRadius: 24))
            .overlay {
                RoundedRectangle(cornerRadius: 24)
                    .stroke(Color.primary.opacity(0.06), lineWidth: 1)
            }
        }
    }
}

private struct NoResultsView: View {
    let searchText: String

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "mappin.slash")
                .font(.largeTitle)
                .foregroundStyle(.secondary)
                .padding(.top, 24)

            Text("No Places Found")
                .font(.headline)
                .foregroundStyle(.primary)

            Text("No results matching \"\(searchText)\".")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
        .background(.white, in: .rect(cornerRadius: 24))
        .overlay {
            RoundedRectangle(cornerRadius: 24)
                .stroke(Color.primary.opacity(0.06), lineWidth: 1)
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
