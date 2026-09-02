import ComposableArchitecture

@Reducer
struct RequestTrustedPersonFeature {
  @ObservableState
  struct State: Equatable {
  }

  enum Action: Equatable {
  }

  var body: some Reducer<State, Action> {
    Reduce { state, action in
      switch action {
      }
    }
  }
}
