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
  @State private var isSheetExpanded = false

  var body: some View {
    ZStack(alignment: .bottom) {
      Map(position: $cameraPosition, interactionModes: [.pan, .zoom, .rotate]) {
        UserAnnotation()
      }
      .mapStyle(.standard(elevation: .realistic))
      .ignoresSafeArea()

      BottomSheetView(store: store, isExpanded: $isSheetExpanded)
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
  }
}

private struct BottomSheetView: View {
  let store: StoreOf<MainFeature>
  @Binding var isExpanded: Bool
  @GestureState private var dragOffset: CGFloat = 0

  private let people = [
    Person(name: "Awan", status: "Walking"),
    Person(name: "Royyan", status: "Idle"),
    Person(name: "Safa", status: "Idle"),
    Person(name: "Nadia", status: "Idle")
  ]

  private let savedPlaces = [
    SavedPlace(name: "Home", subtitle: "Bendungan Hilir, South Jakarta", iconName: "house.fill"),
    SavedPlace(name: "Gym", subtitle: "Agora Mall, Central Jakarta", iconName: "figure.strengthtraining.traditional"),
    SavedPlace(name: "Office", subtitle: "Bendungan Hilir, South Jakarta", iconName: "building.2.fill")
  ]

  var body: some View {
    GeometryReader { geometry in
      let collapsedHeight = min(max(356, geometry.size.height * 0.42), 410)
      let expandedHeight = min(max(626, geometry.size.height * 0.72), geometry.size.height - geometry.safeAreaInsets.top - 18)
      let targetHeight = isExpanded ? expandedHeight : collapsedHeight
      let currentHeight = min(max(targetHeight - dragOffset, collapsedHeight), expandedHeight)

      VStack(spacing: 0) {
        Spacer(minLength: 0)

        sheetContent(width: geometry.size.width, bottomInset: geometry.safeAreaInsets.bottom)
          .frame(height: currentHeight, alignment: .top)
          .background {
            sheetBackground
          }
          .clipShape(sheetShape)
          .shadow(color: .black.opacity(0.08), radius: 24, x: 0, y: -8)
          .contentShape(Rectangle())
          .gesture(sheetDragGesture(collapsedHeight: collapsedHeight, expandedHeight: expandedHeight, targetHeight: targetHeight))
          .animation(.spring(response: 0.45, dampingFraction: 0.86), value: isExpanded)
      }
      .ignoresSafeArea(edges: .bottom)
    }
  }

  private func sheetContent(width: CGFloat, bottomInset: CGFloat) -> some View {
    VStack(alignment: .leading, spacing: 22) {
      dragIndicator
        .frame(maxWidth: .infinity)
        .padding(.top, 14)

      HStack(spacing: 12) {
        SearchBarView()
        ProfileButton(store: store)
      }
      .padding(.top, 2)

      PeopleSection(people: people)

      if isExpanded {
        SavedSection(savedPlaces: savedPlaces)
          .transition(.asymmetric(
            insertion: .opacity.combined(with: .move(edge: .bottom)),
            removal: .opacity
          ))
      }

      Spacer(minLength: 0)
    }
    .padding(.horizontal, horizontalPadding(for: width))
    .padding(.bottom, bottomInset + 18)
  }

  private var dragIndicator: some View {
    Capsule(style: .continuous)
      .fill(Color.black.opacity(0.18))
      .frame(width: 40, height: 5)
  }

  private var sheetBackground: some View {
    ZStack {
      Rectangle()
        .fill(.ultraThinMaterial)

      Rectangle()
        .fill(Color.white.opacity(0.58))

      sheetShape
        .stroke(Color.white.opacity(0.58), lineWidth: 1)
    }
  }

  private var sheetShape: UnevenRoundedRectangle {
    UnevenRoundedRectangle(
      topLeadingRadius: 32,
      bottomLeadingRadius: 0,
      bottomTrailingRadius: 0,
      topTrailingRadius: 32,
      style: .continuous
    )
  }

