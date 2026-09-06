import re

with open('Astar/Features/Main/MainFeature.swift', 'r') as f:
    text = f.read()

# Add trackingClient dependency
dep_pattern = r'(@Dependency\(\\\.usersClient\) var usersClient\n)'
text = re.sub(dep_pattern, r'\1  @Dependency(\\.trackingClient) var trackingClient\n', text, count=1)

# Update onAppear
onAppear_pattern = r'''(case \.onAppear:\s*
\s*return \.run \{ send in\s*
\s*// 1\. Initial fetch)'''

replacement_onAppear = '''case .onAppear:
        return .run { [currentUser = state.login.userProfile, trackingClient] send in
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

          // 1. Initial fetch'''

text = re.sub(onAppear_pattern, replacement_onAppear, text, count=1)

with open('Astar/Features/Main/MainFeature.swift', 'w') as f:
    f.write(text)

print("MainFeature.swift updated!")
