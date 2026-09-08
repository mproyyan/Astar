//
//  LiveActivityClient.swift
//  Astar
//
//  TCA Dependency Client for ActivityKit Live Activities
//

import ActivityKit
import ComposableArchitecture
import Foundation

@DependencyClient
public struct LiveActivityClient: Sendable {
  public var startLiveActivity: @Sendable (TrailWalkAttributes, TrailWalkAttributes.ContentState) async throws -> Void
  public var updateLiveActivity: @Sendable (String, TrailWalkAttributes.ContentState) async -> Void
  public var endLiveActivity: @Sendable (String) async -> Void
}

extension LiveActivityClient: DependencyKey {
  public static let liveValue: Self = {
    return Self(
      startLiveActivity: { attributes, state in
        guard ActivityAuthorizationInfo().areActivitiesEnabled else {
          print("⚠️ [LiveActivityClient] Live Activities are disabled or not supported in Info.plist!")
          return
        }
        // End any pre-existing activity for the same session
        for activity in Activity<TrailWalkAttributes>.activities where activity.attributes.sessionID == attributes.sessionID {
          await activity.end(nil, dismissalPolicy: .immediate)
        }
        let content = ActivityContent(
          state: state,
          staleDate: Date().addingTimeInterval(300),
          relevanceScore: state.isApproaching ? 100 : 80
        )
        do {
          let activity = try Activity.request(attributes: attributes, content: content, pushType: nil)
          print("✅ [LiveActivityClient] Started Live Activity: \(activity.id)")
        } catch {
          print("❌ [LiveActivityClient] Failed to start Live Activity: \(error)")
        }
      },
      updateLiveActivity: { sessionID, state in
        let content = ActivityContent(
          state: state,
          staleDate: Date().addingTimeInterval(300),
          relevanceScore: state.isApproaching ? 100 : 80
        )
        for activity in Activity<TrailWalkAttributes>.activities where activity.attributes.sessionID == sessionID {
          await activity.update(content)
        }
      },
      endLiveActivity: { sessionID in
        for activity in Activity<TrailWalkAttributes>.activities where activity.attributes.sessionID == sessionID {
          await activity.end(nil, dismissalPolicy: .immediate)
        }
      }
    )
  }()

  public static let testValue: Self = Self(
    startLiveActivity: { _, _ in },
    updateLiveActivity: { _, _ in },
    endLiveActivity: { _ in }
  )
  public static let previewValue: Self = Self(
    startLiveActivity: { _, _ in },
    updateLiveActivity: { _, _ in },
    endLiveActivity: { _ in }
  )
}

extension DependencyValues {
  public var liveActivityClient: LiveActivityClient {
    get { self[LiveActivityClient.self] }
    set { self[LiveActivityClient.self] = newValue }
  }
}
