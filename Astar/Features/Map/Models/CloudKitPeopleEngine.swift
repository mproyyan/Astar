//
//  CloudKitPeopleEngine.swift
//  Astar
//
//  Created by Dimas Prihady Setyawan on 26/08/26.
//

import CloudKit
import Foundation

/// Handles all CKRecord <-> value type conversions and CloudKit public DB CRUD
/// for the People status tracking feature (iCloud.com.astar.trail).
@MainActor
enum CloudKitPeopleEngine {
    static let container = CKContainer(identifier: "iCloud.com.astar.trail")
    static let publicDB = container.publicCloudDatabase

    // MARK: - Record Type Constants

    static let personRecordType = "CD_Person"
    static let journeyRecordType = "CD_Journey"
    static let companionRecordType = "CD_Companion"

    // MARK: - Fetch All People

    static func fetchAllPeople() async throws -> [Person] {
        let query = CKQuery(
            recordType: personRecordType,
            predicate: NSPredicate(value: true)
        )
        query.sortDescriptors = [NSSortDescriptor(key: "name", ascending: true)]

        let (results, _) = try await publicDB.records(
            matching: query,
            desiredKeys: ["name", "email", "avatarImageName", "status"],
            resultsLimit: 50
        )

        return results.compactMap { _, result in
            guard let record = try? result.get() else { return nil }
            return personFromRecord(record)
        }
    }

    // MARK: - Find or Create Current iCloud User

    /// Looks up an existing Person record for the signed-in iCloud user, or creates one.
    static func findOrCreateCurrentUser(name: String) async throws -> Person {
        let userRecordID = try await container.userRecordID()

        // Query for an existing Person owned by this iCloud account
        let predicate = NSPredicate(
            format: "creatorUserRecordID == %@",
            userRecordID
        )
        let query = CKQuery(
            recordType: personRecordType,
            predicate: predicate
        )

        let (results, _) = try await publicDB.records(
            matching: query,
            resultsLimit: 1
        )

        if let first = results.first,
           let record = try? first.1.get() {
            return personFromRecord(record)
        }

        // Create a new Person record for this user
        let record = CKRecord(recordType: personRecordType)
        record["name"] = name as CKRecordValue
        record["email"] = "" as CKRecordValue
        record["avatarImageName"] = "" as CKRecordValue
        record["status"] = PersonStatus.idle.rawValue as CKRecordValue
        record["lastStatusChange"] = Date.now as CKRecordValue

        let saved = try await publicDB.save(record)
        return personFromRecord(saved)
    }

    // MARK: - Start Journey

    /// Creates a CD_Journey record and marks the walker's status as Walking.
    static func startJourney(
        personRecordID: CKRecord.ID,
        destination: SavedPlace
    ) async throws {
        // 1. Create Journey record
        let journeyRecord = CKRecord(recordType: journeyRecordType)
        journeyRecord["walker"] = CKRecord.Reference(
            recordID: personRecordID,
            action: .none
        )
        journeyRecord["destinationName"] = destination.name as CKRecordValue
        journeyRecord["destinationSubtitle"] = destination.subtitle as CKRecordValue
        journeyRecord["destinationIconName"] = destination.iconName as CKRecordValue
        journeyRecord["destinationLat"] = (destination.coordinate?.latitude ?? 0) as CKRecordValue
        journeyRecord["destinationLon"] = (destination.coordinate?.longitude ?? 0) as CKRecordValue
        journeyRecord["startTime"] = Date.now as CKRecordValue
        journeyRecord["isActive"] = 1 as CKRecordValue

        let savedJourney = try await publicDB.save(journeyRecord)

        // 2. Update Person status → Walking
        let personRecord = try await publicDB.record(for: personRecordID)
        personRecord["status"] = PersonStatus.walking.rawValue as CKRecordValue
        personRecord["lastStatusChange"] = Date.now as CKRecordValue
        personRecord["activeJourney"] = CKRecord.Reference(
            recordID: savedJourney.recordID,
            action: .none
        )
        try await publicDB.save(personRecord)
    }

    // MARK: - End Journey

