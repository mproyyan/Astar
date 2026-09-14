//
//  TrailLiveActivityWidget.swift
//  Astar
//
//  Live Activity & Dynamic Island Widget for Companion Walking Tracking
//

import ActivityKit
import SwiftUI
import WidgetKit

/// ============================================================================
/// 🏝️ DYNAMIC ISLAND & LOCK SCREEN WIDGET (TrailLiveActivityWidget)
/// ============================================================================
///
/// 💡 TEORI & ANALOGI PYTHON / COMPUTER SCIENCE:
/// - Dalam sistem operasi modern Apple, widget ini dirender dalam proses sandbox
///   terpisah (`WidgetExtension`) yang dikendalikan langsung oleh SpringBoard (Window Manager iOS).
/// - Menyediakan 4 mode rendering adaptif sesuai kondisi perangkat:
///   1. **Lock Screen Banner**: Tampilan kartu penuh saat ponsel terkunci.
///   2. **Dynamic Island Expanded**: Tampilan interaktif saat Dynamic Island ditekan lama (Long-press).
///   3. **Dynamic Island Compact (Leading & Trailing)**: Tampilan kapsul ganda saat ponsel sedang digunakan membuka app lain.
///   4. **Dynamic Island Minimal**: Tampilan lingkaran tunggal ketika ada lebih dari satu Live Activity aktif di OS.
/// ============================================================================
public struct TrailLiveActivityWidget: Widget {
  public init() {}

