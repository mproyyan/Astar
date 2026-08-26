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
    enum DirectionSheetMode {
        case directions
        case progress
        case journeyLog
    }

    let store: StoreOf<MainFeature>
    @Binding var selectedDetent: PresentationDetent
    var onRouteReady: ((MKRoute?, SavedPlace) -> Void)? = nil
    var onStartNavigation: ((SavedPlace) -> Void)? = nil
    var onCancelDirections: (() -> Void)? = nil

    @State private var isSearching = false
    @State private var searchText = ""
    @State private var selectedDestination: SavedPlace? = nil
    @State private var directionMode: DirectionSheetMode = .directions
    @State private var isJourneyDone = false
    @State private var currentRouteInfo: WalkingRouteInfo? = nil
    @State private var journeyTracker = JourneyTrackingManager()
    @State private var selectedWalker: Person? = nil
    @State private var isWalkerDestinationReached = false
    @State private var isViewingHistoryList = false
    @State private var selectedHistoryTrip: WalkerHistoryTrip? = nil

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
                            userLocation: store.map.currentLocation,
                            destination: destination,
                            onCancel: {
                                onCancelDirections?()
                                journeyTracker.reset()
                                withAnimation(.easeInOut(duration: 0.25)) {
                                    selectedDestination = nil
                                    isJourneyDone = false
                                    currentRouteInfo = nil
                                    directionMode = .directions
                                    selectedDetent = .fraction(0.42)
                                }
                            },
                            onRouteReady: { route, updatedDest in
                                onRouteReady?(route, updatedDest)
                            },
                            onStartNavigation: { routeInfo in
                                currentRouteInfo = routeInfo
                                onStartNavigation?(destination)

                                let originCoord = store.map.currentLocation ?? CLLocationCoordinate2D(latitude: -6.2088, longitude: 106.8456)
                                let originPlace = SavedPlace(
                                    name: "Start Position",
                                    subtitle: "Current Area",
                                    iconName: "location.fill",
                                    coordinate: originCoord
                                )

                                Task {
                                    await journeyTracker.startTracking(
                                        origin: originPlace,
                                        destination: destination,
                                        userLocation: store.map.currentLocation
                                    )
                                }

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
                            estimatedTime: currentRouteInfo?.travelTimeString ?? "12 min",
                            eta: currentRouteInfo?.etaString ?? "11.00 ETA",
                            totalDistance: currentRouteInfo?.distanceString ?? destination.distance ?? "850 m",
                            isDone: journeyTracker.isDestinationReached || isJourneyDone,
                            onJourneyLog: {
                                withAnimation(.easeInOut(duration: 0.25)) {
                                    directionMode = .journeyLog
                                    selectedDetent = .large
                                }
                            },
                            onEndJourney: {
                                onCancelDirections?()
                                journeyTracker.reset()
                                withAnimation(.easeInOut(duration: 0.25)) {
                                    selectedDestination = nil
                                    isJourneyDone = false
                                    currentRouteInfo = nil
                                    directionMode = .directions
                                    selectedDetent = .fraction(0.42)
                                }
                            },
                            onDone: {
                                onCancelDirections?()
                                journeyTracker.reset()
                                withAnimation(.easeInOut(duration: 0.25)) {
                                    selectedDestination = nil
                                    isJourneyDone = false
                                    currentRouteInfo = nil
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
                            isDone: journeyTracker.isDestinationReached || isJourneyDone,
                            entries: journeyTracker.currentEntries.isEmpty ? nil : journeyTracker.currentEntries,
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
                } else if let walker = selectedWalker {
                    if walker.status == "Idle" {
                        if let trip = selectedHistoryTrip {
                            WalkerCardHistoryDetail(
                                trip: trip,
                                onDismiss: {
                                    withAnimation(.easeInOut(duration: 0.25)) {
                                        selectedHistoryTrip = nil
                                    }
                                }
                            )
                            .padding(.horizontal, 16)
                            .padding(.top, 12)
                            .transition(.opacity)
                        } else if isViewingHistoryList {
                            WalkerCardHistoryList(
                                onDismiss: {
                                    withAnimation(.easeInOut(duration: 0.25)) {
                                        isViewingHistoryList = false
                                    }
                                },
                                onSelectTrip: { trip in
                                    withAnimation(.easeInOut(duration: 0.25)) {
                                        selectedHistoryTrip = trip
                                    }
                                }
                            )
                            .padding(.horizontal, 16)
                            .padding(.top, 12)
                            .transition(.opacity)
                        } else {
                            WalkerCardIdle(
                                name: walker.name,
                                email: "awanmendung@icloud.com",
                                onDismiss: {
                                    withAnimation(.easeInOut(duration: 0.25)) {
                                        selectedWalker = nil
                                        isViewingHistoryList = false
                                        selectedHistoryTrip = nil
                                        selectedDetent = .fraction(0.42)
                                    }
                                },
                                onViewAllHistory: {
                                    withAnimation(.easeInOut(duration: 0.25)) {
                                        isViewingHistoryList = true
                                    }
                                },
                                onSelectTrip: { trip in
                                    withAnimation(.easeInOut(duration: 0.25)) {
                                        selectedHistoryTrip = trip
                                    }
                                }
                            )
                            .padding(.horizontal, 16)
                            .padding(.top, 12)
                            .transition(.opacity)
                        }
                    } else {
                        if isWalkerDestinationReached {
                            WalkerCardReachDestination(
                                walkerName: "\(walker.name) Mendung",
                                avatarImageName: "AwanAvatar",
                                onDismiss: {
                                    withAnimation(.easeInOut(duration: 0.25)) {
                                        selectedWalker = nil
                                        isWalkerDestinationReached = false
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
                                    timeAgo: "1 Min Ago",
                                    originPlaceName: "Autograph Tower",
                                    originIconName: "briefcase.fill",
                                    destinationPlaceName: "Home",
                                    destinationIconName: "house.fill",
                                    recentLocations: WalkerSampleData.awanLocations
                                ),
                                onDismiss: {
                                    withAnimation(.easeInOut(duration: 0.25)) {
                                        selectedWalker = nil
                                        isWalkerDestinationReached = false
                                        selectedDetent = .fraction(0.42)
                                    }
                                },
                                onExitTrack: {
                                    withAnimation(.easeInOut(duration: 0.25)) {
                                        isWalkerDestinationReached = true
                                        selectedDetent = .fraction(0.35)
                                    }
                                },
                                onReachDestination: {
                                    withAnimation(.easeInOut(duration: 0.25)) {
                                        isWalkerDestinationReached = true
                                        selectedDetent = .fraction(0.35)
                                    }
                                }
                            )
                            .padding(.horizontal, 16)
                            .padding(.top, 12)
                            .transition(.opacity)
                        }
                    }
                } else if isSearching {
                    MapSheetSearchContent(
                        isSearching: $isSearching,
                        searchText: $searchText,
                        selectedDetent: $selectedDetent,
                        userLocation: store.map.currentLocation,
                        onSelectPlace: { place in
                            UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                                isSearching = false
                                searchText = ""
                                selectedDestination = place
                                isJourneyDone = false
                                currentRouteInfo = nil
                                journeyTracker.reset()
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
                                currentRouteInfo = nil
                                journeyTracker.reset()
                                directionMode = .directions
                                selectedDetent = .fraction(0.52)
                            }
                        },
                        onSelectPerson: { person in
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                                selectedWalker = person
                                isWalkerDestinationReached = false
                                isViewingHistoryList = false
                                selectedHistoryTrip = nil
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
        .animation(.easeInOut(duration: 0.25), value: selectedDestination != nil)
        .onChange(of: selectedDetent) { _, newDetent in
            if isSearching && newDetent != .large {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isSearching = false
                    searchText = ""
                }
            }
        }
        .onChange(of: store.map.currentLocation) { _, newLocation in
            if let newCoord = newLocation, directionMode == .progress || directionMode == .journeyLog {
                Task {
                    await journeyTracker.updateLocation(newCoord)
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
