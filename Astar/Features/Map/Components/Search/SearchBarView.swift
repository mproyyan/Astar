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

            Text("Search Place")
                .font(.body)
                .foregroundStyle(.secondary)

            Spacer(minLength: 8)

            Image(systemName: "mic")
                .font(.body.weight(.semibold))
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 16)
        .frame(height: 40)
        .background(.white, in: .capsule)
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
