//
//  SavedPlacesView.swift
//  Astar
//
//  Created by Safa Auliya Hidayat on 27/08/26.
//

import ComposableArchitecture
import CoreLocation
import SwiftUI

struct SavedPlacesView: View {
    @Bindable var store: StoreOf<SavedPlacesFeature>
    @Environment(\.dismiss) private var dismiss

    let columns = [
        GridItem(.adaptive(minimum: 90, maximum: 110), spacing: 20, alignment: .top)
    ]

    var body: some View {
        WithPerceptionTracking {
            ZStack {
                Color.white
                    .ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 28) {
                        // Title & Subtitle
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Places")
                                .font(.system(size: 34, weight: .bold))
                                .foregroundStyle(.primary)

                            Text("Add places you visit often")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.top, 8)

                        // Circular Icons Grid (Screen 1 & 4)
                        LazyVGrid(columns: columns, spacing: 28) {
                            // 1. Home Item
                            CircularPlaceCard(
                                title: store.homePlace?.label ?? store.homePlace?.name ?? "Home",
                                subtitle: "Change",
                                iconName: "house.fill",
                                categoryColor: Color(red: 0.15, green: 0.75, blue: 0.85),
                                onAction: {
                                    if let home = store.homePlace {
                                        store.send(.changeLocationTapped(home, .home))
                                    } else {
                                        store.send(.addPlaceButtonTapped(.home))
                                    }
                                }
                            )

                            // 2. Office Item
                            CircularPlaceCard(
                                title: store.officePlace?.label ?? store.officePlace?.name ?? "Office",
                                subtitle: "Change",
                                iconName: "briefcase.fill",
                                categoryColor: Color(red: 0.65, green: 0.48, blue: 0.35),
                                onAction: {
                                    if let office = store.officePlace {
                                        store.send(.changeLocationTapped(office, .office))
                                    } else {
                                        store.send(.addPlaceButtonTapped(.office))
                                    }
                                }
                            )

                            // 3. Custom Places (Golden yellow circles with map pin icon)
                            ForEach(store.customPlaces) { place in
                                CircularPlaceCard(
                                    title: place.label ?? place.name,
                                    subtitle: "Change",
                                    iconName: place.resolvedIconName,
                                    categoryColor: place.categoryColor,
                                    onAction: {
                                        store.send(.changeLocationTapped(place, .custom))
                                    },
                                    contextMenu: {
                                        Button(role: .destructive) {
                                            store.send(.deletePlaceById(place.id))
                                        } label: {
                                            Label("Delete Place", systemImage: "trash")
                                        }
                                    }
                                )
                            }

                            // 4. Add Button (Light blue circle with blue +, no subtitle)
                            VStack(spacing: 8) {
                                Button {
                                    store.send(.addPlaceButtonTapped(.custom))
                                } label: {
                                    Circle()
                                        .fill(Color(red: 0.88, green: 0.95, blue: 1.0))
                                        .frame(width: 80, height: 80)
                                        .overlay {
                                            Image(systemName: "plus")
                                                .font(.system(size: 32, weight: .medium))
                                                .foregroundStyle(Color(red: 0.00, green: 0.55, blue: 0.95))
                                        }
                                }
                                .buttonStyle(.plain)

                                Text("Add")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.primary)
                                    .lineLimit(1)
                            }
                        }

                        Spacer()
                    }
                    .padding(.horizontal, 20)
                }
            }
            .navigationBarBackButtonHidden(true)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "chevron.left")
                            .font(.body.weight(.semibold))
                            .foregroundStyle(.primary)
                            .frame(width: 36, height: 36)
                            .background(Color.primary.opacity(0.06), in: Circle())
                    }
                }
            }
            .sheet(isPresented: Binding(
                get: { store.isAddingPlace },
                set: { isPresented in
                    if !isPresented {
                        store.send(.dismissAddSheetTapped)
                    }
                }
            )) {
                NavigationStack {
                    PinPlaceSheet(store: store)
                }
            }
            .onAppear {
                store.send(.onAppear)
            }
        }
    }
}

// MARK: - Circular Place Card Component
private struct CircularPlaceCard<MenuContent: View>: View {
    let title: String
    let subtitle: String?
    let iconName: String
    let categoryColor: Color
    let onAction: () -> Void
    @ViewBuilder let contextMenu: () -> MenuContent

