import UIKit
import CloudKit
import ComposableArchitecture

class AppDelegate: UIResponder, UIApplicationDelegate {

    // We can store a reference to the global store here if needed, or pass notification info via publishers
    static let locationPingNotification = Notification.Name("locationPingNotification")

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {

        // Request Notification Permission
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if granted {
                DispatchQueue.main.async {
                    application.registerForRemoteNotifications()
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

        guard let notification = CKNotification(fromRemoteNotificationDictionary: userInfo) else {
            completionHandler(.newData)
            return
        }

        if let queryNotification = notification as? CKQueryNotification,
           (queryNotification.queryNotificationReason == .recordCreated || queryNotification.queryNotificationReason == .recordUpdated) {

            // Post local notification to be picked up by map view tracking
            if let recordID = queryNotification.recordID {
                NotificationCenter.default.post(
                    name: AppDelegate.locationPingNotification,
                    object: nil,
                    userInfo: ["recordID": recordID]
                )
            }
            completionHandler(.newData)
        } else {
            completionHandler(.noData)
        }
    }
}
