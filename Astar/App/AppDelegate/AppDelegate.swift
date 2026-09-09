import UIKit
import CloudKit
import ComposableArchitecture

class AppDelegate: UIResponder, UIApplicationDelegate, UNUserNotificationCenterDelegate {

    // We can store a reference to the global store here if needed, or pass notification info via publishers
    static let walkSessionUpdateNotification = Notification.Name("walkSessionUpdateNotification")
    static let walkInvitationNotification = Notification.Name("walkInvitationNotification")
    static let walkInvitationAcceptedNotification = Notification.Name("walkInvitationAcceptedNotification")
    static let walkInvitationDismissedNotification = Notification.Name("walkInvitationDismissedNotification")
    static let journeyLogUpdateNotification = Notification.Name("journeyLogUpdateNotification")

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {

        let center = UNUserNotificationCenter.current()
        center.delegate = self

        // Register Actionable Notification Category for Walk Invitations
        let acceptAction = UNNotificationAction(
            identifier: "ACCEPT_WALK_ACTION",
            title: "Accompany",
            options: [.foreground]
        )
        let dismissAction = UNNotificationAction(
            identifier: "DISMISS_WALK_ACTION",
            title: "Dismiss",
            options: [.destructive]
        )
        let walkCategory = UNNotificationCategory(
            identifier: "WALK_INVITATION",
            actions: [acceptAction, dismissAction],
            intentIdentifiers: [],
            options: [.customDismissAction]
        )
        center.setNotificationCategories([walkCategory])

        // Request Notification Permission
        center.requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if granted {
                DispatchQueue.main.async {
                    application.registerForRemoteNotifications()
                }
            }
        }

        // Purge legacy noisy subscriptions from Apple's CloudKit servers
        Task {
            let db = CKContainer.default().publicCloudDatabase
            if let subs = try? await db.allSubscriptions() {
                for sub in subs where sub.subscriptionID.hasPrefix("walk-session-") {
                    if let querySub = sub as? CKQuerySubscription, querySub.notificationInfo?.alertBody != nil {
                        try? await db.deleteSubscription(withID: sub.subscriptionID)
                        print("🧹 [AppDelegate] Purged legacy noisy subscription: \(sub.subscriptionID)")
                    }
                }
            }
        }

        return true
    }

    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        print("Registered for remote notifications: \(deviceToken)")
    }

    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        print("Failed to register for remote notifications: \(error)")
    }

    func application(_ application: UIApplication, didReceiveRemoteNotification userInfo: [AnyHashable : Any], fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {

        let receiveTime = Date()
        guard let notification = CKNotification(fromRemoteNotificationDictionary: userInfo) else {
            print("⚠️ [AppDelegate] Received remote notification but could not parse CKNotification at \(receiveTime)")
            completionHandler(.noData)
            return
        }

        if let queryNotification = notification as? CKQueryNotification,
           (queryNotification.queryNotificationReason == .recordCreated || queryNotification.queryNotificationReason == .recordUpdated) {

            if let recordID = queryNotification.recordID {
                let reasonStr = queryNotification.queryNotificationReason == .recordCreated ? "recordCreated" : "recordUpdated"
                let subID = queryNotification.subscriptionID ?? ""
                print("📬 [AppDelegate] APNs Remote Notification received at \(receiveTime) | Reason: \(reasonStr) | SubID: \(subID) | RecordID: \(recordID.recordName)")

                if subID.hasPrefix("session-participants-") {
                    // Participant status update for the walker's session - handled by walker's participant stream
                    print("ℹ️ [AppDelegate] Session participants update received for session: \(subID)")
                } else if subID.hasPrefix("session-participant-invitation-") || recordID.recordName.hasPrefix("SessionParticipant_") {
                    NotificationCenter.default.post(
                        name: AppDelegate.walkInvitationNotification,
                        object: nil,
                        userInfo: ["recordID": recordID, "receivedAt": receiveTime]
                    )
                } else if subID.hasPrefix("journey-logs-") {
                    NotificationCenter.default.post(
                        name: AppDelegate.journeyLogUpdateNotification,
                        object: nil,
                        userInfo: ["recordID": recordID, "receivedAt": receiveTime]
                    )
                } else {
                    NotificationCenter.default.post(
                        name: AppDelegate.walkSessionUpdateNotification,
                        object: nil,
                        userInfo: ["recordID": recordID, "receivedAt": receiveTime]
                    )
                }
            }
            completionHandler(.newData)
        } else {
            print("ℹ️ [AppDelegate] Remote notification ignored (non-query or unhandled reason) at \(receiveTime)")
            completionHandler(.noData)
        }
    }

    // MARK: - UNUserNotificationCenterDelegate

    // Show banner even if the app is currently in the foreground, but strictly suppress noisy walk session updates
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        let content = notification.request.content
        let body = content.body
        let title = content.title

        if body.localizedCaseInsensitiveContains("Walk session was updated") ||
            title.localizedCaseInsensitiveContains("Walk session was updated") ||
            body.localizedCaseInsensitiveContains("walk-session") {
            print("🔕 [AppDelegate] Suppressed foreground banner for walk session update")
            completionHandler([])
            return
        }

        completionHandler([.banner, .sound, .badge])
    }

    // Handle user tap on notification action buttons ("Accompany" vs "Dismiss")
    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        let actionID = response.actionIdentifier
        let userInfo = response.notification.request.content.userInfo

        if actionID == "ACCEPT_WALK_ACTION" || actionID == UNNotificationDefaultActionIdentifier {
            print("✅ [AppDelegate] Companion accepted walk invitation (action: \(actionID))")
            if let ckNotification = CKNotification(fromRemoteNotificationDictionary: userInfo) as? CKQueryNotification,
               let recordID = ckNotification.recordID {
                if recordID.recordName.hasPrefix("SessionParticipant_") {
                    NotificationCenter.default.post(
                        name: AppDelegate.walkInvitationAcceptedNotification,
                        object: nil,
                        userInfo: ["recordID": recordID, "isAccepted": true]
                    )
                } else {
                    NotificationCenter.default.post(
                        name: AppDelegate.walkSessionUpdateNotification,
                        object: nil,
                        userInfo: ["recordID": recordID, "isAccepted": true]
                    )
                }
            }
        } else if actionID == "DISMISS_WALK_ACTION" || actionID == UNNotificationDismissActionIdentifier {
            print("🚫 [AppDelegate] Companion dismissed walk invitation (action: \(actionID))")
            if let ckNotification = CKNotification(fromRemoteNotificationDictionary: userInfo) as? CKQueryNotification,
               let recordID = ckNotification.recordID {
                NotificationCenter.default.post(
                    name: AppDelegate.walkInvitationDismissedNotification,
                    object: nil,
                    userInfo: ["recordID": recordID]
                )
            }
        }

        completionHandler()
    }
}
