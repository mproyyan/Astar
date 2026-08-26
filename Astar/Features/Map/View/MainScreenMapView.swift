//
//  MainScreenMapView.swift
//  Astar
//
//  Created by Muhammad Pandu Royyan on 24/08/26.
//

import Combine
import ComposableArchitecture
import CoreLocation
import MapKit
import SwiftUI

struct MainScreenMapView: View {
  @Bindable var store: StoreOf<MainFeature>
  @State private var cameraPosition: MapCameraPosition = .region(.initialJakartaRegion)
  @State private var hasCenteredOnUserLocation = false
  @State private var selectedDetent: PresentationDetent = .fraction(0.42)

  private var isSheetPresented: Binding<Bool> {
    Binding(
      get: { store.path.isEmpty },
      set: { _ in }
    )
  }

  var body: some View {
    NavigationStack(path: $store.scope(state: \.path, action: \.path)) {
      Map(position: $cameraPosition, interactionModes: [.pan, .zoom, .rotate]) {
        UserAnnotation()
      }
      .sheet(isPresented: isSheetPresented) {
        MapSheet(store: store, selectedDetent: $selectedDetent)
          .presentationDetents([.fraction(0.1), .fraction(0.35), .fraction(0.42), .fraction(0.52), .fraction(0.6), .large], selection: $selectedDetent)
          .presentationDragIndicator(.visible)
          .presentationBackgroundInteraction(.enabled(upThrough: .large))
          .presentationCornerRadius(34)
          .interactiveDismissDisabled(true)
      }
      .task {
        store.send(.map(.onAppear))
      }
      .onChange(of: store.map.currentLocation) { _, newLocation in
        guard let coordinate = newLocation, !hasCenteredOnUserLocation else { return }
        hasCenteredOnUserLocation = true

        withAnimation(.easeInOut(duration: 0.8)) {
          cameraPosition = .region(MKCoordinateRegion(
            center: coordinate,
            span: MKCoordinateSpan(latitudeDelta: 0.012, longitudeDelta: 0.012)
          ))
        }
      }
      .onChange(of: store.map.authorizationStatus) { _, newStatus in
          if newStatus == .notDetermined {
             store.send(.map(.requestLocation))
          }
      }
    } destination: { store in
      NavigationDestination(store: store)
    }
  }
}

private struct NavigationDestination: View {
    let store: StoreOf<MainFeature.Path>

    var body: some View {
        switch store.case {
        case let .profile(profileStore):
            ProfileView(store: profileStore)
        }
    }
}


private extension MKCoordinateRegion {
  static let initialJakartaRegion = MKCoordinateRegion(
    center: CLLocationCoordinate2D(latitude: -6.2088, longitude: 106.8456),
    span: MKCoordinateSpan(latitudeDelta: 0.08, longitudeDelta: 0.08)
  )
}

#Preview {
  MainScreenMapView(store: Store(initialState: MainFeature.State()) { MainFeature() })
}

