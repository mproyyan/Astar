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

    private var statusColor: Color {
        switch person.personStatus {
        case .idle: Color.secondary.opacity(0.6)
        case .walking: Color(red: 0.20, green: 0.78, blue: 0.35)
        case .companion: Color.blue
        }
    }

    private var statusIconName: String {
        switch person.personStatus {
        case .idle: "minus.circle.fill"
        case .walking: "figure.walk"
        case .companion: "eye.fill"
        }
    }

    var body: some View {
        Button {
            onSelect?()
        } label: {
            VStack(spacing: 8) {
                ZStack(alignment: .bottomTrailing) {
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

                    // Status indicator badge
                    if person.personStatus != .idle {
                        Circle()
                            .fill(statusColor)
                            .frame(width: 22, height: 22)
                            .overlay {
                                Image(systemName: statusIconName)
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundStyle(.white)
                            }
                            .overlay {
                                Circle().stroke(Color.white, lineWidth: 2)
                            }
                            .offset(x: 2, y: 2)
                    }
                }

                VStack(spacing: 2) {
                    Text(person.name)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.primary)
                        .lineLimit(1)

                    Text(person.status)
                        .font(.caption)
                        .foregroundStyle(statusColor)
                        .lineLimit(1)
                }
            }
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(person.name), \(person.status)")
    }
}

#Preview {
    HStack {
        PersonView(person: Person(name: "Awan", status: "Walking"))
        PersonView(person: Person(name: "Royyan", status: "Idle"))
        PersonView(person: Person(name: "Safa", status: "Companion"))
    }
    .padding()
}
