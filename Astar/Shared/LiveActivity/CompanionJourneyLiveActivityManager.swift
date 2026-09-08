import Foundation
import ActivityKit

public final class CompanionJourneyLiveActivityManager {
    public static let shared = CompanionJourneyLiveActivityManager()

    private var activity: Activity<CompanionJourneyAttributes>?

    private init() {}

    public func startActivity(walkerName: String) {
        // Guard if ActivityKit is not supported
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }

        let attributes = CompanionJourneyAttributes(walkerName: walkerName)
        let contentState = CompanionJourneyAttributes.ContentState(
            latestLandmarkName: "Menunggu log pertama...",
            latestTimeString: "--:--",
            isArrived: false
        )

        do {
            if #available(iOS 16.2, *) {
                let content = ActivityContent(state: contentState, staleDate: nil, relevanceScore: 100)
                self.activity = try Activity.request(
                    attributes: attributes,
                    content: content
                )
            } else {
                self.activity = try Activity.request(
                    attributes: attributes,
                    contentState: contentState
                )
            }
            print("Successfully started Live Activity for \(walkerName) with id \(activity?.id ?? "")")
        } catch {
            print("Failed to start Live Activity: \(error.localizedDescription)")
        }
    }

    public func updateActivity(latestLandmarkName: String, latestTimeString: String, isArrived: Bool) {
        guard let activity = self.activity else { return }

        let updatedState = CompanionJourneyAttributes.ContentState(
            latestLandmarkName: latestLandmarkName,
            latestTimeString: latestTimeString,
            isArrived: isArrived
        )

        Task {
            if #available(iOS 16.2, *) {
                let content = ActivityContent(state: updatedState, staleDate: nil, relevanceScore: 100)
                await activity.update(content)
            } else {
                await activity.update(using: updatedState)
            }
        }
    }

    public func endActivity() {
        guard let activity = self.activity else { return }

        let finalState = activity.contentState

        Task {
            if #available(iOS 16.2, *) {
                let content = ActivityContent(state: finalState, staleDate: nil)
                await activity.end(content, dismissalPolicy: .default)
            } else {
                await activity.end(using: finalState, dismissalPolicy: .default)
            }
            self.activity = nil
        }
    }
}
