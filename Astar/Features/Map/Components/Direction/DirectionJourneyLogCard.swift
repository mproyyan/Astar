//
//  DirectionJourneyLogCard.swift
//  Astar
//
//  Created by Dimas Prihady Setyawan on 25/08/26.
//

import SwiftUI

struct DirectionJourneyLogCard: View {
    let entries: [JourneyLogEntry]

    var body: some View {
        VStack(spacing: 0) {
            ForEach(entries.enumerated(), id: \.element.id) { index, entry in
                DirectionJourneyLogRow(
                    entry: entry,
                    isFirst: index == 0,
                    isLast: index == entries.count - 1
                )

                if index < entries.count - 1 {
                    Divider()
                        .padding(.leading, 52)
                        .opacity(0.5)
                }
            }
        }
        .padding(.horizontal, 14)
        .background(.white, in: .rect(cornerRadius: 24))
        .overlay {
            RoundedRectangle(cornerRadius: 24)
                .stroke(Color.primary.opacity(0.06), lineWidth: 1)
        }
    }
}

#Preview {
    DirectionJourneyLogCard(entries: JourneyLogSampleData.defaultEntries)
        .padding()
        .background(Color(red: 0.95, green: 0.95, blue: 0.97))
}
