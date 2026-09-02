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
    let currentCoordinate: Data?
    let lastPingAt: Date
}

struct SessionParticipant: Equatable, Sendable {
    let id: String
    let sessionRef: String
    let companionRef: String
    let joinedAt: Date
}

@DependencyClient
struct TrackingClient: Sendable {
    var startWalkSession: @Sendable (_ walkerRecordID: String, _ destinationName: String, _ destLat: Double, _ destLon: Double, _ routePolyline: String?, _ initialCoordinateData: Data) async throws -> WalkSession
    var endWalkSession: @Sendable (_ sessionID: String) async throws -> Void
    var joinWalkSession: @Sendable (_ sessionID: String, _ companionRecordID: String) async throws -> SessionParticipant
    var leaveWalkSession: @Sendable (_ participantID: String) async throws -> Void
    var updateUserStatus: @Sendable (_ userRecordID: String, _ status: String, _ activeSessionID: String?, _ watchingSessionID: String?) async throws -> Void
    var pushLocationUpdate: @Sendable (_ sessionID: String, _ coordinatesData: Data) async throws -> Void
    
    var setSubscribeWalkSession: @Sendable (_ sessionID: String, _ isSubscribed: Bool) async throws -> Void
    var subscribeToWalkSession: @Sendable (_ sessionID: String) async throws -> AsyncStream<WalkSession>
    
    var getWalkSession: @Sendable (_ sessionID: String) async throws -> WalkSession
    var getWalkerActiveSessionID: @Sendable (_ walkerRecordID: String) async throws -> String?
}

