//
//  SavedPlacesFeature.swift
//  Astar
//
//  Created by Safa Auliya Hidayat on 27/08/26.
//

import ComposableArchitecture
import CoreLocation
import Foundation
import MapKit
import SwiftUI

@Reducer
struct SavedPlacesFeature {
    @ObservableState
    struct State: Equatable {
        var userId: String = SavedPlacesStorage.defaultUserId
        var places: [SavedPlace] = []
        var isAddingPlace: Bool = false
        var targetPresetForAdd: CategoryPreset? = nil
        var pinStep: PinStep = .chooseLocation
        var searchQuery: String = ""
        var searchResults: [SavedPlace] = []
        var isLoading: Bool = false
        var selectedPlaceForLabel: SavedPlace? = nil
        var customLabel: String = ""
        var editingPlaceId: UUID? = nil
        var hasChanges: Bool {
            guard let editingId = editingPlaceId,
                  let originalPlace = places.first(where: { $0.id == editingId }) else {
                // Adding a new place
                return selectedPlaceForLabel != nil
            }

            let currentLabel = customLabel.trimmingCharacters(in: .whitespacesAndNewlines)

            let originalLabel = (originalPlace.label ?? originalPlace.name)
                .trimmingCharacters(in: .whitespacesAndNewlines)

            let isLabelChanged = !currentLabel.isEmpty && currentLabel != originalLabel

            let isLocationChanged = selectedPlaceForLabel?.id != originalPlace.id

            return isLabelChanged || isLocationChanged
        }

        enum PinStep: Equatable {
            case chooseLocation
            case renamePlace
        }

        enum CategoryPreset: String, CaseIterable, Equatable, Identifiable {
            case home = "Home"
            case office = "Office"
            case custom = "Custom"

            var id: String { rawValue }

            var iconName: String {
                switch self {
                case .home: return "house.fill"
                case .office: return "briefcase.fill"
                case .custom: return "mappin.fill"
                }
            }
        }

        var homePlace: SavedPlace? {
            places.first(where: { $0.isHome })
        }

        var officePlace: SavedPlace? {
            places.first(where: { $0.isOffice })
        }

        var customPlaces: [SavedPlace] {
            places.filter { $0.isCustom }
        }
    }

    enum Action: Equatable {
        case onAppear
        case placesLoaded([SavedPlace])
        case addPlaceButtonTapped(State.CategoryPreset?)
        case changeLocationTapped(SavedPlace, State.CategoryPreset?)
        case dismissAddSheetTapped
        case searchQueryChanged(String)
        case searchResponse([SavedPlace])
        case clearSearchTapped
        case selectPlaceSearchResult(SavedPlace)
        case backToChooseLocationTapped
        case customLabelChanged(String)
        case confirmSavePlace
        case deletePlaceById(UUID)
        case delegate(Delegate)

        enum Delegate: Equatable {
            case savedPlacesUpdated([SavedPlace])
        }
    }

    @Dependency(\.savedPlacesRepository) var repository
    @Dependency(\.placeSearch) var placeSearch
    @Dependency(\.locationManager) var locationManager
    @Dependency(\.continuousClock) var clock

