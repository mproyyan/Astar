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
//                .padding(.top, 20)
//                .padding(.bottom, 0)
//                .padding(.horizontal, 2)

                if !isDone {
                    Divider()
                        .opacity(0.5)

                    VStack(alignment: .leading, spacing: 14) {
                        HStack(spacing: 6) {
                            Text("Watching:")
                                .font(.title3.weight(.semibold))
                                .foregroundStyle(.primary)

                            Text(watchingPeople.isEmpty ? "None" : "\(watchingPeople.count) Person")
                                .font(.title3.weight(.medium))
                                .foregroundStyle(.secondary)

                            Spacer()
                        }

                        if !watchingPeople.isEmpty {
                            HStack(spacing: 16) {
                                ForEach(watchingPeople) { person in
                                    DirectionPersonView(person: person)
                                }
                            }
                            .padding(.vertical, 4)
                        }
                    }
                    .padding(.vertical, 14)
                    .padding(.horizontal, 2)
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

#Preview("In Progress") {
    DirectionProgress(isDone: false)
        .padding()
        .background(Color(red: 0.95, green: 0.95, blue: 0.97))
}

#Preview("Done") {
    DirectionProgress(isDone: true)
        .padding()
        .background(Color(red: 0.95, green: 0.95, blue: 0.97))
}
