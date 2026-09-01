import CloudKit
import ComposableArchitecture
import Foundation

// Data models
struct WalkSession: Equatable, Sendable {
    let id: String
    let walkerRef: String
    var status: String
    let destinationName: String
    let destinationLatitude: Double
    let destinationLongitude: Double
    let routePolyline: String?
    let startedAt: Date
    let endedAt: Date?
    let lastPingAt: Date
}

struct SessionParticipant: Equatable, Sendable {
    let id: String
    let sessionRef: String
    let companionRef: String
    let joinedAt: Date
}

struct LocationPing: Equatable, Sendable {
    let id: String
    let sessionRef: String
    let encodedCoordinates: [Data]
    let recordedAt: Date
}

@DependencyClient
struct TrackingClient: Sendable {
    var startWalkSession: @Sendable (_ walkerRecordID: String, _ destinationName: String, _ destLat: Double, _ destLon: Double, _ routePolyline: String?) async throws -> WalkSession
    var endWalkSession: @Sendable (_ sessionID: String) async throws -> Void
    var joinWalkSession: @Sendable (_ sessionID: String, _ companionRecordID: String) async throws -> SessionParticipant
    var leaveWalkSession: @Sendable (_ participantID: String) async throws -> Void
    var updateUserStatus: @Sendable (_ userRecordID: String, _ status: String, _ activeSessionID: String?, _ watchingSessionID: String?) async throws -> Void
    var pushLocationPing: @Sendable (_ sessionID: String, _ coordinatesData: Data) async throws -> Void
    var subscribeToLocationPings: @Sendable (_ sessionID: String) async throws -> AsyncStream<LocationPing>

    var getWalkSession: @Sendable (_ sessionID: String) async throws -> WalkSession
    var getWalkerActiveSessionID: @Sendable (_ walkerRecordID: String) async throws -> String?
}

