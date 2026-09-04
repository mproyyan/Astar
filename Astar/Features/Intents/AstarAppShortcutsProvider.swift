//
//  AstarAppShortcutsProvider.swift
//  Astar
//
//  Created by Dimas Prihady Setyawan on 26/08/26.
//

import AppIntents

struct AstarAppShortcutsProvider: AppShortcutsProvider {
  static var appShortcuts: [AppShortcut] {
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
