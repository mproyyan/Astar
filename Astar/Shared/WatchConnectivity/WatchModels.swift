import Foundation

public struct WatchPerson: Codable, Equatable, Identifiable {
    public let id: String
    public let name: String
    public let status: String

    public init(id: String = UUID().uuidString, name: String, status: String) {
        self.id = id
        self.name = name
        self.status = status
    }
}

public struct WatchDirectionState: Codable, Equatable {
    public var destinationName: String
    public var eta: String
    public var estimatedTime: String
    public var totalDistance: String
    public var isDone: Bool
    public var watchingPeople: [WatchPerson]

    public init(destinationName: String = "", eta: String = "--.--", estimatedTime: String = "--", totalDistance: String = "--", isDone: Bool = false, watchingPeople: [WatchPerson] = []) {
        self.destinationName = destinationName
        self.eta = eta
        self.estimatedTime = estimatedTime
        self.totalDistance = totalDistance
        self.isDone = isDone
        self.watchingPeople = watchingPeople
    }
}

public enum WatchActionMessage: Codable, Equatable {
    case areYouSafe(message: String)
    case imSafe
    case needHelp
}