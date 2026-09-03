//
//  TrustedPersonView.swift
//  Astar
//
//  Created by Nadia Putri Natali Lubis on 26/08/26.
//

import SwiftUI
import ComposableArchitecture

struct TrustedPersonView: View {
    @Bindable var store: StoreOf<TrustedPersonFeature>
    
    var body: some View {
        ScrollView {
            RequestSection(store: store)
            
            TrustedPersonList(store: store)
        }
        .padding(16)
        .navigationTitle("Trusted Person")
        .navigationBarTitleDisplayMode(.automatic)
        .onAppear {
            store.send(.onAppear)
        }
        .sheet(item: $store.scope(state: \.destination?.addParticipant, action: \.destination.addParticipant)) { addParticipantStore in
            AddTrustedPersonView(store: addParticipantStore)
        }
    }
}

// MARK: Request Section

struct RequestSection: View {
    @Bindable var store: StoreOf<TrustedPersonFeature>

    var body: some View {
        if !store.requestConnections.isEmpty {
            Button {
                store.send(.requestSectionTapped)
            } label: {
                
                HStack (spacing: 16) {
                    ZStack {
                        Circle()
                            .fill(Color.blue)
                            .frame(width: 32, height: 32)
                        Image(systemName: "person.fill.badge.plus")
                            .font(.body)
                            .foregroundStyle(.white)
                        
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Request")
                            .font(.subheadline)
                            .bold()
                        let firstRequestName = store.requestConnections.first?.partnerProfile.name ?? "User"
                        let othersCount = store.requestConnections.count - 1
                        let othersText = othersCount > 0 ? " + \(othersCount) others" : ""
                        Text("\(firstRequestName)\(othersText)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .font(.body)
                }
                .padding(.vertical, 16)
                .padding(.horizontal, 20)
                .clipShape(.rect(cornerRadius: 26))
                .overlay(
                    RoundedRectangle(cornerRadius: 26)
                        .stroke(Color(.systemGray6), lineWidth:1)
                )
            }
            .buttonStyle(.plain)
        }
    }
}

// MARK: Trusted Person List

struct TrustedPersonList: View {
    @Bindable var store: StoreOf<TrustedPersonFeature>

    var body: some View {
        VStack {
            ForEach(store.mutualConnections) { connectionProfile in
                TrustedPersonRow(connectionProfile: connectionProfile)
                Divider()
                    .padding(.leading, 72)
            }
            AddParticipantButton(store: store)
        }
        .padding(.vertical, 16)
        .clipShape(.rect(cornerRadius: 26))
        .overlay(
        RoundedRectangle(cornerRadius: 26)
            .stroke(Color(.systemGray6), lineWidth: 1)
        )
    }
}

// MARK: Trusted Person Row

struct TrustedPersonRow: View {
    var connectionProfile: ConnectionProfile
    
    var body: some View {
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
                
                if connectionProfile.connection.status == "mutual" {
                    Text(connectionProfile.partnerProfile.email)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            
            if connectionProfile.connection.status == "request" {
                Spacer()
                Text("Invited")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 16)
            }
            
            if connectionProfile.connection.status == "mutual" {
                Spacer()
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 8)
    }
}

// MARK: Add participant Button

struct AddParticipantButton: View {
    @Bindable var store: StoreOf<TrustedPersonFeature>

    var body: some View {
        Button {
            store.send(.addParticipantTapped)
        } label: {
            Text("Add Participant")
                .padding(.vertical, 8)
                .padding(.horizontal, 20)
            Spacer()
        }
    }
}

#Preview {
    TrustedPersonView(store: Store(initialState: TrustedPersonFeature.State()) { TrustedPersonFeature() })
}
