//
//  PeopleSection.swift
//  Astar
//
//  Created by Dimas Prihady Setyawan on 25/08/26.
//

import SwiftUI

struct PeopleSection: View {
    let people: [Person]
    var isLoading: Bool = false
    var onSelectPerson: ((Person) -> Void)? = nil
    var onProfileTapped: (() -> Void)? = nil

    @State private var containerWidth: CGFloat = 0
    private let cardWidth: CGFloat = 80

    private var visibleSlotCount: CGFloat {
        CGFloat(min(max(people.count, 1), 3))
    }

    private var slotWidth: CGFloat {
        guard containerWidth > 0 else { return cardWidth }
        return max(containerWidth / visibleSlotCount, cardWidth)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 4) {
                Text("Trusted person")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.primary)

                Image(systemName: "chevron.right")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
            }

            if isLoading {
                PeopleSectionSkeleton()
            } else if people.isEmpty {
                PeopleSectionEmptyState(onProfileTapped: onProfileTapped)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(alignment: .top, spacing: 0) {
                        ForEach(people) { person in
                            PersonView(
                                person: person,
                                onSelect: {
                                    onSelectPerson?(person)
                                }
                            )
                            .frame(maxWidth: .infinity)
                        }
                    }
                }
                .scrollBounceBehavior(.always)
            }
        }
        .onGeometryChange(for: CGFloat.self) { proxy in
            proxy.size.width
        } action: { newWidth in
            if newWidth > 0 && abs(newWidth - containerWidth) > 0.5 {
                containerWidth = newWidth
            }
        }
    }
}

// MARK: - Loading Skeleton

struct PeopleSectionSkeleton: View {
    @State private var isAnimating = false

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            ForEach(0..<3, id: \.self) { _ in
                VStack(spacing: 8) {
                    Circle()
                        .fill(Color(.systemGray5))
                        .frame(width: 80, height: 80)
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color(.systemGray5))
                        .frame(width: 56, height: 12)
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color(.systemGray6))
                        .frame(width: 40, height: 10)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .opacity(isAnimating ? 0.4 : 1.0)
        .animation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true), value: isAnimating)
        .onAppear { isAnimating = true }
    }
}

// MARK: - Empty State

struct PeopleSectionEmptyState: View {
    var onProfileTapped: (() -> Void)? = nil

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "person.2.slash")
                .font(.system(size: 32))
                .foregroundStyle(.tertiary)

            VStack(spacing: 4) {
                Text("Your trusted person will be shown here.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)

                HStack(spacing: 4) {
                    Text("Add your trusted person in")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    Button {
                        onProfileTapped?()
                    } label: {
                        Text("Profile")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.blue)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
    }
}

#Preview("Empty State") {
    PeopleSectionEmptyState()
        .padding()
}

#Preview("Populated") {
    PeopleSection(people: MapSampleData.people)
        .padding()
}

#Preview("Loading") {
    PeopleSection(people: [], isLoading: true)
        .padding()
}

#Preview("Empty") {
    PeopleSection(people: [], isLoading: false)
        .padding()
}
