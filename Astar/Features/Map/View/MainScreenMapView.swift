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
        userAnnotationPart
        destinationMarkerPart
        trackedWalkerPart
        activeRoutePart
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
        .presentationDetents(
          store.map.isSearchActive
            ? [.fraction(0.42), .large]
            : [.fraction(0.1), .fraction(0.35), .fraction(0.42), .fraction(0.52), .fraction(0.6), .large],
          selection: $selectedDetent
        )
        .presentationDragIndicator(.visible)
        .presentationBackgroundInteraction(.enabled(upThrough: .large))
        .presentationCornerRadius(34)
        .interactiveDismissDisabled(true)
      }
      .task {
        store.send(.map(.onAppear))
        store.send(.onAppear)
      }
      .onReceive(NotificationCenter.default.publisher(for: SavedPlacesStorage.savedPlacesDidChangeNotification)) { notification in
        if let places = notification.object as? [SavedPlace] {
          store.send(.map(.savedPlacesUpdated(places)))
        } else {
          store.send(.map(.reloadSavedPlaces))
        }
      }
      .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
        store.send(.refreshPeople)
      }
      .onChange(of: store.map.isSearchActive) { _, isSearching in
        if isSearching {
          withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
            selectedDetent = .large
          }
        }
      }
      .onChange(of: selectedDetent) { _, newDetent in
        if store.map.isSearchActive && newDetent != .large {
          UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
          store.send(.map(.dismissSearch))
          withAnimation(.easeInOut(duration: 0.25)) {
            selectedDetent = .fraction(0.42)
          }
        }
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
        if isNavigating {
          withAnimation(.easeInOut(duration: 0.25)) {
            selectedDetent = .fraction(0.6)
          }
          if let userCoord = store.map.currentLocation {
            zoomToRoadLevel(coordinate: userCoord)
          }
        }
      }
      .onChange(of: store.map.trackedWalkerLocation, initial: true) { _, newTrackerCoord in
        guard !store.map.isNavigating, store.map.activeWalkSessionID != nil else { return }
        guard let trackerCoordinate = newTrackerCoord, !store.map.hasFittedTrackedWalker else { return }

        if let destCoordinate = store.map.trackedWalkerDestination {
            fitTrackedWalker(tracker: trackerCoordinate, destination: destCoordinate)
        } else {
            centerCamera(on: trackerCoordinate)
        }

        store.send(.map(.markTrackedWalkerFitted))
      }
      .onChange(of: store.map.activeWalkSessionID) { _, newSession in
        guard !store.map.isNavigating, newSession != nil, let trackerCoordinate = store.map.trackedWalkerLocation else { return }
        if let destCoordinate = store.map.trackedWalkerDestination {
            fitTrackedWalker(tracker: trackerCoordinate, destination: destCoordinate)
        } else {
            centerCamera(on: trackerCoordinate)
        }
        store.send(.map(.markTrackedWalkerFitted))
      }
    } destination: { store in
      NavigationDestination(store: store)
    }
  }

  private func fitTrackedWalker(tracker: CLLocationCoordinate2D, destination: CLLocationCoordinate2D) {
    withAnimation(.easeInOut(duration: 0.8)) {
        let p1 = MKMapPoint(tracker)
        let p2 = MKMapPoint(destination)
        let mapRect = MKMapRect(
            x: min(p1.x, p2.x),
            y: min(p1.y, p2.y),
            width: abs(p1.x - p2.x),
            height: abs(p1.y - p2.y)
        )
        // Add padding
        cameraPosition = .rect(mapRect.insetBy(dx: -mapRect.width * 0.3, dy: -mapRect.height * 0.3))
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
      let rect = route.polyline.boundingMapRect
      let paddedRect = rect.insetBy(dx: -rect.width * 0.25, dy: -rect.height * 0.35)
      cameraPosition = .rect(paddedRect)
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

  @MapContentBuilder
  private var userAnnotationPart: some MapContent {
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
  }

  @MapContentBuilder
  private var destinationMarkerPart: some MapContent {
    if let sheet = store.map.sheet, case let .direction(directionState) = sheet, let coord = directionState.destination.coordinate {
      if !directionState.destination.iconName.isEmpty {
        Marker(directionState.destination.name, systemImage: directionState.destination.iconName, coordinate: coord)
          .tint(.red)
      } else {
        Marker(directionState.destination.name, coordinate: coord)
          .tint(.red)
      }
    }
  }

  @MapContentBuilder
  private var trackedWalkerPart: some MapContent {
    if !store.map.isNavigating && store.map.activeWalkSessionID != nil {
      if let polyline = store.map.trackedWalkerPolyline {
        MapPolyline(polyline)
          .stroke(Color.orange.opacity(0.8), lineWidth: 4)
      } else if let route = store.map.trackedWalkerRoute {
        MapPolyline(route.polyline)
          .stroke(Color.orange.opacity(0.8), lineWidth: 4)
      }

      if let trackedCoord = store.map.trackedWalkerLocation {
        Annotation("Walker", coordinate: trackedCoord, anchor: .bottom) {
          ZStack {
            Circle()
              .fill(Color.orange.opacity(0.3))
              .frame(width: 44, height: 44)
            Circle()
              .fill(Color.white)
              .frame(width: 28, height: 28)
              .shadow(color: .black.opacity(0.2), radius: 3, y: 1)
            Image(systemName: "figure.walk")
              .font(.system(size: 14, weight: .bold))
              .foregroundColor(.orange)
          }
        }
        .annotationTitles(.hidden)
      }

      if let destinationCoord = store.map.trackedWalkerDestination {
        Marker(store.map.trackedWalkerDestinationName ?? "Destination", coordinate: destinationCoord)
          .tint(.orange)
      }
    }
  }

  private var previewPolyline: MKPolyline? {
    if let route = store.map.activeRoute {
      return route.polyline
    }
    if let polyline = store.map.activePolyline {
      return polyline
    }
    if let sheet = store.map.sheet, case let .direction(d) = sheet {
      return d.activeRoute?.polyline ?? d.walkingRouteInfo?.polyline
    }
    return nil
  }

  @MapContentBuilder
  private var activeRoutePart: some MapContent {
    if store.map.isShowRouteGuide, let polyline = previewPolyline {
      MapPolyline(polyline)
        .stroke(Color.blue, lineWidth: 5)
    }
  }
}

private struct NavigationDestination: View {
  let store: StoreOf<MainFeature.Path>

  var body: some View {
    switch store.case {
    case let .profile(profileStore):
      ProfileView(store: profileStore)
    case let .trustedPerson(trustedPersonStore):
      TrustedPersonView(store: trustedPersonStore)
    case let .requestTrustedPerson(requestTrustedPersonStore):
      RequestTrustedPersonView(store: requestTrustedPersonStore)
    }
  }
}

private extension MKCoordinateRegion {
  static let initialJakartaRegion = MKCoordinateRegion(
    center: CLLocationCoordinate2D(latitude: -6.2088, longitude: 106.8456),
    span: MKCoordinateSpan(latitudeDelta: 0.08, longitudeDelta: 0.08)
  )
}
