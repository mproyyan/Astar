import CloudKit
import ComposableArchitecture
import Foundation
import Combine

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
    
    var setSubscribeWalkSession: @Sendable (_ sessionID: String, _ isSubscribed: Bool) async throws -> Void
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
            print("[endWalkSession] called for session: \(sessionID)")
            let db = CKContainer.default().publicCloudDatabase
            let id = CKRecord.ID(recordName: sessionID)
            do {
                let record = try await db.record(for: id)
                record["status"] = "completed"
                record["endedAt"] = Date()
                try await db.save(record)
                print("[endWalkSession] status set to completed for \(sessionID)")
            } catch {
                print("[endWalkSession] FAILED: \(error)")
                throw error
            }
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
            let pingRecordID = CKRecord.ID(recordName: "LocationPing_\(sessionID)")
            let pingRecord = CKRecord(recordType: "LocationPing", recordID: pingRecordID)
            let sessionRef = CKRecord.Reference(recordID: CKRecord.ID(recordName: sessionID), action: .none)

            pingRecord["sessionRef"] = sessionRef
            pingRecord["encodedCoordinates"] = [coordinatesData]
            pingRecord["recordedAt"] = Date()

            // Save single deterministic record with changedKeys policy
            let (saveResults, _) = try await db.modifyRecords(
                saving: [pingRecord],
                deleting: [],
                savePolicy: .changedKeys,
                atomically: false
            )
            for (_, result) in saveResults {
                if case .failure(let error) = result {
                    print("[pushLocationPing] LocationPing save failed: \(error)")
                    throw error
                }
            }

            // Update WalkSession lastPingAt without a fetch-then-save race
            do {
                let sessionRecordID = CKRecord.ID(recordName: sessionID)
                let sessionRecord = CKRecord(recordType: "WalkSession", recordID: sessionRecordID)
                sessionRecord["lastPingAt"] = Date()

                let (sessionSaveResults, _) = try await db.modifyRecords(
                    saving: [sessionRecord],
                    deleting: [],
                    savePolicy: .changedKeys,
                    atomically: false
                )
                for (_, result) in sessionSaveResults {
                    if case .failure(let error) = result {
                        print("[pushLocationPing] lastPingAt update failed: \(error)")
                    }
                }
            } catch {
                print("[pushLocationPing] lastPingAt update threw: \(error)")
            }
        },
        setSubscribeWalkSession: { sessionID, isSubscribed in
            let container = CKContainer.default()
            let db = container.publicCloudDatabase
            
            let subscriptionID = "walk-session-\(sessionID)"
            
            if !isSubscribed {
                print("[TrackingClient] Attempting to unsubscribe: \(subscriptionID)")
                do {
                    try await db.deleteSubscription(withID: subscriptionID)
                    print("Unsubscribed from session: \(sessionID)")
                } catch let error as CKError where error.code == .unknownItem {
                    
                } catch {
                    throw error
                }
                return
            }
            
            // Subscribe flow
            print("[TrackingClient] Checking existing subscription: \(subscriptionID)")
            do {
                _ = try await db.subscription(for: subscriptionID)
                print("Already subscribed to session: \(sessionID)")
                return
            } catch let error as CKError where error.code == .unknownItem {
                print("[TrackingClient] Subscription missing, creating new one...")
                // Subscription does not exist, proceed to create
            } catch {
                print("[TrackingClient] Subscription check error: \(error.localizedDescription)")
                throw error
            }
            
            let pingRecordID = CKRecord.ID(recordName: "LocationPing_\(sessionID)")
            let predicate = NSPredicate(format: "recordID == %@", pingRecordID)
            
            let subscription = CKQuerySubscription(
                recordType: "LocationPing",
                predicate: predicate,
                subscriptionID: subscriptionID,
                options: [.firesOnRecordCreation, .firesOnRecordUpdate, .firesOnRecordDeletion]
            )
            
            let info = CKSubscription.NotificationInfo()
            // 1. triggers silent push to wake the app in background
            info.shouldSendContentAvailable = true
            // 2. triggers visual push alert so we can see it during demo
            info.alertBody = "A location was updated in the public database."
            info.soundName = "default"
            info.desiredKeys = ["encodedCoordinates", "sessionRef", "recordedAt"]
            
            subscription.notificationInfo = info
            
            print("📤 [TrackingClient] Saving CKQuerySubscription for LocationPing: \(pingRecordID.recordName)...")
            try await db.save(subscription)
            print("✅ [TrackingClient] Subscribed successfully to LocationPing for session: \(sessionID)")
        },
        
        
        subscribeToLocationPings: { sessionID in
            AsyncStream { (continuation: AsyncStream<LocationPing>.Continuation) in
                let db = CKContainer.default().publicCloudDatabase
                let expectedPingRecordName = "LocationPing_\(sessionID)"
                
                let task = Task {
                    for await notification in NotificationCenter.default.publisher(for: AppDelegate.locationPingNotification).values {
                        guard !Task.isCancelled else { break }
                        
                        print("[TrackingClient] Push notification received in NotificationCenter!")
                        
                        guard let userInfo = notification.userInfo,
                              let recordID = userInfo["recordID"] as? CKRecord.ID else {
                            print("[TrackingClient] Notification missing recordID in userInfo")
                            continue
                        }
                        
                        print("[TrackingClient] RecordID in push: \(recordID.recordName) | Target SessionID: \(sessionID)")
                        
                        guard recordID.recordName == expectedPingRecordName || recordID.recordName == sessionID else {
                            print("[TrackingClient] Ignored notification for non-matching record: \(recordID.recordName) (expected: \(expectedPingRecordName))")
                            continue
                        }
                        
                        print("[Push] Fetching ping record: \(recordID.recordName)")
                        
                        do {
                            let record = try await db.record(for: recordID)
                            print("[TrackingClient] Successfully fetched record: \(record.recordID.recordName)")
                            
                            let refSessionID = (record["sessionRef"] as? CKRecord.Reference)?.recordID.recordName ?? sessionID
                            if let encodedCoordinates = record["encodedCoordinates"] as? [Data],
                               refSessionID == sessionID {
                                
                                let ping = LocationPing(
                                    id: record.recordID.recordName,
                                    sessionRef: refSessionID,
                                    encodedCoordinates: encodedCoordinates,
                                    recordedAt: record["recordedAt"] as? Date ?? Date()
                                )
                                
                                print("[TrackingClient] Yielding ping with \(encodedCoordinates.count) coordinates at \(ping.recordedAt)")
                                continuation.yield(ping)
                            } else {
                                print("[TrackingClient] 'encodedCoordinates' is nil or invalid in CloudKit record")
                            }
                        } catch {
                            print("[Push] Error fetching ping record: \(error)")
                        }
                    }
                }
                
                continuation.onTermination = { @Sendable _ in
                    print("[Stream] Stream terminated/cancelled.")
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