  private func horizontalPadding(for width: CGFloat) -> CGFloat {
    width < 380 ? 16 : 20
  }

  private func sheetDragGesture(collapsedHeight: CGFloat, expandedHeight: CGFloat, targetHeight: CGFloat) -> some Gesture {
    DragGesture(minimumDistance: 8)
      .updating($dragOffset) { value, state, _ in
        state = value.translation.height
      }
      .onEnded { value in
        let projectedHeight = targetHeight - value.predictedEndTranslation.height
        let midpoint = (collapsedHeight + expandedHeight) / 2

        withAnimation(.spring(response: 0.45, dampingFraction: 0.86)) {
          if value.translation.height < -70 {
            isExpanded = true
          } else if value.translation.height > 70 {
            isExpanded = false
          } else {
            isExpanded = projectedHeight > midpoint
          }
        }
      }
  }
}

private struct SearchBarView: View {
  var body: some View {
    HStack(spacing: 12) {
      Image(systemName: "magnifyingglass")
        .font(.system(size: 18, weight: .semibold))
        .foregroundStyle(.secondary)

      Text("Search Place")
        .font(.system(size: 16, weight: .medium))
        .foregroundStyle(Color.black.opacity(0.46))

      Spacer(minLength: 8)

      Image(systemName: "mic.fill")
        .font(.system(size: 18, weight: .semibold))
        .foregroundStyle(Color.black.opacity(0.42))
    }
    .padding(.horizontal, 18)
    .frame(height: 52)
    .background {
      Capsule(style: .continuous)
        .fill(Color.white.opacity(0.56))
        .overlay {
          Capsule(style: .continuous)
            .stroke(Color.white.opacity(0.72), lineWidth: 1)
        }
    }
  }
}

private struct ProfileButton: View {
  let store: StoreOf<MainFeature>
  @State private var showingSignOut = false
    
  var body: some View {
    Button {
        showingSignOut = true
    } label: {
      Text(initials)
        .font(.system(size: 16, weight: .semibold))
        .foregroundStyle(.white)
        .frame(width: 52, height: 52)
        .background {
          Circle()
            .fill(Color(red: 0.67, green: 0.72, blue: 0.93))
            .shadow(color: Color(red: 0.45, green: 0.50, blue: 0.82).opacity(0.16), radius: 8, x: 0, y: 4)
        }
    }
    .buttonStyle(.plain)
    .confirmationDialog("Profile", isPresented: $showingSignOut, titleVisibility: .visible) {
        Button("Sign Out", role: .destructive) {
            store.send(.login(.signOutButtonTapped))
        }
        Button("Cancel", role: .cancel) {}
    } message: {
        Text("Logged in as \(emailAddress)")
    }
  }
    
  private var initials: String {
      if let name = store.login.userProfile?.name, !name.isEmpty {
          let parts = name.split(separator: " ")
          if parts.count >= 2 {
              return "\(parts[0].prefix(1))\(parts[1].prefix(1))".uppercased()
          } else {
              return String(name.prefix(2)).uppercased()
          }
      }
      return "NL"
  }
    
  private var emailAddress: String {
      store.login.userProfile?.email ?? "Unknown"
  }
}

private struct PeopleSection: View {
  let people: [Person]

  var body: some View {
    VStack(alignment: .leading, spacing: 14) {
      Text("People")
        .font(.system(size: 23, weight: .semibold))
        .foregroundStyle(Color.black.opacity(0.86))

      GeometryReader { geometry in
        let spacing: CGFloat = geometry.size.width < 360 ? 5 : 6
        let avatarSize = min(98, max(78, (geometry.size.width - (spacing * CGFloat(people.count - 1))) / CGFloat(people.count)))

        HStack(alignment: .top, spacing: spacing) {
          ForEach(people) { person in
            PersonView(person: person, avatarSize: avatarSize)
              .frame(maxWidth: .infinity)
          }
        }
        .frame(maxWidth: .infinity)
      }
      .frame(height: 146)
    }
  }
}

