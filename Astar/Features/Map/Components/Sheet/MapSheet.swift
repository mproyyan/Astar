//
//  MapSheet.swift
//  Astar
//
//  Created by Dimas Prihady Setyawan on 25/08/26.
//

import ComposableArchitecture
import SwiftUI

struct MapSheet: View {
    enum DirectionSheetMode {
        case directions
        case progress
        case journeyLog
    }

    let store: StoreOf<MainFeature>
    @Binding var selectedDetent: PresentationDetent
    @State private var isSearching = false
    @State private var searchText = ""
    @State private var selectedDestination: SavedPlace? = nil
    @State private var directionMode: DirectionSheetMode = .directions
    @State private var isJourneyDone = false

    private var isExpanded: Bool {
        selectedDetent == .large
    }

    var body: some View {
        ScrollView(.vertical) {
            Group {
                if let destination = selectedDestination {
                    switch directionMode {
                    case .directions:
                        MapSheetDirectionContent(
                            destination: destination,
                            onCancel: {
                                withAnimation(.easeInOut(duration: 0.25)) {
                                    selectedDestination = nil
                                    isJourneyDone = false
                                    directionMode = .directions
                                    selectedDetent = .fraction(0.42)
                                }
                            },
                            onStartNavigation: {
                                withAnimation(.easeInOut(duration: 0.25)) {
                                    isJourneyDone = false
                                    directionMode = .progress
                                    selectedDetent = .fraction(0.6)
                                }
                            }
                        )
                        .transition(.opacity)

                    case .progress:
                        DirectionProgress(
                            destination: destination,
                            isDone: isJourneyDone,
                            onJourneyLog: {
                                withAnimation(.easeInOut(duration: 0.25)) {
                                    directionMode = .journeyLog
                                    selectedDetent = .large
                                }
                            },
                            onEndJourney: {
                                withAnimation(.easeInOut(duration: 0.25)) {
                                    isJourneyDone = true
                                }
                            },
                            onDone: {
                                withAnimation(.easeInOut(duration: 0.25)) {
                                    selectedDestination = nil
                                    isJourneyDone = false
                                    directionMode = .directions
                                    selectedDetent = .fraction(0.42)
                                }
                            }
                        )
                        .padding(.horizontal, 16)
                        .padding(.top, 12)
                        .transition(.opacity)

                    case .journeyLog:
                        DirectionJourneyLog(
                            destinationName: destination.name,
                            isDone: isJourneyDone,
                            onDismiss: {
                                withAnimation(.easeInOut(duration: 0.25)) {
                                    directionMode = .progress
                                    selectedDetent = .fraction(0.6)
                                }
                            },
                            onChecklistTapped: {
                                withAnimation(.easeInOut(duration: 0.25)) {
                                    directionMode = .progress
                                    selectedDetent = .fraction(0.6)
                                }
                            }
                        )
                        .padding(.horizontal, 16)
                        .padding(.top, 12)
                        .transition(.opacity)
                    }
                } else if isSearching {
                    MapSheetSearchContent(
                        isSearching: $isSearching,
                        searchText: $searchText,
                        selectedDetent: $selectedDetent,
                        onSelectPlace: { place in
                            UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                                isSearching = false
                                searchText = ""
                                selectedDestination = place
                                isJourneyDone = false
                                directionMode = .directions
                                selectedDetent = .fraction(0.52)
                            }
                        }
                    )
                    .transition(.opacity)
                } else {
                    MapSheetMainContent(
                        store: store,
                        isExpanded: isExpanded,
                        onSearchTapped: {
                            withAnimation(.easeInOut(duration: 0.25)) {
                                selectedDetent = .large
                                isSearching = true
                            }
                        },
                        onSelectPlace: { place in
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                                selectedDestination = place
                                isJourneyDone = false
                                directionMode = .directions
                                selectedDetent = .fraction(0.52)
                            }
                        }
                    )
                    .transition(.opacity)
                }
            }
        }
        .scrollIndicators(.hidden)
        .presentationBackground {
            if isExpanded {
                Color(red: 0.95, green: 0.95, blue: 0.97)
            }
        }
        .animation(.easeInOut(duration: 0.25), value: isExpanded)
        .animation(.easeInOut(duration: 0.25), value: selectedDestination != nil)
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
