import Foundation

public struct WatchPerson: Codable, Identifiable, Equatable {
    public let id: String
    public let name: String
    public let status: String
    public let avatarData: Data?
    public let joinedAt: String

    public init(id: String, name: String, status: String, avatarData: Data? = nil, joinedAt: String) {
        self.id = id
        self.name = name
        self.status = status
        self.avatarData = avatarData
        self.joinedAt = joinedAt
    }
}

public struct WatchDirectionState: Codable, Equatable {
    public var destinationName: String
    public var eta: String
    public var estimatedTime: String
    public var totalDistance: String
    public var isDone: Bool
    public var watchingPeople: [WatchPerson]

    public init(
        destinationName: String = "",
        eta: String = "--.--",
        estimatedTime: String = "-- min",
        totalDistance: String = "-- km",
        isDone: Bool = false,
        watchingPeople: [WatchPerson] = []
    ) {
        self.destinationName = destinationName
        self.eta = eta
        self.estimatedTime = estimatedTime
        self.totalDistance = totalDistance
        self.isDone = isDone
        self.watchingPeople = watchingPeople
    }
}

public enum WatchActionMessage: Codable, Equatable {
    case areYouSafe
    case imSafe
    case needHelp
}