    init(
        title: String,
        subtitle: String? = nil,
        iconName: String,
        categoryColor: Color,
        onAction: @escaping () -> Void,
        @ViewBuilder contextMenu: @escaping () -> MenuContent = { EmptyView() }
    ) {
        self.title = title
        self.subtitle = subtitle
        self.iconName = iconName
        self.categoryColor = categoryColor
        self.onAction = onAction
        self.contextMenu = contextMenu
    }

    var body: some View {
        Button(action: onAction) {
            VStack(spacing: 6) {
                Circle()
                    .fill(categoryColor)
                    .frame(width: 80, height: 80)
                    .overlay {
                        Image(systemName: iconName.isEmpty || iconName == "mappin.and.ellipse" ? "mappin.fill" : iconName)
                            .font(.system(size: 34, weight: .semibold))
                            .foregroundStyle(.white)
                    }

                VStack(spacing: 2) {
                    Text(title)
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                        .multilineTextAlignment(.center)

                    if let subtitle = subtitle {
                        Text(subtitle)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .buttonStyle(.plain)
        .contextMenu(menuItems: contextMenu)
    }
}

// MARK: - Figma "Pin Place" Sheet Component (Screens 2 & 3)
private struct PinPlaceSheet: View {
    @Bindable var store: StoreOf<SavedPlacesFeature>
    @FocusState private var isSearchFocused: Bool
    @FocusState private var isNameFocused: Bool

    private var searchTextBinding: Binding<String> {
        Binding(
            get: { store.searchQuery },
            set: { store.send(.searchQueryChanged($0)) }
        )
    }

    private var displayedPlaces: [SavedPlace] {
        store.searchResults
    }

    private var categoryColor: Color {
        if let preset = store.targetPresetForAdd {
            switch preset {
            case .home: return Color(red: 0.15, green: 0.75, blue: 0.85)
            case .office: return Color(red: 0.65, green: 0.48, blue: 0.35)
            case .custom:
                if let selected = store.selectedPlaceForLabel {
                    return selected.categoryColor
                }
                return Color(red: 0.98, green: 0.78, blue: 0.12)
            }
        }
        if store.customLabel.lowercased() == "home" {
            return Color(red: 0.15, green: 0.75, blue: 0.85)
        } else if store.customLabel.lowercased() == "office" || store.customLabel.lowercased() == "work" {
            return Color(red: 0.65, green: 0.48, blue: 0.35)
        }
        if let selected = store.selectedPlaceForLabel {
            return selected.categoryColor
        }
        return Color(red: 0.98, green: 0.78, blue: 0.12)
    }

    private var categoryIcon: String {
        if let preset = store.targetPresetForAdd {
            switch preset {
            case .home: return "house.fill"
            case .office: return "briefcase.fill"
            case .custom:
                if let selected = store.selectedPlaceForLabel {
                    return selected.resolvedIconName
                }
                return "mappin.fill"
            }
        }
        if store.customLabel.lowercased() == "home" {
            return "house.fill"
        } else if store.customLabel.lowercased() == "office" || store.customLabel.lowercased() == "work" {
            return "briefcase.fill"
        }
        if let selected = store.selectedPlaceForLabel {
            return selected.resolvedIconName
        }
        return "mappin.fill"
    }

    var body: some View {
        WithPerceptionTracking {
            VStack(spacing: 0) {
                if store.pinStep == .chooseLocation {
                    // SCREEN 2: "Choose Home/Office Location"
                    VStack(spacing: 16) {
                        // Search Bar
                        ActiveSearchBarView(
                            searchText: searchTextBinding,
                            isFocused: $isSearchFocused
                        )
                        .padding(.horizontal, 16)
                        .padding(.top, 8)

                        if store.isLoading && store.searchResults.isEmpty {
                            VStack(spacing: 12) {
                                ProgressView()
                                    .padding(.top, 24)
                                Text("Searching places...")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                            .frame(maxWidth: .infinity)
                            Spacer()
                        } else if !displayedPlaces.isEmpty {
                            // Search Results List Card with Landmark Red Pin Icons
                            ScrollView {
                                VStack(spacing: 0) {
                                    ForEach(displayedPlaces) { place in
                                        Button {
                                            store.send(.selectPlaceSearchResult(place))
                                            isSearchFocused = false
                                        } label: {
                                            HStack(spacing: 14) {
                                                Circle()
                                                    .fill(place.categoryColor)
                                                    .frame(width: 36, height: 36)
                                                    .overlay {
                                                        Image(systemName: place.resolvedIconName)
                                                            .font(.system(size: 18, weight: .semibold))
                                                            .foregroundStyle(.white)
                                                    }

                                                VStack(alignment: .leading, spacing: 2) {
                                                    Text(place.name)
                                                        .font(.subheadline.weight(.semibold))
                                                        .foregroundStyle(.primary)

                                                    Text(formattedSubtitle(for: place))
                                                        .font(.caption)
                                                        .foregroundStyle(.secondary)
                                                        .lineLimit(1)
                                                }

                                                Spacer()
                                            }
                                            .padding(.horizontal, 16)
                                            .padding(.vertical, 12)
                                        }
                                        .buttonStyle(.plain)

                                        if place.id != displayedPlaces.last?.id {
                                            Divider()
                                                .padding(.leading, 66)
                                        }
                                    }
                                }
                                .background(Color.white, in: .rect(cornerRadius: 18))
                                .overlay {
                                    RoundedRectangle(cornerRadius: 18)
                                        .stroke(Color.primary.opacity(0.06), lineWidth: 1)
                                }
                                .padding(.horizontal, 16)
                                .padding(.bottom, 20)
                            }
                        } else {
                            Spacer()
                        }
                    }
                } else {
                    // SCREEN 3: "Rename home if you want to"
                    VStack(alignment: .leading, spacing: 16) {
                        VStack(alignment: .leading, spacing: 14) {
                            // Top Section: Category Circle + Rename TextField
                            HStack(spacing: 12) {
                                Circle()
                                    .fill(categoryColor)
                                    .frame(width: 36, height: 36)
                                    .overlay {
                                        Image(systemName: categoryIcon)
                                            .font(.system(size: 18, weight: .semibold))
                                            .foregroundStyle(.white)
                                    }

                                TextField("Home", text: $store.customLabel.sending(\.customLabelChanged))
                                    .font(.headline.weight(.semibold))
                                    .textFieldStyle(.plain)
                                    .focused($isNameFocused)
                            }

                            Divider()

                            // Bottom Section: Selected Location Name & Address
                            VStack(alignment: .leading, spacing: 3) {
                                Text(store.selectedPlaceForLabel?.name ?? "")
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(.primary)

                                Text(store.selectedPlaceForLabel?.subtitle ?? "")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(2)
                            }
                        }
                        .padding(16)
                        .background(Color.white, in: .rect(cornerRadius: 18))
                        .overlay {
                            RoundedRectangle(cornerRadius: 18)
                                .stroke(Color.primary.opacity(0.06), lineWidth: 1)
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 12)

                        Spacer()
                    }
                }
            }
            .background(Color(red: 0.96, green: 0.96, blue: 0.98).ignoresSafeArea())
            .navigationTitle("Pin Place")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    if store.pinStep == .renamePlace {
                        Button {
                            store.send(.backToChooseLocationTapped)
                        } label: {
                            Image(systemName: "chevron.left")
                                .font(.body.weight(.semibold))
                                .foregroundStyle(.primary)
                                .frame(width: 32, height: 32)
                                .background(Color.primary.opacity(0.06), in: Circle())
                        }
                    } else {
                        Button("Cancel") {
                            store.send(.dismissAddSheetTapped)
                        }
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    if store.pinStep == .renamePlace {
                        Button {
                            store.send(.confirmSavePlace)
                        } label: {
                            Circle()
                                .fill(Color(red: 0.00, green: 0.55, blue: 0.95))
                                .frame(width: 32, height: 32)
                                .overlay {
                                    Image(systemName: "checkmark")
                                        .font(.system(size: 16, weight: .bold))
                                        .foregroundStyle(.white)
                                }
                        }
                    } else if let first = displayedPlaces.first {
                        Button {
                            store.send(.selectPlaceSearchResult(first))
                        } label: {
                            Circle()
                                .fill(Color(red: 0.00, green: 0.55, blue: 0.95))
                                .frame(width: 32, height: 32)
                                .overlay {
                                    Image(systemName: "checkmark")
                                        .font(.system(size: 16, weight: .bold))
                                        .foregroundStyle(.white)
                                }
                        }
                    }
                }
            }
            .onAppear {
                if store.pinStep == .chooseLocation {
                    isSearchFocused = true
                } else {
                    isNameFocused = true
                }
            }
        }
    }

    private func formattedSubtitle(for place: SavedPlace) -> String {
        if let distance = place.distance, !distance.isEmpty {
            return "\(distance) • \(place.subtitle)"
        }
        return place.subtitle
    }
}
