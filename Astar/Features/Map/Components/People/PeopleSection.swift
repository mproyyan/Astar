//
//  PeopleSection.swift
//  Astar
//
//  Created by Dimas Prihady Setyawan on 25/08/26.
//

import SwiftUI

struct PeopleSection: View {
    let people: [Person]
    var onSelectPerson: ((Person) -> Void)? = nil

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
                Text("People")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.primary)

                Image(systemName: "chevron.right")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .top, spacing: 0) {
                    ForEach(people) { person in
                        PersonView(
                            person: person,
                            onSelect: {
                                onSelectPerson?(person)
                            }
                        )
                        .frame(width: slotWidth)
                    }
                }
            }
            .scrollBounceBehavior(.always)
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

#Preview {
    PeopleSection(people: MapSampleData.people)
        .padding()
}
