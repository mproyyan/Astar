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
  }
}

// MARK: - Components

struct ProfileHeader: View {
  let store: StoreOf<ProfileFeature>

  var body: some View {
    VStack(spacing: 8) {
      // Avatar Placeholder
      ZStack {
        Circle()
          .fill(Color(red: 0.88, green: 0.88, blue: 0.90))
          .frame(width: 96, height: 96)

        Image(systemName: "person.fill")
          .resizable()
          .scaledToFit()
          .frame(width: 48, height: 48)
          .foregroundColor(.gray)
          .offset(y: 4) // adjust visual center of the person icon
      }
      .padding(.bottom, 8)

      // 3. Profile Information
      Text(store.userProfile?.name ?? "Unknown User")
        .font(.title2.bold())
        .foregroundColor(.primary)
        .multilineTextAlignment(.center)

      Text(store.userProfile?.email ?? "unknown@apple.com")
        .font(.footnote)
        .tint(Color.gray)
        .multilineTextAlignment(.center)
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
