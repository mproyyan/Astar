//
//  MapSheet.swift
//  Astar
//
//  Created by Dimas Prihady Setyawan on 25/08/26.
//

import ComposableArchitecture
import MapKit
import SwiftUI

struct MapSheet: View {
    @Bindable var store: StoreOf<MainFeature>
    @Binding var selectedDetent: PresentationDetent

    private var isExpanded: Bool {
        selectedDetent == .large
    }

    var body: some View {
        ScrollView(.vertical) {
            Group {
                if let destination = store.map.selectedDestination {
                    switch store.map.directionMode {
                    case .directions:
                        MapSheetDirectionContent(
                            store: store,
                            onCancel: {
                                withAnimation(.easeInOut(duration: 0.25)) {
                                    selectedDetent = .fraction(0.42)
                                }
                            },
                            onStartNavigation: {
                                withAnimation(.easeInOut(duration: 0.25)) {
                                    selectedDetent = .fraction(0.6)
                                }
                            }
                        )
                        .transition(.opacity)

                    case .progress:
                        DirectionProgress(
                            destination: destination,
                            estimatedTime: store.map.walkingRouteInfo?.travelTimeString ?? "12 min",
                            eta: store.map.walkingRouteInfo?.etaString ?? "11.00 ETA",
                            totalDistance: store.map.walkingRouteInfo?.distanceString ?? destination.distance ?? "850 m",
                            watchingPeople: store.map.companions,
                            isDone: store.map.isDestinationReached,
                            onJourneyLog: {
                                store.send(.map(.journeyLogTapped))
                                withAnimation(.easeInOut(duration: 0.25)) {
                                    selectedDetent = .large
                                }
                            },
                            onEndJourney: {
                                store.send(.map(.endJourneyTapped))
                                withAnimation(.easeInOut(duration: 0.25)) {
                                    selectedDetent = .fraction(0.42)
                                }
                            },
                            onDone: {
                                store.send(.map(.endJourneyTapped))
                                withAnimation(.easeInOut(duration: 0.25)) {
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
                            isDone: store.map.isDestinationReached,
                            entries: store.map.journeyLogEntries.isEmpty ? nil : store.map.journeyLogEntries,
                            onDismiss: {
                                store.send(.map(.dismissJourneyLogTapped))
                                withAnimation(.easeInOut(duration: 0.25)) {
                                    selectedDetent = .fraction(0.6)
                                }
                            },
                            onChecklistTapped: {
                                store.send(.map(.dismissJourneyLogTapped))
                                withAnimation(.easeInOut(duration: 0.25)) {
                                    selectedDetent = .fraction(0.6)
                                }
                            }
                        )
                        .padding(.horizontal, 16)
                        .padding(.top, 12)
                        .transition(.opacity)
                    }
                } else if let walker = store.map.selectedWalker {
                    if walker.status == "Idle" {
                        if let trip = store.map.selectedHistoryTrip {
                            WalkerCardHistoryDetail(
                                trip: trip,
                                onDismiss: {
                                    store.send(.map(.dismissHistoryDetail))
                                }
                            )
                            .padding(.horizontal, 16)
                            .padding(.top, 12)
                            .transition(.opacity)
                        } else if store.map.isViewingHistoryList {
                            WalkerCardHistoryList(
                                sections: store.map.selectedWalkerHistorySections.isEmpty ? WalkerSampleData.defaultHistorySections : store.map.selectedWalkerHistorySections,
                                onDismiss: {
                                    store.send(.map(.dismissHistoryList))
                                },
                                onSelectTrip: { trip in
                                    store.send(.map(.selectHistoryTrip(trip)))
                                }
                            )
                            .padding(.horizontal, 16)
                            .padding(.top, 12)
                            .transition(.opacity)
                        } else {
                            WalkerCardIdle(
                                name: walker.name,
                                email: walker.email.isEmpty ? "\(walker.name.lowercased().replacingOccurrences(of: " ", with: ""))@icloud.com" : walker.email,
                                avatarImageName: walker.avatarImageName,
                                trips: store.map.selectedWalkerTrips.isEmpty ? WalkerSampleData.defaultTrips : store.map.selectedWalkerTrips,
                                onDismiss: {
                                    store.send(.map(.dismissWalker))
                                    withAnimation(.easeInOut(duration: 0.25)) {
                                        selectedDetent = .fraction(0.42)
                                    }
                                },
                                onViewAllHistory: {
                                    store.send(.map(.viewAllHistoryTapped))
                                },
                                onSelectTrip: { trip in
                                    store.send(.map(.selectHistoryTrip(trip)))
                                }
                            )
                            .padding(.horizontal, 16)
                            .padding(.top, 12)
                            .transition(.opacity)
                        }
                    } else {
                        if store.map.isWalkerDestinationReached {
                            WalkerCardReachDestination(
                                walkerName: walker.name,
                                avatarImageName: walker.avatarImageName,
                                onDismiss: {
                                    store.send(.map(.dismissWalker))
                                    withAnimation(.easeInOut(duration: 0.25)) {
                                        selectedDetent = .fraction(0.42)
                                    }
                                }
                            )
                            .padding(.horizontal, 16)
                            .padding(.top, 12)
                            .transition(.opacity)
                        } else {
                            WalkerCardWalking(
                                walker: WalkerProfile(
                                    name: walker.name,
                                    locationSubtitle: "Central Jakarta, Jakarta",
                                    timeAgo: "Live",
                                    originPlaceName: walker.activeOriginName ?? "Current Location",
                                    originIconName: "location.fill",
                                    destinationPlaceName: walker.activeDestinationName ?? "Destination",
                                    destinationIconName: walker.activeDestinationIcon ?? "house.fill",
                                    recentLocations: WalkerSampleData.awanLocations
                                ),
                                onDismiss: {
                                    store.send(.map(.dismissWalker))
                                    withAnimation(.easeInOut(duration: 0.25)) {
                                        selectedDetent = .fraction(0.42)
                                    }
                                },
                                onTrack: {
                                    if let walkerRecordID = walker.recordID {
                                        store.send(.map(.becomeCompanionTapped(walkerRecordID: walkerRecordID)))
                                    }
                                },
                                onExitTrack: {
                                    store.send(.map(.exitTrackTapped))
                                    store.send(.map(.dismissWalker))
                                    withAnimation(.easeInOut(duration: 0.25)) {
                                        selectedDetent = .fraction(0.42)
                                    }
                                },
                                onReachDestination: {
                                    store.send(.map(.reachDestinationTapped))
                                    withAnimation(.easeInOut(duration: 0.25)) {
                                        selectedDetent = .fraction(0.35)
                                    }
                                }
                            )
                            .padding(.horizontal, 16)
                            .padding(.top, 12)
                            .transition(.opacity)
                        }
                    }
                } else if store.map.isSearching {
                    MapSheetSearchContent(
                        store: store,
                        selectedDetent: $selectedDetent,
                        onSelectPlace: { place in
                            UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                            store.send(.map(.selectPlace(place)))
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
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
                            store.send(.map(.searchTapped))
                            withAnimation(.easeInOut(duration: 0.25)) {
                                selectedDetent = .large
                            }
                        },
                        onSelectPlace: { place in
                            store.send(.map(.selectPlace(place)))
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                                selectedDetent = .fraction(0.52)
                            }
                        },
                        onSelectPerson: { person in
                            store.send(.map(.selectPerson(person)))
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                                selectedDetent = .large
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
        .animation(.easeInOut(duration: 0.25), value: store.map.selectedDestination != nil)
        .onChange(of: selectedDetent) { _, newDetent in
            if store.map.isSearching && newDetent != .large {
                store.send(.map(.clearSearchTapped))
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
