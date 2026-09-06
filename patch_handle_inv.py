import re

with open('Astar/Features/Main/MainFeature.swift', 'r') as f:
    text = f.read()

handler_pattern = r'(case \.onAppear:)'
replacement = '''case let .handleAcceptedInvitation(walkerRef):
        // walkerRef is "UserProfile_<appleUserId>_<cloudKitUserId>"
        let prefix = "UserProfile_"
        let ids = walkerRef.replacingOccurrences(of: prefix, with: "").components(separatedBy: "_")
        if ids.count >= 2 {
            let appleUserId = ids[0]
            let cloudKitUserId = ids[1...].joined(separator: "_")
            if let person = state.people.first(where: { $0.appleUserId == appleUserId && $0.cloudKitUserId == cloudKitUserId }) {
                return .send(.map(.selectPerson(person)))
            } else if let person = state.people.first(where: { $0.cloudKitUserId == cloudKitUserId }) {
                return .send(.map(.selectPerson(person)))
            }
        }
        return .none

      \g<1>'''

text = re.sub(handler_pattern, replacement, text, count=1)

with open('Astar/Features/Main/MainFeature.swift', 'w') as f:
    f.write(text)

