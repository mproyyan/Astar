//
//  WalkerProfileHeader.swift
//  Astar
//
//  Created by Dimas Prihady Setyawan on 25/08/26.
//

import SwiftUI

struct WalkerProfileHeader: View {
    let name: String
    let locationSubtitle: String
    let timeAgo: String
    var avatarImageName: String = "AwanAvatar"
    var isTracked: Bool = false

    var onTrack: (() -> Void)? = nil
    var onExitTrack: (() -> Void)? = nil
    var onPing: (() -> Void)? = nil

    private let avatarSize: CGFloat = 52

    var body: some View {
        VStack(spacing: 16) {
            HStack(spacing: 14) {
                Group {
                    if let _ = UIImage(named: avatarImageName) {
                        Image(avatarImageName)
                            .resizable()
                            .scaledToFill()
                    } else {
                        Circle()
                            .fill(Color(red: 0.77, green: 0.81, blue: 0.96))
                            .overlay {
                                Text(String(name.prefix(1)))
                                    .font(.title3.weight(.semibold))
                                    .foregroundStyle(.white)
                            }
                    }
                }
                .frame(width: avatarSize, height: avatarSize)
                .clipShape(Circle())

                VStack(alignment: .leading, spacing: 3) {
                    Text(name)
                        .font(.title3.weight(.bold))
                        .foregroundStyle(.primary)

                    HStack(spacing: 4) {
                        Text(locationSubtitle)
                            .lineLimit(1)

                        Text("•")

                        Text(timeAgo)
                    }
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                }

                Spacer(minLength: 0)
            }

            if isTracked {
                HStack(spacing: 12) {
                    Button {
                        onExitTrack?()
                    } label: {
                        Text("Exit Track")
                            .font(.headline.weight(.semibold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(Color(red: 1.0, green: 0.23, blue: 0.19), in: .capsule)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Exit Track")

                    Button {
                        onPing?()
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "bell.fill")
                            Text("Ping")
                        }
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Color(red: 1.0, green: 0.80, blue: 0.0), in: .capsule)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Ping \(name)")
                }
            } else {
                Button {
                    onTrack?()
                } label: {
                    Text("Track")
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Color.blue, in: .capsule)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Track \(name)")
            }
        }
    }
}

#Preview("Untracked") {
    WalkerProfileHeader(
        name: "Awan",
        locationSubtitle: "Central Jakarta, Jakarta",
        timeAgo: "1 Min Ago",
        isTracked: false
    )
    .padding()
}

#Preview("Tracked") {
    WalkerProfileHeader(
        name: "Awan",
        locationSubtitle: "Central Jakarta, Jakarta",
        timeAgo: "1 Min Ago",
        isTracked: true
    )
    .padding()
}
