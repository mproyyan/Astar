//
//  AlwaysHomeIntent.swift
//  Astar
//
//  Created by Dimas Prihady Setyawan on 26/08/26.
//

import AppIntents
import Foundation

struct AlwaysHomeIntent: AppIntent {
  static var title: LocalizedStringResource = "Always Home"
  static var description = IntentDescription("Directly start walking navigation from your current location to your home.")
  static var openAppWhenRun: Bool = true

  @MainActor
  func perform() async throws -> some IntentResult {
    NotificationCenter.default.post(name: .startAlwaysHomeNavigation, object: nil)
    return .result()
  }
}
