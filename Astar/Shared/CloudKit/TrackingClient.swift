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
    var status: String
    var joinedAt: Date?
    var leftAt: Date?
}

@DependencyClient
struct TrackingClient: Sendable {
    var startWalkSession: @Sendable (_ walkerRecordID: String, _ destinationName: String, _ destLat: Double, _ destLon: Double, _ routePolyline: String?, _ initialCoordinateData: Data) async throws -> WalkSession
    var endWalkSession: @Sendable (_ sessionID: String) async throws -> Void
    var inviteToWalkSession: @Sendable (_ sessionID: String, _ companionRecordID: String) async throws -> Void
    var updateParticipantStatus: @Sendable (_ sessionID: String, _ companionRecordID: String, _ status: String) async throws -> SessionParticipant
    var updateUserStatus: @Sendable (_ userRecordID: String, _ status: String, _ activeSessionID: String?, _ watchingSessionID: String?) async throws -> Void
    var pushLocationUpdate: @Sendable (_ sessionID: String, _ coordinatesData: Data) async throws -> Void
    var addJourneyLog: @Sendable (_ sessionID: String, _ entry: JourneyLogEntry) async throws -> Void
    var fetchJourneyLogs: @Sendable (_ sessionID: String) async throws -> [JourneyLogEntry]
    var subscribeToJourneyLogs: @Sendable (_ sessionID: String) async throws -> AsyncStream<[JourneyLogEntry]>
    
    var setSubscribeWalkSession: @Sendable (_ sessionID: String, _ isSubscribed: Bool) async throws -> Void
    var subscribeToWalkSession: @Sendable (_ sessionID: String) async throws -> AsyncStream<WalkSession>
    var setupInvitationSubscription: @Sendable (_ companionRecordID: String) async throws -> Void
    
