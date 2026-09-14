//
//  OnboardingFeature.swift
//  Astar
//
//  Created by Muhammad Pandu Royyan on 24/08/26.
//

// `ComposableArchitecture` brings in all TCA types: `@Reducer`, `@ObservableState`,
// `Reduce`, `Scope`, `Effect`, `@Dependency`, etc.
// `Foundation` provides `Date`, `Timer`, `URL`, and other base types.
import ComposableArchitecture
import Foundation

// MARK: - GlossaryItem
/// A single term-definition pair displayed in glossary-style onboarding pages.
///
/// Conforms to:
///   - `Equatable`: TCA state must be `Equatable` so the framework can detect changes
///     via value comparison (like Python `__eq__`).
///   - `Identifiable`: required by SwiftUI's `ForEach` to uniquely track list items.
///     The `id` computed property uses `term` as the identity – assumes terms are unique
///     within a page, which is a safe assumption for a glossary.
///
/// **Python analogy**: equivalent to a frozen `@dataclass(eq=True)` with a `__hash__`
/// based on `term`.
struct GlossaryItem: Equatable, Identifiable {
    /// SwiftUI uses this property to track item identity across list updates (insertions,
    /// deletions, reorders). Here we use the term string as the stable identity.
    var id: String { term }
    /// The word or phrase being defined (e.g. "Walker", "Companion").
    let term: String
    /// The human-readable explanation shown alongside the term.
    let definition: String
}

// MARK: - PageBody
/// An **Algebraic Data Type** (Sum Type) representing the two possible content layouts
/// for an onboarding page body.
///
/// **Why an enum?** Because each page needs *either* a paragraph *or* a glossary –
/// never both. An enum enforces this mutual exclusivity at the type level.
///
/// **Python analogy**: Think of `Union[str, list[GlossaryItem]]`, but Swift's enum
/// carries the payload *inside* the case, so the UI can pattern-match on it exhaustively.
///
/// ```swift
/// switch content.body {
/// case .paragraph(let text): // render a Text view
/// case .glossary(let items): // render a list of term-definition rows
/// }
/// ```
enum PageBody: Equatable {
    /// A single block of descriptive text (prose paragraph).
    case paragraph(String)
    /// A list of `GlossaryItem`s for pages that explain terminology.
    case glossary([GlossaryItem])
}

// MARK: - OnboardingContent
/// Describes a single slide (page) in the onboarding carousel.
///
/// Conforms to `Identifiable` so SwiftUI's `ForEach` and `TabView(selection:)` can track
/// pages without explicit indices. The `id` is derived from `title` – guaranteed unique
/// since each page has a distinct title.
///
/// This is a pure **data model** (no UI logic). The view (`OnboardingView`) reads from it
/// and decides how to render each field. This separation mirrors the
/// Model-View separation in MVC / the State-View split in TCA.
struct OnboardingContent: Equatable, Identifiable {
  /// Stable identity for SwiftUI diffing. Using `title` is fine here since all titles differ.
  var id: String { title }
  /// Bold headline displayed at the top of the slide.
  let title: String
  /// The body content – either prose or a glossary, determined at compile time via `PageBody`.
  let body: PageBody
  /// SF Symbols icon name (e.g. "figure.walk.motion", "house.fill").
  /// SF Symbols is Apple's built-in icon library (~6000 icons). Like Font Awesome for Apple platforms.
  let imageName: String
}

// MARK: - OnboardingFeature (TCA Reducer)
/// The TCA Reducer that manages the full onboarding experience, including:
///   1. A **carousel / pager** of onboarding slides that auto-advance every 3 seconds.
///   2. Embedding the **`LoginFeature`** as a child reducer.
///   3. **Bubbling** the login success event up to the parent app reducer via `delegate`.
///
/// **Child Reducer Composition**:
/// TCA allows composing reducers in a tree. `OnboardingFeature` *owns* a `LoginFeature`
/// sub-state (`.login`) and forwards actions to it. This is analogous to Redux's
/// `combineReducers` or nesting Python state machines.
///
/// **Timer pattern with `ContinuousClock`**:
/// Instead of `DispatchQueue` or `Timer.publish`, TCA uses its `@Dependency(\.continuousClock)`
/// to create an `AsyncStream`-like timer. This makes timers:
///   - **Testable**: inject a `TestClock` that you advance manually in tests.
///   - **Cancellable**: tied to a string ID; cancel by ID from any action.
///   - **Composable**: cancellable effects integrate cleanly with the reducer's `Effect` system.
///
/// **Python analogy for the timer**: Like `asyncio.create_task(ticker())` where `ticker`
/// is an `async def` that yields every 3 seconds, and you can `task.cancel()` it at will.
@Reducer
struct OnboardingFeature {

