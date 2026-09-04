//
//  BroadcastInfoSheet.swift
//  Astar
//
//  Created by Safa Auliya Hidayat on 03/09/26.
//

import SwiftUI

struct BroadcastInfoSheet: View {
    var body: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(Color.blue.opacity(0.12))
                    .frame(width: 56, height: 56)

                Image(systemName: "checkmark")
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundStyle(.blue)
            }
            .padding(.top, 24)

            VStack(spacing: 8) {
                Text("Your journey has been broadcast")
                    .font(.title3.weight(.bold))
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.center)

                Text("Your trusted contacts can now see your journey and help keep you safe along the way.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, 24)

            Spacer(minLength: 16)
        }
        .padding(.bottom, 16)
        .presentationDetents([.height(240)])
        .presentationDragIndicator(.visible)
        .presentationCornerRadius(28)
    }
}

#Preview {
    Text("Map View Background")
        .sheet(isPresented: .constant(true)) {
            BroadcastInfoSheet()
        }
}
