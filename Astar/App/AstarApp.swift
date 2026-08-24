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
    }
  }
}
