//
//  MapSheet.swift
//  Astar
//
//  Created by Dimas Prihady Setyawan on 25/08/26.
//

import ComposableArchitecture
import SwiftUI

struct MapSheet: View {
    let store: StoreOf<MainFeature>
    @Binding var selectedDetent: PresentationDetent
    @State private var isSearching = false
    @State private var searchText = ""

    private var isExpanded: Bool {
        selectedDetent == .large
    }

    var body: some View {
        ScrollView(.vertical) {
            if isSearching {
                MapSheetSearchContent(
                    isSearching: $isSearching,
                    searchText: $searchText,
                    selectedDetent: $selectedDetent
                )
            } else {
                MapSheetMainContent(
                    store: store,
                    isExpanded: isExpanded,
                    onSearchTapped: {
                        withAnimation(.easeInOut(duration: 0.25)) {
                            selectedDetent = .large
                            isSearching = true
                        }
                    }
                )
            }
        }
        .scrollIndicators(.hidden)
        .presentationBackground {
            if isExpanded {
                Color(red: 0.95, green: 0.95, blue: 0.97)
            } else {
                Rectangle().fill(.ultraThinMaterial)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: isExpanded)
        .onChange(of: selectedDetent) { _, newDetent in
            if isSearching && newDetent != .large {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isSearching = false
                    searchText = ""
                }
            }
        }
    }
}

#Preview {
    @Previewable @State var selectedDetent: PresentationDetent = .fraction(0.42)

    MapSheet(
        store: Store(initialState: MainFeature.State()) {
            MainFeature()
        },
        selectedDetent: $selectedDetent
    )
}
