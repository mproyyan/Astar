//
//  BroadcastInfoSheet.swift
//  Astar
//
//  Created by Safa Auliya Hidayat on 03/09/26.
//

import SwiftUI

// MARK: - BroadcastInfoSheet
/// A bottom sheet that confirms to the user that their journey has been broadcast
/// to their trusted contacts.
///
/// **What is a "bottom sheet"?**
/// A bottom sheet is a panel that slides up from the bottom edge of the screen,
/// partially covering the content below. In UIKit this was done with
/// `UISheetPresentationController`; in SwiftUI it is rendered by presenting
/// this view inside a `.sheet()` modifier with `presentationDetents` controlling height.
///
/// **This view is purely presentational** (no TCA store, no state).
/// It receives no input and emits no actions – it only renders static confirmation text.
/// In TCA parlance this is a "leaf view" or "dumb component" (like a React presentational
/// component). The parent decides *when* to show/dismiss it.
///
/// **Layout overview**:
/// ```
/// VStack (spacing: 16)
///   ├── ZStack (icon badge)
///   │     ├── Circle (blue tinted background)
///   │     └── checkmark (SF Symbol)
///   ├── VStack (text block)
///   │     ├── Title text
///   │     └── Subtitle text
///   └── Spacer
/// ```
struct BroadcastInfoSheet: View {
    var body: some View {
        // `VStack(spacing: 16)` stacks children vertically with 16 pt gaps.
        // The entire sheet content lives here.
        VStack(spacing: 16) {

            // MARK: Icon Badge
            // `ZStack` layers views on top of each other (z-axis stacking, like CSS `position: absolute`).
            // Layer 1 (bottom): a translucent blue `Circle` as the icon's background badge.
            // Layer 2 (top): the SF Symbol checkmark centered over the circle.
            ZStack {
                Circle()
                    // `.fill(Color.blue.opacity(0.12))` – a very light blue tint (12% opacity).
                    // This creates a "badge" effect: a colored disc behind the icon.
                    .fill(Color.blue.opacity(0.12))
                    // `.frame(width:height:)` fixes the circle to 56×56 pt.
                    // In SwiftUI, pt (points) are resolution-independent (like CSS `px` / `dp`).
                    .frame(width: 56, height: 56)

                Image(systemName: "checkmark")
                    // `.font(.system(size: 24, weight: .semibold))` – for SF Symbols, font size
                    // controls icon scale. `.semibold` makes the strokes slightly thicker.
                    .font(.system(size: 24, weight: .semibold))
                    // `.foregroundStyle(.blue)` – sets the icon stroke color.
                    .foregroundStyle(.blue)
            }
            // `.accessibilityHidden(true)` – instructs VoiceOver (Apple's screen reader) to
            // skip this icon entirely. It's purely decorative; the text below provides the
            // full accessible description. Analogous to `aria-hidden="true"` in HTML.
            .accessibilityHidden(true)
            // `.padding(.top, 24)` – adds 24 pt of space above the icon badge,
            // giving breathing room from the drag indicator at the top of the sheet.
            .padding(.top, 24)

            // MARK: Text Block
            VStack(spacing: 8) {
                // Primary (title) text: bold, title3 size, centered.
                Text("Your journey has been broadcast")
                    // `.title3` is the 4th largest in SwiftUI's Dynamic Type scale.
                    // Dynamic Type respects the user's preferred font size in Accessibility settings.
                    .font(.title3.weight(.bold))
                    .foregroundStyle(.primary)   // adaptive: black in light mode, white in dark mode
                    .multilineTextAlignment(.center)
                    // `.accessibilityLabel` provides an explicit VoiceOver label.
                    // Here it matches the text content, so it's redundant – but explicit labeling
                    // is a good practice for UI components that might have icon-only contexts.
                    .accessibilityLabel("Your journey has been broadcast")

                // Secondary (subtitle) text: smaller, gray, wraps to multiple lines.
                Text("Your trusted contacts can now see your journey and help keep you safe along the way.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)  // system gray, adapts to dark mode
                    .multilineTextAlignment(.center)
                    // `.fixedSize(horizontal: false, vertical: true)` – allows the text to grow
                    // *vertically* to fit its full content, while staying constrained horizontally.
                    // Without this, SwiftUI might clip or truncate the text in some layout contexts.
                    // Python analogy: like setting `max-width` but `height: auto` in CSS.
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityLabel("Your trusted contacts can now see your journey and help keep you safe along the way.")
            }
            // `.accessibilitySortPriority(1)` – when VoiceOver reads elements, higher priority
            // elements are read first. Priority 1 > 0 (default), so this text block is read
            // before other elements at default priority (like the icon above).
            .accessibilitySortPriority(1)
            // `.accessibilityElement(children: .combine)` – merges the title and subtitle into
            // a single VoiceOver element. The reader reads both texts in one swipe, which is
            // a better UX than navigating each `Text` separately.
            .accessibilityElement(children: .combine)
            .padding(.horizontal, 24)

            // `Spacer(minLength: 16)` fills remaining vertical space, but guarantees at
            // least 16 pt of space. This pushes text up and away from the sheet's bottom edge.
            Spacer(minLength: 16)
        }
        // `.padding(.bottom, 16)` adds space between the Spacer and the home indicator.
        .padding(.bottom, 16)

        // MARK: Sheet Presentation Modifiers
        // These modifiers configure how this view behaves when presented as a `.sheet()`.
        // They must be applied to the *content* view itself, not the parent that presents it.

        // `.presentationDetents` defines the allowed heights ("stops") of the sheet.
        // `.height(240)` fixes the sheet to exactly 240 pt tall – a compact confirmation sheet.
        // For comparison, `.medium` is ~50% screen height, `.large` is ~100%.
        .presentationDetents([.height(240)])

        // `.presentationDragIndicator(.visible)` shows the standard drag handle (a rounded
        // gray pill) at the top of the sheet. It signals to the user that the sheet is
        // dismissible by dragging down.
        .presentationDragIndicator(.visible)

        // `.presentationCornerRadius(28)` rounds the top corners of the sheet with a 28 pt
        // radius, matching Apple's native sheet design language (introduced iOS 16+).
        .presentationCornerRadius(28)
    }
}

// MARK: - Preview
/// Xcode Canvas preview that simulates a sheet presentation.
/// `.sheet(isPresented: .constant(true))` keeps the sheet permanently visible in the preview
/// so we can inspect the layout without navigating through the app flow.
/// `.constant(true)` creates a non-writable `Binding<Bool>` that is always `true`.
#Preview {
    Text("Map View Background")
        .sheet(isPresented: .constant(true)) {
            BroadcastInfoSheet()
        }
}