  public var body: some WidgetConfiguration {
    ActivityConfiguration(for: TrailWalkAttributes.self) { context in
      // 1. TAMPILAN LOCK SCREEN & BANNER NOTIFIKASI
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
        // 2. TAMPILAN DYNAMIC ISLAND: EXPANDED (Saat disentuh lama)
        
        // Region Kiri (Leading): Avatar & Status Pejalan Kaki
        DynamicIslandExpandedRegion(.leading) {
          HStack(spacing: 6) {
            ZStack {
              Circle()
                .fill((context.state.isArrived || context.state.isApproaching) ? Color.green.opacity(0.25) : Color.blue.opacity(0.25))
                .frame(width: 28, height: 28)
              Image(systemName: context.state.isArrived ? "checkmark" : "figure.walk")
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle((context.state.isArrived || context.state.isApproaching) ? Color.green : Color(red: 0.20, green: 0.50, blue: 0.98))
            }
            VStack(alignment: .leading, spacing: 1) {
              Text(context.attributes.walkerName)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.white)
                .lineLimit(1)
              Text(context.state.isArrived ? "Arrived" : (context.state.isApproaching ? "Arriving" : "Walking"))
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle((context.state.isArrived || context.state.isApproaching) ? Color.green : .white.opacity(0.7))
            }
          }
          .padding(.leading, 4)
        }

        // Region Kanan (Trailing): Waktu Estimasi Tiba (ETA) & Ikon Finis
        DynamicIslandExpandedRegion(.trailing) {
          HStack(spacing: 6) {
            VStack(alignment: .trailing, spacing: 1) {
              if context.state.isArrived {
                Text("Arrived")
                  .font(.system(size: 12, weight: .bold, design: .rounded))
                  .foregroundStyle(Color.green)
                Text("Complete")
                  .font(.system(size: 11, weight: .medium, design: .rounded))
                  .foregroundStyle(.white.opacity(0.7))
              } else {
                Text("ETA \(context.state.formattedETA)")
                  .font(.system(size: 12, weight: .bold, design: .rounded))
                  .monospacedDigit()
                  .foregroundStyle(.white)
                Text(context.state.formattedDistanceRemaining)
                  .font(.system(size: 11, weight: .medium, design: .rounded))
                  .monospacedDigit()
                  .foregroundStyle(.white.opacity(0.7))
              }
            }
            ZStack {
              Circle()
                .fill(Color.white.opacity(0.12))
                .frame(width: 28, height: 28)
              if context.state.isArrived {
                Image(systemName: "checkmark.circle.fill")
                  .font(.system(size: 20))
                  .foregroundStyle(Color.green)
              } else {
                Image(systemName: "mappin.circle.fill")
                  .font(.system(size: 18))
                  .foregroundStyle(Color.red, Color.yellow)
              }
            }
          }
          .padding(.trailing, 4)
        }

        // Region Tengah (Center): Judul Ringkasan Waktu Tempuh
        DynamicIslandExpandedRegion(.center) {
          Text(context.state.headerTitle)
            .font(.system(size: 14, weight: .bold, design: .rounded))
            .monospacedDigit()
            .foregroundStyle(.white)
            .lineLimit(1)
        }

        // Region Bawah (Bottom): Progress Bar Garis Jalan & Landmark Terkini
        DynamicIslandExpandedRegion(.bottom) {
          VStack(alignment: .leading, spacing: 6) {
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

            // Visualisasi Progress Bar Rute Jalan (Interpolasi Linear 0.0 s/d 1.0)
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
                  .fill((context.state.isArrived || context.state.isApproaching) ? Color.green : Color(red: 0.20, green: 0.50, blue: 0.98))
                  .frame(width: max(0, indicatorX), height: 4)
                  .padding(.leading, 8)

                // Indikator Posisi Walker di Progress Bar
                ZStack {
                  Circle()
                    .fill((context.state.isArrived || context.state.isApproaching) ? Color.green : Color(red: 0.20, green: 0.50, blue: 0.98))
                    .frame(width: 18, height: 18)
                  if context.state.isArrived {
                    Image(systemName: "checkmark")
                      .font(.system(size: 8, weight: .bold))
                      .foregroundStyle(.white)
                  } else {
                    Image(systemName: "location.north.fill")
                      .font(.system(size: 8, weight: .bold))
                      .foregroundStyle(.white)
                      .rotationEffect(.degrees(90))
                  }
                }
                .offset(x: max(0, min(totalWidth - 20, indicatorX - 9)))

                // Titik Finis Destinasi
                HStack {
                  Spacer()
                  ZStack {
                    Circle()
                      .strokeBorder(Color.white, lineWidth: 2)
                      .background(Circle().fill(context.state.isArrived ? Color.green : Color.black))
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
        // 3. TAMPILAN COMPACT LEADING (Kapsul Kiri Dynamic Island)
        HStack(spacing: 4) {
          if context.state.isArrived {
            Image(systemName: "checkmark.circle.fill")
              .font(.system(size: 11, weight: .bold))
              .foregroundStyle(Color.green)
            Text("Arrived")
              .font(.system(size: 12, weight: .bold, design: .rounded))
              .foregroundStyle(.white)
          } else {
            Image(systemName: "figure.walk")
              .font(.system(size: 10, weight: .bold))
              .foregroundStyle(context.state.isApproaching ? Color.green : Color(red: 0.20, green: 0.50, blue: 0.98))
            Text(context.state.expectedTravelTime)
              .font(.system(size: 12, weight: .bold, design: .rounded))
              .monospacedDigit()
              .foregroundStyle(.white)
          }
        }
      } compactTrailing: {
        // 4. TAMPILAN COMPACT TRAILING (Kapsul Kanan Dynamic Island)
        if context.state.isArrived {
          Image(systemName: "flag.checkered")
            .font(.system(size: 11, weight: .bold))
            .foregroundStyle(Color.green)
        } else {
          Text(context.state.formattedDistanceRemaining)
            .font(.system(size: 12, weight: .bold, design: .rounded))
            .monospacedDigit()
            .foregroundStyle(context.state.isApproaching ? Color.green : .white)
        }
      } minimal: {
        // 5. TAMPILAN MINIMAL (Lingkaran Tunggal jika berbagi Dynamic Island)
        Image(systemName: context.state.isArrived ? "checkmark.circle.fill" : "figure.walk")
          .font(.system(size: 11, weight: .bold))
          .foregroundStyle((context.state.isArrived || context.state.isApproaching) ? Color.green : Color(red: 0.20, green: 0.50, blue: 0.98))
      }
      .keylineTint((context.state.isArrived || context.state.isApproaching) ? Color.green : Color(red: 0.20, green: 0.50, blue: 0.98))
    }
  }
}
