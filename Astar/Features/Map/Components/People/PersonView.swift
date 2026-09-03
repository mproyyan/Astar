//
//  PersonView.swift
//  Astar
//
//  Created by Dimas Prihady Setyawan on 25/08/26.
//

import SwiftUI

struct PersonView: View {
    let person: Person
    var onSelect: (() -> Void)? = nil
    private let avatarSize: CGFloat = 80

    var body: some View {
        Button {
            onSelect?()
        } label: {
            VStack(spacing: 6) {
                Circle()
                    .fill(Color(red: 0.77, green: 0.81, blue: 0.96))
                    .overlay {
                        Circle()
                            .fill(.linearGradient(
                                colors: [
                                    .white.opacity(0.42),
                                    .clear
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ))
                    }
                    .overlay {
                        Text(String(person.name.prefix(1)))
                            .font(.title3.weight(.semibold))
                            .foregroundStyle(.white.opacity(0.92))
                    }
                    .frame(width: avatarSize, height: avatarSize)

                VStack(spacing: 2) {
                    Text(person.name)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.primary)
                        .multilineTextAlignment(.center)
                        .lineLimit(1)
                        .truncationMode(.tail)

                    Text(person.status)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(person.name), \(person.status)")
    }
}

#Preview {
    PersonView(person: Person(name: "Awan", status: "Walking"))
        .padding()
}
