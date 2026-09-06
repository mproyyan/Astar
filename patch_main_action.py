import re

with open('Astar/Features/Main/MainFeature.swift', 'r') as f:
    text = f.read()

# Add handleAcceptedInvitation to Action
action_pattern = r'(case path\(StackActionOf<Path>\)\n\s*case delegate\(Delegate\))'
text = re.sub(action_pattern, r'\1\n    case handleAcceptedInvitation(String)', text, count=1)

# Refactor onAppear to return a merged effect
onAppear_pattern = r'''(case \.onAppear:\s*
\s*return \.run \{ \[currentUser = state\.login\.userProfile, trackingClient\] send in\s*
\s*if let profile = currentUser \?\? UserProfileStorage\.load\(\) \{\s*
\s*let selfRecordID = "UserProfile_\\\(profile\.appleUserId\)_\\\(profile\.cloudKitUserId\)"\s*
\s*\.replacingOccurrences\(of: "\[\^a-zA-Z0-9\]", with: "_", options: \.regularExpression\)\s*
\s*do \{\s*
\s*try await trackingClient\.setupInvitationSubscription\(selfRecordID\)\s*
\s*print\("✅ Setup invitation subscription for \\\(selfRecordID\)"\)\s*
\s*\} catch \{\s*
\s*print\("⚠️ Failed setting up invitation subscription: \\\(error\)"\)\s*
\s*\}\s*
\s*\}\s*
\s*// 1\. Initial fetch\s*
\s*await send\(\.refreshPeople\)\s*
\s*// 2\. Periodic background refresh every 6 seconds to keep presence in sync\s*
\s*while !Task\.isCancelled \{\s*
\s*try\? await Task\.sleep\(nanoseconds: 6_000_000_000\)\s*
\s*guard !Task\.isCancelled else \{ break \}\s*
\s*await send\(\.refreshPeople\)\s*
\s*\}\s*
\s*\})'''

replacement_onAppear = '''case .onAppear:
        return .merge(
          .run { [currentUser = state.login.userProfile, trackingClient] send in
            if let profile = currentUser ?? UserProfileStorage.load() {
               let selfRecordID = "UserProfile_\\(profile.appleUserId)_\\(profile.cloudKitUserId)"
                  .replacingOccurrences(of: "[^a-zA-Z0-9]", with: "_", options: .regularExpression)
               do {
                   try await trackingClient.setupInvitationSubscription(selfRecordID)
                   print("✅ Setup invitation subscription for \\(selfRecordID)")
               } catch {
                   print("⚠️ Failed setting up invitation subscription: \\(error)")
               }
            }

            // 1. Initial fetch
            await send(.refreshPeople)

            // 2. Periodic background refresh every 6 seconds to keep presence in sync
            while !Task.isCancelled {
              try? await Task.sleep(nanoseconds: 6_000_000_000)
              guard !Task.isCancelled else { break }
              await send(.refreshPeople)
            }
          },
          .run { [trackingClient] send in
              for await notification in NotificationCenter.default.publisher(for: Notification.Name("walkSessionUpdateNotification")).values {
                  guard !Task.isCancelled else { break }
                  if let userInfo = notification.userInfo,
                     let isAccepted = userInfo["isAccepted"] as? Bool,
                     isAccepted,
                     let recordID = userInfo["recordID"] as? __import__("CloudKit").CKRecord.ID {
                     
                     let parts = recordID.recordName.components(separatedBy: "_")
                     if parts.count >= 3 && parts[0] == "SessionParticipant" {
                         let sessionID = parts[1]
                         let prefix = "SessionParticipant_\\(sessionID)_"
                         let selfRecordID = recordID.recordName.replacingOccurrences(of: prefix, with: "")
                         
                         do {
                             try await trackingClient.updateParticipantStatus(sessionID, selfRecordID, "accept")
                             let session = try await trackingClient.getWalkSession(sessionID)
                             await send(.handleAcceptedInvitation(session.walkerRef))
                         } catch {
                             print("❌ Failed to accept invitation or get session: \\(error)")
                         }
                     }
                  }
              }
          }
        )'''

text = re.sub(onAppear_pattern, replacement_onAppear, text, count=1)

with open('Astar/Features/Main/MainFeature.swift', 'w') as f:
    f.write(text)

print("MainFeature.swift updated!")
