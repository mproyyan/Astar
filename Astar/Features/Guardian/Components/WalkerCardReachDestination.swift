//
//  WalkerCardReachDestination.swift
//  Astar
//
//  Created by Dimas Prihady Setyawan on 25/08/26.
//

import SwiftUI

struct WalkerCardReachDestination: View {
    var walkerName: String = "Awan Mendung"
    var avatarImageName: String = "AwanAvatar"
    var onDismiss: (() -> Void)? = nil
    var onJourneyLog: (() -> Void)? = nil
    var onDone: (() -> Void)? = nil

    private let avatarSize: CGFloat = 80

    var body: some View {
        VStack(spacing: 16) {
            // Header Bar
            HStack {
                Text("People")
                    .font(.title.weight(.bold))
                    .foregroundStyle(.primary)

                Spacer()

                Button {
                    onDismiss?()
                } label: {
                    Image(systemName: "xmark")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(.primary)
                        .frame(width: 36, height: 36)
                }
                .buttonStyle(.plain)
                .glassEffect(.regular.interactive(), in: .circle)
                .accessibilityLabel("Close")
            }

            VStack(spacing: 16) {
                // Avatar with checkmark badge
                ZStack(alignment: .bottomTrailing) {
                    Group {
                        if let _ = UIImage(named: avatarImageName) {
                            Image(avatarImageName)
                                .resizable()
                                .scaledToFill()
                        } else {
                            Circle()
                                .fill(Color(red: 0.77, green: 0.81, blue: 0.96))
                                .overlay {
                                    Text(String(walkerName.prefix(1)))
                                        .font(.system(size: 32, weight: .semibold))
                                        .foregroundStyle(.white)
                                }
                        }
                    }
                    .frame(width: avatarSize, height: avatarSize)
                    .clipShape(Circle())

                    // Green checkmark badge
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 24))
                        .symbolRenderingMode(.palette)
                        .foregroundStyle(.white, Color(red: 0.19, green: 0.82, blue: 0.35))
                        .background(Circle().fill(.white).padding(2))
                        .offset(x: 2, y: 2)
                }
                .padding(.top, 4)

                // Message Text
                Text("\(walkerName) has reached\nthe destination")
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
                
                // Journey Log Button
                Button {
                    onJourneyLog?()
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "list.bullet")
                            .resizable()
                            .scaledToFit()
                            .fontWeight(.semibold)
                            .frame(width: 24, height: 24)

                        Text("Journey Log")
                            .font(.subheadline.weight(.semibold))
                    }
                    .foregroundStyle(.primary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Color.primary.opacity(0.06), in: .capsule)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Journey Log")
                .padding(.top, 4)

                // Done Button
                Button {
                    onDone?() ?? onDismiss?()
                } label: {
                    Text("Done")
                        .font(.headline.weight(.bold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Color.blue, in: .capsule)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Done")
            }
            .frame(maxWidth: .infinity)
            .padding(.bottom, 8)
        }
        .padding(.top, 8)
    }
}

#Preview {
    ScrollView {
        WalkerCardReachDestination()
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
    }
    .background(Color(red: 0.95, green: 0.95, blue: 0.97))
}
