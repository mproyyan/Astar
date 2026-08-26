//
//  MapSheetDirectionContent.swift
//  Astar
//
//  Created by Dimas Prihady Setyawan on 25/08/26.
//

import CoreLocation
import MapKit
import SwiftUI

struct MapSheetDirectionContent: View {
    var userLocation: CLLocationCoordinate2D? = nil
    let destination: SavedPlace
    let onCancel: () -> Void
    var onRouteReady: ((MKRoute?, SavedPlace) -> Void)? = nil
    var onStartNavigation: ((WalkingRouteInfo) -> Void)? = nil

    @State private var originPlace: SavedPlace = SavedPlace(
        name: "Current Location",
        subtitle: "Locating current area...",
        iconName: "location.fill"
    )
    @State private var walkingRoute: WalkingRouteInfo? = nil
    @State private var isLoadingRoute: Bool = true

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            DirectionCard(
                origin: originPlace,
                destination: destination,
                walkingRoute: walkingRoute,
                isLoadingRoute: isLoadingRoute,
                onCancel: onCancel,
                onStartNavigation: {
                    if let route = walkingRoute {
                        onStartNavigation?(route)
                    } else {
                        let fallback = WalkingRouteInfo(
                            travelTimeString: "12 min",
                            etaString: "11.00 ETA",
                            distanceString: destination.distance ?? "850 m",
                            rawTravelTime: 720,
                            rawDistanceMeters: 850
                        )
                        onStartNavigation?(fallback)
                    }
                }
            )
            .padding(.top, 8)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16)
        .padding(.top, 12)
        .task(id: destination.id) {
            isLoadingRoute = true

            let originCoord = userLocation ?? CLLocationCoordinate2D(latitude: -6.2088, longitude: 106.8456)

            // 1. Reverse geocode origin
            async let userAddressTask = DirectionRouteService.reverseGeocode(coordinate: originCoord)

            // 2. Resolve destination coordinate if nil
            var destCoord = destination.coordinate
            if destCoord == nil {
                let searchReq = MKLocalSearch.Request()
                searchReq.naturalLanguageQuery = "\(destination.name) \(destination.subtitle)"
                if let resp = try? await MKLocalSearch(request: searchReq).start(),
                   let firstItem = resp.mapItems.first {
                    destCoord = firstItem.placemark.coordinate
                } else {
                    destCoord = CLLocationCoordinate2D(latitude: -6.2088, longitude: 106.8456)
                }
            }

            let resolvedDestCoord = destCoord ?? CLLocationCoordinate2D(latitude: -6.2088, longitude: 106.8456)

            // 3. Calculate walking route
            async let routeTask = DirectionRouteService.calculateWalkingRoute(from: originCoord, to: resolvedDestCoord)

            let (userAddress, calculatedRoute) = await (userAddressTask, routeTask)

            originPlace = SavedPlace(
                name: "Current Location",
                subtitle: userAddress,
                iconName: "location.fill",
                coordinate: originCoord
            )

            walkingRoute = calculatedRoute
            isLoadingRoute = false

            // Update destination coordinate if it was resolved
            let updatedDest = SavedPlace(
                id: destination.id,
                name: destination.name,
                subtitle: destination.subtitle,
                iconName: destination.iconName,
                distance: calculatedRoute.distanceString,
                coordinate: resolvedDestCoord
            )

            onRouteReady?(calculatedRoute.route, updatedDest)
        }
    }
}

#Preview {
    MapSheetDirectionContent(
        destination: MapSampleData.savedPlaces[0],
        onCancel: {}
    )
}
