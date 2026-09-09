//
//  TrailWalkAttributes.swift
//  Astar
//
//  ActivityKit Live Activity Attributes & Dynamic ContentState Contract
//

import ActivityKit
import Foundation

public struct TrailWalkAttributes: ActivityAttributes, Equatable, Hashable {
  public var sessionID: String
  public var walkerName: String
  public var originTitle: String
  public var destinationTitle: String

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

    public var formattedDistanceRemaining: String {
      if remainingDistanceMeters >= 1000 {
        return String(format: "%.1f km", remainingDistanceMeters / 1000.0)
      } else {
        return "\(Int(remainingDistanceMeters)) m"
      }
    }

    public var formattedETA: String {
      let formatter = DateFormatter()
      formatter.dateFormat = "HH.mm"
      return formatter.string(from: estimatedArrivalDate)
    }

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
