//
//  PersonView.swift
//  Astar
//
//  Created by Dimas Prihady Setyawan on 25/08/26.
//

import SwiftUI

struct PersonView: View {
    let person: Person
    var onSelect: (() -> Void)? = nil
    @State private var loadedAvatarData: Data?
    private let avatarSize: CGFloat = 80

    private var effectiveAvatarData: Data? {
        person.avatarData ?? loadedAvatarData
    }

    var body: some View {
        Button {
            onSelect?()
        } label: {
            VStack(spacing: 6) {
                if let avatarData = effectiveAvatarData, let uiImage = UIImage(data: avatarData) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFill()
                        .frame(width: avatarSize, height: avatarSize)
                        .clipShape(Circle())
                } else if let avatarImageName = person.avatarImageName, let _ = UIImage(named: avatarImageName) {
                    Image(avatarImageName)
                        .resizable()
                        .scaledToFill()
                        .frame(width: avatarSize, height: avatarSize)
                        .clipShape(Circle())
                } else {
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
                            Text(initials)
                                .font(.title3.weight(.semibold))
                                .foregroundStyle(.white.opacity(0.92))
                        }
                        .frame(width: avatarSize, height: avatarSize)
                }

                VStack(spacing: 2) {
                    Text(person.name)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.primary)
                        .multilineTextAlignment(.center)
                        .lineLimit(1)
                        .truncationMode(.tail)

                    Text(person.status)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(person.name), \(person.status)")
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

    private var initials: String {
        let parts = person.name.split(separator: " ").filter { !$0.isEmpty }
        if parts.count >= 2 {
            return "\(parts[0].prefix(1))\(parts[1].prefix(1))".uppercased()
        }
        return String(person.name.prefix(1)).uppercased()
    }
}

#Preview {
    PersonView(person: Person(name: "Awan", status: "Walking"))
        .padding()
}
