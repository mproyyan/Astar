import Foundation

struct FetchUsersError: Error, Equatable, Sendable {
    let message: String
    init(error: Error) {
        self.message = error.localizedDescription
    }
}
