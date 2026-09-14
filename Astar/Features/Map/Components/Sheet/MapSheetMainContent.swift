//
//  MapSheetMainContent.swift
//  Astar
//
//  Created by Dimas Prihady Setyawan on 25/08/26.
//

import ComposableArchitecture
import SwiftUI

// MARK: - MapSheetMainContent
/// The main content rendered inside the map's bottom sheet when it is in its "home" state
/// (i.e. showing the search bar, nearby people, and saved places – not a search result).
///
/// **Architectural role**:
/// This is a **stateless presentational component** (in React terminology). It receives
/// all its data through properties and delegates all user interactions via callbacks.
/// It does not own a TCA store of its own – it reads data from the passed-in `store`
/// and exposes closures for user-initiated events. This design:
///   - Keeps the component reusable and easy to preview.
///   - Keeps business logic in the `MainFeature` reducer, not in the view.
///   - Follows the "props down, events up" pattern (identical to React's unidirectional flow).
///
/// **Callback properties** (analogous to Python callbacks or JS event handlers):
/// These are optional `(() -> Void)?` closures (functions with no arguments and no return value).
/// `nil` means no handler is attached – useful for previews or scenarios where a section
/// doesn't need to respond to a particular event.
///
/// **Layout overview**:
/// ```
/// WithPerceptionTracking
///   └── VStack (leading, spacing 20)
///         ├── HStack (search bar + profile button)
///         └── VStack (spacing 32)
///               ├── PeopleSection
///               └── SavedSection (with enter/exit transition)
/// ```
struct MapSheetMainContent: View {
    /// The TCA store for `MainFeature`. This view reads from it but does NOT dispatch
    /// actions to it directly – user events are surfaced via the callback closures below.
    /// Reading from `store.people`, `store.map.savedPlaces`, etc., automatically registers
    /// this view as an observer of those specific properties (via `Observation`/`Perception`).
    let store: StoreOf<MainFeature>

    /// Whether the containing bottom sheet is in its expanded state.
    /// Not currently used to conditionally render content in this file (the name suggests
    /// it may affect child subviews or future layout changes).
    let isExpanded: Bool

    /// Called when the user taps the search bar. The parent handles navigation to the
    /// search screen. Using a callback rather than dispatching an action directly keeps
    /// this view decoupled from `MainFeature.Action`.
    let onSearchTapped: () -> Void

    /// Called when the user selects a saved place from the list.
    /// Optional (`?`) because not all presentation contexts need place selection (e.g. previews).
    var onSelectPlace: ((SavedPlace) -> Void)? = nil

    /// Called when the user taps a person in the people section.
    var onSelectPerson: ((Person) -> Void)? = nil

    /// Called when the user taps the "Saved Places" section header (e.g. to navigate to
    /// a full saved-places management screen).
    var onSavedPlacesHeaderTapped: (() -> Void)? = nil

    /// Called when the user taps the profile avatar button in the top-right corner.
    var onProfileTapped: (() -> Void)? = nil

    // MARK: Derived Data (computed properties)
    // These private computed properties extract specific slices of store state.
    // They centralise property access so individual UI components don't need to
    // know about the full store structure.
    //
    // **Why computed instead of stored?** Computed properties are re-evaluated every
    // time the view renders, so they always reflect the latest store state without
    // manual synchronisation. In Python terms: think of these as `@property` accessors
    // on a class that delegates to an underlying data source.

    /// The list of people (contacts/companions) to display.
    private var people: [Person] { store.people }

    /// The list of saved places (Home, Work, etc.) to display.
    private var savedPlaces: [SavedPlace] { store.map.savedPlaces }

    /// `true` while the people list is being fetched (drives a loading skeleton/spinner).
    private var isPeopleLoading: Bool { store.isPeopleLoading }

