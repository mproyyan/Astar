/// ============================================================================
/// 📜 AUDIT TRAIL TIMELINE VIEW (DirectionJourneyLog)
/// ============================================================================
///
/// 💡 COMPUTER SCIENCE CONCEPTS:
/// - **Chronological Event Stream Rendering**:
///   Renders an ordered list of milestone checkpoints reached during the journey, proving continuous
///   progress along the route.
///
/// 🌍 REAL-LIFE ANALOGY:
///   Think of a package delivery courier tracking timeline: "Departed Hub 10:00 AM", "Arrived at
///   Sorting Facility 10:15 AM", "Out for Delivery 10:30 AM".
/// ============================================================================
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
        .background(.background)
}

#Preview("Done") {
    DirectionJourneyLog(isDone: true)
        .padding()
        .background(.background)
}