extension TrackingClient: DependencyKey {
    static let liveValue = TrackingClient(
        startWalkSession: { walkerRecordID, destName, destLat, destLon, routePolyline in
            let db = CKContainer.default().publicCloudDatabase
            let record = CKRecord(recordType: "WalkSession")
            let walkerRef = CKRecord.Reference(recordID: CKRecord.ID(recordName: walkerRecordID), action: .none)
            
            record["walkerRef"] = walkerRef
            record["status"] = "active"
            record["destinationName"] = destName
            record["destinationLatitude"] = destLat
            record["destinationLongitude"] = destLon
            if let poly = routePolyline { record["routePolyline"] = poly }
            record["startedAt"] = Date()
            record["lastPingAt"] = Date()
            
            try await db.save(record)
            
            return WalkSession(
                id: record.recordID.recordName,
                walkerRef: walkerRecordID,
                status: "active",
                destinationName: destName,
                destinationLatitude: destLat,
                destinationLongitude: destLon,
                routePolyline: routePolyline,
                startedAt: record["startedAt"] as? Date ?? Date(),
                endedAt: nil,
                lastPingAt: record["lastPingAt"] as? Date ?? Date()
            )
        },
        endWalkSession: { sessionID in
            let db = CKContainer.default().publicCloudDatabase
            let id = CKRecord.ID(recordName: sessionID)
            let record = try await db.record(for: id)
            record["status"] = "completed"
            record["endedAt"] = Date()
            try await db.save(record)
        },
        joinWalkSession: { sessionID, companionRecordID in
            let db = CKContainer.default().publicCloudDatabase
            let record = CKRecord(recordType: "SessionParticipant")
            let sessionRef = CKRecord.Reference(recordID: CKRecord.ID(recordName: sessionID), action: .none)
            let companionRef = CKRecord.Reference(recordID: CKRecord.ID(recordName: companionRecordID), action: .none)
            
            record["sessionRef"] = sessionRef
            record["companionRef"] = companionRef
            record["joinedAt"] = Date()
            
            try await db.save(record)
            
            return SessionParticipant(
                id: record.recordID.recordName,
                sessionRef: sessionID,
                companionRef: companionRecordID,
                joinedAt: record["joinedAt"] as? Date ?? Date()
            )
        },
        leaveWalkSession: { participantID in
            let db = CKContainer.default().publicCloudDatabase
            let id = CKRecord.ID(recordName: participantID)
            try await db.deleteRecord(withID: id)
        },
        updateUserStatus: { userRecordID, status, activeSessionID, watchingSessionID in
            let db = CKContainer.default().publicCloudDatabase
            let id = CKRecord.ID(recordName: userRecordID)
            let record = try await db.record(for: id)
            
            record["Status"] = status
            
            if let activeID = activeSessionID {
                record["activeWalkSessionRef"] = CKRecord.Reference(recordID: CKRecord.ID(recordName: activeID), action: .none)
            } else {
                record["activeWalkSessionRef"] = nil
            }
            
            if let watchingID = watchingSessionID {
                record["watchingSessionRef"] = CKRecord.Reference(recordID: CKRecord.ID(recordName: watchingID), action: .none)
            } else {
                record["watchingSessionRef"] = nil
            }
            
            try await db.save(record)
        },
        pushLocationPing: { sessionID, coordinatesData in
            let db = CKContainer.default().publicCloudDatabase
            let record = CKRecord(recordType: "LocationPing")
            let sessionRef = CKRecord.Reference(recordID: CKRecord.ID(recordName: sessionID), action: .none)
            
            record["sessionRef"] = sessionRef
            record["encodedCoordinates"] = [coordinatesData]
            record["recordedAt"] = Date()
            
            try await db.save(record)
            
            // Also update WalkSession lastPingAt
            let sessionRecord = try await db.record(for: CKRecord.ID(recordName: sessionID))
            sessionRecord["lastPingAt"] = Date()
            try await db.save(sessionRecord)
        },
        subscribeToLocationPings: { sessionID in
            AsyncStream { (continuation: AsyncStream<LocationPing>.Continuation) in
                let db = CKContainer.default().publicCloudDatabase

                // We use pure polling so no CKQuerySubscription or Remote Notifications are needed.
                let task = Task {
                    // Try to fetch the session first to know its walkerRef
                    var walkerRefStr: String? = nil
                    do {
                        let id = CKRecord.ID(recordName: sessionID)
                        let record = try await db.record(for: id)
                        walkerRefStr = (record["walkerRef"] as? CKRecord.Reference)?.recordID.recordName
                    } catch {
                        print("📡 [Polling] Failed to get session to determine walkerRef: \(error)")
                    }

                    while !Task.isCancelled {
                        print("📡 [Polling] Getting pings for \(sessionID)")
                        let query = CKQuery(recordType: "LocationPing", predicate: NSPredicate(value: true))
                        // Removed sortDescriptors by creationDate to prevent "Field '___createTime' is not marked sortable" error

                        do {
                            let (matchResults, _) = try await db.records(matching: query)
                            // Filter matches locally! (Inefficient for prod, but good for debug!)
                            let sortedRecords = matchResults.compactMap { try? $0.1.get() }
                                .filter { record in
                                     if let ref = record["sessionRef"] as? CKRecord.Reference {
                                         let refName = ref.recordID.recordName
                                         if refName == sessionID { return true }
                                         if let wRef = walkerRefStr, refName == wRef { return true }
                                     }
                                     return false
                                }
                                .sorted {
                                    ($0.creationDate ?? Date.distantPast) > ($1.creationDate ?? Date.distantPast)
                                }

                            if let record = sortedRecords.first {
                                if let encodedCoordinates = record["encodedCoordinates"] as? [Data],
                                   let sessionRef = (record["sessionRef"] as? CKRecord.Reference)?.recordID.recordName {

                                    let ping = LocationPing(
                                        id: record.recordID.recordName,
                                        sessionRef: sessionRef,
                                        encodedCoordinates: encodedCoordinates,
                                        recordedAt: record.creationDate ?? Date()
                                    )
                                    continuation.yield(ping)
                                } else {
                                    print("📡 [Polling] Record found but fields missing.")
                                }
                            }
                        } catch {
                            print("📡 [Polling] error: \(error)")
                        }

                        try? await Task.sleep(nanoseconds: 3_000_000_000) // Poll every 3 seconds
                    }
                    print("📡 [Polling] Task cancelled loop exit.")
                }

                continuation.onTermination = { @Sendable _ in
                    print("📡 [Polling] Stream terminated/cancelled.")
                    task.cancel()
                }
            }
        },
        getWalkSession: { sessionID in
            let db = CKContainer.default().publicCloudDatabase
            let id = CKRecord.ID(recordName: sessionID)
            let record = try await db.record(for: id)
            let walkerRef = (record["walkerRef"] as? CKRecord.Reference)?.recordID.recordName ?? ""

            return WalkSession(
                id: sessionID,
                walkerRef: walkerRef,
                status: record["status"] as? String ?? "",
                destinationName: record["destinationName"] as? String ?? "",
                destinationLatitude: record["destinationLatitude"] as? Double ?? 0.0,
                destinationLongitude: record["destinationLongitude"] as? Double ?? 0.0,
                routePolyline: record["routePolyline"] as? String,
                startedAt: record["startedAt"] as? Date ?? Date(),
                endedAt: record["endedAt"] as? Date,
                lastPingAt: record["lastPingAt"] as? Date ?? Date()
            )
        },
        getWalkerActiveSessionID: { walkerRecordID in
            let db = CKContainer.default().publicCloudDatabase
            let id = CKRecord.ID(recordName: walkerRecordID)
            let record = try await db.record(for: id)
            return (record["activeWalkSessionRef"] as? CKRecord.Reference)?.recordID.recordName
        }
    )

    static let testValue = Self()
}

extension DependencyValues {
    var trackingClient: TrackingClient {
        get { self[TrackingClient.self] }
        set { self[TrackingClient.self] = newValue }
    }
}
