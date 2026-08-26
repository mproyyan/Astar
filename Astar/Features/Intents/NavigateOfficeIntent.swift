//
//  NavigateOfficeIntent.swift
//  Astar
//
//  Created by Dimas Prihady Setyawan on 26/08/26.
//

import AppIntents
import Foundation

struct NavigateOfficeIntent: AppIntent {
  static var title: LocalizedStringResource = "Navigate to Office"
  static var description = IntentDescription("Directly start walking navigation from your current location to Autograph Tower (Office).")
  static var openAppWhenRun: Bool = true

  @MainActor
  func perform() async throws -> some IntentResult {
    NotificationCenter.default.post(
      name: .startDirectNavigation,
      object: nil,
      userInfo: ["destination": "Office"]
    )
    return .result()
  }
}
