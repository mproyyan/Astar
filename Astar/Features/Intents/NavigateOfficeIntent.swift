/// ============================================================================
/// ⚡️ APP INTENT - OFFICE SHORTCUT (NavigateOfficeIntent)
/// ============================================================================
///
/// 💡 COMPUTER SCIENCE CONCEPTS:
/// - **Static Command Pattern & OS Integration**:
///   Encapsulates an operation as an executable object (`perform() async throws -> some IntentResult`)
///   registered in the iOS System Capability Table.
/// - **Declarative Metadata & System Reflection**:
///   Static metadata (`title`, `description`, `openAppWhenRun`) is compiled into an OS-level
///   metadata dictionary allowing Spotlight search to index app capabilities without loading the
///   entire executable into RAM.
///
/// 🌍 REAL-LIFE ANALOGY:
///   Think of an emergency express elevator key. You don't have to navigate each floor lobby;
///   inserting the key sends the elevator straight to your office floor with a single command.
/// ============================================================================
//
//  NavigateOfficeIntent.swift
//  Astar
//
//  Created by Dimas Prihady Setyawan on 26/08/26.
//

import AppIntents
import Foundation

/// ============================================================================
/// 🏢 SIRI INTENT: NAVIGASI KE KANTOR (Autograph Tower)
/// ============================================================================
struct NavigateOfficeIntent: AppIntent {
  static var title: LocalizedStringResource = "Navigate to Office"
  static var description = IntentDescription("Directly start walking navigation from your current location to Autograph Tower (Office).")
  static var openAppWhenRun: Bool = true

  @MainActor
  func perform() async throws -> some IntentResult {
    // Mengirim payload "destination": "Office" via NotificationCenter
    NotificationCenter.default.post(
      name: .startDirectNavigation,
      object: nil,
      userInfo: ["destination": "Office"]
    )
    return .result()
  }
}
