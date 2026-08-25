//
//  WalkerCardRoute.swift
//  Astar
//
//  Created by Dimas Prihady Setyawan on 25/08/26.
//

import SwiftUI

struct WalkerCardRoute: View {
    var originName: String = "Autograph Tower"
    var originIconName: String = "briefcase.fill"
    var destinationName: String = "Home"
    var destinationIconName: String = "house.fill"

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Route")
                .font(.title3.weight(.semibold))
                .foregroundStyle(.primary)

            VStack(spacing: 0) {
                // Origin Row
                HStack(spacing: 12) {
                    Circle()
                        .fill(Color(red: 0.85, green: 0.72, blue: 0.65))
                        .overlay {
                            Image(systemName: originIconName)
                                .font(.caption.weight(.bold))
                                .foregroundStyle(.white)
                        }
                        .frame(width: 36, height: 36)

                    Text(originName)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)

                    Spacer(minLength: 8)
                }
                .padding(.top, 18)
                .padding(.bottom, 6)

                // Connecting Line & Horizontal Divider
                ZStack(alignment: .leading) {
                    Divider()
                        .padding(.leading, 48)

                    Rectangle()
                        .fill(Color.secondary.opacity(0.25))
                        .frame(width: 3, height: 20)
                        .padding(.leading, 16.5)
                }
                .frame(height: 20)

                // Destination Row
                HStack(spacing: 12) {
                    Circle()
                        .fill(Color(red: 0.20, green: 0.75, blue: 0.95))
                        .overlay {
                            Image(systemName: destinationIconName)
                                .font(.caption.weight(.bold))
                                .foregroundStyle(.white)
                        }
                        .frame(width: 36, height: 36)

                    Text(destinationName)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)

                    Spacer(minLength: 8)
                }
                .padding(.top, 6)
                .padding(.bottom, 18)
            }
            .padding(.horizontal, 16)
            .background(.white, in: .rect(cornerRadius: 24))
            .overlay {
                RoundedRectangle(cornerRadius: 24)
                    .stroke(Color.primary.opacity(0.06), lineWidth: 1)
            }
        }
    }
}

#Preview {
    WalkerCardRoute()
        .padding()
        .background(Color(red: 0.95, green: 0.95, blue: 0.97))
}
