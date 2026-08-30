//
//  SavedPlacesView.swift
//  Astar
//
//  Created by Safa Auliya Hidayat on 27/08/26.
//

import ComposableArchitecture
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

                        // Circular Icons Grid
                        LazyVGrid(columns: columns, spacing: 28) {
                            // 1. Home Item
                            CircularPlaceCard(
                                title: store.homePlace?.name ?? "Set Home",
                                subtitle: store.homePlace != nil ? "Change" : "Set",
                                iconName: "house.fill",
                                categoryColor: Color(red: 0.15, green: 0.75, blue: 0.85)
                            ) {
                                if let home = store.homePlace {
                                    store.send(.editPlaceTapped(home, .home))
                                } else {
                                    store.send(.addPlaceButtonTapped(.home))
                                }
                            }

                            // 2. Office Item
                            CircularPlaceCard(
                                title: store.officePlace?.name ?? "Set Office",
                                subtitle: store.officePlace != nil ? "Change" : "Set",
                                iconName: "briefcase.fill",
                                categoryColor: Color(red: 0.65, green: 0.48, blue: 0.35)
                            ) {
                                if let office = store.officePlace {
                                    store.send(.editPlaceTapped(office, .office))
                                } else {
                                    store.send(.addPlaceButtonTapped(.office))
                                }
                            }

                            // 3. Custom Places (Yellow circles with key icon)
                            ForEach(store.customPlaces) { place in
                                CircularPlaceCard(
                                    title: place.name,
                                    subtitle: "Change",
                                    iconName: place.iconName.isEmpty ? "key.fill" : place.iconName,
                                    categoryColor: place.categoryColor
                                ) {
                                    store.send(.editPlaceTapped(place, .custom))
                                } contextMenu: {
                                    Button(role: .destructive) {
                                        store.send(.deletePlaceById(place.id))
                                    } label: {
                                        Label("Delete Place", systemImage: "trash")
                                    }
                                }
                            }

                            // 4. Add Button (Light cyan circle with blue +)
                            VStack(spacing: 8) {
                                Button {
                                    store.send(.addPlaceButtonTapped(nil))
                                } label: {
                                    Circle()
                                        .fill(Color(red: 0.88, green: 0.96, blue: 0.99))
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

// MARK: - Circular Place Card Component (Figma Design)
private struct CircularPlaceCard<MenuContent: View>: View {
    let title: String
    let subtitle: String
    let iconName: String
    let categoryColor: Color
    let action: () -> Void
    @ViewBuilder let contextMenu: () -> MenuContent

    init(
        title: String,
        subtitle: String,
        iconName: String,
        categoryColor: Color,
        action: @escaping () -> Void,
        @ViewBuilder contextMenu: @escaping () -> MenuContent = { EmptyView() }
    ) {
        self.title = title
        self.subtitle = subtitle
        self.iconName = iconName
        self.categoryColor = categoryColor
        self.action = action
        self.contextMenu = contextMenu
    }

    var body: some View {
        VStack(spacing: 6) {
            Button(action: action) {
                Circle()
                    .fill(categoryColor)
                    .frame(width: 80, height: 80)
                    .overlay {
                        Image(systemName: iconName)
                            .font(.system(size: 36, weight: .semibold))
                            .foregroundStyle(.white)
                    }
            }
            .buttonStyle(.plain)

            VStack(spacing: 2) {
                Text(title)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .multilineTextAlignment(.center)

                Text(subtitle)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .contextMenu(menuItems: contextMenu)
    }
}

// MARK: - Figma "Pin Place" Sheet Component
private struct PinPlaceSheet: View {
    @Bindable var store: StoreOf<SavedPlacesFeature>

    var body: some View {
        WithPerceptionTracking {
            VStack(spacing: 0) {
                if store.pinStep == .search {
                    // Search Step
                    VStack(spacing: 16) {
                        // Search Bar
                        HStack(spacing: 10) {
                            Image(systemName: "magnifyingglass")
                                .foregroundStyle(.secondary)
                            TextField("Search", text: $store.searchQuery.sending(\.searchQueryChanged))
                                .textFieldStyle(.plain)
                            Image(systemName: "mic.fill")
                                .foregroundStyle(.secondary)
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 12)
                        .background(Color(red: 0.95, green: 0.95, blue: 0.97), in: .rect(cornerRadius: 14))
                        .padding(.horizontal, 16)
                        .padding(.top, 8)

                        // Search Results List
                        ScrollView {
                            LazyVStack(spacing: 12) {
                                ForEach(store.searchResults) { place in
                                    Button {
                                        store.send(.selectPlaceSearchResult(place))
                                    } label: {
                                        HStack(spacing: 14) {
                                            // Red Pin Circle
                                            Circle()
                                                .fill(Color(red: 0.92, green: 0.25, blue: 0.20))
                                                .frame(width: 36, height: 36)
                                                .overlay {
                                                    Image(systemName: "mappin.fill")
                                                        .font(.system(size: 18, weight: .semibold))
                                                        .foregroundStyle(.white)
                                                }

                                            VStack(alignment: .leading, spacing: 2) {
                                                Text(place.name)
                                                    .font(.subheadline.weight(.semibold))
                                                    .foregroundStyle(.primary)
                                                Text(place.subtitle)
                                                    .font(.caption)
                                                    .foregroundStyle(.secondary)
                                                    .lineLimit(1)
                                            }

                                            Spacer()
                                        }
                                        .padding(.horizontal, 16)
                                        .padding(.vertical, 10)
                                        .background(Color.white, in: .rect(cornerRadius: 16))
                                        .overlay {
                                            RoundedRectangle(cornerRadius: 16)
                                                .stroke(Color.primary.opacity(0.06), lineWidth: 1)
                                        }
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(.horizontal, 16)
                        }
                    }
                } else {
                    // Configure Place Name Step (Step 2)
                    VStack(alignment: .leading, spacing: 16) {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack(spacing: 12) {
                                Circle()
                                    .fill(Color(red: 0.92, green: 0.25, blue: 0.20))
                                    .frame(width: 36, height: 36)
                                    .overlay {
                                        Image(systemName: "mappin.fill")
                                            .font(.system(size: 18, weight: .semibold))
                                            .foregroundStyle(.white)
                                    }

                                TextField("Place Name (e.g. Rumah Awan)", text: $store.customLabel.sending(\.customLabelChanged))
                                    .font(.headline.weight(.bold))
                                    .textFieldStyle(.plain)
                            }

                            Divider()

                            VStack(alignment: .leading, spacing: 2) {
                                Text(store.selectedPlaceForLabel?.name ?? "")
                                    .font(.subheadline.weight(.medium))
                                    .foregroundStyle(.primary)

                                Text(store.selectedPlaceForLabel?.subtitle ?? "")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding(16)
                        .background(Color.white, in: .rect(cornerRadius: 20))
                        .shadow(color: Color.black.opacity(0.05), radius: 10, x: 0, y: 4)

                        Spacer()
                    }
                    .padding(16)
                }
            }
            .navigationTitle("Pin Place")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    if store.pinStep == .configureLabel {
                        Button {
                            store.send(.backToSearchStep)
                        } label: {
                            Image(systemName: "chevron.left")
                                .font(.body.weight(.semibold))
                        }
                    } else {
                        Button("Cancel") {
                            store.send(.dismissAddSheetTapped)
                        }
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    if store.pinStep == .configureLabel {
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
                    }
                }
            }
        }
    }
}
