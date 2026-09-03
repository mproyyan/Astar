//
//  RequestTrustedPersonView.swift
//  Astar
//
//  Created by Nadia Putri Natali Lubis on 26/08/26.
//

import SwiftUI
import ComposableArchitecture

struct RequestTrustedPersonView: View {
    let store: StoreOf<RequestTrustedPersonFeature>

    var body: some View {
        ScrollView {
            VStack (spacing: 8) {
                ForEach(store.requests) { request in
                    RequestCard(store: store, connectionProfile: request)
                }
            }
            .padding(.vertical, 16)
            .background(.background)
            .clipShape(.rect(cornerRadius: 26))
            .overlay(
                RoundedRectangle(cornerRadius: 26)
                    .stroke(Color(.systemGray6), lineWidth: 1)
            )
        }
        .padding(.horizontal, 16)
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Request")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: Request Card

struct RequestCard : View {
    let store: StoreOf<RequestTrustedPersonFeature>
    let connectionProfile: ConnectionProfile
    
    var body: some View {
        VStack {
            HStack (spacing: 16) {
                ZStack {
                    Circle()
                        .frame(width:40, height: 40)
                        .foregroundStyle(.quaternary)
                    Image(systemName: "person.crop.circle.fill")
                        .font(.body)
                        .foregroundStyle(Color.white)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(connectionProfile.partnerProfile.name)
                        .font(.subheadline)
                        .bold()
                    
                    Text(connectionProfile.partnerProfile.email)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 8)
            
            RequestButton(store: store, connectionProfile: connectionProfile)
        }
    }
}


// MARK: Button

struct RequestButton : View {
    let store: StoreOf<RequestTrustedPersonFeature>
    let connectionProfile: ConnectionProfile
    
    var body: some View {
        HStack {
            Spacer()
            Button(action: {
                store.send(.confirmTapped(connectionProfile.connection.id))
            }) {
                Text("Confirm")
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .font(.subheadline)
                    .foregroundStyle(.white)
                    .background(.blue)
                    .clipShape(.capsule)
            }
            .buttonStyle(.plain)
            
            Button(action: {
                store.send(.deleteTapped(connectionProfile.connection.id))
            }) {
                Text("Delete")
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .font(.subheadline)
                    .foregroundStyle(.primary)
                    .background(.quinary)
                    .clipShape(.capsule)
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 16)
    }
}

#Preview {
    RequestTrustedPersonView(store: Store(initialState: RequestTrustedPersonFeature.State()) { RequestTrustedPersonFeature() })
}
