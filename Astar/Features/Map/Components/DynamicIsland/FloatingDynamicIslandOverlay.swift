//
//  FloatingDynamicIslandOverlay.swift
//  Astar
//
//  Interactive in-app Dynamic Island Pill, Hold-to-Expand, & Google Maps Card Preview
//

import SwiftUI

public struct FloatingDynamicIslandOverlay: View {
  public let state: TrailWalkAttributes.ContentState
  public let attributes: TrailWalkAttributes
  @State private var isExpanded: Bool = false

  public init(state: TrailWalkAttributes.ContentState, attributes: TrailWalkAttributes) {
    self.state = state
    self.attributes = attributes
  }

  public var body: some View {
    VStack(spacing: 8) {
      if isExpanded {
        // Expanded Google Maps Style View
        GoogleMapsLiveActivityCard(
          walkerName: attributes.walkerName,
          destinationTitle: attributes.destinationTitle,
          originTitle: attributes.originTitle,
          currentLandmark: state.currentLandmark,
          progress: state.progressPercentage,
          remainingDistanceMeters: state.remainingDistanceMeters,
          expectedTravelTime: state.expectedTravelTime,
          etaString: state.formattedETA,
          isApproaching: state.isApproaching
        )
        .overlay(alignment: .topTrailing) {
          Button {
            triggerLightHaptic()
            withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
              isExpanded = false
            }
          } label: {
            Image(systemName: "chevron.up.circle.fill")
              .font(.system(size: 20))
              .foregroundStyle(.white.opacity(0.6))
              .padding(12)
          }
          .buttonStyle(.plain)
        }
        .onTapGesture {
          triggerLightHaptic()
          withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
            isExpanded = false
          }
        }
        .transition(.asymmetric(
          insertion: .scale(scale: 0.85).combined(with: .opacity),
          removal: .scale(scale: 0.85).combined(with: .opacity)
        ))
      } else {
        // Compact Dynamic Island Pill
        compactIslandPill
          .onTapGesture {
            triggerLightHaptic()
            withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
              isExpanded = true
            }
          }
          .onLongPressGesture(minimumDuration: 0.15) {
            triggerMediumHaptic()
            withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
              isExpanded = true
            }
          }
          .transition(.asymmetric(
            insertion: .scale(scale: 0.85).combined(with: .opacity),
            removal: .scale(scale: 0.85).combined(with: .opacity)
          ))
      }
    }
    .padding(.horizontal, 16)
    .padding(.top, 12)
  }

  private var compactIslandPill: some View {
    HStack(spacing: 8) {
      // Leading: Travel Time remaining (e.g. 1 hr 33 min / 6 min)
      HStack(spacing: 6) {
        Image(systemName: "figure.walk")
          .font(.system(size: 11, weight: .bold))
          .foregroundStyle(state.isApproaching ? Color.green : Color(red: 0.20, green: 0.50, blue: 0.98))

        Text(state.expectedTravelTime)
          .font(.system(size: 13, weight: .bold, design: .rounded))
          .monospacedDigit()
          .foregroundStyle(.white)
      }

      Spacer()

      // Trailing: Distance remaining (e.g. 30 km / 650 m)
      Text(state.formattedDistanceRemaining)
        .font(.system(size: 13, weight: .bold, design: .rounded))
        .monospacedDigit()
        .foregroundStyle(state.isApproaching ? Color.green : .white)
    }
    .padding(.horizontal, 14)
    .padding(.vertical, 8)
    .frame(maxWidth: 240)
    .background(Color.black)
    .clipShape(Capsule())
    .overlay(
      Capsule()
        .stroke(state.isApproaching ? Color.green.opacity(0.6) : Color.white.opacity(0.18), lineWidth: 1.2)
    )
    .shadow(color: Color.black.opacity(0.45), radius: 10, x: 0, y: 5)
  }

  private func triggerLightHaptic() {
    UIImpactFeedbackGenerator(style: .light).impactOccurred()
  }

  private func triggerMediumHaptic() {
    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
  }
}
