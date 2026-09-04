//
//  MapSheetMainContent.swift
//  Astar
//
//  Created by Dimas Prihady Setyawan on 25/08/26.
//

import ComposableArchitecture
import SwiftUI

struct MapSheetMainContent: View {
    let store: StoreOf<MainFeature>
    let isExpanded: Bool
    let onSearchTapped: () -> Void
    var onSelectPlace: ((SavedPlace) -> Void)? = nil
    var onSelectPerson: ((Person) -> Void)? = nil
    var onSavedPlacesHeaderTapped: (() -> Void)? = nil

    private var people: [Person] { store.people }
    private var savedPlaces: [SavedPlace] { store.map.savedPlaces }

    var body: some View {
        WithPerceptionTracking {
            VStack(alignment: .leading, spacing: 20) {
            HStack(spacing: 12) {
                Button(action: onSearchTapped) {
                    SearchBarView()
                }
                .buttonStyle(.plain)

                ProfileButton(store: store)
            }
            .padding(.top, 8)

            VStack(spacing: 32) {
                PeopleSection(people: people, onSelectPerson: onSelectPerson)

                SavedSection(
                    savedPlaces: savedPlaces,
                    onSelectPlace: onSelectPlace,
                    onHeaderTap: onSavedPlacesHeaderTapped
                )
                    .transition(.asymmetric(
                        insertion: .opacity.combined(with: .move(edge: .bottom)),
                        removal: .opacity
                    ))
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16)
        .padding(.top, 12)
        }
    }
}

#Preview {
    MapSheetMainContent(
        store: Store(initialState: MainFeature.State()) {
            MainFeature()
        },
        isExpanded: true,
        onSearchTapped: {}
    )
}
