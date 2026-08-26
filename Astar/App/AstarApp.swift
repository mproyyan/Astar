//
//  AstarApp.swift
//  Astar
//
//  Created by Muhammad Pandu Royyan on 24/08/26.
//

import SwiftUI
import ComposableArchitecture

@main
struct AstarApp: App {
  let store: StoreOf<RootFeature>

  init() {
    self.store = Store(initialState: .onboarding(OnboardingFeature.State())) {
      RootFeature()
    }
  }

  var body: some Scene {
    WindowGroup {
      ContentView(store: store)
        .onAppear {
          store.send(.appDelegate(.didFinishLaunching))
        }
        .onOpenURL { url in
          store.send(.openURL(url))
        }
        .onReceive(NotificationCenter.default.publisher(for: .startAlwaysHomeNavigation)) { _ in
          store.send(.handleDeepLink(.alwaysHome))
        }
        .onReceive(NotificationCenter.default.publisher(for: .startDirectNavigation)) { notification in
          if let dest = notification.userInfo?["destination"] as? String, !dest.isEmpty {
            store.send(.handleDeepLink(.navigate(destination: dest)))
          } else {
            store.send(.handleDeepLink(.alwaysHome))
          }
        }
    }
  }
}
