//
//  OnboardingView.swift
//  Astar
//
//  Created by Muhammad Pandu Royyan on 24/08/26.
//

// SwiftUI is Apple's declarative UI framework (analogous to React/Jetpack Compose).
// Views are `struct`s (value types) that describe *what* to render; the framework
// decides *how* and *when* to render them.
import SwiftUI
// TCA's SwiftUI integration: `StoreOf`, `@Bindable`, `WithPerceptionTracking`.
import ComposableArchitecture
// `AuthenticationServices` provides `SignInWithAppleButton` and
// `ASAuthorizationAppleIDCredential` – the native "Sign In with Apple" UI component.
import AuthenticationServices

// MARK: - String Extension: nilIfBlank (private to this file)
/// Returns `nil` if the string is empty or contains only whitespace; otherwise returns
/// the trimmed string. Scoped `private` to this file to avoid global namespace pollution.
///
/// Used when extracting name/email from the Apple credential – Apple may return a blank
/// string instead of `nil` in some edge cases, so we normalise those to `nil`.
///
/// **Python analogy**: `s.strip() or None`
private extension String {
  var nilIfBlank: String? {
    let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
    return trimmed.isEmpty ? nil : trimmed
  }
}

// MARK: - OnboardingView
/// The root SwiftUI view for the onboarding / login screen.
///
/// **TCA View Pattern**:
/// In TCA, a view holds a `Store` (the "store" is TCA's central object that holds state,
/// processes actions, and runs effects). The view:
///   1. Reads from `store.someProperty` to render UI.
///   2. Calls `store.send(.someAction)` to dispatch user events.
///   3. Never mutates state directly (all mutations go through the reducer).
///
/// **Python analogy**: The store is like a Redux store (`store.getState()` / `store.dispatch()`).
/// The view is a pure render function: `render(state) -> UI`.
///
/// **`@Bindable var store`**: The `@Bindable` property wrapper (from the `Observation` framework)
/// allows creating two-way SwiftUI `Binding`s from the store's properties. For example,
/// `$store.currentIndex` creates a `Binding<Int>` that reads the current index and dispatches
/// an action when written. The `.sending(\.setIndex)` extension converts a write into a
/// specific TCA action instead of directly mutating state (preserving the unidirectional
/// data flow invariant).
struct OnboardingView: View {
  /// The TCA store scoped to `OnboardingFeature`. This is the single source of truth
  /// for everything this view and its sub-views render.
  @Bindable var store: StoreOf<OnboardingFeature>

