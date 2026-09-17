/// ============================================================================
/// 🔎 STATIC SEARCH BAR TRIGGER (SearchBarView)
/// ============================================================================
///
/// 💡 COMPUTER SCIENCE CONCEPTS:
/// - **Tappable Placeholder Primitive**:
///   Mimics an input bar to provide an intuitive hit target for transitioning into active search mode.
///
/// 🌍 REAL-LIFE ANALOGY:
///   Think of a false search drawer handle that smoothly glides open into a full keyboard when touched.
/// ============================================================================
//
//  SearchBarView.swift
//  Astar
//
//  Created by Dimas Prihady Setyawan on 25/08/26.
//

import SwiftUI

struct SearchBarView: View {
    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.body.weight(.semibold))
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)

            Text("Search Destination")
                .font(.body)
                .foregroundStyle(.secondary)

            Spacer(minLength: 8)

            Image(systemName: "mic")
                .font(.body.weight(.semibold))
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)
        }
        .padding(.horizontal, 16)
        .frame(height: 40)
        .background(.background, in: .capsule)
        .overlay {
            Capsule()
                .stroke(Color.primary.opacity(0.08), lineWidth: 1)
        }
    }
}

#Preview {
    SearchBarView()
        .padding()
}
