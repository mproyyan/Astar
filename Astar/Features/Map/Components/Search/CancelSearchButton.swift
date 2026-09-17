/// ============================================================================
/// ❌ CANCEL SEARCH ACTION BUTTON (CancelSearchButton)
/// ============================================================================
///
/// 💡 COMPUTER SCIENCE CONCEPTS:
/// - **State Reset Trigger**:
///   Emits actions to clear active text queries and dismiss search mode back to default map overview.
///
/// 🌍 REAL-LIFE ANALOGY:
///   Think of an "Escape" key on a keyboard that clears the search prompt and returns to the desktop.
/// ============================================================================
//
//  CancelSearchButton.swift
//  Astar
//
//  Created by Dimas Prihady Setyawan on 25/08/26.
//

import SwiftUI

struct CancelSearchButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "xmark")
                .font(.body.weight(.semibold))
                .foregroundStyle(.primary)
                .frame(width: 40, height: 40)
        }
        .buttonStyle(.plain)
        .glassEffect(.regular.interactive(), in: .circle)
        .accessibilityLabel("Cancel search")
    }
}

#Preview {
    CancelSearchButton(action: {})
        .padding()
}
