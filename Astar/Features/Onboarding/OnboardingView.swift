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
        VStack(spacing: 0) {

            // MARK: - Content
            TabView(selection: $store.currentIndex.sending(\.setIndex)) {
                ForEach(
                    Array(store.contents.enumerated()),
                    id: \.element.id
                ) { index, content in

                    VStack(spacing: 0) {
                        Spacer(minLength: 20)

                        // MARK: Icon
                        Group {
                            if index == 0 {
                                Image("TrailLogo")
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 88, height: 88)
                            } else {
                                Image(systemName: content.imageName)
                                    .font(.system(size: 56, weight: .medium))
                                    .foregroundStyle(.tint)
                                    .frame(width: 88, height: 88)
                            }
                        }

                        Spacer()
                            .frame(height: 28)

                        // MARK: Title
                        Text(content.title)
                            .font(.title2.weight(.bold))
                            .foregroundStyle(.primary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 24)

                        Spacer()
                            .frame(height: 16)

                        // MARK: Body
                        switch content.body {
                        case .paragraph(let text):
                            Text(text)
                                .font(.body)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                                .lineSpacing(3)
                                .padding(.horizontal, 32)

                        case .glossary(let items):
                            VStack(alignment: .leading, spacing: 20) {
                                ForEach(items) { item in
                                    HStack(alignment: .top, spacing: 16) {
                                        Text(item.term)
                                            .font(.subheadline.weight(.semibold))
                                            .foregroundStyle(.primary)
                                            .frame(
                                                width: 104,
                                                alignment: .leading
                                            )

                                        Text(item.definition)
                                            .font(.subheadline)
                                            .foregroundStyle(.secondary)
                                            .multilineTextAlignment(.leading)
                                            .frame(
                                                maxWidth: .infinity,
                                                alignment: .leading
                                            )
                                    }
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 28)
                        }

                        Spacer()
                    }
                    .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))

            // MARK: - Page Indicator
            HStack(spacing: 8) {
                ForEach(
                    0..<store.contents.count,
                    id: \.self
                ) { index in
                    Circle()
                        .fill(
                            index == store.currentIndex
                            ? Color.primary
                            : Color.secondary.opacity(0.3)
                        )
                        .frame(width: 8, height: 8)
                }
            }
            .padding(.bottom, 28)

            // MARK: - Sign in with Apple
            if store.login.isLoading {
                HStack(spacing: 10) {
                    ProgressView()
                        .tint(.white)

                    Text("Signing in…")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(.white)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(.black)
                .clipShape(Capsule())
                .padding(.horizontal, 24)
                .padding(.bottom, 32)

            } else {
                SignInWithAppleButton(
                    .signIn,
                    onRequest: { request in
                        request.requestedScopes = [
                            .fullName,
                            .email
                        ]
                    },
                    onCompletion: { result in
                        switch result {
                        case .success(let authorization):
                            if let credential =
                                authorization.credential
                                as? ASAuthorizationAppleIDCredential {

                                let formatter =
                                    PersonNameComponentsFormatter()

                                let payload = AppleSignInCredential(
                                    appleUserId: credential.user,
                                    name: credential.fullName
                                        .map {
                                            formatter.string(from: $0)
                                        }
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
                .frame(height: 50)
                .clipShape(Capsule())
                .padding(.horizontal, 24)
                .padding(.bottom, 32)
            }
        }
        .background(.background)
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
        store: Store(
            initialState: OnboardingFeature.State()
        ) {
            OnboardingFeature()
        }
    )
}
