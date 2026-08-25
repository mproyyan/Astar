//
//  WalkerStatusSection.swift
//  Astar
//
//  Created by Dimas Prihady Setyawan on 25/08/26.
//

import SwiftUI

struct WalkerStatusSection: View {
    let status: WalkerStatus
    var onCycleStatus: (() -> Void)? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Status")
                .font(.title3.weight(.semibold))
                .foregroundStyle(.primary)

            Button {
                onCycleStatus?()
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: status.iconName)
                        .font(.body.weight(.semibold))

                    Text(status.rawValue)
                        .font(.headline.weight(.semibold))
                }
                .foregroundStyle(status.color)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Status: \(status.rawValue)")
        }
    }
}

#Preview("Available") {
    WalkerStatusSection(status: .available)
        .padding()
}

#Preview("Not Moving") {
    WalkerStatusSection(status: .notMoving)
        .padding()
}

#Preview("No Response") {
    WalkerStatusSection(status: .noResponse)
        .padding()
}
