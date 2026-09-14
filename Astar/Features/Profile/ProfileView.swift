//
//  ProfileView.swift
//  Astar
//
//  Created by Muhammad Pandu Royyan on 24/08/26.
//

import SwiftUI
import ComposableArchitecture

// MARK: - ProfileView
//
// The top-level SwiftUI view for the Profile screen.
//
// In TCA, every "screen" (or "feature") is driven by a `Store`, which is the
// single source of truth — analogous to a Redux store in JavaScript or a
// ViewModel in MVVM. The `store` property holds the current `State` and
// accepts `Action`s sent from the UI.
//
// Architecture flow:
//   User taps something → View sends Action → Reducer mutates State → SwiftUI re-renders

struct ProfileView: View {
  // `StoreOf<ProfileFeature>` is syntactic sugar for `Store<ProfileFeature.State, ProfileFeature.Action>`.
  // Using `let` (not `@Bindable`) here because we only need to READ state and SEND actions;
  // we're not doing two-way binding on any state properties directly.
  let store: StoreOf<ProfileFeature>

  var body: some View {
    // `ZStack` layers views on top of each other (Z axis = depth).
    // Python analogy: think of it as absolute-positioned divs stacked in HTML/CSS.
    ZStack {
      // Background
        // `Color(.systemGroupedBackground)` uses a semantic iOS color that adapts
        // automatically to light/dark mode — similar to CSS `var(--background-color)`.
        Color(.systemGroupedBackground)
        .ignoresSafeArea() // Extend the background behind notches / home indicator

      // `VStack` arranges children vertically, like a CSS flexbox column.
      // `spacing: 0` removes the default gap between children so we control padding explicitly.
      VStack(spacing: 0) {
        // 2. Profile Header
        // Decomposing the header into its own sub-view (`ProfileHeader`) keeps
        // `ProfileView.body` readable — same principle as decomposing React components.
        ProfileHeader(store: store)
          .padding(.top, 24)
          .padding(.bottom, 16)

        // 4 & 5. Profile Options List
        // `List` in SwiftUI produces a UITableView-backed scrollable list.
        // `Section` groups rows with optional headers/footers, like `<optgroup>` in HTML.
        List {
          Section {
            // Tapping "Trusted Person" sends an action to the reducer instead of
            // directly navigating — TCA keeps navigation logic inside the reducer,
            // not scattered in the view.
            Button {
              store.send(.trustedPersonTapped)
            } label: {
              HStack {
                Text("Trusted Person")
                  .font(.body)
                Spacer() // Push the chevron to the trailing edge
                Image(systemName: "chevron.right")
                  .font(.footnote)
                  .fontWeight(.semibold)
                  .foregroundStyle(.tertiary)
              }
              .padding(.vertical, 8)
              // `contentShape(Rectangle())` makes the entire row tappable, not just the text/icon.
              // Without it, only the visible ink of the label would respond to taps.
              .contentShape(Rectangle())
            }
            .buttonStyle(.plain) // Suppress the default blue tint on List buttons

            // `NavigationLink` pushes a new view onto a `NavigationStack`.
            // Here the destination creates its own ephemeral Store for `SavedPlacesFeature`.
            // Note: the `userId` is read directly from `store.userProfile` — TCA state is
            // observable like a @Published property in an ObservableObject.
            NavigationLink {
              // [REPLACED WITH DYNAMIC SAVED PLACES]
              // Text("Set Default Locations")
              SavedPlacesView(
                store: Store(
                  initialState: SavedPlacesFeature.State(
                    // `?? "default_user"` is Swift's nil-coalescing operator —
                    // equivalent to Python's `or` for falsy values: `profile.apple_user_id or "default_user"`
                    userId: store.userProfile?.appleUserId ?? "default_user"
                  )
                ) {
                  SavedPlacesFeature()
                }
              )
            } label: {
              Text("Saved Places")
                .font(.body)
                .padding(.vertical, 8)
            }

            // Placeholder row — the History feature is not yet implemented.
            NavigationLink {
              Text("History")
            } label: {
              Text("History")
                .font(.body)
                .padding(.vertical, 8)
            }
          }
          .listRowBackground(Color(.secondarySystemGroupedBackground))
          // Note: Native list section corner radius is managed by iOS.

          // "Settings" section with a header label.
          Section("Settings") {
            // `Toggle` is a boolean switch control (like a checkbox).
            // We bridge TCA's unidirectional state to SwiftUI's `Binding<Bool>` manually:
            //   - `get`: reads the current value from the TCA store (pure read)
            //   - `set`: sends an action back to the reducer with the new value
            // This pattern keeps the reducer as the single authority over state mutation.
            // Python analogy: like a property with a getter and a setter that calls a callback.
            Toggle(
              isOn: Binding(
                get: { store.isDevelopmentMode },
                set: { store.send(.setDevelopmentMode($0)) }
              )
            ) {
              HStack(spacing: 12) {
                Image(systemName: "hammer.fill")
                  .foregroundStyle(.blue)
                  .font(.system(size: 18))
                  .frame(width: 24)

                VStack(alignment: .leading, spacing: 2) {
                  Text("Development Mode")
                    .font(.body)
                  Text("Show mock walker and arrival simulation")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
              }
              .padding(.vertical, 4)
            }

            // Walking Route Guide toggle — same Binding pattern as above.
            Toggle(
              isOn: Binding(
                get: { store.isShowRouteGuide },
                set: { store.send(.setRouteGuide($0)) }
              )
            ) {
              HStack(spacing: 12) {
                Image(systemName: "point.topleft.down.to.point.bottomright.curvepath.fill")
                  .foregroundStyle(.blue)
                  .font(.system(size: 18))
                  .frame(width: 24)

                VStack(alignment: .leading, spacing: 2) {
                  Text("Walking Route Guide")
                    .font(.body)
                  Text("Show blue line guide to destination during walking")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
              }
              .padding(.vertical, 4)
            }

            // Friend Doe Walking mock toggle.
            Toggle(
              isOn: Binding(
                get: { store.isDoeWalkingMock },
                set: { store.send(.setDoeWalkingMock($0)) }
              )
            ) {
              HStack(spacing: 12) {
                Image(systemName: "figure.walk.circle.fill")
                  .foregroundStyle(.green)
                  .font(.system(size: 18))
                  .frame(width: 24)

                VStack(alignment: .leading, spacing: 2) {
                  Text("Friend Doe Walking")
                    .font(.body)
                  Text("Simulate friend Doe walking to destination")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
              }
              .padding(.vertical, 4)
            }

            // Conditionally show the reset button ONLY when BOTH dev mode and
            // Doe walking mock are enabled. Swift `&&` is the same as Python `and`.
            // SwiftUI re-evaluates `body` whenever observed state changes,
            // so this conditional renders/removes automatically.
            if store.isDoeWalkingMock && store.isDevelopmentMode {
              Button {
                store.send(.resetDoeWalkingSimulation)
              } label: {
                HStack(spacing: 12) {
                  Image(systemName: "arrow.counterclockwise.circle.fill")
                    .foregroundStyle(.orange)
                    .font(.system(size: 18))
                    .frame(width: 24)

                  VStack(alignment: .leading, spacing: 2) {
                    Text("Restart Doe's Walk")
                      .font(.body)
                      .foregroundStyle(.primary)
                    Text("Reset position and walking status")
                      .font(.caption)
                      .foregroundStyle(.secondary)
                  }
                }
                .padding(.vertical, 4)
              }
              .buttonStyle(.plain)
            }
          }
          .listRowBackground(Color(.secondarySystemGroupedBackground))
        }
        .listStyle(.insetGrouped)       // Rounded, inset card-style list sections
        .scrollContentBackground(.hidden) // Let our custom ZStack background show through

        // 6. Sign Out Button — isolated into its own sub-view for clarity.
        SignOutButton(store: store)
          .padding(.horizontal, 20)
          .padding(.bottom, 32)
      }
    }
    // 1. Navigation
    // Sets the title in the navigation bar. `.inline` displays it in the center.
    .navigationTitle("Profile")
    .navigationBarTitleDisplayMode(.inline)
    // `.onAppear` fires once when the view enters the view hierarchy —
    // analogous to React's `useEffect(() => { ... }, [])` with an empty dependency array.
    // Sending `.onAppear` lets the reducer trigger data-loading side-effects on first render.
    .onAppear {
      store.send(.onAppear)
    }
  }
}

// MARK: - Components

// MARK: ProfileHeader
//
// Displays the user's avatar (photo or initials fallback), name, and email.
// Kept separate from `ProfileView` to limit re-render scope and to follow
// the Single Responsibility Principle — same as splitting a Python class
// into focused helper classes.
struct ProfileHeader: View {
  let store: StoreOf<ProfileFeature>

  // `@State` is a SwiftUI property wrapper for local, view-owned mutable state.
  // It lives inside the View struct (a value type!) but SwiftUI manages its storage
  // on the heap behind the scenes. When it changes, SwiftUI re-renders the view.
  // Python analogy: instance variable on a class, but the class is actually a struct.
  @State private var loadedAvatarData: Data?

  // Computed property — no stored value, evaluated on each access.
  // Reads from TCA store first, falls back to local persistence.
  private var profile: UserProfile? {
    store.userProfile ?? UserProfileStorage.load()
  }

  // Prefers the profile's avatarData (from CloudKit / TCA state) over the
  // locally-fetched contact photo, giving the cloud version priority.
  private var effectiveAvatarData: Data? {
    profile?.avatarData ?? loadedAvatarData
  }

  // Derives initials from the user's name for the avatar placeholder.
  // "John Doe" → "JD", "Alice" → "Al"
  // Uses Swift's `split(separator:)` which is like Python's `str.split()`.
  private var initials: String {
    guard let name = profile?.name, !name.trimmingCharacters(in: .whitespaces).isEmpty else { return "U" }

    let parts = name.split(separator: " ").filter { !$0.isEmpty }
    if parts.count >= 2 {
      // `prefix(1)` is like Python's slicing: `name[:1]`
      return "\(parts[0].prefix(1))\(parts[1].prefix(1))".uppercased()
    }
    return String(name.prefix(2)).uppercased()
  }

  var body: some View {
    VStack(spacing: 8) {
      // Swift `if let` ("optional binding") safely unwraps an Optional value.
      // Python analogy: `if avatar_data := profile.avatar_data: ...` (walrus operator).
      // If avatarData exists AND we can decode it into a UIImage, show the photo.
      if let avatarData = effectiveAvatarData, let uiImage = UIImage(data: avatarData) {
        Image(uiImage: uiImage)
          .resizable()
          .scaledToFill()           // Like CSS `object-fit: cover`
          .frame(width: 96, height: 96)
          .clipShape(Circle())      // Crop to a circle
          .padding(.bottom, 8)
      } else {
        // Avatar Initial Placeholder
        // `ZStack` layers the gradient overlay on top of the base circle.
        ZStack {
          Circle()
            .fill(Color(red: 0.67, green: 0.72, blue: 0.93))
            .overlay {
              // A subtle top-left-to-bottom-right gradient gives a frosted-glass look.
              Circle()
                .fill(.linearGradient(
                  colors: [
                    .white.opacity(0.42),
                    .clear
                  ],
                  startPoint: .topLeading,
                  endPoint: .bottomTrailing
                ))
            }
            .shadow(color: Color(red: 0.45, green: 0.50, blue: 0.82).opacity(0.16), radius: 10, x: 0, y: 4)

          Text(initials)
            .font(.system(size: 34, weight: .semibold))
            .foregroundStyle(.white.opacity(0.95))
        }
        .frame(width: 96, height: 96)
        .padding(.bottom, 8)
      }

      // 3. Profile Information
      Text(profile?.name ?? "Unknown User")
        .font(.title2.bold())
        .foregroundStyle(.primary)
        .multilineTextAlignment(.center)

      Text(profile?.email ?? "unknown@apple.com")
        .font(.footnote)
        .foregroundStyle(.secondary)
        .multilineTextAlignment(.center)
    }
    // `.task` is like `asyncio.create_task(...)` — it launches an async Task
    // that is automatically cancelled when the view disappears.
    // This is where we fetch the user's contact photo without blocking the UI thread.
    .task {
      let resolvedEmail = profile?.email
      let resolvedName = profile?.name
      // `await` suspends execution here until the async function returns,
      // but does NOT block the main thread — the Swift concurrency runtime
      // (structured concurrency) handles this via cooperative multitasking,
      // similar to Python's asyncio event loop.
      let fetched = await ContactPhotoClient.liveValue.fetchMeCardPhoto(resolvedEmail, resolvedName)
      loadedAvatarData = fetched
      // If the fetched photo differs from what's stored, persist the update locally.
      if var current = profile, current.avatarData != fetched {
        current.avatarData = fetched
        UserProfileStorage.save(current)
      }
    }
  }
}

// MARK: SignOutButton
//
// An isolated sub-view for the sign-out action.
// Splitting it out keeps `ProfileView.body` focused and makes it trivial to
// independently style or test this button.
struct SignOutButton: View {
  let store: StoreOf<ProfileFeature>

  var body: some View {
    Button(action: {
      // Sends the `.signOutButtonTapped` action to the reducer.
      // The reducer decides what async side-effects to perform (e.g., clearing
      // keychain, navigating to the login screen). The view has no business logic.
      store.send(.signOutButtonTapped)
    }) {
      Text("Sign Out")
        .font(.system(size: 18, weight: .semibold))
        .foregroundColor(.white)
        .frame(maxWidth: .infinity) // Stretch to fill the available width
        .frame(height: 56)
    }
    .buttonStyle(.plain)
    // `glassEffect` applies a visionOS-style frosted glass effect tinted red,
    // giving the button a distinct destructive visual affordance.
    .glassEffect(.regular.tint(.red).interactive(), in: .rect(cornerRadius: 16))
  }
}

// MARK: - Preview
//
// `#Preview` creates a canvas preview in Xcode — analogous to Storybook stories
// in the JS ecosystem. We wrap it in a `NavigationStack` so the navigation bar
// title renders correctly in the canvas.
#Preview {
  NavigationStack {
    ProfileView(store: Store(initialState: ProfileFeature.State()) { ProfileFeature() })
  }
}
