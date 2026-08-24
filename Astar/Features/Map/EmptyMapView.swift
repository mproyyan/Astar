//
//  EmptyMapView.swift
//  Astar
//
//  Created by Muhammad Pandu Royyan on 24/08/26.
//

import SwiftUI
import ComposableArchitecture

private extension String {
  var nilIfBlank: String? {
    let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
    return trimmed.isEmpty ? nil : trimmed
  }
}

struct EmptyMapView: View {
  @Bindable var store: StoreOf<LoginFeature>

  var body: some View {
    VStack(spacing: 24) {
      Text("Map View")
        .font(.largeTitle)
        .fontWeight(.bold)

      if let profile = store.userProfile {
        VStack(spacing: 8) {
          Text("Apple ID: \(profile.appleUserId)")
          Text("CloudKit ID: \(profile.cloudKitUserId)")
          Text("Name: " + (profile.name.nilIfBlank ?? "Not provided by Apple"))
          Text("Email: " + (profile.email.nilIfBlank ?? "Not provided by Apple"))
        }
        .font(.callout)
        .padding()
        .background(Color.secondary.opacity(0.1))
        .cornerRadius(12)
      } else {
        Text("No user profile found.")
          .foregroundColor(.secondary)
      }

      Spacer()

      Button(role: .destructive) {
        store.send(.signOutButtonTapped)
      } label: {
        Text("Sign Out")
          .fontWeight(.semibold)
          .frame(maxWidth: .infinity)
          .padding()
          .background(Color.red.opacity(0.1))
          .cornerRadius(12)
      }
      .padding(.horizontal)
      .padding(.bottom, 24)
    }
    .padding()
  }
}

#Preview {
  EmptyMapView(
    store: Store(initialState: LoginFeature.State(
      userProfile: UserProfile(
        appleUserId: "apple-123",
        cloudKitUserId: "ck-456",
        name: "John Doe",
        email: "john@example.com"
      )
    )) {
      LoginFeature()
    }
  )
}
