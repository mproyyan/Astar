//
//  DirectionJourneyLog.swift
//  Astar
//
//  Created by Dimas Prihady Setyawan on 25/08/26.
//

import SwiftUI

struct DirectionJourneyLog: View {
    @Environment(\.dismiss) private var dismiss
    var destinationName: String = "Home"
    var isDone: Bool = false
    var entries: [JourneyLogEntry]? = nil

    var onDismiss: (() -> Void)? = nil
    var onChecklistTapped: (() -> Void)? = nil

    private var effectiveEntries: [JourneyLogEntry] {
        entries ?? (isDone ? JourneyLogSampleData.doneEntries : JourneyLogSampleData.inProgressEntries)
    }

    var body: some View {
        VStack(spacing: 16) {
            // Top Bar: Centered destination title and trailing blue checkmark button
            HStack {
                Spacer()

                Text(destinationName)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)

                Spacer()

                Button {
                    if let onChecklistTapped {
                        onChecklistTapped()
                    } else if let onDismiss {
                        onDismiss()
                    } else {
                        dismiss()
                    }
                } label: {
                    Image(systemName: "checkmark")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(.white)
                        .frame(width: 36, height: 36)
                        .background(Color.blue, in: .circle)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Done")
            }
            .padding(.horizontal, 4)

            DirectionJourneyLogCard(entries: effectiveEntries)
        }
    }
}

#Preview("In Progress") {
    DirectionJourneyLog(isDone: false)
        .padding()
        .background(Color(red: 0.95, green: 0.95, blue: 0.97))
}

#Preview("Done") {
    DirectionJourneyLog(isDone: true)
        .padding()
        .background(Color(red: 0.95, green: 0.95, blue: 0.97))
}
