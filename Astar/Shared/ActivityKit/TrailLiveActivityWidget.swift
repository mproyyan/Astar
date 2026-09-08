//
//  TrailLiveActivityWidget.swift
//  Astar
//
//  Live Activity & Dynamic Island Widget for Companion Walking Tracking
//

import ActivityKit
import SwiftUI
import WidgetKit

public struct TrailLiveActivityWidget: Widget {
  public init() {}

  public var body: some WidgetConfiguration {
    ActivityConfiguration(for: TrailWalkAttributes.self) { context in
      // Lock Screen / Notification Banner presentation
      GoogleMapsLiveActivityCard(
        walkerName: context.attributes.walkerName,
        destinationTitle: context.attributes.destinationTitle,
        originTitle: context.attributes.originTitle,
        currentLandmark: context.state.currentLandmark,
        progress: context.state.progressPercentage,
        remainingDistanceMeters: context.state.remainingDistanceMeters,
        expectedTravelTime: context.state.expectedTravelTime,
        etaString: context.state.formattedETA,
        isApproaching: context.state.isApproaching,
        isStale: context.isStale
      )
      .activityBackgroundTint(Color.black.opacity(0.85))
      .activitySystemActionForegroundColor(Color.white)
    } dynamicIsland: { context in
      DynamicIsland {
        // Expanded Dynamic Island presentation
        DynamicIslandExpandedRegion(.leading) {
          HStack(spacing: 6) {
            ZStack {
              Circle()
                .fill(context.state.isApproaching ? Color.green.opacity(0.25) : Color.blue.opacity(0.25))
                .frame(width: 28, height: 28)
              Image(systemName: "figure.walk")
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(context.state.isApproaching ? Color.green : Color(red: 0.20, green: 0.50, blue: 0.98))
            }
            VStack(alignment: .leading, spacing: 1) {
              Text(context.attributes.walkerName)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.white)
                .lineLimit(1)
              Text(context.state.isApproaching ? "Arriving" : "Walking")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(context.state.isApproaching ? Color.green : .white.opacity(0.7))
            }
          }
          .padding(.leading, 4)
        }

        DynamicIslandExpandedRegion(.trailing) {
          HStack(spacing: 6) {
            VStack(alignment: .trailing, spacing: 1) {
              Text("ETA \(context.state.formattedETA)")
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(.white)
              Text(context.state.formattedDistanceRemaining)
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(.white.opacity(0.7))
            }
            ZStack {
              Circle()
                .fill(Color.white.opacity(0.12))
                .frame(width: 28, height: 28)
              Image(systemName: "mappin.circle.fill")
                .font(.system(size: 18))
                .foregroundStyle(Color.red, Color.yellow)
            }
          }
          .padding(.trailing, 4)
        }

        DynamicIslandExpandedRegion(.center) {
          Text(context.state.headerTitle)
            .font(.system(size: 14, weight: .bold, design: .rounded))
            .monospacedDigit()
            .foregroundStyle(.white)
            .lineLimit(1)
        }

        DynamicIslandExpandedRegion(.bottom) {
          VStack(alignment: .leading, spacing: 6) {
            // Subtitle with Landmark & Status
            HStack {
              if context.isStale {
                Label("Updating...", systemImage: "arrow.trianglehead.2.clockwise")
                  .font(.system(size: 11, weight: .medium))
                  .foregroundStyle(Color.orange)
              } else {
                Text(context.state.subtitle(destinationTitle: context.attributes.destinationTitle))
                  .font(.system(size: 12, weight: .medium))
                  .foregroundStyle(.white.opacity(0.8))
                  .lineLimit(1)
              }
              Spacer()
            }

            // Route Progress line
            GeometryReader { geo in
              let totalWidth = geo.size.width
              let clampedProgress = min(max(context.state.progressPercentage, 0.0), 1.0)
              let usableWidth = max(0, totalWidth - 28)
              let indicatorX = 10 + (usableWidth * clampedProgress)

              ZStack(alignment: .leading) {
                Capsule()
                  .fill(Color.white.opacity(0.3))
                  .frame(height: 4)
                  .padding(.horizontal, 8)

                Capsule()
                  .fill(context.state.isApproaching ? Color.green : Color(red: 0.20, green: 0.50, blue: 0.98))
                  .frame(width: max(0, indicatorX), height: 4)
                  .padding(.leading, 8)

                ZStack {
                  Circle()
                    .fill(context.state.isApproaching ? Color.green : Color(red: 0.20, green: 0.50, blue: 0.98))
                    .frame(width: 18, height: 18)
                  Image(systemName: "location.north.fill")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundStyle(.white)
                    .rotationEffect(.degrees(90))
                }
                .offset(x: max(0, min(totalWidth - 20, indicatorX - 9)))

                HStack {
                  Spacer()
                  ZStack {
                    Circle()
                      .strokeBorder(Color.white, lineWidth: 2)
                      .background(Circle().fill(Color.black))
                      .frame(width: 10, height: 10)
                    Circle()
                      .fill(Color.white)
                      .frame(width: 3, height: 3)
                  }
                  .padding(.trailing, 4)
                }
              }
              .frame(height: 18)
            }
            .frame(height: 18)
          }
          .padding(.horizontal, 4)
          .padding(.top, 2)
        }
      } compactLeading: {
        // Compact Leading (Home Screen Dynamic Island Left)
        HStack(spacing: 4) {
          Image(systemName: "figure.walk")
            .font(.system(size: 10, weight: .bold))
            .foregroundStyle(context.state.isApproaching ? Color.green : Color(red: 0.20, green: 0.50, blue: 0.98))
          Text(context.state.expectedTravelTime)
            .font(.system(size: 12, weight: .bold, design: .rounded))
            .monospacedDigit()
            .foregroundStyle(.white)
        }
      } compactTrailing: {
        // Compact Trailing (Home Screen Dynamic Island Right)
        Text(context.state.formattedDistanceRemaining)
          .font(.system(size: 12, weight: .bold, design: .rounded))
          .monospacedDigit()
          .foregroundStyle(context.state.isApproaching ? Color.green : .white)
      } minimal: {
        // Minimal presentation
        Image(systemName: "figure.walk")
          .font(.system(size: 11, weight: .bold))
          .foregroundStyle(context.state.isApproaching ? Color.green : Color(red: 0.20, green: 0.50, blue: 0.98))
      }
      .keylineTint(context.state.isApproaching ? Color.green : Color(red: 0.20, green: 0.50, blue: 0.98))
    }
  }
}
