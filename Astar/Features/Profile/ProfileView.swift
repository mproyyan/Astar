//
//  ProfileView.swift
//  Astar
//
//  Created by Muhammad Pandu Royyan on 24/08/26.
//

import SwiftUI
import ComposableArchitecture

struct ProfileView: View {
  let store: StoreOf<ProfileFeature>

  var body: some View {
    ZStack {
      // Background
      Color(red: 0.95, green: 0.95, blue: 0.97)
        .ignoresSafeArea()

      VStack(spacing: 0) {
        // 2. Profile Header
        ProfileHeader(store: store)
          .padding(.top, 24)
          .padding(.bottom, 16)

        // 4 & 5. Profile Options List
        List {
          Section {
            Button {
              store.send(.trustedPersonTapped)
            } label: {
              HStack {
                Text("Trusted Person")
                  .font(.body)
                Spacer()
                Image(systemName: "chevron.right")
                  .font(.footnote)
                  .fontWeight(.semibold)
                  .foregroundColor(Color(UIColor.tertiaryLabel))
              }
              .padding(.vertical, 8)
              .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            NavigationLink {
              // [REPLACED WITH DYNAMIC SAVED PLACES]
              // Text("Set Default Locations")
              SavedPlacesView(
                store: Store(
                  initialState: SavedPlacesFeature.State(
                    userId: store.userProfile?.appleUserId ?? "default_user"
                  )
                ) {
                  SavedPlacesFeature()
                }
              )
            } label: {
              Text("Set Default Locations")
                .font(.body)
                .padding(.vertical, 8)
            }

            NavigationLink {
              Text("History")
            } label: {
              Text("History")
                .font(.body)
                .padding(.vertical, 8)
            }
          }
          .listRowBackground(Color.white)
          // Note: Native list section corner radius is managed by iOS.

          Section("Settings") {
            Toggle(
              isOn: Binding(
                get: { store.isDevelopmentMode },
                set: { store.send(.setDevelopmentMode($0)) }
              )
            ) {
              HStack(spacing: 12) {
                Image(systemName: "hammer.fill")
                  .foregroundStyle(.blue)
                  .font(.system(size: 18))
                  .frame(width: 24)

                VStack(alignment: .leading, spacing: 2) {
                  Text("Development Mode")
                    .font(.body)
                  Text("Show mock walker and arrival simulation")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
              }
              .padding(.vertical, 4)
            }

            Toggle(
              isOn: Binding(
                get: { store.isShowRouteGuide },
                set: { store.send(.setRouteGuide($0)) }
              )
            ) {
              HStack(spacing: 12) {
                Image(systemName: "point.topleft.down.to.point.bottomright.curvepath.fill")
                  .foregroundStyle(.blue)
                  .font(.system(size: 18))
                  .frame(width: 24)

                VStack(alignment: .leading, spacing: 2) {
                  Text("Walking Route Guide")
                    .font(.body)
                  Text("Show blue line guide to destination during walking")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
              }
              .padding(.vertical, 4)
            }

            Toggle(
              isOn: Binding(
                get: { store.isDoeWalkingMock },
                set: { store.send(.setDoeWalkingMock($0)) }
              )
            ) {
              HStack(spacing: 12) {
                Image(systemName: "figure.walk.circle.fill")
                  .foregroundStyle(.green)
                  .font(.system(size: 18))
                  .frame(width: 24)

                VStack(alignment: .leading, spacing: 2) {
                  Text("Friend Doe Walking")
                    .font(.body)
                  Text("Simulate friend Doe walking to destination")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
              }
              .padding(.vertical, 4)
            }

            if store.isDoeWalkingMock && store.isDevelopmentMode {
              Button {
                store.send(.resetDoeWalkingSimulation)
              } label: {
                HStack(spacing: 12) {
                  Image(systemName: "arrow.counterclockwise.circle.fill")
                    .foregroundStyle(.orange)
                    .font(.system(size: 18))
                    .frame(width: 24)

                  VStack(alignment: .leading, spacing: 2) {
                    Text("Restart Doe's Walk")
                      .font(.body)
                      .foregroundStyle(.primary)
                    Text("Reset position and walking status")
                      .font(.caption)
                      .foregroundStyle(.secondary)
                  }
                }
                .padding(.vertical, 4)
              }
              .buttonStyle(.plain)
            }
          }
          .listRowBackground(Color.white)
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)

        // 6. Sign Out Button
        SignOutButton(store: store)
          .padding(.horizontal, 20)
          .padding(.bottom, 32)
      }
    }
    // 1. Navigation
    .navigationTitle("Profile")
    .navigationBarTitleDisplayMode(.inline)
    .onAppear {
      store.send(.onAppear)
    }
  }
}

// MARK: - Components

struct ProfileHeader: View {
  let store: StoreOf<ProfileFeature>
  @State private var loadedAvatarData: Data?

  private var profile: UserProfile? {
    store.userProfile ?? UserProfileStorage.load()
  }

  private var effectiveAvatarData: Data? {
    profile?.avatarData ?? loadedAvatarData
  }

  private var initials: String {
    guard let name = profile?.name, !name.trimmingCharacters(in: .whitespaces).isEmpty else { return "U" }

    let parts = name.split(separator: " ").filter { !$0.isEmpty }
    if parts.count >= 2 {
      return "\(parts[0].prefix(1))\(parts[1].prefix(1))".uppercased()
    }
    return String(name.prefix(2)).uppercased()
  }

  var body: some View {
    VStack(spacing: 8) {
      if let avatarData = effectiveAvatarData, let uiImage = UIImage(data: avatarData) {
        Image(uiImage: uiImage)
          .resizable()
          .scaledToFill()
          .frame(width: 96, height: 96)
          .clipShape(Circle())
          .padding(.bottom, 8)
      } else {
        // Avatar Initial Placeholder
        ZStack {
          Circle()
            .fill(Color(red: 0.67, green: 0.72, blue: 0.93))
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
            .shadow(color: Color(red: 0.45, green: 0.50, blue: 0.82).opacity(0.16), radius: 10, x: 0, y: 4)

          Text(initials)
            .font(.system(size: 34, weight: .semibold))
            .foregroundStyle(.white.opacity(0.95))
        }
        .frame(width: 96, height: 96)
        .padding(.bottom, 8)
      }

      // 3. Profile Information
      Text(profile?.name ?? "Unknown User")
        .font(.title2.bold())
        .foregroundColor(.primary)
        .multilineTextAlignment(.center)

      Text(profile?.email ?? "unknown@apple.com")
        .font(.footnote)
        .tint(Color.gray)
        .multilineTextAlignment(.center)
    }
    .task {
      let resolvedEmail = profile?.email
      let resolvedName = profile?.name
      let fetched = await ContactPhotoClient.liveValue.fetchMeCardPhoto(resolvedEmail, resolvedName)
      loadedAvatarData = fetched
      if var current = profile, current.avatarData != fetched {
        current.avatarData = fetched
        UserProfileStorage.save(current)
      }
    }
  }
}

struct SignOutButton: View {
  let store: StoreOf<ProfileFeature>

  var body: some View {
    Button(action: {
      store.send(.signOutButtonTapped)
    }) {
      Text("Sign Out")
        .font(.system(size: 18, weight: .semibold))
        .foregroundColor(.white)
        .frame(maxWidth: .infinity)
        .frame(height: 56)
    }
    .buttonStyle(.plain)
    .glassEffect(.regular.tint(.red).interactive(), in: .rect(cornerRadius: 16))
  }
}

#Preview {
  NavigationStack {
    ProfileView(store: Store(initialState: ProfileFeature.State()) { ProfileFeature() })
  }
}
