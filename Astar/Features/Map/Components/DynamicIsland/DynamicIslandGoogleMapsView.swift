//
//  DynamicIslandGoogleMapsView.swift
//  Astar
//
//  Google Maps style Live Activity Card & Dynamic Island Presentation
//

import SwiftUI

public struct GoogleMapsLiveActivityCard: View {
  public let walkerName: String
  public let destinationTitle: String
  public let originTitle: String
  public let currentLandmark: String
  public let progress: Double
  public let remainingDistanceMeters: Double
  public let expectedTravelTime: String
  public let etaString: String
  public let isApproaching: Bool
  public let isStale: Bool

  public init(
    walkerName: String,
    destinationTitle: String,
    originTitle: String,
    currentLandmark: String,
    progress: Double,
    remainingDistanceMeters: Double,
    expectedTravelTime: String,
    etaString: String,
    isApproaching: Bool = false,
    isStale: Bool = false
  ) {
    self.walkerName = walkerName
    self.destinationTitle = destinationTitle
    self.originTitle = originTitle
    self.currentLandmark = currentLandmark
    self.progress = progress
    self.remainingDistanceMeters = remainingDistanceMeters
    self.expectedTravelTime = expectedTravelTime
    self.etaString = etaString
    self.isApproaching = isApproaching
    self.isStale = isStale
  }

  public var formattedDistance: String {
    if remainingDistanceMeters >= 1000 {
      return String(format: "%.1f km", remainingDistanceMeters / 1000.0)
    } else {
      return "\(Int(remainingDistanceMeters)) m"
    }
  }

  public var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      // Header: Walk Time & Distance + Destination Pin
      HStack(alignment: .top) {
        VStack(alignment: .leading, spacing: 3) {
          HStack(spacing: 6) {
            Text("Walk \(expectedTravelTime) (\(formattedDistance))")
              .font(.system(size: 19, weight: .bold, design: .rounded))
              .monospacedDigit()
              .foregroundStyle(.white)

            if isApproaching {
              Text("ARRIVING")
                .font(.system(size: 9, weight: .bold))
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Color.green.opacity(0.35))
                .foregroundStyle(Color.green)
                .clipShape(Capsule())
            }
          }

          if isStale {
            HStack(spacing: 4) {
              Image(systemName: "arrow.trianglehead.2.clockwise")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Color.orange)
              Text("Updating position...")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(Color.orange.opacity(0.9))
            }
          } else {
            let displayLandmark = currentLandmark.isEmpty ? destinationTitle : currentLandmark
            Text("ETA \(etaString) · \(displayLandmark)")
              .font(.system(size: 13, weight: .medium))
              .foregroundStyle(.white.opacity(0.82))
              .lineLimit(1)
          }
        }

        Spacer()

        // Top-right Destination Pin Marker
        ZStack {
          Circle()
            .fill(Color.white.opacity(0.12))
            .frame(width: 32, height: 32)
          Image(systemName: "mappin.circle.fill")
            .font(.system(size: 20))
            .foregroundStyle(Color.red, Color.yellow)
        }
      }

      // Google Maps Route Progress Line with Navigation Arrow & Target Point
      GeometryReader { geo in
        let totalWidth = geo.size.width
        let clampedProgress = min(max(progress, 0.0), 1.0)
        let usableWidth = max(0, totalWidth - 36)
        let indicatorX = 14 + (usableWidth * clampedProgress)

        ZStack(alignment: .leading) {
          // Inactive Track Line
          Capsule()
            .fill(Color.white.opacity(0.3))
            .frame(height: 4)
            .padding(.horizontal, 12)

          // Active Bright Blue Progress Line
          Capsule()
            .fill(isApproaching ? Color.green : Color(red: 0.20, green: 0.50, blue: 0.98))
            .frame(width: max(0, indicatorX), height: 4)
            .padding(.leading, 12)

          // Moving Navigation Indicator Circle
          ZStack {
            Circle()
              .fill(isApproaching ? Color.green : Color(red: 0.20, green: 0.50, blue: 0.98))
              .frame(width: 22, height: 22)
              .shadow(color: Color.black.opacity(0.35), radius: 3, y: 1)
            Image(systemName: "location.north.fill")
              .font(.system(size: 10, weight: .bold))
              .foregroundStyle(.white)
              .rotationEffect(.degrees(90))
          }
          .offset(x: max(0, min(totalWidth - 28, indicatorX - 11)))
          .animation(.spring(response: 0.45, dampingFraction: 0.8), value: progress)

          // Right Destination Target Circle Marker
          HStack {
            Spacer()
            ZStack {
              Circle()
                .strokeBorder(Color.white, lineWidth: 2.5)
                .background(Circle().fill(Color.black))
                .frame(width: 12, height: 12)
              Circle()
                .fill(Color.white)
                .frame(width: 4, height: 4)
            }
            .padding(.trailing, 8)
          }
        }
        .frame(height: 22)
      }
      .frame(height: 22)
      .padding(.top, 4)
    }
    .padding(16)
    .background(Color(red: 0.08, green: 0.08, blue: 0.09))
    .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
    .overlay(
      RoundedRectangle(cornerRadius: 22, style: .continuous)
        .stroke(Color.white.opacity(0.14), lineWidth: 1)
    )
    .shadow(color: Color.black.opacity(0.5), radius: 14, x: 0, y: 7)
  }
}
