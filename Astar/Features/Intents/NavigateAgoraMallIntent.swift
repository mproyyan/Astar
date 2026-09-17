/// ============================================================================
/// ⚡️ APP INTENT - AGORA MALL SHORTCUT (NavigateAgoraMallIntent)
/// ============================================================================
///
/// 💡 COMPUTER SCIENCE CONCEPTS:
/// - **Inter-Process Remote Procedure Call (IPC / RPC) via SiriKit**:
///   `AppIntent` exposes an application capability to the host operating system (iOS SpringBoard,
///   Siri voice assistant, and Shortcuts automation engine). The OS invokes this intent out-of-process.
/// - **Deep-Link URL Dispatching & IPC Transport**:
///   Constructs a custom URL scheme (`astar://navigate?lat=...&lon=...`) and delegates to
///   `UIApplication.shared.open()`, acting as an inter-process message passing channel to trigger
///   navigation within the active UI window.
///
/// 🌍 REAL-LIFE ANALOGY:
///   Think of a speed-dial button on an intercom telephone. Instead of picking up the handset,
///   opening the phonebook, and dialing 10 digits to reach Agora Mall, pressing the speed-dial
///   button transmits the pre-programmed frequency directly to the switchboard.
/// ============================================================================
//
//  NavigateAgoraMallIntent.swift
//  Astar
//
//  Created by Dimas Prihady Setyawan on 26/08/26.
//

import AppIntents
import Foundation

/// ============================================================================
/// 🛍️ SIRI INTENT: NAVIGASI KE AGORA MALL
/// ============================================================================
struct NavigateAgoraMallIntent: AppIntent {
  static var title: LocalizedStringResource = "Navigate to Agora Mall"
  static var description = IntentDescription("Directly start walking navigation from your current location to Agora Mall.")
  static var openAppWhenRun: Bool = true

  @MainActor
  func perform() async throws -> some IntentResult {
    // Mengirim payload "destination": "Agora Mall" via NotificationCenter
    NotificationCenter.default.post(
      name: .startDirectNavigation,
      object: nil,
      userInfo: ["destination": "Agora Mall"]
    )
    return .result()
  }
}
