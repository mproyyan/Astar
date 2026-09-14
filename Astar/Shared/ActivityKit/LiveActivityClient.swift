//
//  LiveActivityClient.swift
//  Astar
//
//  TCA Dependency Client for ActivityKit Live Activities
//

import ActivityKit
import ComposableArchitecture
import Foundation

/// ============================================================================
/// 🏝️ LIVE ACTIVITY & DYNAMIC ISLAND CLIENT (@DependencyClient)
/// ============================================================================
///
/// 💡 TEORI & ANALOGI PYTHON / COMPUTER SCIENCE:
/// - Ini adalah implementasi **Adapter Pattern** dan **Dependency Inversion Principle (DIP)**:
///   Logika bisnis Reducer tidak boleh mengontrol framework `ActivityKit` secara langsung,
///   melainkan melalui kontrak fungsi abstrak (`startLiveActivity`, `updateLiveActivity`, dll).
/// - Keuntungan untuk Unit Test:
///   Dalam unit test, kita menyuntikkan `testValue` (mock tanpa efek samping), sehingga
///   tes dapat berjalan di CI/CD tanpa perangkat fisik iOS.
/// ============================================================================
@DependencyClient
public struct LiveActivityClient: Sendable {
  public var startLiveActivity: @Sendable (TrailWalkAttributes, TrailWalkAttributes.ContentState) async throws -> Void
  public var updateLiveActivity: @Sendable (String, TrailWalkAttributes.ContentState) async -> Void
  public var endLiveActivity: @Sendable (String, TrailWalkAttributes.ContentState?) async -> Void
  public var endAllLiveActivities: @Sendable () async -> Void
}

extension LiveActivityClient: DependencyKey {
  /// Implementasi nyata (Live Value) yang berinteraksi langsung dengan sistem operasi iOS:
  public static let liveValue: Self = {
    return Self(
      startLiveActivity: { attributes, state in
        // 1. Cek otorisasi fitur Live Activities pada pengaturan sistem iPhone
        guard ActivityAuthorizationInfo().areActivitiesEnabled else {
          print("⚠️ [LiveActivityClient] Live Activities are disabled or not supported in Info.plist!")
          return
        }
        // 2. Bersihkan sesi lama yang memiliki sessionID sama untuk mencegah duplikasi widget
        for activity in Activity<TrailWalkAttributes>.activities where activity.attributes.sessionID == attributes.sessionID {
          await activity.end(nil, dismissalPolicy: .immediate)
        }
        // 3. Bungkus content state dengan relevansi skor dan waktu kadaluarsa (stale date)
        let content = ActivityContent(
          state: state,
          staleDate: Date().addingTimeInterval(300), // 5 menit dianggap basi jika tidak ada ping GPS
          relevanceScore: state.isApproaching ? 100 : 80 // Prioritaskan di Dynamic Island jika hampir sampai
        )
        do {
          // 4. Minta sistem operasi meluncurkan Live Activity di Lock Screen
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
        // Cari aktivitas yang cocok dengan ID sesi dan dorong konten baru
        for activity in Activity<TrailWalkAttributes>.activities where activity.attributes.sessionID == sessionID {
          await activity.update(content)
        }
      },
      endLiveActivity: { sessionID, finalState in
        let finalContent: ActivityContent<TrailWalkAttributes.ContentState>?
        if let finalState = finalState {
          finalContent = ActivityContent(
            state: finalState,
            staleDate: nil,
            relevanceScore: 100
          )
        } else {
          finalContent = nil
        }
        // Akhiri aktivitas di Lock Screen
        for activity in Activity<TrailWalkAttributes>.activities where activity.attributes.sessionID == sessionID {
          if let finalContent = finalContent {
            await activity.end(finalContent, dismissalPolicy: .default)
          } else {
            await activity.end(nil, dismissalPolicy: .immediate)
          }
        }
      },
      endAllLiveActivities: {
        for activity in Activity<TrailWalkAttributes>.activities {
          await activity.end(nil, dismissalPolicy: .immediate)
        }
      }
    )
  }()

  // Implementasi Mock untuk Unit Testing (No-Op):
  public static let testValue: Self = Self(
    startLiveActivity: { _, _ in },
    updateLiveActivity: { _, _ in },
    endLiveActivity: { _, _ in },
    endAllLiveActivities: { }
  )
  public static let previewValue: Self = Self(
    startLiveActivity: { _, _ in },
    updateLiveActivity: { _, _ in },
    endLiveActivity: { _, _ in },
    endAllLiveActivities: { }
  )
}

/// Mendaftarkan client ke ekosistem Dependency Injection TCA
extension DependencyValues {
  public var liveActivityClient: LiveActivityClient {
    get { self[LiveActivityClient.self] }
    set { self[LiveActivityClient.self] = newValue }
  }
}
