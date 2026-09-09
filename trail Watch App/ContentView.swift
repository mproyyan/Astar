import SwiftUI
import Combine
import UIKit

struct ContentView: View {
    @EnvironmentObject var sessionManager: WatchSessionManager

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                if sessionManager.state.destinationName.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "location.slash.fill")
                            .font(.largeTitle)
                            .foregroundStyle(.secondary)
                        Text("No Active Journey")
                            .font(.headline)
                        Text("Start navigation on your iPhone to see it here.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.top, 20)
                } else if sessionManager.state.isDone {
                    VStack(spacing: 8) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.largeTitle)
                            .foregroundStyle(.green)
                        Text("You've Reached")
                            .font(.headline)
                        Text(sessionManager.state.destinationName)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.top, 20)
                } else {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("To \(sessionManager.state.destinationName)")
                            .font(.headline)
                            .lineLimit(1)
                        HStack {
                            Text(sessionManager.state.estimatedTime)
                            Spacer()
                            Text(sessionManager.state.eta)
                        }
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal, 4)

                    Divider()
                        .padding(.vertical, 4)

                    if sessionManager.state.watchingPeople.isEmpty {
                        Text("No companions yet")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .padding(.top, 8)
                    } else {
                        HStack {
                            Text("\(sessionManager.state.watchingPeople.count) Companions")
                                .font(.headline)
                            Spacer()
                        }
                        .padding(.horizontal, 4)

                        ForEach(sessionManager.state.watchingPeople) { person in
                            CompanionCard(person: person)
                        }
                    }
                }
            }
            .padding(.horizontal, 8)
            .padding(.bottom, 24)
        }
        .navigationTitle("Journey")
    }
}

struct CompanionCard: View {
    let person: WatchPerson

    var body: some View {
        HStack(spacing: 12) {
            Group {
                if let data = person.avatarData, let uiImage = UIImage(data: data) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFill()
                } else {
                    let initials = String(person.name.prefix(2)).uppercased()
                    ZStack {
                        Color.blue.opacity(0.3)
                        Text(initials)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(.white)
                    }
                }
            }
            .frame(width: 44, height: 44)
            .clipShape(Circle())
            .overlay(Circle().stroke(Color.white.opacity(0.2), lineWidth: 1))

            VStack(alignment: .leading, spacing: 2) {
                Text(person.name)
                    .font(.body)
                    .fontWeight(.medium)
                    .lineLimit(1)

                HStack(spacing: 4) {
                    Circle()
                        .fill(Color.green)
                        .frame(width: 6, height: 6)
                    Text("Joined \(person.joinedAt)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            Spacer()
        }
        .padding(12)
        .background(Color.white.opacity(0.1))
        .cornerRadius(12)
    }
}
