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
        ZStack {
            Color(.systemBackground)
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                
                // MARK: Onboarding Pages
                TabView(selection: $store.currentIndex.sending(\.setIndex)) {
                    ForEach(Array(store.contents.enumerated()), id: \.element.id) { index, content in
                        VStack(spacing: 0) {
                            
                            Spacer()
                            
                            // MARK: Icon
                            if index == 0 {
                                Image("TrailLogo")
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 96, height: 96)
                            } else {
                                Image(systemName: content.imageName)
                                    .font(.system(size: 64, weight: .medium))
                                    .foregroundStyle(.tint)
                                    .frame(height: 100)
                            }
                            
                            Spacer()
                                .frame(height: 28)
                            
                            // MARK: Title
                            Text(content.title)
                                .font(.system(size: 32, weight: .bold))
                                .foregroundStyle(.primary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 24)
                            
                            Spacer()
                                .frame(height: 28)
                            
                            // MARK: Description
                            switch content.body {
                            case .paragraph(let text):
                                Text(text)
                                    .font(.system(size: 20))
                                    .foregroundStyle(.secondary)
                                    .multilineTextAlignment(.center)
                                    .lineSpacing(4)
                                    .padding(.horizontal, 36)
                                
                            case .glossary(let items):
                                VStack(spacing: 24) {
                                    ForEach(items) { item in
                                        HStack(alignment: .top, spacing: 20) {
                                            Text(item.term)
                                                .font(.system(size: 19))
                                                .foregroundStyle(.primary)
                                                .frame(width: 110, alignment: .leading)
                                            
                                            Text(item.definition)
                                                .font(.system(size: 19))
                                                .foregroundStyle(.secondary)
                                                .multilineTextAlignment(.leading)
                                                .frame(maxWidth: .infinity, alignment: .leading)
                                        }
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                    }
                                }
                                .padding(.horizontal, 32)
                            }
                            
                            Spacer()
                        }
                        .tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                
                // MARK: Page Indicator
                HStack(spacing: 12) {
                    ForEach(0..<store.contents.count, id: \.self) { index in
                        Circle()
                            .fill(
                                index == store.currentIndex
                                ? Color.primary
                                : Color.secondary.opacity(0.35)
                            )
                            .frame(width: 10, height: 10)
                    }
                }
                .padding(.bottom, 36)
                
                // MARK: Sign in with Apple
                if store.login.isLoading {
                    HStack(spacing: 12) {
                        ProgressView()
                            .tint(.white)
                        
                        Text("Signing in...")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(.white)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 64)
                    .background(Color.black)
                    .clipShape(Capsule())
                    .padding(.horizontal, 24)
                    .padding(.bottom, 32)
                    
                } else {
                    SignInWithAppleButton(
                        .signIn,
                        onRequest: { request in
                            request.requestedScopes = [.fullName, .email]
                        },
                        onCompletion: { result in
                            switch result {
                            case .success(let authorization):
                                if let credential =
                                    authorization.credential as? ASAuthorizationAppleIDCredential {
                                    
                                    let formatter = PersonNameComponentsFormatter()
                                    
                                    let payload = AppleSignInCredential(
                                        appleUserId: credential.user,
                                        name: credential.fullName
                                            .map { formatter.string(from: $0) }
                                            .flatMap(\.nilIfBlank),
                                        email: credential.email?.nilIfBlank
                                    )
                                    
                                    store.send(
                                        .login(
                                            .appleSignInCompleted(payload)
                                        )
                                    )
                                }
                                
                            case .failure(let error):
                                print(
                                    "Sign in with Apple failed: \(error.localizedDescription)"
                                )
                            }
                        }
                    )
                    .signInWithAppleButtonStyle(.black)
                    .frame(height: 64)
                    .clipShape(Capsule())
                    .padding(.horizontal, 24)
                    .padding(.bottom, 32)
                }
            }
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
