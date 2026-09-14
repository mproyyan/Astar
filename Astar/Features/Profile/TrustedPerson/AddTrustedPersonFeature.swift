import ComposableArchitecture
import Foundation

// MARK: - AddTrustedPersonFeature
//
// This TCA Reducer manages the "Add Trusted Person" flow, where a user types
// one or more iCloud email addresses and confirms them to send connection requests.
//
// TCA Reducer overview (Python analogy):
//   A Reducer is a PURE FUNCTION: (State, Action) → (State, Effect)
//   Like `reduce()` in Python: it takes the current accumulator (State) and
//   the next event (Action) and returns a new accumulator (State).
//   Side-effects (network calls, navigation) are returned as `Effect` values —
//   they never happen inside the reducer body itself.

// `@Reducer` macro generates boilerplate (Equatable conformances, body wiring, etc.)
// and registers this struct as a TCA feature.
@Reducer
struct AddTrustedPersonFeature {

  // MARK: State
  //
  // `State` is a plain value type (struct) that fully represents the UI's data model.
  // Swift structs are VALUE TYPES — every assignment copies the value (like Python
  // namedtuples or dataclasses with `frozen=True`). This makes mutation predictable:
  // the reducer always creates a fresh copy of State; nothing mutates "in place" from
  // outside.
  //
  // `@ObservableState` (TCA macro) makes every property observable so SwiftUI knows
  // which views to re-render when a property changes — similar to MobX observables
  // or Vue's reactive() system.
  @ObservableState
  struct State: Equatable {
      /// The list of valid email addresses the user has confirmed so far.
      /// Displayed as "chips" (pill-shaped tags) in the UI.
      var addedEmails: [String] = []

      /// The text currently typed in the input field but NOT yet committed.
      /// Think of it as the "in-flight" draft — like a textarea's current value
      /// in a React controlled component before `onSubmit`.
      var draft: String = ""

      /// When `true`, shows an inline error hint telling the user the email is invalid.
      /// Toggled by the reducer after validating `draft`.
      var showInvalidHint: Bool = false
  }

  // MARK: Action
  //
  // `Action` is an enum (Algebraic Data Type / Sum Type) listing every possible
  // event that can occur in this feature. Swift enums with associated values are
  // like Python tagged unions or sealed classes in Kotlin.
  //
  // Rule: ONLY the Reducer reacts to Actions. Views just "fire and forget" them.
  enum Action: Equatable {
      /// Fired on every keystroke in the email field. Carries the full new string.
      case draftChanged(String)

      /// Triggered when the user presses the Return key or types a space/comma —
      /// signals intent to "lock in" the current draft as a chip.
      case commitDraft

      /// Removes a previously added email chip by value.
      case removeEmail(String)

      /// User taps the confirm button — all current chips plus the draft are submitted.
      case commitSelection

      // MARK: Delegate Actions
      //
      // The `delegate` action is TCA's preferred communication pattern for a
      // CHILD feature to notify its PARENT without tight coupling.
      //
      // Analogy (Python): imagine the child feature calls `parent.on_event(data)`
      // but instead of holding a direct reference to the parent, it emits a
      // `.delegate(...)` action that the parent's reducer "intercepts" through
      // a `.forEach` / `.ifLet` scope. This is the Observer / Event Bus pattern
      // but enforced at compile time.
      case delegate(Delegate)

      /// Sub-enum for events this feature reports UP to its parent reducer.
      enum Delegate: Equatable {
          /// Emitted after the user confirms selection; carries the final list of emails.
          case didAddPersons([String])
      }
  }

  // MARK: Dependencies
  //
  // `@Dependency` is TCA's dependency injection mechanism.
  // `\.dismiss` is a built-in TCA dependency that programmatically dismisses
  // the current sheet/modal. It wraps SwiftUI's `@Environment(\.dismiss)` in a
  // thread-safe, testable wrapper so the reducer (which runs on any thread) can
  // trigger dismissal safely without touching the view layer.
  @Dependency(\.dismiss) var dismiss

  // MARK: Reducer Body
  //
  // `body` is where the state-mutation logic lives. `Reduce` takes a closure
  // `(inout State, Action) -> Effect<Action>`.
  //
  // `inout State` means the state is passed BY REFERENCE into the closure so
  // you can mutate it directly — Swift's version of a mutable parameter.
  // Under the hood TCA still treats state as a value type (copy-on-write).
  var body: some Reducer<State, Action> {
    Reduce { state, action in
      switch action {

      // When the user types a character, update the draft and check whether
      // they typed a delimiter (space or comma) that should auto-commit it.
      case let .draftChanged(draft):
          state.draft = draft
          if let last = draft.last, last == " " || last == "," {
              // Auto-commit when delimiter detected — return a new Effect
              // that sends `.commitDraft` back into the reducer.
              // `.send` is a fire-and-forget Effect with no async work.
              return .send(.commitDraft)
          } else {
              state.showInvalidHint = false
              return .none // No side-effect needed
          }

      // Validate the draft string against an email regex and either
      // add it to the chip list or show the invalid hint.
      case .commitDraft:
          // Strip surrounding whitespace and comma delimiters from the draft.
          let candidate = state.draft.trimmingCharacters(in: CharacterSet.whitespaces.union(CharacterSet(charactersIn: ",")))
          guard !candidate.isEmpty else { return .none }

          // RFC-5321 simplified email regex. `#"..."#` is Swift's raw string literal
          // (equivalent to Python's `r"..."` — no need to escape backslashes).
          let regex = #"^[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$"#
          let isValid = candidate.range(of: regex, options: .regularExpression) != nil

          if isValid {
              // Deduplicate: only append if not already present.
              if !state.addedEmails.contains(candidate) {
                  state.addedEmails.append(candidate)
              }
              state.draft = ""
              state.showInvalidHint = false
          } else {
              state.showInvalidHint = true
          }
          return .none

      // Remove a chip by its email string value.
      // `removeAll(where:)` is like Python's list comprehension:
      //   `added_emails = [e for e in added_emails if e != email]`
      case let .removeEmail(email):
          state.addedEmails.removeAll { $0 == email }
          return .none

      // The user confirms their selection. This is an ASYNC effect:
      //   1. Notify the parent reducer (via `.delegate`) with the final email list.
      //   2. Dismiss the modal sheet.
      //
      // `.run { send in ... }` spawns a Swift structured-concurrency Task.
      // Python analogy: `asyncio.create_task(coroutine())` — runs concurrently
      // without blocking the caller, but is lifecycle-managed by TCA.
      case .commitSelection:
          let emails = state.addedEmails
          return .run { send in
              // `await send(...)` dispatches actions back to the store from
              // inside the async closure — thread-safe by design.
              await send(.delegate(.didAddPersons(emails)))
              // `dismiss()` tells SwiftUI to pop/dismiss this screen.
              // It must be awaited because it posts to the main run loop.
              await self.dismiss()
          }

      // The `.delegate` case is handled by the PARENT reducer (TrustedPersonFeature).
      // This feature's own reducer does nothing with it — the action is just a
      // "pass-through" message aimed at the ancestor.
      case .delegate:
          return .none
      }
    }
  }
}
