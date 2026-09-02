import ComposableArchitecture

@Reducer
struct TrustedPersonFeature {
  @ObservableState
  struct State: Equatable {
      @Presents var destination: Destination.State?
  }

  enum Action: Equatable {
      case destination(PresentationAction<Destination.Action>)
      case requestSectionTapped
      case addParticipantTapped
      case delegate(Delegate)
      
      enum Delegate: Equatable {
          case requestSectionTapped
      }
  }

  @Reducer(state: .equatable, action: .equatable)
  enum Destination {
      case addParticipant(AddTrustedPersonFeature)
  }

  var body: some Reducer<State, Action> {
    Reduce { state, action in
      switch action {
      case .requestSectionTapped:
          return .send(.delegate(.requestSectionTapped))
          
      case .addParticipantTapped:
          state.destination = .addParticipant(AddTrustedPersonFeature.State())
          return .none
          
      case let .destination(.presented(.addParticipant(.delegate(.didAddPersons(emails))))):
          print("Added emails: \(emails)")
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