    var body: some Reducer<State, Action> {
        Reduce { state, action in
            switch action {
            case .onAppear:
                let userId = state.userId
                return .run { send in
                    let places = await repository.load(for: userId)
                    await send(.placesLoaded(places))
                }

            case let .placesLoaded(places):
                state.places = places
                return .none

            case let .addPlaceButtonTapped(preset):
                state.targetPresetForAdd = preset
                state.isAddingPlace = true
                state.pinStep = .chooseLocation
                state.searchQuery = ""
                state.searchResults = []
                state.isLoading = false
                state.selectedPlaceForLabel = nil
                state.customLabel = preset == .home ? "Home" : (preset == .office ? "Office" : "")
                state.editingPlaceId = nil
                return .none

            case let .changeLocationTapped(place, preset):
                state.targetPresetForAdd = preset ?? (place.isHome ? .home : (place.isOffice ? .office : .custom))
                state.isAddingPlace = true
                state.pinStep = .renamePlace
                state.searchQuery = ""
                state.searchResults = []
                state.isLoading = false
                state.selectedPlaceForLabel = place
                state.customLabel = place.label ?? place.name
                state.editingPlaceId = place.id
                return .none

            case .dismissAddSheetTapped:
                state.isAddingPlace = false
                state.pinStep = .chooseLocation
                state.searchQuery = ""
                state.searchResults = []
                state.selectedPlaceForLabel = nil
                state.editingPlaceId = nil
                state.isLoading = false
                return .cancel(id: "savedPlacesSearchDebounce")

            case let .searchQueryChanged(query):
                state.searchQuery = query
                let cleanQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !cleanQuery.isEmpty else {
                    state.searchResults = []
                    state.isLoading = false
                    return .cancel(id: "savedPlacesSearchDebounce")
                }
                state.isLoading = true
                return .run { send in
                    try await clock.sleep(for: .milliseconds(300))
                    let userLoc = await locationManager.getCurrentLocation()
                    let results = await placeSearch.searchPlaces(query: cleanQuery, userLocation: userLoc)
                    await send(.searchResponse(results))
                }
                .cancellable(id: "savedPlacesSearchDebounce", cancelInFlight: true)

            case let .searchResponse(results):
                state.isLoading = false
                state.searchResults = results
                return .none

            case .clearSearchTapped:
                state.searchQuery = ""
                state.searchResults = []
                state.isLoading = false
                return .cancel(id: "savedPlacesSearchDebounce")

            case let .selectPlaceSearchResult(place):
                state.selectedPlaceForLabel = place
                if state.customLabel.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    if state.targetPresetForAdd == .home {
                        state.customLabel = "Home"
                    } else if state.targetPresetForAdd == .office {
                        state.customLabel = "Office"
                    } else {
                        state.customLabel = place.name
                    }
                }
                state.pinStep = .renamePlace
                return .none

            case .backToChooseLocationTapped:
                if state.editingPlaceId != nil {
                    return .send(.dismissAddSheetTapped)
                }
                state.pinStep = .chooseLocation
                return .none

            case let .customLabelChanged(label):
                state.customLabel = label
                return .none

            case .confirmSavePlace:
                guard var targetPlace = state.selectedPlaceForLabel else { return .none }
                let labelText = state.customLabel.trimmingCharacters(in: .whitespacesAndNewlines)
                let finalName = labelText.isEmpty ? (state.targetPresetForAdd == .home ? "Home" : (state.targetPresetForAdd == .office ? "Office" : targetPlace.name)) : labelText

                let iconName: String
                let categoryLabel: String?
                if let preset = state.targetPresetForAdd {
                    switch preset {
                    case .home:
                        iconName = "house.fill"
                        categoryLabel = "Home"
                    case .office:
                        iconName = "briefcase.fill"
                        categoryLabel = "Office"
                    case .custom:
                        let inferred = PlaceSearchEngine.categoryIcon(for: nil, name: finalName, subtitle: targetPlace.subtitle)
                        if targetPlace.resolvedIconName != "mappin.fill" {
                            iconName = targetPlace.resolvedIconName
                        } else if inferred != "mappin.fill" {
                            iconName = inferred
                        } else {
                            iconName = "mappin.fill"
                        }
                        categoryLabel = finalName
                    }
                } else if finalName.lowercased() == "home" {
                    iconName = "house.fill"
                    categoryLabel = "Home"
                } else if finalName.lowercased() == "office" || finalName.lowercased() == "work" {
                    iconName = "briefcase.fill"
                    categoryLabel = "Office"
                } else {
                    let inferred = PlaceSearchEngine.categoryIcon(for: nil, name: finalName, subtitle: targetPlace.subtitle)
                    if targetPlace.resolvedIconName != "mappin.fill" {
                        iconName = targetPlace.resolvedIconName
                    } else if inferred != "mappin.fill" {
                        iconName = inferred
                    } else {
                        iconName = "mappin.fill"
                    }
                    categoryLabel = finalName
                }

                let targetId = state.editingPlaceId ?? targetPlace.id

                // Remove existing place if replacing Home/Office preset OR if we are updating an existing place by ID
                if iconName == "house.fill" || categoryLabel == "Home" {
                    state.places.removeAll { $0.isHome || $0.id == targetId }
                } else if iconName == "briefcase.fill" || iconName == "building.2.fill" || categoryLabel == "Office" {
                    state.places.removeAll { $0.isOffice || $0.id == targetId }
                } else {
                    state.places.removeAll { $0.id == targetId }
                }

                targetPlace = SavedPlace(
                    id: targetId,
                    name: finalName,
                    subtitle: targetPlace.subtitle,
                    iconName: iconName,
                    distance: targetPlace.distance,
                    coordinate: targetPlace.coordinate,
                    label: categoryLabel
                )

                // Place Home & Office at the beginning if appropriate
                if iconName == "house.fill" || categoryLabel == "Home" {
                    state.places.insert(targetPlace, at: 0)
                } else if iconName == "briefcase.fill" || iconName == "building.2.fill" || categoryLabel == "Office" {
                    if let homeIdx = state.places.firstIndex(where: { $0.isHome }) {
                        state.places.insert(targetPlace, at: homeIdx + 1)
                    } else {
                        state.places.insert(targetPlace, at: 0)
                    }
                } else {
                    state.places.append(targetPlace)
                }

                let userId = state.userId
                let updatedPlaces = state.places
                state.isAddingPlace = false
                state.pinStep = .chooseLocation
                state.selectedPlaceForLabel = nil
                state.editingPlaceId = nil
                state.searchQuery = ""
                state.searchResults = []

                return .merge(
                    .send(.delegate(.savedPlacesUpdated(updatedPlaces))),
                    .run { _ in
                        await repository.save(updatedPlaces, for: userId)
                    }
                )

            case let .deletePlaceById(id):
                state.places.removeAll { $0.id == id }
                let userId = state.userId
                let updated = state.places
                return .merge(
                    .send(.delegate(.savedPlacesUpdated(updated))),
                    .run { send in
                        let saved = await repository.delete(id: id, for: userId)
                        await send(.placesLoaded(saved))
                    }
                )

            case .delegate:
                return .none
            }
        }
    }
}