  // MARK: State
  /// The observable state for the onboarding screen.
  ///
  /// `@ObservableState` wraps all `var` properties with `Observation` framework tracking.
  /// SwiftUI views re-render only for the specific properties they read – fine-grained
  /// reactivity superior to `@Published` (which re-renders the entire view on any change).
  @ObservableState
  struct State: Equatable {
    /// The 0-based index of the currently visible carousel slide.
    /// Drives the `TabView(selection:)` binding in the view.
    var currentIndex = 0

    /// **Deep link** state that was received *before* the user was authenticated.
    ///
    /// A deep link is a URL that should navigate the user to a specific in-app location
    /// (e.g. `astar://map/route/123`). When such a URL arrives while the user hasn't
    /// logged in yet, we can't act on it immediately. We store it here as "pending"
    /// and replay it once authentication succeeds.
    ///
    /// This is a common pattern in mobile apps:
    ///   1. App receives a push notification / universal link → parse into `DeepLink`.
    ///   2. If not logged in → store in `pendingDeepLink`.
    ///   3. After login → the parent reads `pendingDeepLink` and navigates accordingly.
    ///
    /// `nil` means no deep link is waiting.
    var pendingDeepLink: DeepLink? = nil

    /// Embedded state for the `LoginFeature` child reducer.
    /// TCA requires that parent state contain child state as a property.
    /// This enables the `Scope` reducer to route login-related actions correctly.
    var login: LoginFeature.State = .init()

    /// The ordered list of onboarding slides. Defined inline in `State` so that it is
    /// part of the snapshottable state (e.g. useful in tests to assert slide count).
    ///
    /// In production this is static content, but putting it in state means tests can
    /// inject different content without subclassing or global mutation.
    var contents: [OnboardingContent] = [
      OnboardingContent(
        title: "WalkGuard",
        body: .paragraph("Never feel alone. Trail keeps your trusted person updated in real time, so you can stay aware of your surroundings without checking your phone."),
        imageName: "figure.walk.motion"
      ),
      OnboardingContent(
        title: "Walker & Guardian",
        body: .glossary([
            GlossaryItem(term: "Walker", definition: "The person commuting on foot. Your journey is shared through your iPhone or Apple Watch."),
            GlossaryItem(term: "Companion", definition: "Your trusted person. You can assign your Companion in your profile so they can actively watch your journey and get notified when you arrive."),
        ]),
        imageName: "person.3.fill"
      ),
      OnboardingContent(
        title: "Default Place",
        body: .paragraph("Add frequent stops like Home or Work to your profile. This helps Trail instantly recognize your usual routes without manual typing."),
        imageName: "house.fill"
      )
    ]
  }

  // MARK: Action
  /// Every event that can happen during onboarding.
  ///
  /// Notice the three categories:
  ///   - **Lifecycle events**: `onAppear`, `onDisappear` (view lifecycle hooks from SwiftUI).
  ///   - **Timer events**: `timerTicked`, `setIndex` (internal pager logic).
  ///   - **Child & delegate**: `login(LoginFeature.Action)`, `delegate(Delegate)`.
  enum Action: Equatable {
    /// Fired when the onboarding view appears on screen. Starts the auto-advance timer.
    case onAppear
    /// Fired when the onboarding view disappears. Cancels the timer to avoid memory leaks.
    case onDisappear
    /// Fired by the clock every 3 seconds. Advances the carousel to the next slide.
    case timerTicked
    /// Fired when the user manually swipes to a slide or taps a page dot.
    /// Resets and restarts the auto-advance timer so the user gets a full 3 seconds
    /// on the slide they chose.
    case setIndex(Int)
    /// Routes any `LoginFeature.Action` to the child `LoginFeature` reducer.
    /// TCA's `Scope` reducer (in `body`) intercepts these and forwards them.
    case login(LoginFeature.Action)
    /// Outbound event bubbled to the parent (e.g. `AppFeature`) when login succeeds.
    /// The parent listens for `.delegate(.loggedIn(_))` to switch away from onboarding.
    case delegate(Delegate)

    /// Delegate actions broadcast to the parent reducer.
    /// Using a nested `Delegate` enum is the idiomatic TCA pattern to distinguish
    /// "outbound" events from "internal" events in the same feature.
    enum Delegate: Equatable {
      /// Carries the authenticated `UserProfile` so the parent can store and use it.
      case loggedIn(UserProfile)
    }
  }

  // MARK: Dependency
  /// `@Dependency` is TCA's dependency injection mechanism – analogous to Python's
  /// dependency injection via function parameters or a DI container.
  ///
  /// `\.continuousClock` is a built-in TCA dependency that provides a clock.
  /// In production: uses the system wall clock.
  /// In tests: you inject a `TestClock` (controllable, instant) to advance time manually.
  ///
  /// **Why not use `Timer.publish` or `DispatchQueue.asyncAfter`?**
  /// Those are not testable – you'd have to `sleep()` in tests. `continuousClock` makes
  /// the timer a first-class, swappable dependency.
  @Dependency(\.continuousClock) var clock

