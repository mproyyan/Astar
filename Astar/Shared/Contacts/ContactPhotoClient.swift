//
//  ContactPhotoClient.swift
//  Astar
//
//  Created by Dimas Prihady Setyawan on 25/08/26.
//

import Contacts
import ComposableArchitecture
import Foundation
import UIKit

@DependencyClient
struct ContactPhotoClient: Sendable {
    var fetchMeCardPhoto: @Sendable (_ email: String?, _ name: String?) async -> Data?
    var fetchContactPhotoByEmail: @Sendable (_ email: String) async -> Data?
    var fetchContactPhotoByName: @Sendable (_ name: String) async -> Data?
}

extension ContactPhotoClient: DependencyKey {
    static let liveValue = ContactPhotoClient.live()
    static let testValue = ContactPhotoClient(
        fetchMeCardPhoto: { _, _ in nil },
        fetchContactPhotoByEmail: { _ in nil },
        fetchContactPhotoByName: { _ in nil }
    )

    static func live() -> Self {
        return Self(
            fetchMeCardPhoto: { email, name in
                let cleanEmail: String? = {
                    guard let email = email?.trimmingCharacters(in: .whitespacesAndNewlines), !email.isEmpty else { return nil }
                    let lower = email.lowercased()
                    if lower == "unknown@apple.com" || lower == "unknown@example.com" || lower.hasPrefix("unknown") { return nil }
                    return email
                }()

                let cleanName: String? = {
                    guard let name = name?.trimmingCharacters(in: .whitespacesAndNewlines), !name.isEmpty else { return nil }
                    let lower = name.lowercased()
                    if lower == "user" || lower == "unknown user" || lower == "unknown" { return nil }
                    return name
                }()

                guard cleanEmail != nil || cleanName != nil else {
                    return nil
                }

                let status = CNContactStore.authorizationStatus(for: .contacts)
                guard status == .authorized || status == .notDetermined else { return nil }
                
                let store = CNContactStore()
                let keysToFetch: [CNKeyDescriptor] = [
                    CNContactThumbnailImageDataKey as CNKeyDescriptor,
                    CNContactImageDataAvailableKey as CNKeyDescriptor,
                    CNContactImageDataKey as CNKeyDescriptor,
                    CNContactGivenNameKey as CNKeyDescriptor,
                    CNContactFamilyNameKey as CNKeyDescriptor,
                    CNContactNicknameKey as CNKeyDescriptor,
                    CNContactEmailAddressesKey as CNKeyDescriptor
                ]

                do {
                    if status == .notDetermined {
                        let granted = try await store.requestAccess(for: .contacts)
                        guard granted else { return nil }
                    }

                    // 1. Match by Email exact address
                    if let cleanEmail {
                        let predicate = CNContact.predicateForContacts(matchingEmailAddress: cleanEmail)
                        let contacts = try store.unifiedContacts(matching: predicate, keysToFetch: keysToFetch)
                        for contact in contacts {
                            if contact.imageDataAvailable, let data = contact.thumbnailImageData ?? contact.imageData {
                                return data
                            }
                        }
                    }

                    // 2. Match by Name exact/full match
                    if let cleanName {
                        let predicate = CNContact.predicateForContacts(matchingName: cleanName)
                        let contacts = try store.unifiedContacts(matching: predicate, keysToFetch: keysToFetch)
                        for contact in contacts {
                            let fullName = "\(contact.givenName) \(contact.familyName)".trimmingCharacters(in: .whitespacesAndNewlines)
                            if fullName.caseInsensitiveCompare(cleanName) == .orderedSame || contact.givenName.caseInsensitiveCompare(cleanName) == .orderedSame {
                                if contact.imageDataAvailable, let data = contact.thumbnailImageData ?? contact.imageData {
                                    return data
                                }
                            }
                        }
                    }

                    // 3. Match by Name Tokens (e.g. "Dimas" or "Prihady" or "Setyawan")
                    if let cleanName {
                        let userTokens = Set(cleanName.lowercased().split(separator: " ").filter { $0.count >= 3 }.map(String.init))
                        if !userTokens.isEmpty {
                            let request = CNContactFetchRequest(keysToFetch: keysToFetch)
                            var matchedPhoto: Data?

                            try store.enumerateContacts(with: request) { contact, stop in
                                if contact.imageDataAvailable, let data = contact.thumbnailImageData ?? contact.imageData {
                                    let contactGiven = contact.givenName.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
                                    let contactFamily = contact.familyName.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
                                    let contactNick = contact.nickname.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)

                                    if userTokens.contains(contactGiven) || userTokens.contains(contactFamily) || userTokens.contains(contactNick) {
                                        matchedPhoto = data
                                        stop.pointee = true
                                        return
                                    }

                                    if let cleanEmail {
                                        let emailUser = cleanEmail.split(separator: "@").first.map(String.init)?.lowercased() ?? ""
                                        for emailAddress in contact.emailAddresses {
                                            let address = (emailAddress.value as String).lowercased()
                                            if address == cleanEmail.lowercased() || (!emailUser.isEmpty && address.hasPrefix(emailUser)) {
                                                matchedPhoto = data
                                                stop.pointee = true
                                                return
                                            }
                                        }
                                    }
                                }
                            }

                            if let matchedPhoto {
                                return matchedPhoto
                            }
                        }
                    }
                } catch {
                    // Ignore
                }
                return nil
            },
            fetchContactPhotoByEmail: { email in
                guard let cleanEmail = email.trimmingCharacters(in: .whitespacesAndNewlines).nilIfBlank else { return nil }
                let status = CNContactStore.authorizationStatus(for: .contacts)
                guard status == .authorized || status == .notDetermined else { return nil }

                let store = CNContactStore()
                let keysToFetch: [CNKeyDescriptor] = [
                    CNContactThumbnailImageDataKey as CNKeyDescriptor,
                    CNContactImageDataAvailableKey as CNKeyDescriptor,
                    CNContactImageDataKey as CNKeyDescriptor,
                    CNContactEmailAddressesKey as CNKeyDescriptor
                ]

                do {
                    if status == .notDetermined {
                        let granted = try await store.requestAccess(for: .contacts)
                        guard granted else { return nil }
                    }

                    let predicate = CNContact.predicateForContacts(matchingEmailAddress: cleanEmail)
                    let contacts = try store.unifiedContacts(matching: predicate, keysToFetch: keysToFetch)
                    for contact in contacts {
                        if contact.imageDataAvailable, let data = contact.thumbnailImageData ?? contact.imageData {
                            return data
                        }
                    }
                } catch {
                    // Ignore
                }
                return nil
            },
            fetchContactPhotoByName: { name in
                guard let cleanName = name.trimmingCharacters(in: .whitespacesAndNewlines).nilIfBlank else { return nil }
                let status = CNContactStore.authorizationStatus(for: .contacts)
                guard status == .authorized || status == .notDetermined else { return nil }

                let store = CNContactStore()
                let keysToFetch: [CNKeyDescriptor] = [
                    CNContactThumbnailImageDataKey as CNKeyDescriptor,
                    CNContactImageDataAvailableKey as CNKeyDescriptor,
                    CNContactImageDataKey as CNKeyDescriptor,
                    CNContactGivenNameKey as CNKeyDescriptor,
                    CNContactFamilyNameKey as CNKeyDescriptor,
                    CNContactNicknameKey as CNKeyDescriptor
                ]

                do {
                    if status == .notDetermined {
                        let granted = try await store.requestAccess(for: .contacts)
                        guard granted else { return nil }
                    }

                    let predicate = CNContact.predicateForContacts(matchingName: cleanName)
                    let contacts = try store.unifiedContacts(matching: predicate, keysToFetch: keysToFetch)
                    for contact in contacts {
                        let fullName = "\(contact.givenName) \(contact.familyName)".trimmingCharacters(in: .whitespacesAndNewlines)
                        if fullName.caseInsensitiveCompare(cleanName) == .orderedSame || contact.givenName.caseInsensitiveCompare(cleanName) == .orderedSame {
                            if contact.imageDataAvailable, let data = contact.thumbnailImageData ?? contact.imageData {
                                return data
                            }
                        }
                    }

                    let userTokens = Set(cleanName.lowercased().split(separator: " ").filter { $0.count >= 3 }.map(String.init))
                    if !userTokens.isEmpty {
                        let request = CNContactFetchRequest(keysToFetch: keysToFetch)
                        var matchedPhoto: Data?
                        try store.enumerateContacts(with: request) { contact, stop in
                            if contact.imageDataAvailable, let data = contact.thumbnailImageData ?? contact.imageData {
                                let contactGiven = contact.givenName.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
                                let contactFamily = contact.familyName.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
                                let contactNick = contact.nickname.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)

                                if userTokens.contains(contactGiven) || userTokens.contains(contactFamily) || userTokens.contains(contactNick) {
                                    matchedPhoto = data
                                    stop.pointee = true
                                    return
                                }
                            }
                        }
                        if let matchedPhoto {
                            return matchedPhoto
                        }
                    }
                } catch {
                    // Ignore
                }
                return nil
            }
        )
    }
}

private extension String {
    var nilIfBlank: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}

extension DependencyValues {
    var contactPhotoClient: ContactPhotoClient {
        get { self[ContactPhotoClient.self] }
        set { self[ContactPhotoClient.self] = newValue }
    }
}
