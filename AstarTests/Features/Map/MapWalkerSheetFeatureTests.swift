import ComposableArchitecture
import XCTest
@testable import Astar

@MainActor
final class MapWalkerSheetFeatureTests: XCTestCase {
    
    func testTrackTappedRetrievesSessionCorrectly() async {
        let testAppleID = "apple-test"
        let testCloudKitID = "ck-test"
        
        let testPerson = Person(
            id: UUID(),
            name: "Mentari",
            status: "Walking",
            appleUserId: testAppleID,
            cloudKitUserId: testCloudKitID
        )
        
        let expectedSession = WalkSession(
            id: "session-1234",
            walkerRef: "UserProfile_apple_test_ck_test",
            status: "active",
            destinationName: "Home",
            destinationLatitude: -6.2125,
            destinationLongitude: 106.8166,
            routePolyline: nil,
            startedAt: Date(timeIntervalSince1970: 0),
            endedAt: nil,
            lastPingAt: Date(timeIntervalSince1970: 0)
        )
        
        let store = TestStore(
            initialState: MapWalkerSheetFeature.State(
                walker: testPerson,
                status: "Walking"
            )
        ) {
            MapWalkerSheetFeature()
        } withDependencies: {
            $0.trackingClient.getWalkerActiveSessionID = { recordID in
                XCTAssertEqual(recordID, "UserProfile_\(testAppleID)_\(testCloudKitID)".replacingOccurrences(of: "[^a-zA-Z0-9]", with: "_", options: .regularExpression))
                return "session-1234"
            }
            
            $0.trackingClient.getWalkSession = { sessionID in
                XCTAssertEqual(sessionID, "session-1234")
                return expectedSession
            }
        }
        
        await store.send(.trackTapped)
        
        await store.receive(.WalkSessionLoaded(expectedSession)) {
            $0.activeParticipantID = expectedSession.id
            $0.originPlaceName = "Current Location"
            $0.originIconName = "location.fill"
            $0.destinationPlaceName = expectedSession.destinationName
            $0.destinationIconName = "house.fill"
        }
        
        // Assert exactly matching the enum value rather than using CasePaths \.delegate.trackingStarted
        await store.receive(.delegate(.trackingStarted(testPerson, expectedSession)))
    }
}
