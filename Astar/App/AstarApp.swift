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
    if let profile = UserProfileStorage.load() {
      print("[CloudKit Debug] Loaded local user profile: appleUserId=\(profile.appleUserId), cloudKitUserId=\(profile.cloudKitUserId)")
      initial = .main(MainFeature.State(userProfile: profile))
    } else {
      print("[CloudKit Debug] No local user profile found. Creating local mock profile only; this does not create a CloudKit UserProfile record.")
      let defaultProfile = UserProfile(
        appleUserId: "user-1",
        cloudKitUserId: "ck-1",
        name: "Awan",
        email: "awan@example.com"
      )
      UserProfileStorage.save(defaultProfile)
      initial = .main(MainFeature.State(userProfile: defaultProfile))
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

