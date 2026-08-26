//
//  TrustedPersonView.swift
//  Astar
//
//  Created by Nadia Putri Natali Lubis on 26/08/26.
//

import SwiftUI


struct SampleData: Identifiable {
    var id: Int
    var avatar: String
    var displayName: String
    var icloud: Int
}

var sampleData: [SampleData] = [
    SampleData(id: 1, avatar: "person.crop.circle.fill", displayName: "Alex Morgan", icloud: 128),
    SampleData(id: 2, avatar: "person.crop.square.fill", displayName: "Jordan Lee", icloud: 512),
    SampleData(id: 3, avatar: "person.fill.checkmark", displayName: "Taylor Swift", icloud: 2000),
    SampleData(id: 4, avatar: "person.fill.turn.right", displayName: "Chris Evans", icloud: 50),
    SampleData(id: 5, avatar: "person.wave.2.fill", displayName: "Sam Wilson", icloud: 200)
]

var firstData: SampleData {
    sampleData.first!
}


struct TrustedPersonView: View {
    var body: some View {
        NavigationStack {
            
            
            RequestSection()
            
            TrustedPersonList()
            
            
                .navigationTitle("Trusted Person")
                .navigationBarTitleDisplayMode(.large)
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
                    Text("\(firstData.displayName) + \(sampleData.count - 1) others")
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




#Preview {
    TrustedPersonView()
}
