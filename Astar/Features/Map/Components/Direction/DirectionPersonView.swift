//
//  DirectionPersonView.swift
//  Astar
//
//  Created by Dimas Prihady Setyawan on 25/08/26.
//

import SwiftUI

struct DirectionPersonView: View {
    let person: Person
    private let avatarSize: CGFloat = 80

    var body: some View {
        VStack(spacing: 8) {
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

            Text(person.name)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.primary)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

#Preview {
    DirectionPersonView(person: Person(name: "Awan", status: "Walking"))
        .padding()
}
