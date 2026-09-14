//
//  AstarAppShortcutsProvider.swift
//  Astar
//
//  Created by Dimas Prihady Setyawan on 26/08/26.
//

import AppIntents

/// ============================================================================
/// 🎙️ VOICE SHORTCUT REGISTRATION (AppShortcutsProvider)
/// ============================================================================
///
/// 💡 TEORI & ANALOGI PYTHON / COMPUTER SCIENCE:
/// - Dalam Natural Language Processing (NLP) dan Speech Recognition,
///   sistem memerlukan pola gramatikal / *utterance templates* untuk mengenali
///   intensi pengguna ke fungsi yang tepat.
/// - `AppShortcutsProvider` secara otomatis mendaftarkan frasa suara default ke Siri
///   segera setelah aplikasi diinstal, tanpa mengharuskan pengguna membuka app Shortcuts.
/// ============================================================================
struct AstarAppShortcutsProvider: AppShortcutsProvider {
  /// Daftar shortcut suara yang diekspos ke iOS:
  static var appShortcuts: [AppShortcut] {
    // 1. Shortcut: Navigasi Cepat Pulang ke Rumah
    AppShortcut(
      intent: AlwaysHomeIntent(),
      phrases: [
        "Always Home in \(.applicationName)",
        "Navigate Home with \(.applicationName)",
        "Take me home with \(.applicationName)"
      ],
      shortTitle: "Always Home",
      systemImageName: "house.fill"
    )

    // 2. Shortcut: Navigasi Cepat ke Kantor (Autograph Tower)
    AppShortcut(
      intent: NavigateOfficeIntent(),
      phrases: [
        "Navigate to Office with \(.applicationName)",
        "Walk to Office with \(.applicationName)",
        "Navigate to Autograph Tower with \(.applicationName)",
        "Take me to Office with \(.applicationName)"
      ],
      shortTitle: "Office",
      systemImageName: "building.2.fill"
    )

    // 3. Shortcut: Navigasi Cepat ke Agora Mall
    AppShortcut(
      intent: NavigateAgoraMallIntent(),
      phrases: [
        "Navigate to Agora Mall with \(.applicationName)",
        "Walk to Agora Mall with \(.applicationName)",
        "Take me to Agora Mall with \(.applicationName)"
      ],
      shortTitle: "Agora Mall",
      systemImageName: "bag.fill"
    )
  }
}
