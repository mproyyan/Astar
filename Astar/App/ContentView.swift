//
//  ContentView.swift
//  Astar
//
//  Created by Muhammad Pandu Royyan on 24/08/26.
//

import SwiftUI
import ComposableArchitecture

/// ============================================================================
/// 🧭 ROOT VIEW ROUTER (ContentView)
/// ============================================================================
///
/// 💡 TEORI & ANALOGI PYTHON / COMPUTER SCIENCE:
/// - Dalam web/Python routing (seperti Django URL dispatcher atau React Router),
///   kita memiliki komponen yang membaca state session dan memutuskan view mana
///   yang harus ditampilkan.
/// - Di sini, `ContentView` berperan sebagai **State-Driven Dynamic Router**.
/// - Konsep TCA `store.scope`:
///   Menghindari re-rendering komponen yang tidak perlu dengan membatasi "lingkup"
///   state dan action hanya untuk child view yang sedang aktif.
/// ============================================================================
struct ContentView: View {
  /// `@Bindable var store`:
  /// Properti wrapper Swift modern yang memungkinkan SwiftUI membuat binding 2 arah
  /// ke state observable di dalam TCA Store jika diperlukan.
  @Bindable var store: StoreOf<RootFeature>

  var body: some View {
    // Pattern Matching terhadap Algebraic Data Type (RootFeature.State)
    switch store.state {
    case .onboarding:
      // Scope store root menjadi store OnboardingFeature secara spesifik
      if let store = store.scope(state: \.onboarding, action: \.onboarding) {
        OnboardingView(store: store)
      }
    case .main:
      // Scope store root menjadi store MainFeature secara spesifik
      if let store = store.scope(state: \.main, action: \.main) {
        MainScreenMapView(store: store)
      }
    }
  }
}
