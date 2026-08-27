//
//  OnboardingView.swift
//  Astar
//
//  Created by Muhammad Pandu Royyan on 24/08/26.
//

import SwiftUI
import ComposableArchitecture
import AuthenticationServices

private extension String {
  var nilIfBlank: String? {
    let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
    return trimmed.isEmpty ? nil : trimmed
  }
}

struct OnboardingView: View {
  @Bindable var store: StoreOf<OnboardingFeature>

  var body: some View {
    VStack {
      Spacer()

      TabView(selection: $store.currentIndex.sending(\.setIndex)) {
        ForEach(Array(store.contents.enumerated()), id: \.element.id) { index, content in
          VStack(spacing: 24) {
            Image(systemName: content.imageName)
              .scaledToFit()
              .font(.system(size: 64))
              .foregroundColor(.accentColor)

            VStack(spacing: 16) {
              Text(content.title)
                .font(.title)
                .fontWeight(.bold)
                .multilineTextAlignment(.center)

                
                switch content.body {
                case .paragraph(let text):
                    Text(text)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                    
                case .glossary(let items):
                    VStack (spacing: 16) {
                        ForEach(items) { item in
                            HStack {
                                Text(item.term)
                                    .font(.caption)
                                    .foregroundStyle(.primary)
                                    .fontWeight(.medium)
                                    .frame(width: 100, alignment: .leading)
                                    .multilineTextAlignment(.leading)
                                
                                Text(item.definition)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .multilineTextAlignment(.leading)
                            }
                        }
                    }
                    .padding(.horizontal, 32)
                }
            }
          }
          .tag(index)
        }
      }
      .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
      .frame(height: 400)

      HStack(spacing: 8) {
        ForEach(0..<store.contents.count, id: \.self) { index in
          Circle()
            .fill(index == store.currentIndex ? Color.primary : Color.secondary.opacity(0.3))
            .frame(width: 8, height: 8)
            .animation(.easeInOut, value: store.currentIndex)
        }
      }
      .padding(.top, 16)

      Spacer()

      SignInWithAppleButton(
        .signIn,
        onRequest: { request in
          request.requestedScopes = [.fullName, .email]
        },
        onCompletion: { result in
          switch result {
          case .success(let authorization):
            if let credential = authorization.credential as? ASAuthorizationAppleIDCredential {
              let formatter = PersonNameComponentsFormatter()
              let payload = AppleSignInCredential(
                appleUserId: credential.user,
                name: credential.fullName.map(formatter.string(from:))?.nilIfBlank,
                email: credential.email?.nilIfBlank
              )
              store.send(.appleSignInCompleted(payload))
            }
          case .failure(let error):
            print("Sign in with Apple failed: \(error.localizedDescription)")
          }
        }
      )
      .signInWithAppleButtonStyle(.black)
      .frame(height: 50)
      .padding(.horizontal, 24)
      .padding(.bottom, 40)
    }
    .onAppear {
      store.send(.onAppear)
    }
    .onDisappear {
      store.send(.onDisappear)
    }
  }
}

#Preview {
  OnboardingView(
    store: Store(initialState: OnboardingFeature.State()) {
      OnboardingFeature()
    }
  )
}
