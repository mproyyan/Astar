import SwiftUI

// MARK: - Walk Invitation Banner (Preview Only)
// This simulates what the companion sees on their device as a push notification banner.
// The actual notification is delivered via APNs → AppDelegate → UNUserNotificationCenter.

struct WalkInvitationBannerView: View {
    var walkerName: String = "Awan"
    var destination: String = "Autograph Tower"
    var onAccompany: () -> Void = {}
    var onDismiss: () -> Void = {}

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                Image(systemName: "figure.walk.circle.fill")
                    .font(.title2)
                    .foregroundStyle(.white)
                    .padding(8)
                    .background(.blue, in: .circle)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Walk Invitation 🚶")
                        .font(.caption)
                        .bold()
                        .foregroundStyle(.secondary)
                    Text("\(walkerName) is walking to \(destination)")
                        .font(.subheadline)
                        .bold()
                    Text("Would you like to accompany them?")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }

            Divider()

            HStack {
                Button(action: onAccompany) {
                    Text("Accompany")
                        .font(.subheadline)
                        .bold()
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(.blue.opacity(0.12), in: .rect(cornerRadius: 10))
                        .foregroundStyle(.blue)
                }

                Button(role: .destructive, action: onDismiss) {
                    Text("Dismiss")
                        .font(.subheadline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(.red.opacity(0.10), in: .rect(cornerRadius: 10))
                        .foregroundStyle(.red)
                }
            }
        }
        .padding(16)
        .background(.regularMaterial, in: .rect(cornerRadius: 20))
        .shadow(color: .black.opacity(0.15), radius: 12, y: 4)
        .padding(.horizontal, 16)
    }
}

// MARK: - Preview

#Preview("Walk Invitation Notification Banner") {
    ZStack {
        LinearGradient(colors: [.blue.opacity(0.4), .purple.opacity(0.3)], startPoint: .topLeading, endPoint: .bottomTrailing)
            .ignoresSafeArea()

        VStack {
            WalkInvitationBannerView(
                walkerName: "Awan",
                destination: "Autograph Tower"
            )
            .padding(.top, 60)
            Spacer()
        }
    }
}
