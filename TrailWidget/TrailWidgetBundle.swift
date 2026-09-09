//
//  TrailWidgetBundle.swift
//  TrailWidget
//
//  Widget Bundle for Live Activities & Widgets
//

import ActivityKit
import SwiftUI
import WidgetKit

@main
struct TrailWidgetBundle: WidgetBundle {
  var body: some Widget {
    TrailHomeScreenWidget()
    TrailLiveActivityWidget()
  }
}
