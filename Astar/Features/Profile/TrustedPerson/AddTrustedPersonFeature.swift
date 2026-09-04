import ComposableArchitecture
import Foundation


@Reducer
struct AddTrustedPersonFeature {
  @ObservableState
  struct State: Equatable {
      var addedEmails: [String] = []
      var draft: String = ""
      var showInvalidHint: Bool = false
  }

  enum Action: Equatable {
      case draftChanged(String)
      case commitDraft
      case removeEmail(String)
      case commitSelection
      case delegate(Delegate)
      
      enum Delegate: Equatable {
          case didAddPersons([String])
      }
  }

  @Dependency(\.dismiss) var dismiss

  var body: some Reducer<State, Action> {
    Reduce { state, action in
      switch action {
      case let .draftChanged(draft):
          state.draft = draft
          if let last = draft.last, last == " " || last == "," {
              return .send(.commitDraft)
          } else {
              state.showInvalidHint = false
              return .none
          }
      case .commitDraft:
          let candidate = state.draft.trimmingCharacters(in: CharacterSet.whitespaces.union(CharacterSet(charactersIn: ",")))
          guard !candidate.isEmpty else { return .none }
          
          let regex = #"^[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$"#
          let isValid = candidate.range(of: regex, options: .regularExpression) != nil
          
          if isValid {
              if !state.addedEmails.contains(candidate) {
                  state.addedEmails.append(candidate)
              }
              state.draft = ""
              state.showInvalidHint = false
          } else {
              state.showInvalidHint = true
          }
          return .none
      case let .removeEmail(email):
          state.addedEmails.removeAll { $0 == email }
          return .none
      case .commitSelection:
          let emails = state.addedEmails
          return .run { send in
              await send(.delegate(.didAddPersons(emails)))
              await self.dismiss()
          }
      case .delegate:
          return .none
      }
    }
  }
}
