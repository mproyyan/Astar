import Foundation
import ActivityKit

public struct CompanionJourneyAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        public var latestLandmarkName: String
        public var latestTimeString: String
        public var isArrived: Bool

        public init(latestLandmarkName: String, latestTimeString: String, isArrived: Bool) {
            self.latestLandmarkName = latestLandmarkName
            self.latestTimeString = latestTimeString
            self.isArrived = isArrived
        }
    }

    public var walkerName: String

    public init(walkerName: String) {
        self.walkerName = walkerName
    }
}
