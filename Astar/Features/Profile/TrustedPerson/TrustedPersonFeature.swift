import ComposableArchitecture
import Foundation
import CloudKit

struct FetchConnectionsError: Error, Equatable, Sendable {
    let message: String
}

@Reducer
struct TrustedPersonFeature {
  @ObservableState
  struct State: Equatable {
      @Presents var destination: Destination.State?
      var connections: [ConnectionProfile] = []
      var isLoading = false
      
      var mutualConnections: [ConnectionProfile] {
          let currentUserId = UserProfileStorage.load()?.recordID.recordName
          return connections.filter { 
              $0.connection.status == "mutual" ||
              ($0.connection.status == "request" && $0.connection.initiatedByRowID == currentUserId)
          }
      }
      var requestConnections: [ConnectionProfile] {
          let currentUserId = UserProfileStorage.load()?.recordID.recordName
          return connections.filter {
              $0.connection.status == "request" && $0.connection.initiatedByRowID != currentUserId
          }
      }
  }

  enum Action: Equatable {
      case onAppear
      case fetchConnectionsResponse(Result<[ConnectionProfile], FetchConnectionsError>)
      case destination(PresentationAction<Destination.Action>)
      case requestSectionTapped
      case addParticipantTapped
      case delegate(Delegate)
      case didAddPersonsResponse(Result<Bool, FetchConnectionsError>)
      
      enum Delegate: Equatable {
          case requestSectionTapped([ConnectionProfile])
      }
  }

  @Reducer(state: .equatable, action: .equatable)
  enum Destination {
      case addParticipant(AddTrustedPersonFeature)
  }

  @Dependency(\.connectionsClient) var connectionsClient
  @Dependency(\.usersClient) var usersClient

  var body: some Reducer<State, Action> {
    Reduce { state, action in
      switch action {
      case .onAppear:
          guard let profile = UserProfileStorage.load() else { return .none }
          state.isLoading = true
          return .run { send in
              do {
                  let connections = try await connectionsClient.fetchConnections(profile.recordID)
                  await send(.fetchConnectionsResponse(.success(connections)))
              } catch {
                  await send(.fetchConnectionsResponse(.failure(FetchConnectionsError(message: error.localizedDescription))))
              }
          }
          
      case let .fetchConnectionsResponse(.success(connections)):
          state.isLoading = false
          state.connections = connections
          return .none
          
      case .fetchConnectionsResponse(.failure):
          state.isLoading = false
          return .none

      case .requestSectionTapped:
          return .send(.delegate(.requestSectionTapped(state.requestConnections)))
          
      case .addParticipantTapped:
          state.destination = .addParticipant(AddTrustedPersonFeature.State())
          return .none
          
      case let .destination(.presented(.addParticipant(.delegate(.didAddPersons(emails))))):
          guard let profile = UserProfileStorage.load() else { return .none }
          state.isLoading = true
          return .run { send in
              do {
                  for email in emails {
                      print("Fetching user by email: \(email)")
                      if let partner = try await usersClient.fetchUserByEmail(email) {
                          print("Found partner user: \(partner.name), sending request...")
                          try await connectionsClient.sendRequest(profile.recordID, partner.recordID)
                          print("Request successfully saved to CloudKit!")
                      } else {
                          print("Partner user with email \(email) not found.")
                      }
                  }
                  await send(.didAddPersonsResponse(.success(true)))
              } catch {
                  print("Error occurred while adding person: \(error)")
                  await send(.didAddPersonsResponse(.failure(FetchConnectionsError(message: error.localizedDescription))))
              }
          }
          
      case .didAddPersonsResponse(.success):
          return .send(.onAppear) // Refresh the list
          
      case .didAddPersonsResponse(.failure):
          state.isLoading = false
          return .none
          
      case .destination:
          return .none
          
      case .delegate:
          return .none
      }
    }
    .ifLet(\.$destination, action: \.destination)
  }
}
