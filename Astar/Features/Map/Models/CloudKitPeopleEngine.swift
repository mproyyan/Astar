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

    // MARK: - Fetch All People from Container

    static func fetchAllPeople() async throws -> [Person] {
        var people: [Person] = []
        var seenNames = Set<String>()
        var seenEmails = Set<String>()
        var seenRecordNames = Set<String>()

        let currentCKUserRecordID = try? await container.userRecordID()
        let currentCKUserIdString = currentCKUserRecordID?.recordName ?? ""
        let storedProfile = UserProfileStorage.load()
        let myName = storedProfile?.name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() ?? ""
        let myEmail = storedProfile?.email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() ?? ""
        let myAppleUserId = storedProfile?.appleUserId ?? ""

        func isCurrentUser(record: CKRecord) -> Bool {
            if !currentCKUserIdString.isEmpty && record.recordID.recordName.contains(currentCKUserIdString) {
                return true
            }
            if let creator = record.creatorUserRecordID?.recordName, !currentCKUserIdString.isEmpty, creator == currentCKUserIdString {
                return true
            }
            if let appleId = record["appleUserId"] as? String, !myAppleUserId.isEmpty, appleId == myAppleUserId {
                return true
            }
            if let email = (record["email"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(),
               !myEmail.isEmpty && !email.isEmpty && email == myEmail {
                return true
            }
            if let name = (record["name"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(),
               !myName.isEmpty && !name.isEmpty && name == myName {
                return true
            }
            return false
        }

        // 1. Fetch from "UserProfile" (the users table created during Apple Sign-In)
        let userProfileQuery = CKQuery(
            recordType: "UserProfile",
            predicate: NSPredicate(value: true)
        )
        if let (profileResults, _) = try? await publicDB.records(
            matching: userProfileQuery,
            resultsLimit: 50
        ) {
            for (_, result) in profileResults {
                guard let record = try? result.get() else { continue }
                if isCurrentUser(record: record) { continue }

                let person = personFromRecord(record)
                let nameKey = person.name.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
                let emailKey = (record["email"] as? String)?.lowercased().trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                let recordKey = record.recordID.recordName

                if seenRecordNames.contains(recordKey) { continue }
                if !nameKey.isEmpty && seenNames.contains(nameKey) { continue }
                if !emailKey.isEmpty && seenEmails.contains(emailKey) { continue }

                seenRecordNames.insert(recordKey)
                if !nameKey.isEmpty { seenNames.insert(nameKey) }
                if !emailKey.isEmpty { seenEmails.insert(emailKey) }
                people.append(person)
            }
        }

        // 2. Fetch from "CD_Person" (if any separate CD_Person records exist)
        let cdPersonQuery = CKQuery(
            recordType: personRecordType,
            predicate: NSPredicate(value: true)
        )
        if let (cdResults, _) = try? await publicDB.records(
            matching: cdPersonQuery,
            resultsLimit: 50
        ) {
            for (_, result) in cdResults {
                guard let record = try? result.get() else { continue }
                if isCurrentUser(record: record) { continue }

                let person = personFromRecord(record)
                let nameKey = person.name.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
                let emailKey = (record["email"] as? String)?.lowercased().trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                let recordKey = record.recordID.recordName

                if seenRecordNames.contains(recordKey) { continue }
                if !nameKey.isEmpty && seenNames.contains(nameKey) { continue }
                if !emailKey.isEmpty && seenEmails.contains(emailKey) { continue }

                seenRecordNames.insert(recordKey)
                if !nameKey.isEmpty { seenNames.insert(nameKey) }
                if !emailKey.isEmpty { seenEmails.insert(emailKey) }
                people.append(person)
            }
        }

        // 3. Query active journeys (isActive == 1) to mark walking status across all devices
        let activeJourneyQuery = CKQuery(
            recordType: journeyRecordType,
            predicate: NSPredicate(format: "isActive == 1")
        )
        var activeJourneysByWalker: [String: (origin: String, destination: String, icon: String)] = [:]
        if let (journeyResults, _) = try? await publicDB.records(matching: activeJourneyQuery, resultsLimit: 50) {
            for (_, result) in journeyResults {
                guard let jRecord = try? result.get(),
                      let walkerRef = jRecord["walker"] as? CKRecord.Reference
                else { continue }

                let origin = (jRecord["originName"] as? String) ?? "Autograph Tower"
                let dest = (jRecord["destinationName"] as? String) ?? "Destination"
                let icon = (jRecord["destinationIconName"] as? String) ?? "bag.fill"
                activeJourneysByWalker[walkerRef.recordID.recordName] = (origin, dest, icon)
            }
        }

        // Apply active journeys to people
        people = people.map { person in
            if let recordID = person.recordID, let journey = activeJourneysByWalker[recordID.recordName] {
                return Person(
                    id: person.id,
                    name: person.name,
                    email: person.email,
                    avatarImageName: person.avatarImageName,
                    status: PersonStatus.walking.rawValue,
                    recordID: person.recordID,
                    activeOriginName: journey.origin,
                    activeDestinationName: journey.destination,
                    activeDestinationIcon: journey.icon
                )
            }
            return person
        }

        return people
    }

    // MARK: - Find or Create Current iCloud User

    /// Looks up an existing Person/UserProfile record for the signed-in iCloud user, or creates one.
    static func findOrCreateCurrentUser(name: String) async throws -> Person {
        let userRecordID = try await container.userRecordID()
        let storedProfile = UserProfileStorage.load()

        // 1. Try fetching exact UserProfile record by deterministic record ID
        if let stored = storedProfile {
            let recordName = "UserProfile_\(stored.appleUserId)_\(stored.cloudKitUserId)"
                .map { character in character.isLetter || character.isNumber ? character : "_" }
                .map(String.init)
                .joined()
            let expectedID = CKRecord.ID(recordName: recordName)
            if let record = try? await publicDB.record(for: expectedID) {
                return personFromRecord(record)
            }
        }

        // 2. Query UserProfile by appleUserId if stored
        if let appleUserId = storedProfile?.appleUserId, !appleUserId.isEmpty {
            let query = CKQuery(
                recordType: "UserProfile",
                predicate: NSPredicate(format: "appleUserId == %@", appleUserId)
            )
            if let (results, _) = try? await publicDB.records(matching: query, resultsLimit: 1),
               let first = results.first,
               let record = try? first.1.get() {
                return personFromRecord(record)
            }
        }

        // 3. Query UserProfile by creatorUserRecordID
        let userProfileQuery = CKQuery(
            recordType: "UserProfile",
            predicate: NSPredicate(format: "creatorUserRecordID == %@", userRecordID)
        )
        if let (results, _) = try? await publicDB.records(matching: userProfileQuery, resultsLimit: 1),
           let first = results.first,
           let record = try? first.1.get() {
            return personFromRecord(record)
        }

        // 4. Check existing CD_Person owned by this user
        let cdQuery = CKQuery(
            recordType: personRecordType,
            predicate: NSPredicate(format: "creatorUserRecordID == %@", userRecordID)
        )
        if let (results, _) = try? await publicDB.records(matching: cdQuery, resultsLimit: 1),
           let first = results.first,
           let record = try? first.1.get() {
            return personFromRecord(record)
        }

        // 5. Create a new record for this user in public DB
        let record = CKRecord(recordType: "UserProfile")
        record["name"] = name as CKRecordValue
        record["email"] = (storedProfile?.email ?? "") as CKRecordValue
        record["appleUserId"] = (storedProfile?.appleUserId ?? "") as CKRecordValue
        record["cloudKitUserId"] = userRecordID.recordName as CKRecordValue
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
        journeyRecord["originName"] = "Autograph Tower" as CKRecordValue
        journeyRecord["originSubtitle"] = "Jl. M.H. Thamrin No. 10, Central Jakarta" as CKRecordValue
        journeyRecord["destinationName"] = destination.name as CKRecordValue
        journeyRecord["destinationSubtitle"] = destination.subtitle as CKRecordValue
        journeyRecord["destinationIconName"] = destination.iconName as CKRecordValue
        journeyRecord["destinationLat"] = (destination.coordinate?.latitude ?? -6.1931) as CKRecordValue
        journeyRecord["destinationLon"] = (destination.coordinate?.longitude ?? 106.8218) as CKRecordValue
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

    // MARK: - Simulation Helper

    /// Simulates a person (e.g. Safa Auliya) walking with an active journey in CloudKit public DB.
    static func simulatePersonWalking(namePrefix: String = "Safa") async throws {
        // Query UserProfile for person matching namePrefix
        let userProfileQuery = CKQuery(
            recordType: "UserProfile",
            predicate: NSPredicate(value: true)
        )
        let (results, _) = try await publicDB.records(matching: userProfileQuery, resultsLimit: 50)

        var targetRecord: CKRecord?
        for (_, result) in results {
            if let record = try? result.get() {
                let name = (record["name"] as? String) ?? ""
                if name.localizedCaseInsensitiveContains(namePrefix) {
                    targetRecord = record
                    break
                }
            }
        }

        // If not found in UserProfile, check CD_Person
        if targetRecord == nil {
            let cdQuery = CKQuery(recordType: personRecordType, predicate: NSPredicate(value: true))
            if let (cdResults, _) = try? await publicDB.records(matching: cdQuery, resultsLimit: 50) {
                for (_, result) in cdResults {
                    if let record = try? result.get() {
                        let name = (record["name"] as? String) ?? ""
                        if name.localizedCaseInsensitiveContains(namePrefix) {
                            targetRecord = record
                            break
                        }
                    }
                }
            }
        }

        guard let personRecord = targetRecord else {
            print("[Simulation] No record found matching prefix: \(namePrefix)")
            return
        }

        // Start active journey for this person
        let destination = SavedPlace(
            name: "Plaza Indonesia",
            subtitle: "Jl. M.H. Thamrin No. 28-30, Central Jakarta",
            iconName: "bag.fill",
            distance: "450 m",
            coordinate: CLLocationCoordinate2D(latitude: -6.1931, longitude: 106.8218)
        )

        try await startJourney(
            personRecordID: personRecord.recordID,
            destination: destination
        )
        print("[Simulation] Successfully set \(personRecord["name"] ?? namePrefix) to Walking with active journey to \(destination.name)")
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

    // MARK: - Fetch User History Trips

    /// Fetches completed past journeys for a specific walker from CloudKit.
    static func fetchHistoryTrips(for walkerRecordID: CKRecord.ID?) async -> [WalkerHistoryTrip] {
        guard let walkerRecordID else { return WalkerSampleData.defaultTrips }

        let predicate = NSPredicate(
            format: "walker == %@ AND isActive == 0",
            CKRecord.Reference(recordID: walkerRecordID, action: .none)
        )
        let query = CKQuery(recordType: journeyRecordType, predicate: predicate)
        query.sortDescriptors = [NSSortDescriptor(key: "startTime", ascending: false)]

        guard let (results, _) = try? await publicDB.records(matching: query, resultsLimit: 20) else {
            return WalkerSampleData.defaultTrips
        }

        let trips = results.compactMap { _, result -> WalkerHistoryTrip? in
            guard let record = try? result.get() else { return nil }
            let destName = (record["destinationName"] as? String) ?? "Destination"
            let iconName = (record["destinationIconName"] as? String) ?? "house.fill"
            let startTime = (record["startTime"] as? Date) ?? Date.now
            let endTime = (record["endTime"] as? Date) ?? startTime
            let durationMins = max(1, Int(ceil(endTime.timeIntervalSince(startTime) / 60.0)))
            let dateStr = startTime.formatted(date: .abbreviated, time: .shortened)

            return WalkerHistoryTrip(
                id: UUID(uuidString: record.recordID.recordName) ?? UUID(),
                destinationName: destName,
                iconName: iconName,
                iconColor: SavedPlace.categoryColor(for: iconName),
                dateString: dateStr,
                durationString: "\(durationMins) min",
                distanceString: "1.4 km"
            )
        }

        return trips.isEmpty ? WalkerSampleData.defaultTrips : trips
    }

    // MARK: - Fetch Active Journey Details

    /// Fetches the active journey details for a walking person from CloudKit.
    static func fetchActiveJourneyDetails(for walkerRecordID: CKRecord.ID) async -> (origin: String, destination: String, icon: String)? {
        guard let walkerRecord = try? await publicDB.record(for: walkerRecordID),
              let journeyRef = walkerRecord["activeJourney"] as? CKRecord.Reference,
              let journeyRecord = try? await publicDB.record(for: journeyRef.recordID)
        else { return nil }

        let origin = (journeyRecord["originName"] as? String) ?? "Current Location"
        let dest = (journeyRecord["destinationName"] as? String) ?? "Destination"
        let icon = (journeyRecord["destinationIconName"] as? String) ?? "house.fill"
        return (origin: origin, destination: dest, icon: icon)
    }

    // MARK: - Record ↔ Value Type Conversion

    static func personFromRecord(_ record: CKRecord) -> Person {
        let rawName = (record["name"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let rawEmail = (record["email"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let avatarName = (record["avatarImageName"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let statusString = (record["status"] as? String) ?? PersonStatus.idle.rawValue

        let finalName: String
        if !rawName.isEmpty {
            finalName = rawName
        } else if !rawEmail.isEmpty {
            let emailPrefix = rawEmail.split(separator: "@").first.map(String.init) ?? "User"
            finalName = emailPrefix.capitalized
        } else {
            finalName = "User"
        }

        let finalAvatar = !avatarName.isEmpty ? avatarName : "\(finalName)Avatar"

        return Person(
            id: UUID(uuidString: record.recordID.recordName) ?? UUID(),
            name: finalName,
            email: rawEmail,
            avatarImageName: finalAvatar,
            status: statusString,
            recordID: record.recordID
        )
    }
}