    var getWalkSession: @Sendable (_ sessionID: String) async throws -> WalkSession
    var getWalkerActiveSessionID: @Sendable (_ walkerRecordID: String) async throws -> String?
    var fetchSessionParticipant: @Sendable (_ participantRecordID: String) async throws -> SessionParticipant
    var fetchSessionParticipants: @Sendable (_ sessionID: String) async throws -> [SessionParticipant]
    var setSubscribeSessionParticipants: @Sendable (_ sessionID: String, _ isSubscribed: Bool) async throws -> Void
    var subscribeToSessionParticipants: @Sendable (_ sessionID: String) async throws -> AsyncStream<[SessionParticipant]>
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
        inviteToWalkSession: { sessionID, companionRecordID in
            let db = CKContainer.default().publicCloudDatabase
            let recordID = CKRecord.ID(recordName: "SessionParticipant_\(sessionID)_\(companionRecordID)")
            let record = CKRecord(recordType: "SessionParticipant", recordID: recordID)
            let sessionRef = CKRecord.Reference(recordID: CKRecord.ID(recordName: sessionID), action: .none)
            let companionRef = CKRecord.Reference(recordID: CKRecord.ID(recordName: companionRecordID), action: .none)
            
            record["sessionRef"] = sessionRef
            record["companionRef"] = companionRef
            record["status"] = "notDetermined"
            
            let _ = try await db.modifyRecords(saving: [record], deleting: [], savePolicy: .changedKeys, atomically: false)
        },
        updateParticipantStatus: { sessionID, companionRecordID, status in
            let db = CKContainer.default().publicCloudDatabase
            let recordID = CKRecord.ID(recordName: "SessionParticipant_\(sessionID)_\(companionRecordID)")
            let record: CKRecord
            do {
                record = try await db.record(for: recordID)
            } catch {
                record = CKRecord(recordType: "SessionParticipant", recordID: recordID)
                let sessionRef = CKRecord.Reference(recordID: CKRecord.ID(recordName: sessionID), action: .none)
                let companionRef = CKRecord.Reference(recordID: CKRecord.ID(recordName: companionRecordID), action: .none)
                record["sessionRef"] = sessionRef
                record["companionRef"] = companionRef
            }
            
            record["status"] = status
            if status == "accept" {
                record["joinedAt"] = Date()
                record["leftAt"] = nil
            } else if status == "left" || status == "dismiss" {
                record["leftAt"] = Date()
            }
            
            let _ = try await db.modifyRecords(saving: [record], deleting: [], savePolicy: .changedKeys, atomically: false)
            
            return SessionParticipant(
                id: recordID.recordName,
                sessionRef: sessionID,
                companionRef: companionRecordID,
                status: status,
                joinedAt: record["joinedAt"] as? Date,
                leftAt: record["leftAt"] as? Date
            )
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
            let sessionRecord: CKRecord
            do {
                sessionRecord = try await db.record(for: sessionRecordID)
            } catch {
                sessionRecord = CKRecord(recordType: "WalkSession", recordID: sessionRecordID)
            }
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
        addJourneyLog: { sessionID, entry in
            let db = CKContainer.default().publicCloudDatabase
            let record = CKRecord(recordType: "JourneyLogRecord")
            record["sessionRef"] = CKRecord.Reference(recordID: CKRecord.ID(recordName: sessionID), action: .deleteSelf)
            record["entryID"] = entry.id.uuidString
            record["landmarkName"] = entry.landmarkName
            record["address"] = entry.address
            record["timeString"] = entry.timeString
            record["iconName"] = entry.iconName
            record["entryType"] = entry.entryType.rawValue
            if let coord = entry.coordinate {
                record["latitude"] = coord.latitude
                record["longitude"] = coord.longitude
            }
            try await db.save(record)
        },
        fetchJourneyLogs: { sessionID in
            let db = CKContainer.default().publicCloudDatabase
            let predicate = NSPredicate(format: "sessionRef == %@", CKRecord.Reference(recordID: CKRecord.ID(recordName: sessionID), action: .deleteSelf))
            let query = CKQuery(recordType: "JourneyLogRecord", predicate: predicate)
            // No sortDescriptors on query to avoid "creationDate not sortable" error

            let (results, _) = try await db.records(matching: query)
            var tempLogs: [(entry: JourneyLogEntry, date: Date)] = []
            for (_, result) in results {
                if let record = try? result.get() {
                    let log = JourneyLogEntry(
                        id: UUID(uuidString: record["entryID"] as? String ?? "") ?? UUID(),
                        landmarkName: record["landmarkName"] as? String ?? "",
                        address: record["address"] as? String ?? "",
                        timeString: record["timeString"] as? String ?? "",
                        iconName: record["iconName"] as? String ?? "",
                        entryType: JourneyLogEntryType(rawValue: record["entryType"] as? String ?? "") ?? .checkpoint,
                        coordinate: {
                            if let lat = record["latitude"] as? Double, let lon = record["longitude"] as? Double {
                                return CLLocationCoordinate2D(latitude: lat, longitude: lon)
                            }
                            return nil
                        }()
                    )
                    tempLogs.append((entry: log, date: record.creationDate ?? Date.distantPast))
                }
            }
            return tempLogs.sorted(by: { $0.date > $1.date }).map(\.entry)
        },
        subscribeToJourneyLogs: { sessionID in
            let db = CKContainer.default().publicCloudDatabase
            let predicate = NSPredicate(format: "sessionRef == %@", CKRecord.Reference(recordID: CKRecord.ID(recordName: sessionID), action: .deleteSelf))
            let subscriptionID = "journey-logs-\(sessionID)"
            
            // Register subscription
            do {
                _ = try await db.subscription(for: subscriptionID)
            } catch {
                let subscription = CKQuerySubscription(
                    recordType: "JourneyLogRecord",
                    predicate: predicate,
                    subscriptionID: subscriptionID,
                    options: [.firesOnRecordCreation]
                )
                let info = CKSubscription.NotificationInfo()
                info.shouldSendContentAvailable = true
                subscription.notificationInfo = info
                try? await db.save(subscription)
            }
            
            // We just return an AsyncStream that yields result every time there's a new log
            return AsyncStream { continuation in
                let internalFetch: @Sendable () async -> [JourneyLogEntry]? = {
                    let fetchQuery = CKQuery(recordType: "JourneyLogRecord", predicate: predicate)
                    // Retrieve records without CloudKit-level sort, then sort locally to avoid "creationDate not sortable" error
                    do {
                        let (results, _) = try await db.records(matching: fetchQuery)
                        var tempLogs: [(entry: JourneyLogEntry, date: Date)] = []
                        for (_, result) in results {
                            if let record = try? result.get() {
                                let log = JourneyLogEntry(
                                    id: UUID(uuidString: record["entryID"] as? String ?? "") ?? UUID(),
                                    landmarkName: record["landmarkName"] as? String ?? "",
                                    address: record["address"] as? String ?? "",
                                    timeString: record["timeString"] as? String ?? "",
                                    iconName: record["iconName"] as? String ?? "",
                                    entryType: JourneyLogEntryType(rawValue: record["entryType"] as? String ?? "") ?? .checkpoint,
                                    coordinate: (record["latitude"] as? Double).flatMap { lat in
                                        (record["longitude"] as? Double).map { lon in CLLocationCoordinate2D(latitude: lat, longitude: lon) }
                                    }
                                )
                                tempLogs.append((entry: log, date: record.creationDate ?? Date.distantPast))
                            }
                        }
                        return tempLogs.sorted(by: { $0.date > $1.date }).map(\.entry)
                    } catch {
                        print("❌ [TrackingClient.subscribeToJourneyLogs] internalFetch Error: \(error)")
                        return nil
                    }
                }

                let pollingTask = Task {
                    while !Task.isCancelled {
                        try? await Task.sleep(nanoseconds: 10_000_000_000)
                        guard !Task.isCancelled else { break }
                        if let db = await internalFetch() {
                            continuation.yield(db)
                        }
                    }
                }

                let listenerTask = Task {
                    // Initial fetch
                    if let db = await internalFetch() {
                        continuation.yield(db)
                    }

                    // APNs push notification listener for instant updates
                    for await _ in NotificationCenter.default.publisher(for: AppDelegate.journeyLogUpdateNotification).values {
                        guard !Task.isCancelled else { break }
                        if let db = await internalFetch() {
                            continuation.yield(db)
                        }
                    }
                }

                continuation.onTermination = { @Sendable _ in
                    pollingTask.cancel()
                    listenerTask.cancel()
                }
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
            info.category = "WALK_INVITATION"
            info.desiredKeys = ["status", "lastPingAt"]
            
            subscription.notificationInfo = info
            
            print("📤 [TrackingClient] Saving CKQuerySubscription for WalkSession: \(sessionRecordID.recordName)...")
            try await db.save(subscription)
            print("✅ [TrackingClient] Subscribed successfully to WalkSession for session: \(sessionID)")
        },
        subscribeToWalkSession: { sessionID in
            AsyncStream { (continuation: AsyncStream<WalkSession>.Continuation) in
                let db = CKContainer.default().publicCloudDatabase
                let sessionRecordID = CKRecord.ID(recordName: sessionID)
                
                let fetchSession: @Sendable () async -> WalkSession? = {
                    do {
                        let record = try await db.record(for: sessionRecordID)
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
                    } catch {
                        print("❌ [TrackingClient] Error fetching walk session record \(sessionID): \(error)")
                        return nil
                    }
                }
                
                let task = Task {
                    var lastCompletedSent = false
                    
                    // 1. Initial immediate fetch
                    if let initial = await fetchSession() {
                        print("📍 [TrackingClient.subscribeToWalkSession] Yielding initial WalkSession: \(initial.status)")
                        continuation.yield(initial)
                        if initial.status == "completed" || initial.status == "arrived" {
                            continuation.finish()
                            return
                        }
                    }
                    
                    // 2. Poll loop for real-time location updates every 2.5 seconds
                    let pollingTask = Task {
                        while !Task.isCancelled {
                            try? await Task.sleep(nanoseconds: 2_500_000_000)
                            guard !Task.isCancelled else { break }
                            
                            if let updated = await fetchSession() {
                                continuation.yield(updated)
                                if updated.status == "completed" || updated.status == "arrived" {
                                    if !lastCompletedSent {
                                        lastCompletedSent = true
                                        continuation.finish()
                                    }
                                    break
                                }
                            }
                        }
                    }
                    
                    // 3. APNs push notification listener for instant updates
                    for await notification in NotificationCenter.default.publisher(for: AppDelegate.walkSessionUpdateNotification).values {
                        guard !Task.isCancelled else { break }
                        guard let userInfo = notification.userInfo,
                              let recordID = userInfo["recordID"] as? CKRecord.ID,
                              recordID.recordName == sessionID else {
                            continue
                        }
                        
                        if let updated = await fetchSession() {
                            print("📍 [APNs -> TrackingClient] Yielding WalkSession Update: \(updated.status)")
                            continuation.yield(updated)
                            if updated.status == "completed" || updated.status == "arrived" {
                                if !lastCompletedSent {
                                    lastCompletedSent = true
                                    continuation.finish()
                                }
                                break
                            }
                        }
                    }
                    
                    pollingTask.cancel()
                }
                
                continuation.onTermination = { @Sendable _ in
                    print("[Stream] subscribeToWalkSession stream terminated at \(Date()).")
                    task.cancel()
                }
            }
        },
        setupInvitationSubscription: { companionRecordID in
            let container = CKContainer.default()
            let db = container.publicCloudDatabase
            let subscriptionID = "session-participant-invitation-\(companionRecordID)"
            do {
                _ = try await db.subscription(for: subscriptionID)
                return
            } catch let error as CKError where error.code == .unknownItem {
            } catch { throw error }
            
            let companionRef = CKRecord.Reference(recordID: CKRecord.ID(recordName: companionRecordID), action: .none)
            let predicate = NSPredicate(format: "companionRef == %@ AND status == %@", companionRef, "notDetermined")
            let subscription = CKQuerySubscription(recordType: "SessionParticipant", predicate: predicate, subscriptionID: subscriptionID, options: [.firesOnRecordCreation, .firesOnRecordUpdate])
            
            let info = CKSubscription.NotificationInfo()
            info.shouldSendContentAvailable = true
            info.alertBody = "You have a new walk tracking invitation!"
            info.soundName = "default"
            info.category = "WALK_INVITATION"
            info.desiredKeys = ["sessionRef", "status"]
            subscription.notificationInfo = info
            
            try await db.save(subscription)
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
        },
        fetchSessionParticipant: { participantRecordID in
            let db = CKContainer.default().publicCloudDatabase
            let id = CKRecord.ID(recordName: participantRecordID)
            let record = try await db.record(for: id)
            let sessionRef = (record["sessionRef"] as? CKRecord.Reference)?.recordID.recordName ?? ""
            let companionRef = (record["companionRef"] as? CKRecord.Reference)?.recordID.recordName ?? ""
            let status = record["status"] as? String ?? "notDetermined"
            let joinedAt = record["joinedAt"] as? Date
            let leftAt = record["leftAt"] as? Date

            return SessionParticipant(
                id: participantRecordID,
                sessionRef: sessionRef,
                companionRef: companionRef,
                status: status,
                joinedAt: joinedAt,
                leftAt: leftAt
            )
        },
        fetchSessionParticipants: { sessionID in
            try await querySessionParticipants(sessionID: sessionID)
        },
        setSubscribeSessionParticipants: { sessionID, isSubscribed in
            let db = CKContainer.default().publicCloudDatabase
            let subscriptionID = "session-participants-\(sessionID)"
            
            if !isSubscribed {
                do {
                    try await db.deleteSubscription(withID: subscriptionID)
                    print("[TrackingClient] Deleted participant subscription for session \(sessionID)")
                } catch let error as CKError where error.code == .unknownItem {
                } catch {
                    throw error
                }
                return
            }
            
            do {
                _ = try await db.subscription(for: subscriptionID)
                return
            } catch let error as CKError where error.code == .unknownItem {
            } catch {
                throw error
            }
            
            let sessionRef = CKRecord.Reference(recordID: CKRecord.ID(recordName: sessionID), action: .none)
            let predicate = NSPredicate(format: "sessionRef == %@", sessionRef)
            let subscription = CKQuerySubscription(
                recordType: "SessionParticipant",
                predicate: predicate,
                subscriptionID: subscriptionID,
                options: [.firesOnRecordCreation, .firesOnRecordUpdate]
            )
            
            let info = CKSubscription.NotificationInfo()
            info.shouldSendContentAvailable = true
            info.desiredKeys = ["sessionRef", "companionRef", "status"]
            subscription.notificationInfo = info
            
            try await db.save(subscription)
            print("[TrackingClient] Registered participant subscription for session \(sessionID)")
        },
        subscribeToSessionParticipants: { sessionID in
            AsyncStream { continuation in
                let task = Task {
                    // 1. Initial fetch
                    if let initial = try? await querySessionParticipants(sessionID: sessionID) {
                        continuation.yield(initial)
                    }
                    
                    // 2. Poll every 3 seconds for live updates
                    while !Task.isCancelled {
                        try? await Task.sleep(nanoseconds: 3_000_000_000)
                        guard !Task.isCancelled else { break }
                        
                        if let updated = try? await querySessionParticipants(sessionID: sessionID) {
                            continuation.yield(updated)
                        }
                    }
                }
                
                continuation.onTermination = { @Sendable _ in
                    task.cancel()
                }
            }
        }
    )
    
    static let testValue = Self(
        startWalkSession: { _, _, _, _, _, _ in
            WalkSession(id: "test", walkerRef: "w", status: "active", destinationName: "dest", destinationLatitude: 0, destinationLongitude: 0, routePolyline: nil, startedAt: Date(), endedAt: nil, currentCoordinate: nil, lastPingAt: Date())
        },
        endWalkSession: { _ in },
        inviteToWalkSession: { _, _ in },
        updateParticipantStatus: { s, c, st in SessionParticipant(id: "p", sessionRef: s, companionRef: c, status: st) },
        updateUserStatus: { _, _, _, _ in },
        pushLocationUpdate: { _, _ in },
        addJourneyLog: { _, _ in },
        fetchJourneyLogs: { _ in [] },
        subscribeToJourneyLogs: { _ in AsyncStream { $0.finish() } },
        setSubscribeWalkSession: { _, _ in },
        subscribeToWalkSession: { _ in AsyncStream { $0.finish() } },
        setupInvitationSubscription: { _ in },
        getWalkSession: { s in WalkSession(id: s, walkerRef: "w", status: "active", destinationName: "dest", destinationLatitude: 0, destinationLongitude: 0, routePolyline: nil, startedAt: Date(), endedAt: nil, currentCoordinate: nil, lastPingAt: Date()) },
        getWalkerActiveSessionID: { _ in nil },
        fetchSessionParticipant: { p in SessionParticipant(id: p, sessionRef: "s", companionRef: "c", status: "notDetermined") },
        fetchSessionParticipants: { _ in [] },
        setSubscribeSessionParticipants: { _, _ in },
        subscribeToSessionParticipants: { _ in AsyncStream { $0.finish() } }
    )
}

private func querySessionParticipants(sessionID: String) async throws -> [SessionParticipant] {
    let db = CKContainer.default().publicCloudDatabase
    let sessionRef = CKRecord.Reference(recordID: CKRecord.ID(recordName: sessionID), action: .none)
    let predicate = NSPredicate(format: "sessionRef == %@", sessionRef)
    let query = CKQuery(recordType: "SessionParticipant", predicate: predicate)
    
    let (matchResults, _) = try await db.records(matching: query)
    var participants: [SessionParticipant] = []
    
    for (_, result) in matchResults {
        if case .success(let record) = result {
            let sessionRef = (record["sessionRef"] as? CKRecord.Reference)?.recordID.recordName ?? ""
            let companionRef = (record["companionRef"] as? CKRecord.Reference)?.recordID.recordName ?? ""
            let status = record["status"] as? String ?? "notDetermined"
            let joinedAt = record["joinedAt"] as? Date
            let leftAt = record["leftAt"] as? Date
            
            participants.append(SessionParticipant(
                id: record.recordID.recordName,
                sessionRef: sessionRef,
                companionRef: companionRef,
                status: status,
                joinedAt: joinedAt,
                leftAt: leftAt
            ))
        }
    }
    return participants
}

extension DependencyValues {
    var trackingClient: TrackingClient {
        get { self[TrackingClient.self] }
        set { self[TrackingClient.self] = newValue }
    }
}
