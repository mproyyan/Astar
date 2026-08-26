//
//  TrustedPersonView.swift
//  Astar
//
//  Created by Nadia Putri Natali Lubis on 26/08/26.
//

import SwiftUI


struct TrustedPersonView: View {
    var body: some View {
        NavigationStack {
            
            
            ScrollView {
                RequestSection()
                
                TrustedPersonList()
            }
            .padding(16)
            
            
                .navigationTitle("Trusted Person")
                .navigationBarTitleDisplayMode(.automatic)
            
        }
    }
}


// MARK: Request Section

struct RequestSection: View {
    var body: some View {
        NavigationLink {
            Text("Request Section")
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
                    Text("\(invitedPersons.first?.displayName ?? "user") + \(sampleData.count - 1) others")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.body)
            }
            .padding(.vertical, 16)
            .padding(.horizontal, 20)
//            .background(.red)
            .clipShape(.rect(cornerRadius: 26))
            .overlay(
                RoundedRectangle(cornerRadius: 26)
                    .stroke(Color(.systemGray6), lineWidth:1)
            )
//            .border(Color(.systemGray6), width: 1)
        }
        .buttonStyle(.plain)
    }
}


// MARK: Trusted Person List

struct TrustedPersonList: View {
    var body: some View {
        VStack {
            ForEach(sampleData) { data in
                TrustedPersonRow(data: data)
                Divider()
                    .padding(.leading, 72)
            }
            AddParticipantButton()
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
    var data: SampleData
    
    var body: some View {
        HStack (spacing: 16) {
            ZStack {
                Circle()
                    .frame(width:40, height: 40)
                    .foregroundStyle(.quaternary)
                Image(systemName: "\(data.avatar)")
                    .font(.body)
                    .foregroundStyle(Color.white)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(data.displayName)
                    .font(.subheadline)
                    .bold()
                
                if data.status == .accepted {
                    Text(data.icloud)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    
                }
            }
            
            if data.status == .invited {
                Spacer()
                Text("Invited")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 16)
            }
            
            if data.status == .accepted {
                Spacer()
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 8)
    }
}

// MARK: Add participant Button

struct AddParticipantButton: View {
    var body: some View {
        Button {
            "Add participant"
        } label: {
            Text("Add Participant")
                .padding(.vertical, 8)
                .padding(.horizontal, 20)
            Spacer()
        }
    }
}

#Preview {
    TrustedPersonView()
}