    // MARK: Body
    var body: some View {
        // `WithPerceptionTracking` is a TCA/Perception compatibility wrapper.
        // It ensures the view body is re-evaluated whenever any `store` property read
        // *inside* this closure changes, even on iOS 16 / macOS 13 where Swift's native
        // `Observation` framework isn't available.
        //
        // Think of it as: "track all store property accesses inside this block and
        // re-render when any of them change". On iOS 17+ it's a no-op (native Observation
        // handles it automatically).
        WithPerceptionTracking {
            // `VStack(alignment: .leading, spacing: 20)` stacks children vertically,
            // left-aligning them (like `align-items: flex-start` in CSS Flexbox).
            VStack(alignment: .leading, spacing: 20) {

            // MARK: Top Bar (Search + Profile)
            // A horizontal row with the search bar on the left and the profile avatar button
            // on the right. `HStack(spacing: 12)` is like `display: flex; gap: 12px`.
            HStack(spacing: 12) {
                // `Button(action:)` wraps `SearchBarView()` to make it tappable.
                // `.buttonStyle(.plain)` removes all default button decoration (no blue tint,
                // no pressed highlight beyond what `SearchBarView` itself applies).
                // Without `.plain`, SwiftUI would apply the default `.bordered` or similar
                // style, which could clash with the custom search bar design.
                Button(action: onSearchTapped) {
                    SearchBarView()
                }
                .buttonStyle(.plain)

                // `ProfileButton` is a separate component that shows the user's avatar and
                // handles the tap via a callback passed from this view down to the component.
                ProfileButton(store: store)
            }
            // `.padding(.top, 8)` – nudge the top bar down slightly from the sheet's drag handle.
            .padding(.top, 8)

            // MARK: Content Sections
            // A nested VStack with larger spacing (32 pt) between the two major sections.
            VStack(spacing: 32) {
                // `PeopleSection` renders the horizontal scrollable list of companions/contacts.
                // This is a pure presentational subcomponent – receives data and callbacks,
                // emits nothing upward.
                PeopleSection(
                    people: people,
                    isLoading: isPeopleLoading,
                    onSelectPerson: onSelectPerson,
                    onProfileTapped: onProfileTapped
                )

                // `SavedSection` renders saved places (Home, Work, custom pins).
                // `.transition(...)` defines the animation played when this view is added
                // to or removed from the view hierarchy (e.g. when the sheet expands/collapses
                // and this section appears or disappears).
                //
                // `.asymmetric(insertion:removal:)` lets you specify *different* animations
                // for enter vs. exit:
                //   - Insertion: fade in AND slide up from the bottom
                //     (`.opacity.combined(with: .move(edge: .bottom))`)
                //   - Removal: fade out only (`.opacity`)
                //
                // This asymmetry feels natural: elements "rise up" when they appear but
                // simply "fade away" when they leave, avoiding a jarring downward slide.
                SavedSection(
                    savedPlaces: savedPlaces,
                    onSelectPlace: onSelectPlace,
                    onHeaderTap: onSavedPlacesHeaderTapped
                )
                    .transition(.asymmetric(
                        insertion: .opacity.combined(with: .move(edge: .bottom)),
                        removal: .opacity
                    ))
            }

            // `Spacer(minLength: 0)` pushes the content to the top of the VStack.
            // `minLength: 0` means it can collapse to zero height if there is no extra space,
            // unlike the default `Spacer()` which has a platform-defined minimum (usually 8 pt).
            Spacer(minLength: 0)
        }
        // `.padding(.horizontal, 16)` adds 16 pt left and right margins to the whole content block.
        .padding(.horizontal, 16)
        // `.padding(.top, 12)` adds a small top inset to keep content from touching the sheet edge.
        .padding(.top, 12)
        }
    }
}

// MARK: - Preview
/// Xcode Canvas preview. Boots a real `MainFeature` store with default state.
/// `isExpanded: true` simulates the sheet in its expanded position.
/// `onSearchTapped: {}` provides an empty no-op closure to satisfy the non-optional parameter.
#Preview {
    MapSheetMainContent(
        store: Store(initialState: MainFeature.State()) {
            MainFeature()
        },
        isExpanded: true,
        onSearchTapped: {}
    )
}
