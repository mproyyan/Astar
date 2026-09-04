//
//  ProfileButton.swift
//  Astar
//
//  Created by Dimas Prihady Setyawan on 25/08/26.
//

import ComposableArchitecture
import SwiftUI

struct ProfileButton: View {
    let store: StoreOf<MainFeature>
    @State private var loadedAvatarData: Data?

    private var effectiveAvatarData: Data? {
        store.login.userProfile?.avatarData ?? loadedAvatarData
    }

    var body: some View {
        Button {
            store.send(.profileButtonTapped)
        } label: {
            if let avatarData = effectiveAvatarData, let uiImage = UIImage(data: avatarData) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 40, height: 40)
                    .clipShape(Circle())
                    .shadow(color: Color(red: 0.45, green: 0.50, blue: 0.82).opacity(0.16), radius: 8, x: 0, y: 4)
            } else {
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
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Profile")
        .task {
            let profile = store.login.userProfile ?? UserProfileStorage.load()
            let fetched = await ContactPhotoClient.liveValue.fetchMeCardPhoto(profile?.email, profile?.name)
            loadedAvatarData = fetched
        }
    }

    private var initials: String {
        let profile = store.login.userProfile ?? UserProfileStorage.load()
        guard let name = profile?.name, !name.trimmingCharacters(in: .whitespaces).isEmpty else { return "U" }

        let parts = name.split(separator: " ").filter { !$0.isEmpty }
        if parts.count >= 2 {
            return "\(parts[0].prefix(1))\(parts[1].prefix(1))".uppercased()
        }
        return String(name.prefix(2)).uppercased()
    }
}

#Preview {
    ProfileButton(
        store: Store(initialState: MainFeature.State()) {
            MainFeature()
        }
    )
    .padding()
}
