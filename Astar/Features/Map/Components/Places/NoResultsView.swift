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
        .background(Color(uiColor: .secondarySystemBackground, in: .rect(cornerRadius: 24))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("No Places Found. No results matching \(searchText).")
        .overlay {
            RoundedRectangle(cornerRadius: 24)
                .stroke(Color.primary.opacity(0.06), lineWidth: 1)
        }
        
        .onAppear {
            AccessibilityNotification.Announcement(
                "No Places Found. No results matching \(searchText).").post()
        }
    }
}

#Preview {
    NoResultsView(searchText: "Somewhere")
        .padding()
}
