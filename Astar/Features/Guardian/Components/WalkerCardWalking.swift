//
//  WalkerCardWalking.swift
//  Astar
//
//  Created by Dimas Prihady Setyawan on 25/08/26.
//

import SwiftUI

struct WalkerCardWalking: View {
    var walker: WalkerProfile = WalkerSampleData.defaultWalker
    var initialTracked: Bool = false
    var initialStatus: WalkerStatus = .available

    var onDismiss: (() -> Void)? = nil
    var onTrack: (() -> Void)? = nil
    var onExitTrack: (() -> Void)? = nil
    var onPing: (() -> Void)? = nil
    var onReachDestination: (() -> Void)? = nil

    @State private var isTracked: Bool
    @State private var currentStatus: WalkerStatus

    init(
        walker: WalkerProfile = WalkerSampleData.defaultWalker,
        initialTracked: Bool = false,
        initialStatus: WalkerStatus = .available,
        onDismiss: (() -> Void)? = nil,
        onTrack: (() -> Void)? = nil,
        onExitTrack: (() -> Void)? = nil,
        onPing: (() -> Void)? = nil,
        onReachDestination: (() -> Void)? = nil
    ) {
        self.walker = walker
        self.initialTracked = initialTracked
        self.initialStatus = initialStatus
        self.onDismiss = onDismiss
        self.onTrack = onTrack
        self.onExitTrack = onExitTrack
        self.onPing = onPing
        self.onReachDestination = onReachDestination
        self._isTracked = State(initialValue: initialTracked)
        self._currentStatus = State(initialValue: initialStatus)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Header: Title and Close Button
            HStack {
                Text("People")
                    .font(.title.weight(.bold))
                    .foregroundStyle(.primary)

                Spacer()

                Button {
                    onDismiss?()
                } label: {
                    Image(systemName: "xmark")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(.primary)
                        .frame(width: 36, height: 36)
                }
                .buttonStyle(.plain)
                .glassEffect(.regular.interactive(), in: .circle)
                .accessibilityLabel("Close")
            }

            // Profile Header
            WalkerProfileHeader(
                name: walker.name,
                locationSubtitle: walker.locationSubtitle,
                timeAgo: walker.timeAgo,
                isTracked: isTracked,
                onTrack: {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                        isTracked = true
                    }
                    onTrack?()
                },
                onExitTrack: {
                    if let onExitTrack {
                        onExitTrack()
                    } else if let onReachDestination {
                        onReachDestination()
                    } else {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                            isTracked = false
                        }
                    }
                },
                onPing: onPing
            )

            // Status Section (Tracked mode)
            if isTracked {
                WalkerStatusSection(
                    status: currentStatus,
                    onCycleStatus: {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            cycleStatus()
                        }
                    }
                )
                .transition(.asymmetric(
                    insertion: .opacity.combined(with: .move(edge: .top)),
                    removal: .opacity
                ))
            }

            // Route Card
            WalkerCardRoute(
                originName: walker.originPlaceName,
                originIconName: walker.originIconName,
                destinationName: walker.destinationPlaceName,
                destinationIconName: walker.destinationIconName
            )

            // Recent Locations Card
            WalkerCardRecentLocations(locations: walker.recentLocations)
        }
        .padding(.top, 8)
    }

    private func cycleStatus() {
        let allStatuses = WalkerStatus.allCases
        guard let currentIndex = allStatuses.firstIndex(of: currentStatus) else { return }
        let nextIndex = (currentIndex + 1) % allStatuses.count
        currentStatus = allStatuses[nextIndex]
    }
}

#Preview("Untracked") {
    ScrollView {
        WalkerCardWalking(initialTracked: false)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
    }
    .background(Color(red: 0.95, green: 0.95, blue: 0.97))
}

#Preview("Tracked - Available") {
    ScrollView {
        WalkerCardWalking(initialTracked: true, initialStatus: .available)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
    }
    .background(Color(red: 0.95, green: 0.95, blue: 0.97))
}

#Preview("Tracked - Not Moving") {
    ScrollView {
        WalkerCardWalking(initialTracked: true, initialStatus: .notMoving)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
    }
    .background(Color(red: 0.95, green: 0.95, blue: 0.97))
}

#Preview("Tracked - No Response") {
    ScrollView {
        WalkerCardWalking(initialTracked: true, initialStatus: .noResponse)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
    }
    .background(Color(red: 0.95, green: 0.95, blue: 0.97))
}
