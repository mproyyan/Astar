//
//  SafeWalkAttributes.swift
//  Astar
//
//  ActivityKit Live Activity Attributes & Dynamic ContentState Contract
//

import Foundation
import ActivityKit

public struct SafeWalkAttributes: ActivityAttributes {
    // Static attributes fixed for the activity lifetime
    public var sessionID: String
    public var walkerName: String
    public var originTitle: String
    public var destinationTitle: String
    public var destinationIcon: String

    public struct ContentState: Codable, Hashable, Sendable {
        public var step: String
        public var progressPercentage: Double
        public var remainingDistanceMeters: Double
        public var currentLandmark: String
        public var estimatedArrivalDate: Date
        public var isApproaching: Bool

        public init(
            step: String = "Walking",
            progressPercentage: Double = 0.05,
            remainingDistanceMeters: Double = 450,
            currentLandmark: String = "Autograph Tower Lobby",
            estimatedArrivalDate: Date = Date().addingTimeInterval(420),
            isApproaching: Bool = false
        ) {
            self.step = step
            self.progressPercentage = progressPercentage
            self.remainingDistanceMeters = remainingDistanceMeters
            self.currentLandmark = currentLandmark
            self.estimatedArrivalDate = estimatedArrivalDate
            self.isApproaching = isApproaching
        }

        public var formattedDistanceRemaining: String {
            if remainingDistanceMeters >= 1000 {
                return String(format: "%.1f km", remainingDistanceMeters / 1000.0)
            } else {
                return "\(Int(remainingDistanceMeters)) m"
            }
        }
    }

    public init(
        sessionID: String = UUID().uuidString,
        walkerName: String,
        originTitle: String = "Current Location",
        destinationTitle: String = "Destination",
        destinationIcon: String = "bag.fill"
    ) {
        self.sessionID = sessionID
        self.walkerName = walkerName
        self.originTitle = originTitle
        self.destinationTitle = destinationTitle
        self.destinationIcon = destinationIcon
    }
}
