//
//  AstarApp.swift
//  Astar
//
//  Created by Muhammad Pandu Royyan on 24/08/26.
//

import SwiftUI
import ComposableArchitecture

/// ============================================================================
/// 🚀 ENTRY POINT APLIKASI (@main)
/// ============================================================================
///
/// 💡 TEORI & ANALOGI PYTHON / COMPUTER SCIENCE:
/// - Dalam Python, entry point program biasanya berupa:
///     `if __name__ == "__main__":`
/// - Dalam Swift modern, atribut `@main` menandai tipe struct/class yang menyediakan
///   fungsi `main()` implisit bagi sistem operasi iOS/macOS.
/// - Protokol `App`: Mewakili siklus hidup aplikasi SwiftUI deklaratif.
/// - Di sini kita mendefinisikan `StoreOf<RootFeature>`, yaitu *Single Source of Truth*
///   seluruh state aplikasi yang diatur menggunakan The Composable Architecture (TCA).
/// ============================================================================
@main
struct AstarApp: App {
  /// `@UIApplicationDelegateAdaptor`:
  /// Menghubungkan lifecycle klasik UIKit (`AppDelegate`) ke deklaratif SwiftUI.
  /// Ini diperlukan untuk menangani integrasi tingkat rendah OS seperti push notification APNs.
  @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

  /// `StoreOf<RootFeature>`:
  /// Kontainer runtime utama TCA. Menyimpan State, menjalankan Reducer, dan mengelola Effect.
  /// Mirip dengan Redux Store global pada frontend web.
  let store: StoreOf<RootFeature>

  /// Inisialisasi awal saat aplikasi pertama kali dialokasikan di memori:
  init() {
    let initial: RootFeature.State
    // Cek apakah data user sudah tersimpan di disk lokal (UserDefaults).
    // Jika ada session Apple User ID yang valid -> Langsung masuk ke layar Main (Peta).
    // Jika belum login / user baru -> Arahkan ke alur Onboarding.
    if let profile = UserProfileStorage.load(), !profile.appleUserId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
      initial = .main(MainFeature.State(userProfile: profile))
    } else {
      initial = .onboarding(OnboardingFeature.State())
    }

    // Buat Store dengan initial state yang sudah dievaluasi di atas
    self.store = Store(initialState: initial) {
      RootFeature()
    }
  }

  /// Hierarki visual utama aplikasi (WindowGroup)
  var body: some Scene {
    WindowGroup {
      // ContentView bertindak sebagai router UI utama berdasarkan RootFeature.State
      ContentView(store: store)
        // Dipanggil saat View pertama kali muncul di layar
        .onAppear {
          store.send(.appDelegate(.didFinishLaunching))
        }
        // Menangani Deep Link URL Scheme (misal: astar://navigate?destination=Home)
        .onOpenURL { url in
          store.send(.openURL(url))
        }
        // Reactive Event Listener (Observer Pattern via NotificationCenter):
        // Menangkap sinyal Siri Intent "Always Home"
        .onReceive(NotificationCenter.default.publisher(for: .startAlwaysHomeNavigation)) { _ in
          store.send(.handleDeepLink(.alwaysHome))
        }
        // Menangkap sinyal navigasi langsung ke destinasi tertentu
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
