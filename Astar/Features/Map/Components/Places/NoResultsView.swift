/// ============================================================================
/// 📭 EMPTY STATE PLACEHOLDER (NoResultsView)
/// ============================================================================
///
/// 💡 COMPUTER SCIENCE CONCEPTS:
/// - **Empty State Handling & User Feedback**:
///   Prevents awkward blank screens when spatial search queries return zero records, guiding the
///   user with helpful fallback advice.
///
/// 🌍 REAL-LIFE ANALOGY:
///   Think of a library shelf card saying "No books found under this category; please check the
///   general index desk".
/// ============================================================================
//
//  NoResultsView.swift
//  Astar
//
//  Created by Dimas Prihady Setyawan on 25/08/26.
//

import SwiftUI

struct NoResultsView: View {
    let searchText: String

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "mappin.slash")
                .font(.largeTitle)
                .foregroundStyle(.secondary)
                .padding(.top, 24)
                .accessibilityHidden(true)

            Text("No Places Found")
                .font(.headline)
                .foregroundStyle(.primary)

            Text("No results matching \"\(searchText)\".")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
        .background(
            Color(uiColor: .secondarySystemBackground)
        )
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            "No Places Found. No results matching \(searchText)."
        )
        .overlay {
            RoundedRectangle(cornerRadius: 24)
                .stroke(Color.primary.opacity(0.06), lineWidth: 1)
        }
        .onAppear {
            AccessibilityNotification.Announcement(
                "No Places Found. No results matching \(searchText)."
            ).post()
        }
    }
}

#Preview {
    NoResultsView(searchText: "Somewhere")
        .padding()
}
