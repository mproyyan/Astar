//
//  PersonStatus.swift
//  Astar
//
//  Created by Dimas Prihady Setyawan on 26/08/26.
//

import Foundation

/// Describes a person's real-time activity status, synced via CloudKit public DB.
enum PersonStatus: String, Codable, Sendable, CaseIterable {
    case idle = "Idle"
    case walking = "Walking"
    case companion = "Companion"
}
