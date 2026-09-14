//
//  TrailWalkAttributes.swift
//  Astar
//
//  ActivityKit Live Activity Attributes & Dynamic ContentState Contract
//

import ActivityKit
import Foundation

/// ============================================================================
/// 📲 LIVE ACTIVITY & DYNAMIC ISLAND SCHEMA (TrailWalkAttributes)
/// ============================================================================
///
/// 💡 TEORI & ANALOGI PYTHON / COMPUTER SCIENCE:
/// - ActivityKit Apple memisahkan data menjadi dua domain:
///   1. **Static Data (Attributes)**: Nilai invarian yang tidak pernah berubah
///      selama sesi (nama tujuan, ID sesi, nama user).
///   2. **Dynamic Data (ContentState)**: Time-series telemetry yang berubah
///      secara kontinu (posisi jalan, jarak tersisa, persentase ETA).
/// - Protokol `ActivityAttributes`: Kontrak type-safe antara proses utama aplikasi
///   dengan proses ekstensi widget sistem iOS.
/// ============================================================================
public struct TrailWalkAttributes: ActivityAttributes, Equatable, Hashable {
  // MARK: - Static Attributes (Data Konstan Selama Perjalanan)
  public var sessionID: String
  public var walkerName: String
  public var originTitle: String
  public var destinationTitle: String

  // MARK: - Dynamic State (Data Telemetri Berubah-Ubah)
  public struct ContentState: Codable, Hashable, Equatable {
    public var step: String
    public var progressPercentage: Double
    public var remainingDistanceMeters: Double
    public var currentLandmark: String
    public var estimatedArrivalDate: Date
    public var expectedTravelTime: String
    public var isApproaching: Bool

    public init(
      step: String = "Walking",
      progressPercentage: Double = 0.0,
      remainingDistanceMeters: Double = 0.0,
      currentLandmark: String = "",
      estimatedArrivalDate: Date = Date(),
      expectedTravelTime: String = "5 min",
      isApproaching: Bool = false
    ) {
      self.step = step
      self.progressPercentage = progressPercentage
      self.remainingDistanceMeters = remainingDistanceMeters
      self.currentLandmark = currentLandmark
      self.estimatedArrivalDate = estimatedArrivalDate
      self.expectedTravelTime = expectedTravelTime
      self.isApproaching = isApproaching
    }

    /// Format jarak ramah baca (misal: "1.2 km" atau "450 m")
    public var formattedDistanceRemaining: String {
      if remainingDistanceMeters >= 1000 {
        return String(format: "%.1f km", remainingDistanceMeters / 1000.0)
      } else {
        return "\(Int(remainingDistanceMeters)) m"
      }
    }

    /// Format waktu estimasi tiba jam:menit
    public var formattedETA: String {
      let formatter = DateFormatter()
      formatter.dateFormat = "HH.mm"
      return formatter.string(from: estimatedArrivalDate)
    }

    /// Deteksi apakah pejalan kaki sudah sampai di tujuan
    public var isArrived: Bool {
      step.lowercased() == "arrived" || progressPercentage >= 1.0 || expectedTravelTime.lowercased() == "arrived"
    }

    public var headerTitle: String {
      if isArrived {
        return "Arrived at destination"
      }
      return "Walk \(expectedTravelTime) (\(formattedDistanceRemaining))"
    }

    public func subtitle(destinationTitle: String) -> String {
      let landmark = currentLandmark.isEmpty ? destinationTitle : currentLandmark
      if isArrived {
        return "Completed · \(landmark)"
      }
      return "Arrive \(formattedETA) · \(landmark)"
    }
  }

  public init(
    sessionID: String,
    walkerName: String,
    originTitle: String = "Starting Point",
    destinationTitle: String
  ) {
    self.sessionID = sessionID
    self.walkerName = walkerName
    self.originTitle = originTitle
    self.destinationTitle = destinationTitle
  }
}
