//
//  DirectionProgress.swift
//  Astar
//
//  Created by Dimas Prihady Setyawan on 25/08/26.
//

import SwiftUI

struct DirectionProgress: View {
    var destination: SavedPlace = SavedPlace(
        name: "Home",
        subtitle: "Bendungan Hilir, South Jakarta",
        iconName: "house.fill",
        distance: "28 km"
    )
    var estimatedTime: String = "8 hrs 22 min"
    var eta: String = "08.16 ETA"
    var totalDistance: String = "28 km"
    var watchingPeople: [Person] = [
        Person(name: "Awan", status: "Walking")
    ]

    var isDone: Bool = false
    var isLoading: Bool = false
    var isDevelopmentMode: Bool = DeveloperSettingsStorage.isDevelopmentMode

    var onJourneyLog: (() -> Void)? = nil
    var onEndJourney: (() -> Void)? = nil
    var onDone: (() -> Void)? = nil
    var onSimulateArrival: (() -> Void)? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("To \(destination.name)")
                .font(.title.weight(.bold))
                .foregroundStyle(.primary)

            VStack(alignment: .leading, spacing: 0) {
                VStack(spacing: 16) {
                    if isDone {
                        VStack(spacing: 12) {
                            Image(systemName: "checkmark.circle.fill")
                                .resizable()
                                .scaledToFit()
                                .foregroundStyle(Color(red: 0.19, green: 0.82, blue: 0.35))
                                .frame(width: 82, height: 70)

                            Text("You’ve reached your destination.")
                                .font(.headline.weight(.semibold))
                                .foregroundStyle(.primary)
                                .multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.top, 8)
                    } else if isLoading {
                        HStack {
                            Text("Calculating...")
                                .font(.title3.weight(.semibold))
                                .foregroundStyle(.secondary)

                            Spacer()

                            HStack(spacing: 6) {
                                Text("--.-- ETA")
                                    .font(.callout)
                                    .foregroundStyle(.secondary)

                                Circle()
                                    .fill(Color.secondary.opacity(0.6))
                                    .frame(width: 4, height: 4)

                                Text("-- km")
                                    .font(.callout)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    } else {
                        HStack {
                            Text(estimatedTime)
                                .font(.title3.weight(.semibold))
                                .foregroundStyle(.primary)

                            Spacer()

                            HStack(spacing: 6) {
                                Text(eta)
                                    .font(.callout)
                                    .foregroundStyle(.secondary)

                                Circle()
                                    .fill(Color.secondary.opacity(0.6))
                                    .frame(width: 4, height: 4)

                                Text(totalDistance)
                                    .font(.callout)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }

                    if isDone {
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
                    }
                }

                if !isDone {
                    Divider()
                        .opacity(0.5)

                    DirectionProgressHeroRowCard(
                        watchingPeople: watchingPeople,
                        destinationName: destination.name
                    )
                    .padding(.top, 14)
                    .padding(.bottom, 14)
                }

                Divider()
                    .opacity(0.5)

                if !isDone && isDevelopmentMode {
                    Button {
                        onSimulateArrival?()
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "flag.checkered")
                                .font(.subheadline.weight(.semibold))
                            Text("Simulate Arrival (Mock)")
                                .font(.subheadline.weight(.semibold))
                        }
                        .foregroundStyle(.blue)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color.blue.opacity(0.1), in: .capsule)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Simulate arrival")
                    .padding(.top, 8)
                }

                Button {
                    if isDone {
                        onDone?() ?? onEndJourney?()
                    } else {
                        onEndJourney?()
                    }
                } label: {
                    Text(isDone ? "Done" : "End Journey")
                        .font(.headline.weight(.bold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .padding(.horizontal, 20)
                        .background(isDone ? Color.blue : Color.red, in: .capsule)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(isDone ? "Done" : "End journey")
                .padding(.top, isDone ? 16 : 8)
                .padding(.bottom, 20)
            }
        }
        .padding(.top, 16)
    }
}

// MARK: - Companion Hero Row Card
private struct DirectionProgressHeroRowCard: View {
    let watchingPeople: [Person]
    let destinationName: String

    private var activeCompanions: [Person] {
        watchingPeople.isEmpty ? [Person(name: "Awan", status: "Walking")] : watchingPeople
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Companions Watching")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)

                Spacer()

                HStack(spacing: 4) {
                    Circle()
                        .fill(Color.green)
                        .frame(width: 6, height: 6)
                    Text("\(activeCompanions.count) Connected")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(Color.green)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(Color.green.opacity(0.12), in: .capsule)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 14) {
                    ForEach(activeCompanions) { person in
                        VStack(spacing: 4) {
                            ZStack(alignment: .bottomTrailing) {
                                DirectionPersonAvatar(person: person, size: 46)
                                Circle()
                                    .fill(Color.green)
                                    .frame(width: 11, height: 11)
                                    .overlay(Circle().stroke(Color.white, lineWidth: 2))
                            }

                            Text(person.name.split(separator: " ").first.map(String.init) ?? person.name)
                                .font(.caption.weight(.medium))
                                .foregroundStyle(.primary)
                                .lineLimit(1)
                        }
                    }
                }
                .padding(.vertical, 2)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(Color.primary.opacity(0.03), in: .rect(cornerRadius: 16))
        .overlay {
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.primary.opacity(0.06), lineWidth: 1)
        }
    }
}

// MARK: - Companion Avatar View
struct DirectionPersonAvatar: View {
    let person: Person
    var size: CGFloat = 36
    @State private var loadedAvatarData: Data?

    private var effectiveAvatarData: Data? {
        person.avatarData ?? loadedAvatarData
    }

    private var initials: String {
        let parts = person.name.split(separator: " ").filter { !$0.isEmpty }
        if parts.count >= 2 {
            return "\(parts[0].prefix(1))\(parts[1].prefix(1))".uppercased()
        }
        return String(person.name.prefix(1)).uppercased()
    }

    var body: some View {
        Group {
            if let avatarData = effectiveAvatarData, let uiImage = UIImage(data: avatarData) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
                    .frame(width: size, height: size)
                    .clipShape(Circle())
            } else if let avatarImageName = person.avatarImageName, let _ = UIImage(named: avatarImageName) {
                Image(avatarImageName)
                    .resizable()
                    .scaledToFill()
                    .frame(width: size, height: size)
                    .clipShape(Circle())
            } else {
                Circle()
                    .fill(Color(red: 0.77, green: 0.81, blue: 0.96))
                    .overlay {
                        Text(initials)
                            .font(.system(size: size * 0.38, weight: .semibold))
                            .foregroundStyle(.white)
                    }
                    .frame(width: size, height: size)
            }
        }
        .overlay {
            Circle()
                .stroke(Color.white, lineWidth: 2)
        }
        .shadow(color: Color.black.opacity(0.08), radius: 3, x: 0, y: 1)
        .task(id: person.name) {
            if loadedAvatarData == nil && person.avatarData == nil && person.avatarImageName == nil {
                if let email = person.email, let fetched = await ContactPhotoClient.liveValue.fetchContactPhotoByEmail(email) {
                    loadedAvatarData = fetched
                } else if let fetched = await ContactPhotoClient.liveValue.fetchContactPhotoByName(person.name) {
                    loadedAvatarData = fetched
                }
            }
        }
    }
}

#Preview("In Progress") {
    DirectionProgress(
        destination: SavedPlace(
            name: "Autograph Tower",
            subtitle: "Thamrin Nine",
            iconName: "building.2.fill"
        ),
        estimatedTime: "12 min",
        eta: "11.02 ETA",
        totalDistance: "850 m",
        watchingPeople: [
            Person(name: "Awan Mendung", status: "Walking"),
            Person(name: "Pandu Royyan", status: "Idle")
        ],
        isDone: false
    )
    .padding()
    .background(Color(red: 0.95, green: 0.95, blue: 0.97))
}

#Preview("Done") {
    DirectionProgress(isDone: true)
        .padding()
        .background(Color(red: 0.95, green: 0.95, blue: 0.97))
}
