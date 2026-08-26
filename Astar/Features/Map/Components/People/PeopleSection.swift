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

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("People")
                    .font(.title3)
                    .fontWeight(.semibold)
                    .foregroundStyle(.primary)

                if isLoading {
                    ProgressView()
                        .scaleEffect(0.7)
                        .padding(.leading, 4)
                }
            }

            HStack(alignment: .top, spacing: 10) {
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
    }
}

#Preview {
    PeopleSection(people: MapSampleData.people)
        .padding()
}
