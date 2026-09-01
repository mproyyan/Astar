//
//  DeveloperSettingsStorage.swift
//  Astar
//

import Foundation

enum DeveloperSettingsStorage {
  static let isDevModeKey = "is_development_mode_enabled"
  static let isShowRouteGuideKey = "is_show_route_guide_enabled"
  static let isDoeWalkingMockKey = "is_doe_walking_mock_enabled"

  static var isDevelopmentMode: Bool {
    get {
      UserDefaults.standard.bool(forKey: isDevModeKey)
    }
    set {
      UserDefaults.standard.set(newValue, forKey: isDevModeKey)
    }
  }

  static var isShowRouteGuide: Bool {
    get {
      if UserDefaults.standard.object(forKey: isShowRouteGuideKey) == nil {
        return true
      }
      return UserDefaults.standard.bool(forKey: isShowRouteGuideKey)
    }
    set {
      UserDefaults.standard.set(newValue, forKey: isShowRouteGuideKey)
    }
  }

  static var isDoeWalkingMockEnabled: Bool {
    get {
      if UserDefaults.standard.object(forKey: isDoeWalkingMockKey) == nil {
        return true
      }
      return UserDefaults.standard.bool(forKey: isDoeWalkingMockKey)
    }
    set {
      UserDefaults.standard.set(newValue, forKey: isDoeWalkingMockKey)
    }
  }
}
