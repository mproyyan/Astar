//
//  AlwaysHomeIntent.swift
//  Astar
//
//  Created by Dimas Prihady Setyawan on 26/08/26.
//

import AppIntents
import Foundation

/// ============================================================================
/// 🗣️ SIRI & APP INTENT: ALWAYS HOME
/// ============================================================================
///
/// 💡 TEORI & ANALOGI PYTHON / COMPUTER SCIENCE:
/// - Dalam Computer Science, ini adalah implementasi **Command Pattern**:
///   Membungkus permintaan pengguna menjadi satu objek executable mandiri.
/// - Apple `AppIntent` (iOS 16+) mengekspos aksi aplikasi ke subsistem eksternal
///   seperti Siri Voice Assistant, Spotlight Search, Action Button (iPhone 15 Pro+),
///   dan aplikasi Shortcuts tanpa perlu membuka layar aplikasi terlebih dahulu.
/// ============================================================================
struct AlwaysHomeIntent: AppIntent {
  /// Judul tampilan intent di sistem iOS
  static var title: LocalizedStringResource = "Always Home"
  
  /// Penjelasan fungsi intent untuk pengguna dan Siri Intelligence
  static var description = IntentDescription("Directly start walking navigation from your current location to your home.")
  
  /// Mengharuskan aplikasi berpindah ke foreground saat intent dijalankan
  static var openAppWhenRun: Bool = true

  /// Eksekusi perintah (Dipastikan berjalan di UI Main Thread via `@MainActor`)
  @MainActor
  func perform() async throws -> some IntentResult {
    // Siarkan sinyal event ke NotificationCenter internal aplikasi
    NotificationCenter.default.post(name: .startAlwaysHomeNavigation, object: nil)
    // Kembalikan status sukses ke Siri / Shortcuts engine
    return .result()
  }
}