  // MARK: Body
  var body: some View {
    // `VStack` stacks child views vertically (analogous to a `flex-direction: column`
    // CSS container or Android's `LinearLayout` with vertical orientation).
    VStack {
      // `Spacer()` is a flexible space that expands to push sibling views apart.
      // The top `Spacer` pushes the carousel away from the very top of the screen.
      Spacer()

      // MARK: Carousel / Pager (TabView with PageTabViewStyle)
      // `TabView` is SwiftUI's multi-page container. With `.tabViewStyle(.page)`,
      // it becomes a horizontally swipeable pager (like a ViewPager in Android or
      // a UIPageViewController in UIKit).
      //
      // `selection: $store.currentIndex.sending(\.setIndex)` creates a two-way binding:
      //   - Reading: the TabView shows the page at `store.currentIndex`.
      //   - Writing: when the user swipes, `store.send(.setIndex(newIndex))` is called,
      //     which also resets the auto-advance timer (see OnboardingFeature reducer).
      //
      // This is the TCA way of connecting SwiftUI's `Binding<T>` to a `Store` without
      // directly mutating state – every write goes through the reducer as an Action.
      TabView(selection: $store.currentIndex.sending(\.setIndex)) {
        // `Array(store.contents.enumerated())` pairs each element with its 0-based index.
        // In Python: `list(enumerate(store.contents))`.
        // `id: \.element.id` tells SwiftUI how to uniquely identify each slide by its
        // `OnboardingContent.id` (which is derived from its title).
        ForEach(Array(store.contents.enumerated()), id: \.element.id) { index, content in
          // Each slide is a `VStack` with an icon and text content below it.
          VStack(spacing: 24) {
            // MARK: Slide Icon
            // `Image(systemName:)` renders an SF Symbols icon by name.
            // `.scaledToFit()` – like `object-fit: contain` in CSS.
            // `.font(.system(size: 64))` – for SF Symbols, font size controls the icon size.
            // `.foregroundColor(.accentColor)` – uses the app's accent color (set in Assets.xcassets).
            Image(systemName: content.imageName)
              .scaledToFit()
              .font(.system(size: 64))
              .foregroundColor(.accentColor)

            // MARK: Slide Text Content
            VStack(spacing: 16) {
              // Slide title – bold, centered, adapts to multiple lines.
              Text(content.title)
                .font(.title)
                .fontWeight(.bold)
                .multilineTextAlignment(.center)

              // Pattern-match on `PageBody` to render the appropriate layout.
              // Swift `switch` in a `@ViewBuilder` context returns a `View` for each case.
              // This is like a conditional render in React: `content.body === 'paragraph' ? <p/> : <ul/>`.
                switch content.body {
                case .paragraph(let text):
                    // Simple prose paragraph: small caption font, secondary (gray) color.
                    // `.padding(.horizontal, 32)` adds 32 pt left/right margins.
                    Text(text)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                    
                case .glossary(let items):
                    // Glossary layout: a vertical list of term-definition pairs.
                    VStack (spacing: 16) {
                        ForEach(items) { item in
                            // Each row is a horizontal stack: term on the left, definition on the right.
                            HStack {
                                // Term label: fixed 100 pt width, left-aligned, medium weight.
                                // `.frame(width: 100, alignment: .leading)` reserves space so
                                // definitions across rows start at a consistent horizontal offset –
                                // like a two-column table.
                                Text(item.term)
                                    .font(.caption)
                                    .foregroundStyle(.primary)
                                    .fontWeight(.medium)
                                    .frame(width: 100, alignment: .leading)
                                    .multilineTextAlignment(.leading)
                                
                                // Definition text: secondary color, left-aligned, wraps freely.
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
          // `.tag(index)` associates this page with the integer index, which is what
          // `TabView(selection:)` uses to show/hide pages. The tag *must* match the
          // type of the `selection` binding – both are `Int` here.
          .tag(index)
        }
      }
      // `.tabViewStyle(.page)` switches TabView from its default tab-bar style to
      // a full-screen horizontal pager. `indexDisplayMode: .never` hides the built-in
      // page dots (we draw our own custom dots below for full design control).
      .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
      // Fix the carousel height to 400 pt so it doesn't grow to fill the screen.
      .frame(height: 400)

      // MARK: Custom Page Indicator Dots
      // We draw our own page dots because `indexDisplayMode: .never` hid the built-in ones.
      // Each dot is an 8×8 pt `Circle`. The active dot uses `.primary` (full opacity) while
      // inactive dots use `.secondary.opacity(0.3)` (dimmed gray).
      //
      // `.animation(.easeInOut, value: store.currentIndex)` animates the dot color change
      // whenever `currentIndex` changes – SwiftUI's implicit animation system detects the
      // value change and applies the easing curve automatically. No `UIView.animate` needed.
      HStack(spacing: 8) {
        ForEach(0..<store.contents.count, id: \.self) { index in
          Circle()
            .fill(index == store.currentIndex ? Color.primary : Color.secondary.opacity(0.3))
            .frame(width: 8, height: 8)
            .animation(.easeInOut, value: store.currentIndex)
        }
      }
      .padding(.top, 16)

      // Second `Spacer()` pushes the button area to the bottom of the screen.
      Spacer()

      // MARK: Error Message (conditional)
      // `if let errorMessage = store.login.errorMessage` is Swift's optional binding –
      // the block only renders when the login child state has a non-nil error.
      // The view *reads* deeply nested state (`store.login.errorMessage`) directly –
      // TCA's `Observation` framework tracks this read and re-renders only this portion
      // of the view when that specific property changes.
      if let errorMessage = store.login.errorMessage {
        Text(errorMessage)
          .font(.caption)
          .foregroundStyle(.red)
          .multilineTextAlignment(.center)
          .padding(.horizontal, 24)
          .padding(.bottom, 8)
      }

      // MARK: Sign In Button / Loading State (conditional)
      // An `if/else` in `@ViewBuilder` context: SwiftUI renders one branch or the other.
      // During an in-flight login network call (`isLoading == true`), we swap the button
      // for a spinner row to prevent the user from tapping again (debounce via UI).
      if store.login.isLoading {
        // MARK: Loading Indicator
        // An `HStack` with a spinner and a label, styled to match the "Sign In with Apple"
        // button dimensions (height 50 pt, horizontal padding 24 pt, bottom padding 40 pt).
        HStack(spacing: 12) {
          // `ProgressView()` with no argument renders an indeterminate spinner.
          // `.tint(.white)` sets the spinner's color to white.
          ProgressView()
            .tint(.white)
          Text("Signing in...")
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(.white)
        }
        .frame(maxWidth: .infinity)   // stretch to full available width
        .frame(height: 50)            // match Sign In button height
        .background(.background)      // use adaptive background (white/dark-mode aware)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .padding(.horizontal, 24)
        .padding(.bottom, 40)         // keep button above safe-area / home indicator
      } else {
        // MARK: Sign In with Apple Button
        // `SignInWithAppleButton` is Apple's official, App Store-required UI component for
        // "Sign In with Apple". Using this exact component (vs. a custom button) is mandatory
        // by Apple's Human Interface Guidelines.
        //
        // It has two callbacks:
        //   - `onRequest`: configure the authorization request before it is sent to Apple.
        //   - `onCompletion`: receive the result (success or failure) after the user interacts.
        SignInWithAppleButton(
          // `.signIn` sets the button label to "Sign in with Apple".
          // Alternatives: `.signUp`, `.continue`.
          .signIn,
          onRequest: { request in
            // `requestedScopes` specifies what data we ask Apple to share.
            // `.fullName` – the user's name (only returned on first sign-in).
            // `.email`    – the user's email or relay address (only returned on first sign-in).
            // Apple's privacy model: after the first sign-in, these are nil forever.
            // That's why we fall back to CloudKit UserIdentity in the reducer.
            request.requestedScopes = [.fullName, .email]
          },
          onCompletion: { result in
            // `result` is `Result<ASAuthorization, Error>`.
            // Swift's `Result` type is equivalent to Python's `Union[Success, Failure]`
            // or `Either` in functional programming.
            switch result {
            case .success(let authorization):
              // `authorization.credential` is `ASAuthorizationCredential` (a protocol).
              // We downcast to `ASAuthorizationAppleIDCredential` with `as?` (safe cast –
              // returns nil if the credential is a different type, preventing a crash).
              if let credential = authorization.credential as? ASAuthorizationAppleIDCredential {
                // `credential.user` – the opaque Apple User ID (stable across sign-ins).
                // `credential.fullName` – `PersonNameComponents?` (nil after first sign-in).
                // `PersonNameComponentsFormatter` converts structured name parts into a
                // localised display string (e.g. "Given Family" or "Family, Given" per locale).
                let formatter = PersonNameComponentsFormatter()
                // Build our lightweight value-type credential wrapper.
                // `credential.fullName.map(formatter.string(from:))` – optional map:
                //   if `fullName` is non-nil, format it; otherwise propagate nil.
                // `?.nilIfBlank` – normalise empty strings to nil.
                let payload = AppleSignInCredential(
                  appleUserId: credential.user,
                  name: credential.fullName.map(formatter.string(from:))?.nilIfBlank,
                  email: credential.email?.nilIfBlank
                )
                // Dispatch the action into the store. TCA routes it to `LoginFeature`
                // via the `.login(...)` namespace (see `OnboardingFeature.Action.login`).
                store.send(.login(.appleSignInCompleted(payload)))
              }
            case .failure(let error):
              // User cancelled, or an error occurred (e.g. Face ID failed).
              // We only log here – no action dispatched – because there's nothing meaningful
              // to display to the user for a cancellation.
              print("Sign in with Apple failed: \(error.localizedDescription)")
            }
          }
        )
        // `.signInWithAppleButtonStyle(.black)` – Apple provides three styles:
        // `.black` (black background), `.white` (white background), `.whiteOutline`.
        // The choice must meet Apple's "Sign In with Apple" button styling guidelines.
        .signInWithAppleButtonStyle(.black)
        .frame(height: 50)
        .padding(.horizontal, 24)
        .padding(.bottom, 40)   // breathing room above the home indicator on modern iPhones
      }
    }
    // MARK: View Lifecycle → TCA Actions
    // `.onAppear` / `.onDisappear` are SwiftUI lifecycle modifiers.
    // We translate them into TCA actions so the reducer can start/stop the timer.
    // This keeps all business logic inside the reducer (testable), not in the view.
    .onAppear {
      store.send(.onAppear)
    }
    .onDisappear {
      store.send(.onDisappear)
    }
  }
}

// MARK: - Preview
/// Xcode Canvas preview. Provides a live interactive preview of the view in the IDE.
/// `Store(initialState:reducer:)` boots a real TCA store with a fresh state.
/// No mocking needed because `OnboardingFeature` has no live dependencies that would
/// cause issues in a preview (the `continuousClock` uses the real clock in previews).
#Preview {
  OnboardingView(
    store: Store(initialState: OnboardingFeature.State()) {
      OnboardingFeature()
    }
  )
}