extension TrackingClient: DependencyKey {
    static let liveValue = TrackingClient(
        startWalkSession: { walkerRecordID, destName, destLat, destLon, routePolyline, initialCoordinateData in
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
            record["currentCoordinate"] = initialCoordinateData
            
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
                currentCoordinate: initialCoordinateData,
                lastPingAt: record["lastPingAt"] as? Date ?? Date()
            )
        },
        endWalkSession: { sessionID in
            print("[endWalkSession] called for session: \(sessionID)")
            let db = CKContainer.default().publicCloudDatabase
            let id = CKRecord.ID(recordName: sessionID)
            
            let sessionRecord = CKRecord(recordType: "WalkSession", recordID: id)
            sessionRecord["status"] = "completed"
            sessionRecord["endedAt"] = Date()
            
            do {
                let (saveResults, _) = try await db.modifyRecords(
                    saving: [sessionRecord],
                    deleting: [],
                    savePolicy: .changedKeys,
                    atomically: false
                )
                for (_, result) in saveResults {
                    if case .failure(let error) = result {
                        print("❌ [endWalkSession] WalkSession save failed: \(error)")
                        throw error
                    }
                }
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
        pushLocationUpdate: { sessionID, coordinatesData in
            let db = CKContainer.default().publicCloudDatabase
            let pingTime = Date()
            
            let sessionRecordID = CKRecord.ID(recordName: sessionID)
            let sessionRecord = CKRecord(recordType: "WalkSession", recordID: sessionRecordID)
            sessionRecord["currentCoordinate"] = coordinatesData
            sessionRecord["lastPingAt"] = pingTime
            
            if let coords = try? JSONDecoder().decode([Double].self, from: coordinatesData), coords.count >= 2 {
                print("📤 [TrackingClient.pushLocationUpdate] Updating WalkSession at \(pingTime) for session \(sessionID) | Lat: \(coords[0]), Lon: \(coords[1])")
            } else {
                print("📤 [TrackingClient.pushLocationUpdate] Updating WalkSession location at \(pingTime) for session \(sessionID)")
            }
            
            do {
                let (sessionSaveResults, _) = try await db.modifyRecords(
                    saving: [sessionRecord],
                    deleting: [],
                    savePolicy: .changedKeys,
                    atomically: false
                )
                for (_, result) in sessionSaveResults {
                    if case .failure(let error) = result {
                        print("⚠️ [pushLocationUpdate] WalkSession update failed at \(Date()): \(error)")
                        throw error
                    }
                }
            } catch {
                print("⚠️ [pushLocationUpdate] WalkSession update threw at \(Date()): \(error)")
                throw error
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
            
            print("[TrackingClient] Checking existing subscription: \(subscriptionID)")
            do {
                _ = try await db.subscription(for: subscriptionID)
                print("Already subscribed to session: \(sessionID)")
                return
            } catch let error as CKError where error.code == .unknownItem {
                print("[TrackingClient] Subscription missing, creating new one...")
            } catch {
                print("[TrackingClient] Subscription check error: \(error.localizedDescription)")
                throw error
            }
            
            let sessionRecordID = CKRecord.ID(recordName: sessionID)
            let predicate = NSPredicate(format: "recordID == %@", sessionRecordID)
            
            let subscription = CKQuerySubscription(
                recordType: "WalkSession",
                predicate: predicate,
                subscriptionID: subscriptionID,
                options: [.firesOnRecordUpdate, .firesOnRecordDeletion]
            )
            
            let info = CKSubscription.NotificationInfo()
            info.shouldSendContentAvailable = true
            info.alertBody = "Walk session was updated."
            info.soundName = "default"
            info.desiredKeys = ["currentCoordinate", "status", "lastPingAt"]
            
            subscription.notificationInfo = info
            
            print("📤 [TrackingClient] Saving CKQuerySubscription for WalkSession: \(sessionRecordID.recordName)...")
            try await db.save(subscription)
            print("✅ [TrackingClient] Subscribed successfully to WalkSession for session: \(sessionID)")
        },
        subscribeToWalkSession: { sessionID in
            AsyncStream { (continuation: AsyncStream<WalkSession>.Continuation) in
                let db = CKContainer.default().publicCloudDatabase
                let expectedRecordName = sessionID
                
                let task = Task {
                    var lastCompletedSent = false
                    for await notification in NotificationCenter.default.publisher(for: Notification.Name("walkSessionUpdateNotification")).values {
                        guard !Task.isCancelled else { break }
                        let receiveTime = (notification.userInfo?["receivedAt"] as? Date) ?? Date()
                        
                        guard let userInfo = notification.userInfo,
                              let recordID = userInfo["recordID"] as? CKRecord.ID else {
                            continue
                        }
                        
                        guard recordID.recordName == expectedRecordName else {
                            continue
                        }
                        
                        print("⚡️ [TrackingClient] Fetching WalkSession record \(recordID.recordName) from CloudKit...")
                        
                        do {
                            let record = try await db.record(for: recordID)
                            let walkerRef = (record["walkerRef"] as? CKRecord.Reference)?.recordID.recordName ?? ""
                            
                            let walkSession = WalkSession(
                                id: sessionID,
                                walkerRef: walkerRef,
                                status: record["status"] as? String ?? "",
                                destinationName: record["destinationName"] as? String ?? "",
                                destinationLatitude: record["destinationLatitude"] as? Double ?? 0.0,
                                destinationLongitude: record["destinationLongitude"] as? Double ?? 0.0,
                                routePolyline: record["routePolyline"] as? String,
                                startedAt: record["startedAt"] as? Date ?? Date(),
                                endedAt: record["endedAt"] as? Date,
                                currentCoordinate: record["currentCoordinate"] as? Data,
                                lastPingAt: record["lastPingAt"] as? Date ?? Date()
                            )
                            
                            print("📍 [APNs -> TrackingClient] Yielding WalkSession Update: \(walkSession.status) | ReceivedAt: \(receiveTime)")
                            continuation.yield(walkSession)
                            
                            if walkSession.status == "completed" || walkSession.status == "arrived" {
                                print("🏁 [TrackingClient] session completed, terminating stream.")
                                if !lastCompletedSent {
                                    lastCompletedSent = true
                                    continuation.finish()
                                }
                                break
                            }
                            
                        } catch {
                            print("❌ [TrackingClient] Error fetching walk session record \(recordID.recordName): \(error)")
                        }
                    }
                }
                
                continuation.onTermination = { @Sendable _ in
                    print("[Stream] Stream terminated/cancelled at \(Date()).")
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
                currentCoordinate: record["currentCoordinate"] as? Data,
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
