//
//  FloatingDynamicIslandOverlay.swift
//  Astar
//
//  Interactive In-App Dynamic Island Pill, Hold-to-Expand, & Milestone Overlay
//

import SwiftUI

public struct FloatingDynamicIslandOverlay: View {
    public let walkerName: String
    public let originTitle: String
    public let destinationTitle: String
    public let progressState: SafeWalkAttributes.ContentState
    public var onExitTrack: (() -> Void)? = nil

    @State private var isExpanded: Bool = false

    public init(
        walkerName: String,
        originTitle: String = "Autograph Tower",
        destinationTitle: String = "Plaza Indonesia",
        progressState: SafeWalkAttributes.ContentState,
        onExitTrack: (() -> Void)? = nil
    ) {
        self.walkerName = walkerName
        self.originTitle = originTitle
        self.destinationTitle = destinationTitle
        self.progressState = progressState
        self.onExitTrack = onExitTrack
    }

    public var body: some View {
        VStack(spacing: 8) {
            if isExpanded {
                expandedIslandView
                    .onTapGesture {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                            isExpanded = false
                        }
                    }
                    .transition(.asymmetric(
                        insertion: .scale(scale: 0.9).combined(with: .opacity),
                        removal: .scale(scale: 0.9).combined(with: .opacity)
                    ))
            } else {
                compactIslandView
                    .onTapGesture {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                            isExpanded = true
                        }
                    }
                    .onLongPressGesture(minimumDuration: 0.2) {
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                            isExpanded = true
                        }
                    }
                    .transition(.opacity)
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 4)
    }

    // MARK: - Compact Island Capsule View
    private var compactIslandView: some View {
        HStack(spacing: 8) {
            // Leading: Walking Figure + Walker Name
            HStack(spacing: 5) {
                Image(systemName: "figure.walk.motion")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(progressState.isApproaching ? Color.green : Color.blue)
                Text(walkerName)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white)
            }

            Spacer()

            // Center: Passed Landmark
            HStack(spacing: 4) {
                Image(systemName: "mappin.circle.fill")
                    .font(.system(size: 11))
                    .foregroundStyle(Color.yellow)
                Text(progressState.currentLandmark)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.white.opacity(0.9))
                    .lineLimit(1)
            }
            .frame(maxWidth: 150)

            Spacer()

            // Trailing: Remaining Distance + Chevron
            HStack(spacing: 4) {
                Text(progressState.formattedDistanceRemaining)
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(progressState.isApproaching ? Color.green : Color.white)

                Image(systemName: "chevron.down")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(.white.opacity(0.5))
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(Color.black)
        .clipShape(Capsule())
        .overlay(
            Capsule()
                .stroke(progressState.isApproaching ? Color.green.opacity(0.5) : Color.white.opacity(0.18), lineWidth: 1.5)
        )
        .shadow(color: Color.black.opacity(0.35), radius: 12, x: 0, y: 6)
    }

    // MARK: - Expanded Stepper View
    private var expandedIslandView: some View {
        VStack(spacing: 12) {
            // Header Row
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "figure.walk.motion")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(progressState.isApproaching ? Color.green : Color.blue)
                    Text(walkerName)
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(.white)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 1) {
                    Text(progressState.formattedDistanceRemaining)
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundStyle(progressState.isApproaching ? Color.green : Color.white)
                    Text("remaining")
                        .font(.system(size: 10))
                        .foregroundStyle(.white.opacity(0.6))
                }
            }

            // GoFood-Style Stepper Progress Bar
            VStack(spacing: 6) {
                HStack(spacing: 8) {
                    Circle()
                        .fill(Color.green)
                        .frame(width: 8, height: 8)

                    ProgressView(value: min(1.0, max(0.04, progressState.progressPercentage)))
                        .tint(progressState.isApproaching ? Color.green : Color.blue)

                    Image(systemName: "flag.checkered")
                        .font(.system(size: 12))
                        .foregroundStyle(progressState.progressPercentage >= 1.0 ? Color.green : Color.white.opacity(0.6))
                }

                HStack {
                    Text(originTitle)
                        .font(.system(size: 11))
                        .foregroundStyle(.white.opacity(0.65))
                        .lineLimit(1)
                    Spacer()
                    Text(destinationTitle)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.9))
                        .lineLimit(1)
                }
            }

            // Landmark Milestone Callout Card
            HStack(spacing: 8) {
                Image(systemName: "mappin.and.ellipse")
                    .foregroundStyle(Color.yellow)
                    .font(.system(size: 13, weight: .semibold))
                Text(progressState.currentLandmark)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                Spacer()
                if progressState.isApproaching {
                    Text("NEARBY")
                        .font(.system(size: 9, weight: .bold))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.green.opacity(0.25))
                        .foregroundStyle(Color.green)
                        .clipShape(Capsule())
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color.white.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
        .padding(16)
        .background(Color.black)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(progressState.isApproaching ? Color.green.opacity(0.4) : Color.white.opacity(0.14), lineWidth: 1.5)
        )
        .overlay(alignment: .topTrailing) {
            Button {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                    isExpanded = false
                }
            } label: {
                Image(systemName: "chevron.up.circle.fill")
                    .font(.system(size: 18))
                    .foregroundStyle(.white.opacity(0.6))
                    .padding(12)
            }
        }
        .shadow(color: Color.black.opacity(0.45), radius: 16, x: 0, y: 8)
    }
}