    /// Closes the active journey, resets all companion statuses to Idle, then marks the walker as Idle.
    static func endJourney(personRecordID: CKRecord.ID) async throws {
        let personRecord = try await publicDB.record(for: personRecordID)

        // 1. Close active journey
        if let journeyRef = personRecord["activeJourney"] as? CKRecord.Reference {
            let journeyRecord = try await publicDB.record(for: journeyRef.recordID)
            journeyRecord["isActive"] = 0 as CKRecordValue
            journeyRecord["endTime"] = Date.now as CKRecordValue
            try await publicDB.save(journeyRecord)

            // 2. Reset all companions of this journey back to Idle
            let companionPredicate = NSPredicate(
                format: "journey == %@",
                CKRecord.Reference(recordID: journeyRef.recordID, action: .none)
            )
            let companionQuery = CKQuery(
                recordType: companionRecordType,
                predicate: companionPredicate
            )
            let (companionResults, _) = try await publicDB.records(
                matching: companionQuery,
                resultsLimit: 50
            )

            for (_, result) in companionResults {
                guard
                    let companionRecord = try? result.get(),
                    let companionRef = companionRecord["companion"] as? CKRecord.Reference
                else { continue }

                let companionPerson = try await publicDB.record(for: companionRef.recordID)
                companionPerson["status"] = PersonStatus.idle.rawValue as CKRecordValue
                companionPerson["lastStatusChange"] = Date.now as CKRecordValue
                try await publicDB.save(companionPerson)
            }
        }

        // 3. Reset person status → Idle, remove activeJourney reference
        personRecord["status"] = PersonStatus.idle.rawValue as CKRecordValue
        personRecord["lastStatusChange"] = Date.now as CKRecordValue
        personRecord["activeJourney"] = nil
        try await publicDB.save(personRecord)
    }

    // MARK: - Become Companion

    /// Links a companion person to a walker's active journey and sets their status to Companion.
    static func becomeCompanion(
        companionRecordID: CKRecord.ID,
        walkerRecordID: CKRecord.ID
    ) async throws {
        // 1. Find the walker's active journey
        let walkerRecord = try await publicDB.record(for: walkerRecordID)
        guard let journeyRef = walkerRecord["activeJourney"] as? CKRecord.Reference
        else { return }

        // 2. Create Companion record
        let companionRecord = CKRecord(recordType: companionRecordType)
        companionRecord["journey"] = CKRecord.Reference(
            recordID: journeyRef.recordID,
            action: .none
        )
        companionRecord["companion"] = CKRecord.Reference(
            recordID: companionRecordID,
            action: .none
        )
        companionRecord["joinedAt"] = Date.now as CKRecordValue
        try await publicDB.save(companionRecord)

        // 3. Update companion's status
        let companionPerson = try await publicDB.record(for: companionRecordID)
        companionPerson["status"] = PersonStatus.companion.rawValue as CKRecordValue
        companionPerson["lastStatusChange"] = Date.now as CKRecordValue
        try await publicDB.save(companionPerson)
    }

    // MARK: - Stop Being Companion

    /// Removes the companion link and resets the companion's status to Idle.
    static func stopCompanion(companionRecordID: CKRecord.ID) async throws {
        let companionPerson = try await publicDB.record(for: companionRecordID)
        companionPerson["status"] = PersonStatus.idle.rawValue as CKRecordValue
        companionPerson["lastStatusChange"] = Date.now as CKRecordValue
        try await publicDB.save(companionPerson)
    }

    // MARK: - Fetch Companions for a Walker

    /// Returns all people currently watching the specified walker's active journey.
    static func fetchCompanions(walkerRecordID: CKRecord.ID) async throws -> [Person] {
        let walkerRecord = try await publicDB.record(for: walkerRecordID)
        guard let journeyRef = walkerRecord["activeJourney"] as? CKRecord.Reference
        else { return [] }

        let predicate = NSPredicate(
            format: "journey == %@",
            CKRecord.Reference(recordID: journeyRef.recordID, action: .none)
        )
        let query = CKQuery(recordType: companionRecordType, predicate: predicate)

        let (results, _) = try await publicDB.records(
            matching: query,
            resultsLimit: 50
        )

        var companions: [Person] = []
        for (_, result) in results {
            guard
                let record = try? result.get(),
                let companionRef = record["companion"] as? CKRecord.Reference
            else { continue }

            let personRecord = try await publicDB.record(for: companionRef.recordID)
            companions.append(personFromRecord(personRecord))
        }
        return companions
    }

    // MARK: - Record ↔ Value Type Conversion

    static func personFromRecord(_ record: CKRecord) -> Person {
        Person(
            id: UUID(uuidString: record.recordID.recordName) ?? UUID(),
            name: record["name"] as? String ?? "",
            status: record["status"] as? String ?? PersonStatus.idle.rawValue,
            recordID: record.recordID
        )
    }
}
