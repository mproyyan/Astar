import ComposableArchitecture
import Foundation
import CloudKit

struct ConnectionActionError: Error, Equatable, Sendable {
    let message: String
}

@Reducer
struct RequestTrustedPersonFeature {
  @ObservableState
  struct State: Equatable {
      var requests: [ConnectionProfile] = []
  }

  enum Action: Equatable {
      case confirmTapped(String)
      case deleteTapped(String)
      case confirmResponse(Result<String, ConnectionActionError>)
      case deleteResponse(Result<String, ConnectionActionError>)
  }

  @Dependency(\.connectionsClient) var connectionsClient

  var body: some Reducer<State, Action> {
    Reduce { state, action in
      switch action {
      case let .confirmTapped(connectionID):
          return .run { send in
              do {
                  try await connectionsClient.updateStatus(connectionID, "mutual")
                  await send(.confirmResponse(.success(connectionID)))
              } catch {
                  await send(.confirmResponse(.failure(ConnectionActionError(message: error.localizedDescription))))
              }
          }
      case let .deleteTapped(connectionID):
          return .run { send in
              do {
                  try await connectionsClient.deleteConnection(connectionID)
                  await send(.deleteResponse(.success(connectionID)))
              } catch {
                  await send(.deleteResponse(.failure(ConnectionActionError(message: error.localizedDescription))))
              }
          }
      case let .confirmResponse(.success(connectionID)):
          state.requests.removeAll { $0.connection.id == connectionID }
          return .none
      case .confirmResponse(.failure):
          return .none
      case let .deleteResponse(.success(connectionID)):
          state.requests.removeAll { $0.connection.id == connectionID }
          return .none
      case .deleteResponse(.failure):
          return .none
      }
    }
  }
}