  // MARK: Reducer Body
  var body: some Reducer<State, Action> {
    // `Scope` routes a *slice* of parent state/actions to a child reducer.
    // Here: every `.login(...)` action is forwarded to `LoginFeature()`, which
    // operates on `state.login`. This is TCA's equivalent of Redux's `combineReducers`
    // or Python's nested state machine delegation.
    //
    // `state: \.login` – key path to the child state property.
    // `action: \.login` – case path to the child action case.
    Scope(state: \.login, action: \.login) {
      LoginFeature()
    }

    // The `Reduce` runs *after* `Scope`, so the parent reducer can intercept and
    // react to actions that the child already processed (like `.delegate` events).
    Reduce { state, action in
      switch action {

      // -----------------------------------------------------------------------
      // MARK: .onAppear
      // -----------------------------------------------------------------------
      // Start the auto-advance timer when the view appears.
      //
      // `clock.timer(interval: .seconds(3))` returns an `AsyncStream<Void>` that
      // emits values every 3 seconds indefinitely. `for await _ in ...` is Swift's
      // equivalent of `async for _ in async_generator()` in Python's asyncio.
      //
      // `.cancellable(id:cancelInFlight:)` attaches a string ID to this effect.
      // - `cancelInFlight: true` cancels any previously running effect with the same ID
      //   before starting this one. This prevents duplicate timers if `onAppear` fires
      //   more than once (e.g. due to SwiftUI sheet re-presentation).
      case .onAppear:
        return .run { send in
          for await _ in await self.clock.timer(interval: .seconds(3)) {
            await send(.timerTicked)
          }
        }
        .cancellable(id: "cancel_timer", cancelInFlight: true)

      // -----------------------------------------------------------------------
      // MARK: .onDisappear
      // -----------------------------------------------------------------------
      // Cancel the running timer effect by its ID. Without this, the timer would
      // keep ticking (and potentially crash) after the view is removed from the
      // hierarchy. This is analogous to `task.cancel()` in Python asyncio.
      case .onDisappear:
        return .cancel(id: "cancel_timer")

      // -----------------------------------------------------------------------
      // MARK: .timerTicked
      // -----------------------------------------------------------------------
      // Advance the carousel index by 1, wrapping around via modulo arithmetic.
      // If there are 3 slides (indices 0,1,2) and currentIndex is 2:
      //   (2 + 1) % 3 == 0  → wraps back to slide 0.
      // This creates an infinite looping carousel.
      case .timerTicked:
        state.currentIndex = (state.currentIndex + 1) % state.contents.count
        return .none

      // -----------------------------------------------------------------------
      // MARK: .setIndex
      // -----------------------------------------------------------------------
      // User manually navigated to a specific slide. We:
      //   1. Update `currentIndex` immediately (synchronous state mutation).
      //   2. Cancel the existing auto-advance timer (so we don't skip the slide).
      //   3. Restart the timer from zero (giving a fresh 3-second window on the new slide).
      //
      // `.concatenate` runs effects sequentially: first cancel, then restart.
      // This guarantees the old timer is killed *before* the new one starts.
      // (Contrast with `.merge`, which would run them concurrently.)
      case let .setIndex(index):
        state.currentIndex = index
        return .concatenate(
          .cancel(id: "cancel_timer"),
          .run { send in
            for await _ in await self.clock.timer(interval: .seconds(3)) {
              await send(.timerTicked)
            }
          }
          .cancellable(id: "cancel_timer", cancelInFlight: true)
        )

      // -----------------------------------------------------------------------
      // MARK: .login(.delegate(.loggedIn))
      // -----------------------------------------------------------------------
      // Intercept the child (`LoginFeature`) delegate event and re-emit it as *our*
      // own delegate event. This is the "delegate bubbling" pattern in TCA:
      //
      //   LoginFeature emits `.delegate(.loggedIn(profile))`
      //     → OnboardingFeature catches it here
      //     → OnboardingFeature re-emits `.delegate(.loggedIn(profile))`
      //     → AppFeature (parent) catches it and switches to the main map screen.
      //
      // This pattern keeps each feature self-contained: `LoginFeature` doesn't know
      // about `AppFeature`; it just emits events to its direct parent (`OnboardingFeature`).
      // Python analogy: like an event propagating up a chain of event listeners.
      case let .login(.delegate(.loggedIn(profile))):
        return .send(.delegate(.loggedIn(profile)))

      // -----------------------------------------------------------------------
      // MARK: .login (all other login actions)
      // -----------------------------------------------------------------------
      // All other `LoginFeature.Action`s have already been handled by the `Scope` reducer
      // above. The parent has nothing more to do with them, so we return `.none`.
      case .login:
        return .none

      // -----------------------------------------------------------------------
      // MARK: .delegate
      // -----------------------------------------------------------------------
      // Delegate actions are outbound-only; the reducer itself does nothing with them.
      // The parent reducer will intercept them via its own `switch` block.
      case .delegate:
        return .none
      }
    }
  }
}
