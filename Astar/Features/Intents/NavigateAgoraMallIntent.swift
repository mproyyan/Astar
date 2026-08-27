//
//  NavigateAgoraMallIntent.swift
//  Astar
//
//  Created by Dimas Prihady Setyawan on 26/08/26.
//

import AppIntents
import Foundation

struct NavigateAgoraMallIntent: AppIntent {
  static var title: LocalizedStringResource = "Navigate to Agora Mall"
  static var description = IntentDescription("Directly start walking navigation from your current location to Agora Mall.")
  static var openAppWhenRun: Bool = true

  @MainActor
  func perform() async throws -> some IntentResult {
    NotificationCenter.default.post(
      name: .startDirectNavigation,
      object: nil,
      userInfo: ["destination": "Agora Mall"]
    )
    return .result()
  }
}
