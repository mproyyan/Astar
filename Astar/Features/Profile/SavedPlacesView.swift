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

    var body: some View {
        WithPerceptionTracking {
            ZStack {
                Color(red: 0.95, green: 0.95, blue: 0.97)
                    .ignoresSafeArea()

                VStack(alignment: .leading, spacing: 0) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Saved Places")
                            .font(.system(size: 34, weight: .bold))
                            .foregroundStyle(.primary)

                        Text("Add, edit, or remove places you visit often.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 16)
                    .padding(.bottom, 8)
                    
                    List {
                        Section {
                            ForEach(store.places) { place in
                                SavedPlaceGroupedRow(
                                    place: place,
                                    onSelect: {
                                        let preset: SavedPlacesFeature.State.CategoryPreset? = place.isHome ? .home : (place.isOffice ? .office : .custom)
                                        store.send(.changeLocationTapped(place, preset))
                                    }
                                )
                                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                    Button(role: .destructive) {
                                        store.send(.deletePlaceById(place.id))
                                    } label: {
                                        Label("Delete", systemImage: "trash")
                                    }
                                }
                            }

                            Button {
                                store.send(.addPlaceButtonTapped(.custom))
                            } label: {
                                HStack(spacing: 12) {
                                    Circle()
                                        .fill(Color(red: 0.88, green: 0.95, blue: 1.0))
                                        .frame(width: 40, height: 40)
                                        .overlay {
                                            Image(systemName: "plus")
                                                .font(.body.weight(.semibold))
                                                .foregroundStyle(Color(red: 0.00, green: 0.55, blue: 0.95))
                                        }

                                    Text("Add Place")
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundStyle(Color(red: 0.00, green: 0.55, blue: 0.95))

                                    Spacer()
                                }
                                .padding(.vertical, 4)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .listStyle(.insetGrouped)
                    .scrollContentBackground(.hidden)
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

private struct SavedPlaceGroupedRow: View {
    let place: SavedPlace
    let onSelect: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Button(action: onSelect) {
                HStack(spacing: 12) {
                    Circle()
                        .fill(place.categoryColor)
                        .frame(width: 40, height: 40)
                        .overlay {
                            Image(systemName: place.resolvedIconName)
                                .font(.body.weight(.semibold))
                                .foregroundStyle(.white)
                        }

                    VStack(alignment: .leading, spacing: 2) {
                        Text(place.displayTitle)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.primary)

                        if let label = place.label?.trimmingCharacters(in: .whitespacesAndNewlines),
                           !label.isEmpty,
                           label.lowercased() != place.name.lowercased() {
                            Text(place.name)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)

                            if !place.subtitle.isEmpty && place.subtitle.lowercased() != place.name.lowercased() {
                                Text(place.subtitle)
                                    .font(.caption2)
                                    .foregroundStyle(Color.gray)
                                    .lineLimit(1)
                            }
                        } else {
                            Text(place.displaySubtitle)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                    }

                    Spacer(minLength: 8)
                }
            }
            .buttonStyle(.plain)

            Button(action: onSelect) {
                Image(systemName: "ellipsis")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .frame(width: 34, height: 34)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Options")
        }
        .padding(.vertical, 4)
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
                    VStack(spacing: 16) {
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
                                                
                                                if store.selectedPlaceForLabel?.id == place.id {
                                                    Image(systemName: "checkmark")
                                                        .font(.body.weight(.bold))
                                                        .foregroundStyle(Color(red: 0.00, green: 0.55, blue: 0.95))
                                                }
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
                    VStack(alignment: .leading, spacing: 16) {
                        VStack(alignment: .leading, spacing: 14) {
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
                            Image(systemName: "checkmark")
                                .font(.body.weight(.semibold))
                                .foregroundStyle(
                                    store.hasChanges
                                        ? Color(red: 0.00, green: 0.55, blue: 0.95)
                                        : Color.gray.opacity(0.4)
                                )
                        }
                        .disabled(!store.hasChanges)
                    } else if let selected = store.selectedPlaceForLabel {
                        Button {
                            store.send(.selectPlaceSearchResult(selected))
                        } label: {
                            Circle()
                                .fill(Color(red: 0.00, green: 0.55, blue: 0.95))
                                .frame(width: 32, height: 32)
                                .overlay {
                                    Image(systemName: "checkmark")
                                        .font(.body.weight(.semibold))
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
            .onChange(of: store.pinStep) { _, newStep in
                if newStep == .renamePlace {
                    isSearchFocused = false
                    Task { @MainActor in
                        try? await Task.sleep(nanoseconds: 50_000_000)
                        isNameFocused = true
                    }
                } else if newStep == .chooseLocation {
                    isNameFocused = false
                    isSearchFocused = true
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
