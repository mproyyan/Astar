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
            if let sheetStore = store.scope(state: \.map.sheet, action: \.map.sheet.presented) {
                switch sheetStore.case {
                case let .search(searchStore):
                    MapSheetSearchContent(
                        store: searchStore,
                        selectedDetent: $selectedDetent,
                        onSelectPlace: { place in
                            UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                            store.send(.map(.sheet(.presented(.search(.selectPlace(place))))))
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                                selectedDetent = .fraction(0.52)
                            }
                        },
                        onSavedPlacesHeaderTapped: {
                            store.send(.savedPlacesHeaderTapped)
                        }
                    )
                    .transition(.opacity)
                    
                case let .direction(directionStore):
                    Group {
                        switch directionStore.mode {
                        case .directions:
                            MapSheetDirectionContent(
                                store: directionStore,
                                onCancel: {
                                    withAnimation(.easeInOut(duration: 0.25)) {
                                        selectedDetent = .fraction(0.42)
                                    }
                                },
                                onStartNavigation: {
                                    withAnimation(.easeInOut(duration: 0.25)) {
                                        selectedDetent = .fraction(0.6)
                                    }
                                },
                                currentLocation: store.map.currentLocation
                            )
                            .transition(.opacity)

                        case .progress:
                            DirectionProgress(
                                destination: directionStore.destination,
                                estimatedTime: directionStore.walkingRouteInfo?.travelTimeString ?? "12 min",
                                eta: directionStore.walkingRouteInfo?.etaString ?? "11.00 ETA",
                                totalDistance: directionStore.walkingRouteInfo?.distanceString ?? directionStore.destination.distance ?? "850 m",
                                isDone: directionStore.isDestinationReached,
                                isLoading: directionStore.isCalculatingRoute,
                                isDevelopmentMode: directionStore.isDevelopmentMode,
                                onJourneyLog: {
                                    directionStore.send(.journeyLogTapped)
                                    withAnimation(.easeInOut(duration: 0.25)) {
                                        selectedDetent = .large
                                    }
                                },
                                onEndJourney: {
                                    directionStore.send(.endJourneyTapped)
                                    withAnimation(.easeInOut(duration: 0.25)) {
                                        selectedDetent = .fraction(0.42)
                                    }
                                },
                                onDone: {
                                    directionStore.send(.endJourneyTapped)
                                    withAnimation(.easeInOut(duration: 0.25)) {
                                        selectedDetent = .fraction(0.42)
                                    }
                                },
                                onSimulateArrival: {
                                    directionStore.send(.simulateArrivalTapped)
                                }
                            )
                            .padding(.horizontal, 16)
                            .padding(.top, 12)
                            .transition(.opacity)

                        case .journeyLog:
                            DirectionJourneyLog(
                                destinationName: directionStore.destination.name,
                                isDone: directionStore.isDestinationReached,
                                entries: directionStore.journeyLogEntries.isEmpty ? nil : directionStore.journeyLogEntries,
                                onDismiss: {
                                    directionStore.send(.dismissJourneyLogTapped)
                                    withAnimation(.easeInOut(duration: 0.25)) {
                                        selectedDetent = .fraction(0.6)
                                    }
                                },
                                onChecklistTapped: {
                                    directionStore.send(.dismissJourneyLogTapped)
                                    withAnimation(.easeInOut(duration: 0.25)) {
                                        selectedDetent = .fraction(0.6)
                                    }
                                }
                            )
                            .padding(.horizontal, 16)
                            .padding(.top, 12)
                            .transition(.opacity)
                        }
                    }
                    .sheet(
                        isPresented: Binding(
                            get: { directionStore.isShowingBroadcastSheet },
                            set: { directionStore.send(.setBroadcastSheetPresented($0)) }
                        )
                    ) {
                        BroadcastInfoSheet()
                    }

                case let .walker(walkerStore):
                    if walkerStore.isViewingJourneyLog {
                        DirectionJourneyLog(
                            destinationName: walkerStore.destinationPlaceName,
                            isDone: true,
                            entries: walkerStore.journeyLogEntries.isEmpty ? nil : walkerStore.journeyLogEntries,
                            onDismiss: {
                                walkerStore.send(.dismissJourneyLogTapped)
                                withAnimation(.easeInOut(duration: 0.25)) {
                                    selectedDetent = .fraction(0.42)
                                }
                            },
                            onChecklistTapped: {
                                walkerStore.send(.dismissJourneyLogTapped)
                                withAnimation(.easeInOut(duration: 0.25)) {
                                    selectedDetent = .fraction(0.42)
                                }
                            }
                        )
                        .padding(.horizontal, 16)
                        .padding(.top, 12)
                        .transition(.opacity)
                    } else if walkerStore.isDestinationReached {
                        WalkerCardReachDestination(
                            walkerName: walkerStore.walker.name == "Awan" ? "\(walkerStore.walker.name) Mendung" : walkerStore.walker.name,
                            avatarImageName: walkerStore.walker.name == "Awan" ? "AwanAvatar" : "\(walkerStore.walker.name)Avatar",
                            onDismiss: {
                                walkerStore.send(.dismissWalkerTapped)
                                withAnimation(.easeInOut(duration: 0.25)) {
                                    selectedDetent = .fraction(0.42)
                                }
                            },
                            onJourneyLog: {
                                walkerStore.send(.journeyLogTapped)
                                withAnimation(.easeInOut(duration: 0.25)) {
                                    selectedDetent = .large
                                }
                            },
                            onDone: {
                                walkerStore.send(.dismissWalkerTapped)
                                withAnimation(.easeInOut(duration: 0.25)) {
                                    selectedDetent = .fraction(0.42)
                                }
                            }
                        )
                        .padding(.horizontal, 16)
                        .padding(.top, 12)
                        .transition(.opacity)
                    } else if walkerStore.isIdleOrAccompany {
                        if let trip = walkerStore.selectedHistoryTrip {
                            WalkerCardHistoryDetail(
                                trip: trip,
                                onDismiss: {
                                    walkerStore.send(.dismissHistoryDetailTapped)
                                }
                            )
                            .padding(.horizontal, 16)
                            .padding(.top, 12)
                            .transition(.opacity)
                        } else if walkerStore.isViewingHistoryList {
                            WalkerCardHistoryList(
                                sections: [WalkerHistorySection(title: "Recent", trips: walkerStore.trips)],
                                onDismiss: {
                                    walkerStore.send(.dismissHistoryListTapped)
                                },
                                onSelectTrip: { trip in
                                    walkerStore.send(.selectHistoryTrip(trip))
                                }
                            )
                            .padding(.horizontal, 16)
                            .padding(.top, 12)
                            .transition(.opacity)
                        } else {
                            let userEmail = sampleData.first(where: { $0.displayName.localizedCaseInsensitiveContains(walkerStore.walker.name) })?.icloud
                                ?? (walkerStore.walker.name == "Doe" ? "doe@icloud.com" : "\(walkerStore.walker.name.lowercased().filter { !$0.isWhitespace })@icloud.com")
                            WalkerCardIdle(
                                name: walkerStore.walker.name,
                                email: userEmail,
                                trips: walkerStore.trips,
                                onDismiss: {
                                    walkerStore.send(.dismissWalkerTapped)
                                    withAnimation(.easeInOut(duration: 0.25)) {
                                        selectedDetent = .fraction(0.42)
                                    }
                                },
                                onViewAllHistory: {
                                    walkerStore.send(.viewAllHistoryTapped)
                                },
                                onSelectTrip: { trip in
                                    walkerStore.send(.selectHistoryTrip(trip))
                                }
                            )
                            .padding(.horizontal, 16)
                            .padding(.top, 12)
                            .transition(.opacity)
                        }
                    } else {
                            WalkerCardWalking(
                                walker: WalkerProfile(
                                    name: walkerStore.walker.name,
                                    locationSubtitle: "Central Jakarta, Jakarta",
                                    timeAgo: "1 Min Ago",
                                    originPlaceName: walkerStore.originPlaceName,
                                    originIconName: walkerStore.originIconName,
                                    destinationPlaceName: walkerStore.destinationPlaceName,
                                    destinationIconName: walkerStore.destinationIconName,
                                    recentLocations: walkerStore.journeyLogEntries.isEmpty ? WalkerSampleData.awanLocations : walkerStore.journeyLogEntries
                                ),
                                initialTracked: walkerStore.activeParticipantID != nil,
                                onDismiss: {
                                    walkerStore.send(.dismissWalkerTapped)
                                    withAnimation(.easeInOut(duration: 0.25)) {
                                        selectedDetent = .fraction(0.42)
                                    }
                                },
                                onTrack: {
                                    walkerStore.send(.trackTapped)
                                },
                                onExitTrack: {
                                    walkerStore.send(.exitTrackTapped)
                                    withAnimation(.easeInOut(duration: 0.25)) {
                                        selectedDetent = .fraction(0.35)
                                    }
                                },
                                onReachDestination: {
                                    walkerStore.send(.reachDestinationTapped)
                                    withAnimation(.easeInOut(duration: 0.25)) {
                                        selectedDetent = .fraction(0.35)
                                    }
                                }
                            )
                            .id(walkerStore.activeParticipantID != nil)
                            .padding(.horizontal, 16)
                            .padding(.top, 12)
                            .transition(.opacity)
                    }
                }
            } else {
                // Main Content (when sheet state is nil)
                MapSheetMainContent(
                    store: store,
                    isExpanded: isExpanded,
                    onSearchTapped: {
                        store.send(.map(.searchTapped))
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                            selectedDetent = .large
                        }
                    },
                    onSelectPlace: { place in
                        store.send(.map(.selectSavedPlace(place)))
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                            selectedDetent = .fraction(0.52)
                        }
                    },
                    onSelectPerson: { person in
                        store.send(.map(.selectPerson(person)))
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                            selectedDetent = .fraction(0.42)
                        }
                    },
                    onSavedPlacesHeaderTapped: {
                        store.send(.savedPlacesHeaderTapped)
                    }
                )
                .transition(.opacity)
            }
        }
        .scrollDismissesKeyboard(.interactively)
    }
    }

