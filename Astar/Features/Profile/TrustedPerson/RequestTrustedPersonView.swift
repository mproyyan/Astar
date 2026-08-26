//
//  RequestTrustedPersonView.swift
//  Astar
//
//  Created by Nadia Putri Natali Lubis on 26/08/26.
//

import SwiftUI

struct RequestTrustedPersonView: View {
    var body: some View {
        NavigationStack{
            ScrollView {
                VStack (spacing: 8) {
                    ForEach(sampleData) { data in
                        if data.status == .accepted {
                            RequestCard(data: data)
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
            }
            
            .padding(.horizontal, 16)
            .background(Color(.systemGroupedBackground))
            
            .navigationTitle("Request")
            .navigationBarTitleDisplayMode(.inline)
            
        }
    }
}

// MARK: Request Card

struct RequestCard : View {
    let data: SampleData
    
    var body: some View {
        VStack {
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
                    
                    Text(data.icloud)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    
                }
                
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 8)
            
            RequestButton()
        }
    }
}


// MARK: Button

struct RequestButton : View {
    var body: some View {
        HStack {
            Spacer()
            Button(action: {}) {
                Text("Confirm")
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                
                    .font(.subheadline)
//                    .bold()
                    .foregroundStyle(.white)
                    .background(.blue)
                    .clipShape(.capsule)
                    
            }
            .buttonStyle(.plain)
            
            Button(action: {}) {
                Text("Delete")
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                
                    .font(.subheadline)
//                    .bold()
                    .foregroundStyle(.primary)
                    .background(.quinary)
                    .clipShape(.capsule)
                    
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 16)
//        .padding(16)
//        .background(.red)
    }
}

#Preview {
    RequestTrustedPersonView()
}
