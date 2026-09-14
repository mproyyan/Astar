//
//  ProfileFeature.swift
//  Astar
//
//  Created by Muhammad Pandu Royyan on 24/08/26.
//

import ComposableArchitecture
import Foundation

/// ============================================================================
/// 👤 PROFILE & SETTINGS REDUCER (ProfileFeature)
/// ============================================================================
///
/// 💡 TEORI & ANALOGI PYTHON / COMPUTER SCIENCE:
/// - Mengelola state akun pengguna saat ini, konfigurasi lingkungan runtime (Dev Mode),
///   dan integrasi foto avatar lokal.
/// - **Delegate Pattern dalam TCA**:
///   Tipe `enum Delegate` adalah cara type-safe bagi child reducer untuk berkomunikasi
///   ke parent reducer (`MainFeature`). Mirip dengan emitting event ke parent component
///   di Vue/React atau callback function di Python.
/// ============================================================================
@Reducer
struct ProfileFeature {
  @ObservableState
  struct State: Equatable {
    var userProfile: UserProfile? = UserProfileStorage.load()
    var isDevelopmentMode: Bool = DeveloperSettingsStorage.isDevelopmentMode
    var isShowRouteGuide: Bool = DeveloperSettingsStorage.isShowRouteGuide
    var isDoeWalkingMock: Bool = DeveloperSettingsStorage.isDoeWalkingMockEnabled
  }

  enum Action: Equatable {
    case onAppear
    case avatarLoaded(Data)
    case signOutButtonTapped
    case setDevelopmentMode(Bool)
    case setRouteGuide(Bool)
    case setDoeWalkingMock(Bool)
    case resetDoeWalkingSimulation
    case trustedPersonTapped
    case savedPlacesUpdated([SavedPlace])
    case delegate(Delegate)

    // Aksi delegasi yang dikomunikasikan ke parent (MainFeature):
    enum Delegate: Equatable {
      case signedOut
      case developmentModeChanged(Bool)
      case routeGuideChanged(Bool)
      case doeWalkingMockChanged(Bool)
      case trustedPersonTapped
      case restartDoeWalkingSimulation
      case savedPlacesUpdated([SavedPlace])
    }
  }

  var body: some Reducer<State, Action> {
    Reduce { state, action in
      switch action {
      // 1. Saat layar Profil muncul, ambil foto kontak lokal Me Card secara asinkron
      case .onAppear:
        if state.userProfile == nil {
          state.userProfile = UserProfileStorage.load()
        }
        return .run { [profile = state.userProfile] send in
          if let avatar = await ContactPhotoClient.liveValue.fetchMeCardPhoto(profile?.email, profile?.name) {
            await send(.avatarLoaded(avatar))
          }
        }

      // 2. Simpan binary foto avatar ke state dan persist ke storage
      case let .avatarLoaded(avatar):
        if var profile = state.userProfile {
          profile.avatarData = avatar
          state.userProfile = profile
          UserProfileStorage.save(profile)
        }
        return .none

      // 3. Hapus sesi lokal dan beritahu parent untuk mereset navigasi ke Onboarding
      case .signOutButtonTapped:
        UserProfileStorage.clear()
        return .send(.delegate(.signedOut))

      // 4. Pengaturan Mode Developer
      case let .setDevelopmentMode(enabled):
        state.isDevelopmentMode = enabled
        DeveloperSettingsStorage.isDevelopmentMode = enabled
        return .send(.delegate(.developmentModeChanged(enabled)))

      case let .setRouteGuide(enabled):
        state.isShowRouteGuide = enabled
        DeveloperSettingsStorage.isShowRouteGuide = enabled
        return .send(.delegate(.routeGuideChanged(enabled)))

      case let .setDoeWalkingMock(enabled):
        state.isDoeWalkingMock = enabled
        DeveloperSettingsStorage.isDoeWalkingMockEnabled = enabled
        return .send(.delegate(.doeWalkingMockChanged(enabled)))

      case .resetDoeWalkingSimulation:
        return .send(.delegate(.restartDoeWalkingSimulation))

      case .trustedPersonTapped:
        return .send(.delegate(.trustedPersonTapped))

      case let .savedPlacesUpdated(places):
        return .send(.delegate(.savedPlacesUpdated(places)))

      case .delegate:
        return .none
      }
    }
  }
}
