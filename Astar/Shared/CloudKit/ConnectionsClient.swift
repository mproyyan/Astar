/// ============================================================================
/// 🤝 CLOUDKIT GRAPH CONNECTIONS CLIENT (ConnectionsClient)
/// ============================================================================
///
/// 💡 COMPUTER SCIENCE CONCEPTS:
/// - **Social Graph & Relational Mapping**: CloudKit acts as a distributed graph database.
///   A connection represents an edge in an undirected/directed social graph between two nodes
///   (users): `Node(UserA) <--- Edge(Connection: status) ---> Node(UserB)`.
/// - **Dual-Lookup / Disjunctive Query (OR Query)**:
///   Because an edge between A and B can be stored with A as `member1` or B as `member1`,
///   querying requires checking both orientations: `(member1 == me OR member2 == me)`.
/// - **Dependency Injection Pattern**:
///   Using TCA's `@DependencyClient`, this struct decouples database I/O from presentation logic,
///   allowing test suites to run isolated mock graphs without network latency or CloudKit quotas.
///
/// 🌍 REAL-LIFE ANALOGY:
///   Think of two people exchanging business cards. Either Alice hands a card to Bob or Bob
///   hands one to Alice (the Edge). When the police/receptionist checks if Alice and Bob are
///   connected, they look through Alice's card collection AND Bob's card collection. Once both
///   agree ("mutual"), they can track each other's journey.
/// ============================================================================
import CloudKit
import ComposableArchitecture
import Foundation

struct Connection: Equatable, Sendable, Identifiable {
    let id: String
    let member1RowID: String
    let member2RowID: String
    let initiatedByRowID: String
    let status: String  // e.g., "request", "mutual", "rejected"
    let createdAt: Date
    let updatedAt: Date
}

struct ConnectionProfile: Equatable, Sendable, Identifiable {
    let connection: Connection
    let partnerProfile: UserProfile
    var id: String { connection.id }
}

@DependencyClient
struct ConnectionsClient: Sendable {
    var fetchConnections: @Sendable (_ userRecordID: CKRecord.ID) async throws -> [ConnectionProfile]
    var sendRequest: @Sendable (_ currentUserID: CKRecord.ID, _ partnerUserID: CKRecord.ID) async throws -> Void
    var updateStatus: @Sendable (_ connectionID: String, _ status: String) async throws -> Void
    var deleteConnection: @Sendable (_ connectionID: String) async throws -> Void
}

extension ConnectionsClient: DependencyKey {
    static let liveValue = ConnectionsClient(
        fetchConnections: { userRecordID in
            let db = CKContainer.default().publicCloudDatabase
            let userRef = CKRecord.Reference(recordID: userRecordID, action: .none)
            
            let predicate1 = NSPredicate(format: "member1 == %@", userRef)
            let query1 = CKQuery(recordType: "Connection", predicate: predicate1)
            let (matchResults1, _) = try await db.records(matching: query1)
            
            let predicate2 = NSPredicate(format: "member2 == %@", userRef)
            let query2 = CKQuery(recordType: "Connection", predicate: predicate2)
            let (matchResults2, _) = try await db.records(matching: query2)
            
            // Gabungkan result
            var allMatchResults = matchResults1
            for result in matchResults2 {
                if !allMatchResults.contains(where: { $0.0 == result.0 }) {
                    allMatchResults.append(result)
                }
            }
            
            let matchResults = allMatchResults
            
            var connectionProfiles: [ConnectionProfile] = []
            
            for matchResult in matchResults {
                guard case let .success(record) = matchResult.1,
                      let member1Ref = record["member1"] as? CKRecord.Reference,
                      let member2Ref = record["member2"] as? CKRecord.Reference,
                      let initiatedByRef = record["initiatedBy"] as? CKRecord.Reference,
                      let status = record["status"] as? String,
                      let createdAt = record["createdAt"] as? Date,
                      let updatedAt = record["updatedAt"] as? Date else {
                    continue
                }
                
                let connection = Connection(
                    id: record.recordID.recordName,
                    member1RowID: member1Ref.recordID.recordName,
                    member2RowID: member2Ref.recordID.recordName,
                    initiatedByRowID: initiatedByRef.recordID.recordName,
                    status: status,
                    createdAt: createdAt,
                    updatedAt: updatedAt
                )
                
                let partnerRecordID = (member1Ref.recordID.recordName == userRecordID.recordName) ? member2Ref.recordID : member1Ref.recordID
                
                do {
                    let partnerRecord = try await db.record(for: partnerRecordID)
                    if let appleUserId = partnerRecord["appleUserId"] as? String,
                       let cloudKitUserId = partnerRecord["cloudKitUserId"] as? String,
                       let name = partnerRecord["name"] as? String,
                       let email = partnerRecord["email"] as? String {
                        
                        let profile = UserProfile(
                            appleUserId: appleUserId,
                            cloudKitUserId: cloudKitUserId,
                            name: name,
                            email: email,
                            status: partnerRecord["Status"] as? String,
                            avatarData: partnerRecord["avatarData"] as? Data
                        )
                        
                        connectionProfiles.append(ConnectionProfile(connection: connection, partnerProfile: profile))
                    }
                } catch {
                    print("Failed to fetch partner profile: \(error)")
                }
            }
            
            return connectionProfiles
        },
        sendRequest: { currentUserID, partnerUserID in
            let db = CKContainer.default().publicCloudDatabase
            let record = CKRecord(recordType: "Connection")
            
            let currentRef = CKRecord.Reference(recordID: currentUserID, action: .none)
            let partnerRef = CKRecord.Reference(recordID: partnerUserID, action: .none)
            
            record["member1"] = currentRef
            record["member2"] = partnerRef
            record["initiatedBy"] = currentRef
            record["status"] = "request" as CKRecordValue
            record["createdAt"] = Date() as CKRecordValue
            record["updatedAt"] = Date() as CKRecordValue
            
            try await db.save(record)
        },
        updateStatus: { connectionID, status in
            let db = CKContainer.default().publicCloudDatabase
            let recordID = CKRecord.ID(recordName: connectionID)
            let record = try await db.record(for: recordID)
            
            record["status"] = status as CKRecordValue
            record["updatedAt"] = Date() as CKRecordValue
            
            try await db.save(record)
        },
        deleteConnection: { connectionID in
            let db = CKContainer.default().publicCloudDatabase
            let recordID = CKRecord.ID(recordName: connectionID)
            try await db.deleteRecord(withID: recordID)
        }
    )
    
    static let testValue = Self()
}

extension DependencyValues {
    var connectionsClient: ConnectionsClient {
        get { self[ConnectionsClient.self] }
        set { self[ConnectionsClient.self] = newValue }
    }
}
