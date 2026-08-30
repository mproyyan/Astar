//
//  SavedPlacesFeature.swift
//  Astar
//
//  Created by Safa Auliya Hidayat on 27/08/26.
//

import ComposableArchitecture
import Foundation
import MapKit
import SwiftUI

@Reducer
struct SavedPlacesFeature {
    @ObservableState
    struct State: Equatable {
        var userId: String
        var places: [SavedPlace] = []
        var isAddingPlace: Bool = false
        var targetPresetForAdd: CategoryPreset? = nil
        var pinStep: PinStep = .search
        var searchQuery: String = ""
        var searchResults: [SavedPlace] = []
        var selectedPlaceForLabel: SavedPlace? = nil
        var customLabel: String = ""
        var editingPlaceId: UUID? = nil

        enum PinStep: Equatable {
            case search
            case configureLabel
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
                case .custom: return "key.fill"
                }
            }
        }

        var homePlace: SavedPlace? {
            places.first(where: { $0.iconName == "house.fill" || $0.label?.lowercased() == "home" || $0.name.lowercased() == "home" })
        }

        var officePlace: SavedPlace? {
            places.first(where: { $0.iconName == "briefcase.fill" || $0.iconName == "building.2.fill" || $0.label?.lowercased() == "office" || $0.name.lowercased() == "office" })
        }

        var customPlaces: [SavedPlace] {
            places.filter { place in
                place.id != homePlace?.id && place.id != officePlace?.id
            }
        }
    }

    enum Action: Equatable {
        case onAppear
        case placesLoaded([SavedPlace])
        case addPlaceButtonTapped(State.CategoryPreset?)
        case dismissAddSheetTapped
        case searchQueryChanged(String)
        case searchResponse([SavedPlace])
        case selectPlaceSearchResult(SavedPlace)
        case backToSearchStep
        case customLabelChanged(String)
        case editPlaceTapped(SavedPlace, State.CategoryPreset?)
        case confirmSavePlace
        case deletePlaceById(UUID)
    }

    @Dependency(\.savedPlacesRepository) var repository

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
                state.pinStep = .search
                state.searchQuery = ""
                state.searchResults = []
                state.selectedPlaceForLabel = nil
                state.customLabel = ""
                state.editingPlaceId = nil
                return .none

            case .dismissAddSheetTapped:
                state.isAddingPlace = false
                state.pinStep = .search
                state.selectedPlaceForLabel = nil
                state.editingPlaceId = nil
                return .none

            case let .searchQueryChanged(query):
                state.searchQuery = query
                guard !query.trimmingCharacters(in: .whitespaces).isEmpty else {
                    state.searchResults = []
                    return .none
                }
                let currentQuery = query
                return .run { send in
                    let results = await performMapSearch(query: currentQuery)
                    await send(.searchResponse(results))
                }

            case let .searchResponse(results):
                state.searchResults = results
                return .none

            case let .selectPlaceSearchResult(place):
                state.selectedPlaceForLabel = place
                state.pinStep = .configureLabel
                if let preset = state.targetPresetForAdd {
                    switch preset {
                    case .home: state.customLabel = "Home"
                    case .office: state.customLabel = "Office"
                    case .custom: state.customLabel = place.name
                    }
                } else {
                    state.customLabel = place.name
                }
                return .none

            case .backToSearchStep:
                state.pinStep = .search
                return .none

            case let .customLabelChanged(label):
                state.customLabel = label
                return .none

            case let .editPlaceTapped(place, preset):
                state.targetPresetForAdd = preset
                state.isAddingPlace = true
                state.pinStep = .configureLabel
                state.selectedPlaceForLabel = place
                state.customLabel = place.label ?? place.name
                state.editingPlaceId = place.id
                return .none

            case .confirmSavePlace:
                guard var targetPlace = state.selectedPlaceForLabel else { return .none }
                let labelText = state.customLabel.trimmingCharacters(in: .whitespaces)
                let iconName: String
                if let preset = state.targetPresetForAdd {
                    iconName = preset.iconName
                } else if labelText.lowercased() == "home" {
                    iconName = "house.fill"
                } else if labelText.lowercased() == "office" || labelText.lowercased() == "work" {
                    iconName = "briefcase.fill"
                } else {
                    iconName = "key.fill"
                }

                let targetId = state.editingPlaceId ?? targetPlace.id

                // Remove existing place if replacing Home/Office preset OR if we are updating an existing place by ID
                if iconName == "house.fill" {
                    state.places.removeAll { $0.iconName == "house.fill" || $0.label?.lowercased() == "home" || $0.id == targetId }
                } else if iconName == "briefcase.fill" || iconName == "building.2.fill" {
                    state.places.removeAll { $0.iconName == "briefcase.fill" || $0.iconName == "building.2.fill" || $0.label?.lowercased() == "office" || $0.id == targetId }
                } else {
                    state.places.removeAll { $0.id == targetId }
                }

                targetPlace = SavedPlace(
                    id: targetId,
                    name: labelText.isEmpty ? targetPlace.name : labelText,
                    subtitle: targetPlace.subtitle,
                    iconName: iconName,
                    distance: targetPlace.distance,
                    latitude: targetPlace.latitude,
                    longitude: targetPlace.longitude,
                    label: labelText.isEmpty ? "Saved" : labelText
                )

                state.places.append(targetPlace)
                let userId = state.userId
                let updatedPlaces = state.places
                state.isAddingPlace = false
                state.selectedPlaceForLabel = nil
                state.editingPlaceId = nil

                return .run { _ in
                    await repository.save(updatedPlaces, for: userId)
                }

            case let .deletePlaceById(id):
                state.places.removeAll { $0.id == id }
                let userId = state.userId
                return .run { send in
                    let updated = await repository.delete(id: id, for: userId)
                    await send(.placesLoaded(updated))
                }
            }
        }
    }
}

// MARK: - Map Search Helper
private func performMapSearch(query: String) async -> [SavedPlace] {
    let request = MKLocalSearch.Request()
    request.naturalLanguageQuery = query
    let search = MKLocalSearch(request: request)

    guard let response = try? await search.start() else { return [] }
    return response.mapItems.compactMap { item in
        guard let name = item.name else { return nil }
        let placemark = item.placemark
        let addressParts = [
            placemark.thoroughfare,
            placemark.subLocality,
            placemark.locality,
            placemark.administrativeArea
        ].compactMap { $0 }.filter { !$0.isEmpty }
        let subtitle = addressParts.isEmpty ? (placemark.title ?? "Location") : addressParts.joined(separator: ", ")

        return SavedPlace(
            name: name,
            subtitle: subtitle,
            iconName: "mappin.fill",
            latitude: placemark.coordinate.latitude,
            longitude: placemark.coordinate.longitude
        )
    }
}
