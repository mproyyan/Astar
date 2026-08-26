//
//  Model.swift
//  Astar
//
//  Created by Nadia Putri Natali Lubis on 26/08/26.
//

enum FriendshipStatus {
    case accepted
    case invited
}

struct SampleData: Identifiable {
    var id: Int
    var avatar: String
    var displayName: String
    var icloud: String
    var status: FriendshipStatus = .accepted
}

// Sample Data
var sampleData: [SampleData] = [
    SampleData(id: 1, avatar: "person.crop.circle.fill", displayName: "Pandu Royyan", icloud: "panduroyyan@icloud.com", status: .invited),
    SampleData(id: 2, avatar: "person.crop.circle.fill", displayName: "Awan Mendung", icloud: "awanmendung@icloud.com"),
    SampleData(id: 3, avatar: "person.crop.circle.fill", displayName: "Safa Hidayat", icloud: "sfhidayat@icloud.com"),
    SampleData(id: 4, avatar: "person.crop.circle.fill", displayName: "Chusen Kamal", icloud: "chusenkamal@icloud.com")
]

// Computed variable filtering for invited members
var invitedPersons: [SampleData] {
    sampleData.filter { $0.status == .invited }
}

// Computed variable filtering for accepted members
var activeFriends: [SampleData] {
    sampleData.filter { $0.status == .accepted }
}
