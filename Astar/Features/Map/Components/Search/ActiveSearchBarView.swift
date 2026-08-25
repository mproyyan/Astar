//
//  ActiveSearchBarView.swift
//  Astar
//
//  Created by Dimas Prihady Setyawan on 25/08/26.
//

import SwiftUI

struct ActiveSearchBarView: View {
    @Binding var searchText: String
    @FocusState.Binding var isFocused: Bool

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.body.weight(.semibold))
                .foregroundStyle(.secondary)

            TextField("Search Place", text: $searchText)
                .font(.body)
                .focused($isFocused)
                .autocorrectionDisabled()

            if !searchText.isEmpty {
                Button {
                    searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.body)
                        .foregroundStyle(.tertiary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Clear text")
            } else {
                Image(systemName: "mic")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
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
    @Previewable @State var text = "Agora"
    @FocusState var isFocused: Bool

    ActiveSearchBarView(searchText: $text, isFocused: $isFocused)
        .padding()
}
