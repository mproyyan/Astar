//
//  DeepLinkHandler.swift
//  Astar
//
//  Created by Dimas Prihady Setyawan on 26/08/26.
//

import Foundation

enum DeepLink: Equatable, Sendable {
  case alwaysHome
  case navigate(destination: String)

  static func parse(url: URL) -> DeepLink? {
    guard let scheme = url.scheme?.lowercased(), scheme == "astar" else { return nil }

    let host = url.host()?.lowercased() ?? ""

    if host == "always-home" || host == "home" {
      return .alwaysHome
    }

    if host == "office" {
      return .navigate(destination: "Office")
    }

    if host == "navigate" || host == "navigate-to" || host == "goto" {
      // Check query parameter ?destination=...
      if let components = URLComponents(url: url, resolvingAgainstBaseURL: false) {
        if let queryItem = components.queryItems?.first(where: {
          $0.name.lowercased() == "destination" || $0.name.lowercased() == "to" || $0.name.lowercased() == "place"
        }), let destValue = queryItem.value, !destValue.isEmpty {
          return .navigate(destination: destValue)
        }
      }
      // Or path component: astar://navigate/Agora%20Mall
      let path = url.path().trimmingCharacters(in: CharacterSet(charactersIn: "/"))
      if !path.isEmpty {
        return .navigate(destination: path.removingPercentEncoding ?? path)
      }
    }

    // Direct host (e.g. astar://agora-mall)
    if !host.isEmpty {
      let decoded = host.replacingOccurrences(of: "-", with: " ").removingPercentEncoding ?? host
      return .navigate(destination: decoded)
    }

    let path = url.path().trimmingCharacters(in: CharacterSet(charactersIn: "/"))
    if !path.isEmpty {
      let decoded = path.replacingOccurrences(of: "-", with: " ").removingPercentEncoding ?? path
      return .navigate(destination: decoded)
    }

    return nil
  }
}

extension NSNotification.Name {
  static let startAlwaysHomeNavigation = NSNotification.Name("com.astar.startAlwaysHomeNavigation")
  static let startDirectNavigation = NSNotification.Name("com.astar.startDirectNavigation")
}