private struct PersonView: View {
  let person: Person
  let avatarSize: CGFloat

  var body: some View {
    VStack(spacing: 8) {
      Circle()
        .fill(Color(red: 0.77, green: 0.81, blue: 0.96))
        .overlay {
          Circle()
            .fill(.linearGradient(
              colors: [
                .white.opacity(0.42),
                .clear
              ],
              startPoint: .topLeading,
              endPoint: .bottomTrailing
            ))
        }
        .overlay {
          Text(String(person.name.prefix(1)))
            .font(.system(size: avatarSize * 0.34, weight: .semibold))
            .foregroundStyle(.white.opacity(0.92))
        }
        .frame(width: avatarSize, height: avatarSize)

      VStack(spacing: 2) {
        Text(person.name)
          .font(.system(size: 15, weight: .medium))
          .foregroundStyle(Color.black.opacity(0.82))
          .lineLimit(1)

        Text(person.status)
          .font(.system(size: 14, weight: .regular))
          .foregroundStyle(Color.black.opacity(0.45))
          .lineLimit(1)
      }
    }
    .frame(maxWidth: .infinity)
  }
}

private struct SavedSection: View {
  let savedPlaces: [SavedPlace]

  var body: some View {
    VStack(alignment: .leading, spacing: 14) {
      HStack(spacing: 4) {
        Text("Saved")
          .font(.system(size: 23, weight: .semibold))
          .foregroundStyle(Color.black.opacity(0.86))

        Image(systemName: "chevron.right")
          .font(.system(size: 16, weight: .semibold))
          .foregroundStyle(Color.black.opacity(0.76))
      }

      VStack(spacing: 0) {
        ForEach(Array(savedPlaces.enumerated()), id: \.element.id) { index, place in
          SavedPlaceRow(place: place)

          if index < savedPlaces.count - 1 {
            Divider()
              .padding(.leading, 64)
              .opacity(0.52)
          }
        }
      }
      .padding(.horizontal, 14)
      .padding(.vertical, 6)
      .background {
        RoundedRectangle(cornerRadius: 26, style: .continuous)
          .fill(Color.white.opacity(0.62))
          .overlay {
            RoundedRectangle(cornerRadius: 26, style: .continuous)
              .stroke(Color.white.opacity(0.78), lineWidth: 1)
          }
          .shadow(color: .black.opacity(0.04), radius: 12, x: 0, y: 6)
      }
    }
  }
}

private struct SavedPlaceRow: View {
  let place: SavedPlace

  var body: some View {
    HStack(spacing: 12) {
      Circle()
        .fill(Color(red: 0.78, green: 0.82, blue: 0.97).opacity(0.92))
        .overlay {
          Image(systemName: place.iconName)
            .font(.system(size: 18, weight: .semibold))
            .foregroundStyle(.white)
        }
        .frame(width: 48, height: 48)

      VStack(alignment: .leading, spacing: 4) {
        Text(place.name)
          .font(.system(size: 16, weight: .semibold))
          .foregroundStyle(Color.black.opacity(0.84))

        Text(place.subtitle)
          .font(.system(size: 13, weight: .regular))
          .foregroundStyle(Color.black.opacity(0.45))
          .lineLimit(1)
      }

      Spacer(minLength: 8)

      Button {
      } label: {
        Image(systemName: "ellipsis")
          .font(.system(size: 19, weight: .semibold))
          .foregroundStyle(Color.black.opacity(0.46))
          .frame(width: 34, height: 34)
      }
      .buttonStyle(.plain)
    }
    .frame(height: 68)
  }
}

private struct Person: Identifiable, Equatable {
  let id = UUID()
  let name: String
  let status: String
}

private struct SavedPlace: Identifiable, Equatable {
  let id = UUID()
  let name: String
  let subtitle: String
  let iconName: String
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
