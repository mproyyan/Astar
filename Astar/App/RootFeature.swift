//
//  RootFeature.swift
//  Astar
//
//  Created by Muhammad Pandu Royyan on 24/08/26.
//

import ComposableArchitecture
import Foundation

/// ============================================================================
/// 👑 ROOT REDUCER (RootFeature)
/// ============================================================================
///
/// 💡 TEORI & ANALOGI PYTHON / COMPUTER SCIENCE:
/// - Dalam teori Automata & State Machine:
///   Ini adalah *Master Finite State Machine (FSM)* yang mengoordinasikan transisi
///   antara sub-mesin Onboarding dan sub-mesin Main.
/// - Reducer di TCA adalah fungsi murni (*pure function*):
///     `(inout State, Action) -> Effect<Action>`
///   Mirip dengan reduce() atau fold() dalam functional programming (seperti functools.reduce di Python),
///   di mana state lama digabungkan dengan event baru untuk menghasilkan state baru.
/// ============================================================================
@Reducer
struct RootFeature {
  /// `@ObservableState`:
  /// Macro Swift modern yang mengamati perubahan nilai properti struct secara otomatis.
  /// Dimodelkan sebagai Enum (Algebraic Sum Type) agar keadaan aplikasi tidak pernah berada
  /// dalam status yang tidak valid (misalnya: tidak mungkin onboarding dan main aktif bersamaan).
  @ObservableState
  enum State: Equatable {
    case onboarding(OnboardingFeature.State)
    case main(MainFeature.State)
  }

  /// Kumpulan event (Action) yang dapat memicu perubahan state di tingkat root:
  enum Action: Equatable {
    case onboarding(OnboardingFeature.Action)
    case main(MainFeature.Action)
    case appDelegate(AppDelegateAction)
    case openURL(URL)
    case handleDeepLink(DeepLink)

    enum AppDelegateAction: Equatable {
      case didFinishLaunching
    }
  }

  /// Komposisi Reducer Utama
  var body: some Reducer<State, Action> {
    Reduce { state, action in
      switch action {
      // 1. Event saat AppDelegate selesai inisialisasi:
      case .appDelegate(.didFinishLaunching):
        guard let profile = UserProfileStorage.load(), !profile.appleUserId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return .none }
        state = .main(MainFeature.State(userProfile: profile))
        return .none

      // 2. Event saat aplikasi dibuka via URL scheme (misal dari browser atau QR code):
      case let .openURL(url):
        guard let deepLink = DeepLink.parse(url: url) else { return .none }
        return .send(.handleDeepLink(deepLink))

      // 3. Penanganan Deep Link (Navigasi Instan):
      case let .handleDeepLink(deepLink):
        switch deepLink {
        case .alwaysHome:
          switch state {
          case .main:
            // Jika sudah di Map, langsung perintahkan peta untuk mulai rute pulang
            return .send(.main(.map(.startAlwaysHomeNavigation)))
          case var .onboarding(onboardingState):
            // Jika masih di Onboarding, simpan sebagai antrean (pending) sampai user selesai login
            onboardingState.pendingDeepLink = .alwaysHome
            state = .onboarding(onboardingState)
            return .none
          }

        case let .navigate(destination):
          switch state {
          case .main:
            return .send(.main(.map(.startDirectNavigation(destinationQuery: destination))))
          case var .onboarding(onboardingState):
            onboardingState.pendingDeepLink = .navigate(destination: destination)
            state = .onboarding(onboardingState)
            return .none
          }
        }

      // 4. Delegasi Sukses Login dari Onboarding:
      case let .onboarding(.delegate(.loggedIn(profile))):
        let pending: DeepLink? = if case let .onboarding(onboardingState) = state { onboardingState.pendingDeepLink } else { nil }
        // Transisi State: Dari Onboarding ke Main Screen
        state = .main(MainFeature.State(userProfile: profile))
        // Eksekusi pending deep link jika sebelumnya ada
        if case .alwaysHome = pending {
          return .send(.main(.map(.startAlwaysHomeNavigation)))
        } else if case let .navigate(destination) = pending {
          return .send(.main(.map(.startDirectNavigation(destinationQuery: destination))))
        }
        return .none

      // 5. Penanganan Logout (Sign Out):
      // Mengamati aksi logout dari 3 kemungkinan sumber UI (Main, Login, atau Profile)
      case .main(.delegate(.signedOut)),
           .main(.login(.delegate(.signedOut))),
           .main(.path(.element(id: _, action: .profile(.delegate(.signedOut))))):
        state = .onboarding(OnboardingFeature.State())
        return .none

      case .onboarding, .main:
        return .none
      }
    }
    // `.ifCaseLet`: Operator TCA untuk menghubungkan sub-reducer ke enum case tertentu
    .ifCaseLet(\.onboarding, action: \.onboarding) {
      OnboardingFeature()
    }
    .ifCaseLet(\.main, action: \.main) {
      MainFeature()
        ._printChanges() // Mencetak mutasi state ke Xcode console untuk debugging
    }
  }
}
