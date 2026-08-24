//
//  ContentView.swift
//  Astar
//
//  Created by Muhammad Pandu Royyan on 24/08/26.
//

import SwiftUI
import ComposableArchitecture

struct ContentView: View {
  @Bindable var store: StoreOf<RootFeature>

  var body: some View {
    switch store.state {
    case .onboarding:
      if let store = store.scope(state: \.onboarding, action: \.onboarding) {
        OnboardingView(store: store)
      }
    case .loggedIn:
      if let store = store.scope(state: \.loggedIn, action: \.loggedIn) {
        EmptyMapView(store: store)
      }
    }
  }
}
