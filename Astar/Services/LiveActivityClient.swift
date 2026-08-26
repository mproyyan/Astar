//
//  LiveActivityClient.swift
//  Astar
//
//  ActivityKit Live Activity Client & Dependency for TCA
//

import Foundation
import ActivityKit
import Dependencies
import DependenciesMacros

@DependencyClient
public struct LiveActivityClient: Sendable {
    public var start: @Sendable (
        _ attributes: SafeWalkAttributes,
        _ initialContent: SafeWalkAttributes.ContentState
    ) async -> String?
    public var update: @Sendable (
        _ content: SafeWalkAttributes.ContentState
    ) async -> Void
    public var end: @Sendable (
        _ finalContent: SafeWalkAttributes.ContentState
    ) async -> Void
}

// Actor to safely manage active Activity instance
actor LiveActivityManager {
    static let shared = LiveActivityManager()
    private var currentActivity: Activity<SafeWalkAttributes>?

    func startActivity(
        attributes: SafeWalkAttributes,
        initialContent: SafeWalkAttributes.ContentState
    ) -> String? {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else {
            print("[LiveActivity] Live Activities are disabled by user or system.")
            return nil
        }

        // End any existing stale activity first
        if let existing = currentActivity {
            let staleContent = ActivityContent(state: initialContent, staleDate: nil)
            Task {
                await existing.end(staleContent, dismissalPolicy: .immediate)
            }
        }

        let content = ActivityContent(
            state: initialContent,
            staleDate: Date().addingTimeInterval(3600),
            relevanceScore: 100
        )

        do {
            let activity = try Activity<SafeWalkAttributes>.request(
                attributes: attributes,
                content: content,
                pushType: nil
            )
            self.currentActivity = activity
            print("[LiveActivity] Started Live Activity: \(activity.id)")
            return activity.id
        } catch {
            print("[LiveActivity] Failed to start Live Activity: \(error)")
            return nil
        }
    }

    func updateActivity(contentState: SafeWalkAttributes.ContentState) async {
        guard let activity = currentActivity else { return }
        let content = ActivityContent(
            state: contentState,
            staleDate: Date().addingTimeInterval(3600),
            relevanceScore: contentState.isApproaching ? 100 : 80
        )
        await activity.update(content)
        print("[LiveActivity] Updated Live Activity: \(contentState.currentLandmark) (\(contentState.formattedDistanceRemaining))")
    }

    func endActivity(finalContent: SafeWalkAttributes.ContentState) async {
        guard let activity = currentActivity else { return }
        let content = ActivityContent(state: finalContent, staleDate: nil, relevanceScore: 0)
        await activity.end(content, dismissalPolicy: .immediate)
        self.currentActivity = nil
        print("[LiveActivity] Ended Live Activity.")
    }
}

extension LiveActivityClient: DependencyKey {
    public static let liveValue = Self(
        start: { attributes, initialContent in
            await LiveActivityManager.shared.startActivity(
                attributes: attributes,
                initialContent: initialContent
            )
        },
        update: { content in
            await LiveActivityManager.shared.updateActivity(contentState: content)
        },
        end: { finalContent in
            await LiveActivityManager.shared.endActivity(finalContent: finalContent)
        }
    )

    public static let testValue = Self()
}

extension DependencyValues {
    public var liveActivity: LiveActivityClient {
        get { self[LiveActivityClient.self] }
        set { self[LiveActivityClient.self] = newValue }
    }
}
