//
//  ProfileView.swift
//  Astar
//
//  Created by Muhammad Pandu Royyan on 24/08/26.
//

import SwiftUI

struct ProfileView: View {
  var body: some View {
    NavigationStack {
      ZStack {
        // Background
        Color(red: 0.95, green: 0.95, blue: 0.97)
          .ignoresSafeArea()
        
        VStack(spacing: 0) {
          // 2. Profile Header
          ProfileHeader()
            .padding(.top, 24)
            .padding(.bottom, 16)
          
          // 4 & 5. Profile Options List
          List {
            Section {
              NavigationLink {
                Text("Trusted Person")
              } label: {
                Text("Trusted Person")
                  .font(.body)
                  .padding(.vertical, 8)
              }
              
              NavigationLink {
                Text("Set Default Locations")
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
          }
          .listStyle(.insetGrouped)
          .scrollContentBackground(.hidden)
          
          // 6. Sign Out Button
          SignOutButton()
            .padding(.horizontal, 20)
            .padding(.bottom, 32)
        }
      }
      // 1. Navigation
      .navigationTitle("Profile")
      .navigationBarTitleDisplayMode(.inline)
    }
  }
}

// MARK: - Components

struct ProfileHeader: View {
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
      Text("Muhammad Royyan")
        .font(.title2.bold())
        .foregroundColor(.primary)
        .multilineTextAlignment(.center)
      
      Text("mproyyan@gmail.com")
        .font(.footnote)
        .tint(Color.gray)
      .multilineTextAlignment(.center)    }
  }
}

struct SignOutButton: View {
  var body: some View {
    Button(action: {
      print("Sign out tapped")
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
  ProfileView()
}
