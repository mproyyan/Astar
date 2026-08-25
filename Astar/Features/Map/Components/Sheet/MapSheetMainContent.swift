//
//  MapSheetContent.swift
//  Astar
//
//  Created by Dimas Prihady Setyawan on 25/08/26.
//

import ComposableArchitecture
import SwiftUI

struct MapSheetMainContent: View {
    let store: StoreOf<MainFeature>
    let isExpanded: Bool
    let onSearchTapped: () -> Void

    private let people = MapSampleData.people
    private let savedPlaces = MapSampleData.savedPlaces

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack(spacing: 12) {
                Button(action: onSearchTapped) {
                    SearchBarView()
                }
                .buttonStyle(.plain)

                ProfileButton(store: store)
            }
            .padding(.top, 8)

            VStack(spacing: 32) {
                PeopleSection(people: people)

                SavedSection(savedPlaces: savedPlaces)
                    .transition(.asymmetric(
                        insertion: .opacity.combined(with: .move(edge: .bottom)),
                        removal: .opacity
                    ))
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16)
        .padding(.top, 12)
    }
}

private struct SearchBarView: View {
    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.body.weight(.semibold))
                .foregroundStyle(.secondary)

            Text("Search Place")
                .font(.body)
                .foregroundStyle(.secondary)

            Spacer(minLength: 8)

            Image(systemName: "mic")
                .font(.body.weight(.semibold))
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 16)
        .frame(height: 40)
        .background(.white, in: .capsule)
        .overlay {
            Capsule()
                .stroke(Color.primary.opacity(0.08), lineWidth: 1)
        }
    }
}

private struct ProfileButton: View {
    let store: StoreOf<MainFeature>

    var body: some View {
        Button {
            store.send(.profileButtonTapped)
        } label: {
            Text(initials)
                .font(.body.weight(.semibold))
                .foregroundStyle(.white)
                .frame(width: 40, height: 40)
                .background {
                    Circle()
                        .fill(Color(red: 0.67, green: 0.72, blue: 0.93))
                        .shadow(color: Color(red: 0.45, green: 0.50, blue: 0.82).opacity(0.16), radius: 8, x: 0, y: 4)
                }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Profile")
    }

    private var initials: String {
        guard let name = store.login.userProfile?.name, !name.isEmpty else { return "NL" }

        let parts = name.split(separator: " ")
        if parts.count >= 2 {
            return "\(parts[0].prefix(1))\(parts[1].prefix(1))".uppercased()
        }
        return String(name.prefix(2)).uppercased()
    }
}

private struct PeopleSection: View {
    let people: [Person]

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("People")
                .font(.title3)
                .fontWeight(.semibold)
                .foregroundStyle(.primary)

            HStack(alignment: .top, spacing: 10) {
                ForEach(people) { person in
                    PersonView(person: person)
                        .frame(maxWidth: .infinity)
                }
            }
        }
    }
}

private struct PersonView: View {
    let person: Person
    private let avatarSize: CGFloat = 80

    var body: some View {
        VStack(spacing: 8) {
            Circle()
                .fill(Color(red: 0.77, green: 0.81, blue: 0.96))
                .overlay {
                    Circle()
                        .fill(.linearGradient(
                            colors: [
                                .white.opacity(0.42),
                                .clear
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ))
                }
                .overlay {
                    Text(String(person.name.prefix(1)))
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.92))
                }
                .frame(width: avatarSize, height: avatarSize)

            VStack(spacing: 2) {
                Text(person.name)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                Text(person.status)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .frame(maxWidth: .infinity)
    }
}

private struct SavedSection: View {
    let savedPlaces: [SavedPlace]

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 4) {
                Text("Saved")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.primary)

                Image(systemName: "chevron.right")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
            }

            VStack(spacing: 0) {
                ForEach(savedPlaces.enumerated(), id: \.element.id) { index, place in
                    SavedPlaceRow(
                        place: place,
                        isFirst: index == 0,
                        isLast: index == savedPlaces.count - 1
                    )

                    if index < savedPlaces.count - 1 {
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
}

struct SavedPlaceRow: View {
    let place: SavedPlace
    let isFirst: Bool
    let isLast: Bool

    var body: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(Color(red: 0.78, green: 0.82, blue: 0.97).opacity(0.92))
                .overlay {
                    Image(systemName: place.iconName)
                        .font(.body.weight(.semibold))
                        .foregroundStyle(.white)
                }
                .frame(width: 40, height: 40)

            VStack(alignment: .leading, spacing: 4) {
                Text(place.name)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)

                Text(place.subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 8)

            Button {
            } label: {
                Image(systemName: "ellipsis")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .frame(width: 34, height: 34)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Options")
        }
        .padding(.top, isFirst ? 20 : 16)
        .padding(.bottom, isLast ? 16 : 20)
    }
}

#Preview {
    MapSheetMainContent(
        store: Store(initialState: MainFeature.State()) {
            MainFeature()
        },
        isExpanded: true,
        onSearchTapped: {}
    )
}
