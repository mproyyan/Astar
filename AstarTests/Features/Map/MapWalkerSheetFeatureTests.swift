import ComposableArchitecture
import CoreLocation
import SwiftUI
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
            currentCoordinate: nil,
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

    func testJourneyLogTappedAndDismissed() async {
        let testPerson = Person(
            id: UUID(),
            name: "John Doe",
            status: "Idle"
        )

        let store = TestStore(
            initialState: MapWalkerSheetFeature.State(
                walker: testPerson,
                status: "Idle",
                isDestinationReached: true
            )
        ) {
            MapWalkerSheetFeature()
        }

        await store.send(.journeyLogTapped) {
            $0.isViewingJourneyLog = true
        }

        await store.send(.dismissJourneyLogTapped) {
            $0.isViewingJourneyLog = false
        }
    }

    func testDoeTrackTapped() async {
        let walker = Person(id: Person.mockDoeID, name: "Doe", status: "Walking")
        let now = Date(timeIntervalSince1970: 1000)
        let store = TestStore(
            initialState: MapWalkerSheetFeature.State(
                walker: walker,
                status: "Walking"
            )
        ) {
            MapWalkerSheetFeature()
        } withDependencies: {
            $0.date.now = now
        }

        await store.send(.trackTapped)

        let expectedSession = WalkSession(
            id: "mock-doe-session",
            walkerRef: "mock-doe",
            status: "active",
            destinationName: MockDoeWalkSimulation.destinationName,
            destinationLatitude: MockDoeWalkSimulation.destinationCoordinate.latitude,
            destinationLongitude: MockDoeWalkSimulation.destinationCoordinate.longitude,
            routePolyline: nil,
            startedAt: now,
            endedAt: nil,
            currentCoordinate: nil,
            lastPingAt: now
        )

        await store.receive(.WalkSessionLoaded(expectedSession)) {
            $0.activeParticipantID = "mock-doe-session"
            $0.originPlaceName = "Autograph Tower"
            $0.originIconName = "briefcase.fill"
            $0.destinationPlaceName = "Home"
            $0.destinationIconName = "house.fill"
        }

        await store.receive(.delegate(.trackingStarted(walker, expectedSession)))
    }

    func testDoeReachDestinationTapped() async {
        let walker = Person(id: Person.mockDoeID, name: "Doe", status: "Walking")
        let now = Date(timeIntervalSince1970: 1000)
        let store = TestStore(
            initialState: MapWalkerSheetFeature.State(
                walker: Person(id: Person.mockDoeID, name: "Doe", status: "Walking"),
                status: "Walking",
                trips: []
            )
        ) {
            MapWalkerSheetFeature()
        } withDependencies: {
            $0.date.now = now
        }

        let idleWalker = Person(id: Person.mockDoeID, name: "Doe", status: "Idle")

        await store.send(.reachDestinationTapped) {
            $0.isDestinationReached = true
            $0.status = "Idle"
            $0.walker = idleWalker
            $0.journeyLogEntries = MockDoeWalkSimulation.completedJourneyLog(now: now)
            $0.trips = [MockDoeWalkSimulation.completedTrip(now: now)]
        }
        await store.receive(.delegate(.walkerReachedDestination(idleWalker)))
    }

    func testDoeExitTrackTappedDoesNotMarkDestinationReached() async {
        let walker = Person(id: Person.mockDoeID, name: "Doe", status: "Walking")
        let store = TestStore(
            initialState: MapWalkerSheetFeature.State(
                walker: walker,
                status: "Walking",
                isDestinationReached: false,
                activeParticipantID: "mock-doe-session"
            )
        ) {
            MapWalkerSheetFeature()
        }

        await store.send(.exitTrackTapped) {
            $0.activeParticipantID = nil
            // isDestinationReached must remain false
            $0.isDestinationReached = false
        }

        await store.receive(.delegate(.trackingEnded))
    }

    func testAccompanyStatusEvaluatesToIdleOrAccompany() {
        let accompanyPerson = Person(id: UUID(), name: "Pandu", status: "accompany")
        let accompanyState = MapWalkerSheetFeature.State(walker: accompanyPerson, status: "accompany")
        XCTAssertTrue(accompanyState.isIdleOrAccompany)

        let uppercaseAccompanyState = MapWalkerSheetFeature.State(walker: accompanyPerson, status: "Accompany")
        XCTAssertTrue(uppercaseAccompanyState.isIdleOrAccompany)

        let idlePerson = Person(id: UUID(), name: "Pandu", status: "Idle")
        let idleState = MapWalkerSheetFeature.State(walker: idlePerson, status: "Idle")
        XCTAssertTrue(idleState.isIdleOrAccompany)

        let walkingPerson = Person(id: UUID(), name: "Mentari", status: "Walking")
        let walkingState = MapWalkerSheetFeature.State(walker: walkingPerson, status: "Walking")
        XCTAssertFalse(walkingState.isIdleOrAccompany)
    }

    func testAccompanyStatusHistoryNavigation() async {
        let accompanyPerson = Person(id: UUID(), name: "Pandu", status: "accompany")
        let testTrip = WalkerSampleData.defaultTrips[0]
        let store = TestStore(
            initialState: MapWalkerSheetFeature.State(
                walker: accompanyPerson,
                status: "accompany"
            )
        ) {
            MapWalkerSheetFeature()
        }

        await store.send(.viewAllHistoryTapped) {
            $0.isViewingHistoryList = true
        }

        await store.send(.selectHistoryTrip(testTrip)) {
            $0.selectedHistoryTrip = testTrip
        }

        await store.send(.dismissHistoryDetailTapped) {
            $0.selectedHistoryTrip = nil
        }

        await store.send(.dismissHistoryListTapped) {
            $0.isViewingHistoryList = false
        }
    }
}
