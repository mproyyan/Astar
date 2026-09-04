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
  @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
  let store: StoreOf<RootFeature>

  init() {
    let initial: RootFeature.State
    if let profile = UserProfileStorage.load(), !profile.appleUserId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
      initial = .main(MainFeature.State(userProfile: profile))
    } else {
      initial = .onboarding(OnboardingFeature.State())
    }
    self.store = Store(initialState: initial) {
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
