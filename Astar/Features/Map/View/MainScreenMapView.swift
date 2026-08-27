import Combine
import ComposableArchitecture
import CoreLocation
import MapKit
import SwiftUI

struct MainScreenMapView: View {
  @Bindable var store: StoreOf<MainFeature>
  @State private var cameraPosition: MapCameraPosition = .region(.initialJakartaRegion)
  @State private var hasCenteredOnUserLocation = false
  @State private var isFarFromUser = false
  @State private var selectedDetent: PresentationDetent = .fraction(0.42)
  @Namespace private var mapScope

  private var isSheetPresented: Binding<Bool> {
    Binding(
      get: { store.path.isEmpty },
      set: { _ in }
    )
  }

  var body: some View {
    NavigationStack(path: $store.scope(state: \.path, action: \.path)) {
      Map(position: $cameraPosition, interactionModes: [.pan, .zoom, .rotate], scope: mapScope) {
        // Point A: User Annotation
        UserAnnotation {
          ZStack {
            Circle()
              .fill(Color.blue.opacity(0.18))
              .frame(width: 38, height: 38)

            Circle()
              .fill(Color.white)
              .frame(width: 22, height: 22)
              .shadow(color: .black.opacity(0.15), radius: 3, y: 1)

            Circle()
              .fill(Color.blue)
              .frame(width: 14, height: 14)
          }
        }

        // Point B: Destination Marker
        if let sheet = store.map.sheet, case let .direction(directionState) = sheet, let coord = directionState.destination.coordinate {
          Marker(directionState.destination.name, coordinate: coord)
            .tint(.red)
        }

        // Route Polyline from Point A to Point B
        if let route = store.map.activeRoute {
          MapPolyline(route.polyline)
            .stroke(Color.blue, lineWidth: 5)
        }
      }
      .mapStyle(.standard(elevation: .realistic))
      .mapScope(mapScope)
      .onMapCameraChange(frequency: .onEnd) { context in
        guard let userCoordinate = store.map.currentLocation else { return }
        let userLoc = CLLocation(latitude: userCoordinate.latitude, longitude: userCoordinate.longitude)
        let cameraLoc = CLLocation(latitude: context.region.center.latitude, longitude: context.region.center.longitude)
        let distance = userLoc.distance(from: cameraLoc)

        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
          isFarFromUser = distance > 100
        }
      }
      .overlay(alignment: .topTrailing) {
        VStack(spacing: 12) {
          // North Compass
          MapCompass(scope: mapScope)

          // Recenter Button under North Compass
          Button {
            if let userCoordinate = store.map.currentLocation {
              withAnimation(.spring(response: 0.45, dampingFraction: 0.8)) {
                centerCamera(on: userCoordinate)
                isFarFromUser = false
              }
            } else {
              store.send(.map(.requestLocation))
            }
          } label: {
            Image(systemName: isFarFromUser ? "location" : "location.fill")
              .font(.system(size: 18, weight: .semibold))
              .foregroundStyle(isFarFromUser ? Color.primary : Color.blue)
              .frame(width: 44, height: 44)
              .contentShape(Circle())
          }
          .buttonStyle(.plain)
          .glassEffect(.regular.interactive(), in: .circle)
          .contentShape(Circle())
          .shadow(color: .black.opacity(0.12), radius: 6, y: 2)
          .accessibilityLabel("Re-center to user location")
        }
        .padding(.trailing, 16)
        .padding(.top, 60)
      }
      .sheet(isPresented: isSheetPresented) {
        MapSheet(
          store: store,
          selectedDetent: $selectedDetent
        )
        .presentationDetents([.fraction(0.1), .fraction(0.35), .fraction(0.42), .fraction(0.52), .fraction(0.6), .large], selection: $selectedDetent)
        .presentationDragIndicator(.visible)
        .presentationBackgroundInteraction(.enabled(upThrough: .large))
        .presentationCornerRadius(34)
        .interactiveDismissDisabled(true)
      }
      .task {
        store.send(.map(.onAppear))
        store.send(.onAppear)
      }
      .onChange(of: store.map.currentLocation) { _, newLocation in
        guard let coordinate = newLocation, !hasCenteredOnUserLocation else { return }
        hasCenteredOnUserLocation = true
        centerCamera(on: coordinate)
      }
      .onChange(of: store.map.authorizationStatus) { _, newStatus in
        if newStatus == .notDetermined {
          store.send(.map(.requestLocation))
        }
      }
      .onChange(of: store.map.activeRoute) { _, newRoute in
        if let route = newRoute {
          fitRoute(route: route)
        }
      }
      .onChange(of: store.map.isNavigating) { _, isNavigating in
        if isNavigating, let userCoord = store.map.currentLocation {
          zoomToRoadLevel(coordinate: userCoord)
        }
      }
    } destination: { store in
      NavigationDestination(store: store)
    }
  }

  private func centerCamera(on coordinate: CLLocationCoordinate2D, animated: Bool = true) {
    let verticalOffset = 0.0035
    let adjustedCenter = CLLocationCoordinate2D(
      latitude: coordinate.latitude - verticalOffset,
      longitude: coordinate.longitude
    )

    let region = MKCoordinateRegion(
      center: adjustedCenter,
      span: MKCoordinateSpan(latitudeDelta: 0.012, longitudeDelta: 0.012)
    )

    if animated {
      withAnimation(.easeInOut(duration: 0.8)) {
        cameraPosition = .region(region)
      }
    } else {
      cameraPosition = .region(region)
    }
  }

  private func fitRoute(route: MKRoute) {
    withAnimation(.easeInOut(duration: 0.8)) {
      cameraPosition = .rect(route.polyline.boundingMapRect)
    }
  }

  private func zoomToRoadLevel(coordinate: CLLocationCoordinate2D) {
    withAnimation(.easeInOut(duration: 0.8)) {
      let offsetCenter = CLLocationCoordinate2D(
        latitude: coordinate.latitude - 0.0006,
        longitude: coordinate.longitude
      )
      cameraPosition = .camera(MapCamera(centerCoordinate: offsetCenter, distance: 300, pitch: 45))
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
