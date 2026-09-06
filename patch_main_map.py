import re

with open('Astar/Features/Map/MainMapFeature.swift', 'r') as f:
    text = f.read()

# Replace joinWalkSession
text = text.replace(
    'let sessionParticipant = try await trackingClient.joinWalkSession(session.id, selfRecordID)',
    'let sessionParticipant = try await trackingClient.updateParticipantStatus(session.id, selfRecordID, "accept")'
)

# In trackingEnded, we need to leave the session by updating status to "left"
# Let's find trackingEnded handling
tracking_ended_pattern = r'''(case \.sheet\(\.presented\(\.walker\(\.delegate\(\.trackingEnded\)\)\)\):\s*
\s*let endingSessionID = state\.activeWalkSessionID\s*
\s*state\.activeWalkSessionID = nil\s*
\s*state\.trackedWalkerDestination = nil\s*
\s*state\.trackedWalkerRoute = nil\s*
\s*state\.trackedWalkerPolyline = nil\s*
\s*return \.merge\(\s*
\s*\.send\(\.delegate\(\.companionStatusChanged\(newStatus: "idle"\)\)\),\s*
\s*\.run \{ \[trackingClient\] _ in\s*
\s*if let sessionID = endingSessionID \{\s*
\s*try\? await trackingClient\.setSubscribeWalkSession\(sessionID, false\)\s*
\s*\})'''

replacement_tracking_ended = '''case .sheet(.presented(.walker(.delegate(.trackingEnded)))):
            let endingSessionID = state.activeWalkSessionID
            state.activeWalkSessionID = nil
            state.trackedWalkerDestination = nil
            state.trackedWalkerRoute = nil
            state.trackedWalkerPolyline = nil
            return .merge(
               .send(.delegate(.companionStatusChanged(newStatus: "idle"))),
               .run { [trackingClient] _ in
                  if let sessionID = endingSessionID {
                     try? await trackingClient.setSubscribeWalkSession(sessionID, false)
                     if let profile = UserProfileStorage.load() {
                         let selfRecordID = "UserProfile_\\(profile.appleUserId)_\\(profile.cloudKitUserId)"
                            .replacingOccurrences(of: "[^a-zA-Z0-9]", with: "_", options: .regularExpression)
                         try? await trackingClient.updateParticipantStatus(sessionID, selfRecordID, "left")
                     }
                  }'''

text = re.sub(tracking_ended_pattern, replacement_tracking_ended, text, count=1)

with open('Astar/Features/Map/MainMapFeature.swift', 'w') as f:
    f.write(text)

print("MainMapFeature.swift updated!")
