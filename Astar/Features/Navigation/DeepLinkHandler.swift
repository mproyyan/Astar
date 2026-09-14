//
//  DeepLinkHandler.swift
//  Astar
//
//  Created by Dimas Prihady Setyawan on 26/08/26.
//

import Foundation

/// ============================================================================
/// 🔗 DEEP LINK PARSER & URL SCHEME INTERPRETER
/// ============================================================================
///
/// 💡 TEORI & ANALOGI PYTHON / COMPUTER SCIENCE:
/// - Dalam web development Python (misal: Flask/FastAPI), routing mengurai string URI
///   menjadi parameter fungsi.
/// - Di sini, `DeepLink` dimodelkan sebagai **Algebraic Sum Type (Enum with Associated Values)**.
/// - String URL yang tidak terstruktur (`astar://navigate?destination=Home`) diubah menjadi
///   tipe data yang strictly typed: `DeepLink.navigate(destination: "Home")`.
/// - Protokol `Sendable`: Menjamin nilai enum aman dilewatkan melintasi batas thread (Actor Concurrency).
/// ============================================================================
enum DeepLink: Equatable, Sendable {
  case alwaysHome
  case navigate(destination: String)

  /// Parser deterministik untuk memvalidasi dan memetakan URL
  static func parse(url: URL) -> DeepLink? {
    // 1. Validasi Scheme: Harus diawali dengan protokol custom "astar://"
    guard let scheme = url.scheme?.lowercased(), scheme == "astar" else { return nil }

    let host = url.host()?.lowercased() ?? ""

    // 2. Evaluasi Host Khusus
    if host == "always-home" || host == "home" {
      return .alwaysHome
    }

    if host == "office" {
      return .navigate(destination: "Office")
    }

    // 3. Evaluasi Format Navigasi Umum: astar://navigate?destination=...
    if host == "navigate" || host == "navigate-to" || host == "goto" {
      // Periksa Query Parameter via URLComponents (mirip urllib.parse di Python)
      if let components = URLComponents(url: url, resolvingAgainstBaseURL: false) {
        if let queryItem = components.queryItems?.first(where: {
          $0.name.lowercased() == "destination" || $0.name.lowercased() == "to" || $0.name.lowercased() == "place"
        }), let destValue = queryItem.value, !destValue.isEmpty {
          return .navigate(destination: destValue)
        }
      }
      // Atau periksa via Path Component: astar://navigate/Agora%20Mall
      let path = url.path().trimmingCharacters(in: CharacterSet(charactersIn: "/"))
      if !path.isEmpty {
        return .navigate(destination: path.removingPercentEncoding ?? path)
      }
    }

    // 4. Fallback Host Langsung: astar://agora-mall
    if !host.isEmpty {
      let decoded = host.replacingOccurrences(of: "-", with: " ").removingPercentEncoding ?? host
      return .navigate(destination: decoded)
    }

    // 5. Fallback Path Langsung
    let path = url.path().trimmingCharacters(in: CharacterSet(charactersIn: "/"))
    if !path.isEmpty {
      let decoded = path.replacingOccurrences(of: "-", with: " ").removingPercentEncoding ?? path
      return .navigate(destination: decoded)
    }

    return nil
  }
}

/// ============================================================================
/// 📢 NOTIFICATION NAMES (Pub/Sub Event Identifiers)
/// ============================================================================
/// Topik event statis yang dipancarkan oleh Siri Shortcuts (App Intents)
/// agar dapat ditangkap secara reaktif oleh `AstarApp`.
extension NSNotification.Name {
  static let startAlwaysHomeNavigation = NSNotification.Name("com.astar.startAlwaysHomeNavigation")
  static let startDirectNavigation = NSNotification.Name("com.astar.startDirectNavigation")
}
