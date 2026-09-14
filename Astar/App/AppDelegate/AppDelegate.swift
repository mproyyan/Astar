import UIKit
import CloudKit
import ComposableArchitecture

/// ============================================================================
/// 🔔 SYSTEM DELEGATE & NOTIFICATION DISPATCHER (AppDelegate)
/// ============================================================================
///
/// 💡 TEORI & ANALOGI PYTHON / COMPUTER SCIENCE:
/// - Dalam arsitektur sistem operasi, `AppDelegate` adalah jembatan callback (Hook)
///   antara Kernel / WindowServer iOS dengan memori aplikasi kita.
/// - Berfungsi sebagai **Event Demultiplexer / Dispatcher**:
///   Menerima paket raw APNs (Apple Push Notification service), mengurai payload
///   CloudKit Notification (`CKNotification`), lalu meneruskannya ke subscriber internal
///   melalui Publisher/Subscriber pattern (`NotificationCenter`).
/// ============================================================================
class AppDelegate: UIResponder, UIApplicationDelegate, UNUserNotificationCenterDelegate {

    // MARK: - Notification Event Keys (Pub/Sub Event Topics)
    static let walkSessionUpdateNotification = Notification.Name("walkSessionUpdateNotification")
    static let walkInvitationNotification = Notification.Name("walkInvitationNotification")
    static let walkInvitationAcceptedNotification = Notification.Name("walkInvitationAcceptedNotification")
    static let walkInvitationDismissedNotification = Notification.Name("walkInvitationDismissedNotification")
    static let journeyLogUpdateNotification = Notification.Name("journeyLogUpdateNotification")

    /// Callback saat proses peluncuran aplikasi di OS selesai:
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {

        let center = UNUserNotificationCenter.current()
        center.delegate = self

        // 1. Daftarkan Kategori Notifikasi Interaktif (Actionable Notifications)
        // Pengguna dapat langsung memilih "Accompany" atau "Dismiss" dari banner pop-up tanpa membuka app
        let acceptAction = UNNotificationAction(
            identifier: "ACCEPT_WALK_ACTION",
            title: "Accompany",
            options: [.foreground] // Membuka aplikasi ke foreground saat ditekan
        )
        let dismissAction = UNNotificationAction(
            identifier: "DISMISS_WALK_ACTION",
            title: "Dismiss",
            options: [.destructive] // Ditandai warna merah
        )
        let walkCategory = UNNotificationCategory(
            identifier: "WALK_INVITATION",
            actions: [acceptAction, dismissAction],
            intentIdentifiers: [],
            options: [.customDismissAction]
        )
        center.setNotificationCategories([walkCategory])

        // 2. Minta Izin Notifikasi Pengguna (Alert, Sound, Badge)
        center.requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if granted {
                DispatchQueue.main.async {
                    // Mendaftarkan device token ke server Apple APNs
                    application.registerForRemoteNotifications()
                }
            }
        }

        // 3. Housekeeping: Bersihkan subscription query lama/duplikat di server CloudKit
        // Agar perangkat tidak menerima notifikasi berulang yang membuat bising
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

    /// Callback saat menerima Silent Remote Notification / CloudKit Push di latar belakang (Background Fetch):
    func application(_ application: UIApplication, didReceiveRemoteNotification userInfo: [AnyHashable : Any], fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {

        let receiveTime = Date()
        // Parsing payload JSON menjadi objek typed CloudKit notification
        guard let notification = CKNotification(fromRemoteNotificationDictionary: userInfo) else {
            print("⚠️ [AppDelegate] Received remote notification but could not parse CKNotification at \(receiveTime)")
            completionHandler(.noData)
            return
        }

        // Evaluasi tipe event query CloudKit (apakah ada record dibuat atau diubah)
        if let queryNotification = notification as? CKQueryNotification,
           (queryNotification.queryNotificationReason == .recordCreated || queryNotification.queryNotificationReason == .recordUpdated) {

            if let recordID = queryNotification.recordID {
                let reasonStr = queryNotification.queryNotificationReason == .recordCreated ? "recordCreated" : "recordUpdated"
                let subID = queryNotification.subscriptionID ?? ""
                print("📬 [AppDelegate] APNs Remote Notification received at \(receiveTime) | Reason: \(reasonStr) | SubID: \(subID) | RecordID: \(recordID.recordName)")

                // Routing event berdasarkan prefix subscription ID:
                if subID.hasPrefix("session-participants-") {
                    print("ℹ️ [AppDelegate] Session participants update received for session: \(subID)")
                } else if subID.hasPrefix("session-participant-invitation-") || recordID.recordName.hasPrefix("SessionParticipant_") {
                    // Ada undangan pengawalan masuk untuk user ini
                    NotificationCenter.default.post(
                        name: AppDelegate.walkInvitationNotification,
                        object: nil,
                        userInfo: ["recordID": recordID, "receivedAt": receiveTime]
                    )
                } else if subID.hasPrefix("journey-logs-") {
                    // Ada milestone checkpoint jalan baru
                    NotificationCenter.default.post(
                        name: AppDelegate.journeyLogUpdateNotification,
                        object: nil,
                        userInfo: ["recordID": recordID, "receivedAt": receiveTime]
                    )
                } else {
                    // Pembaruan koordinat atau status WalkSession
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

    // MARK: - UNUserNotificationCenterDelegate (Tampilan Notifikasi Foreground)

    /// Menentukan perilaku saat notifikasi tiba saat aplikasi sedang terbuka di layar:
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        let content = notification.request.content
        let body = content.body
        let title = content.title

        // Redam banner jika itu sekadar update posisi walk session rutin agar tidak menutupi UI peta
        if body.localizedCaseInsensitiveContains("Walk session was updated") ||
            title.localizedCaseInsensitiveContains("Walk session was updated") ||
            body.localizedCaseInsensitiveContains("walk-session") {
            print("🔕 [AppDelegate] Suppressed foreground banner for walk session update")
            completionHandler([])
            return
        }

        // Tampilkan banner, bunyikan audio, dan perbarui badge app icon
        completionHandler([.banner, .sound, .badge])
    }

    /// Menangani respons user saat mengetuk tombol aksi pada banner ("Accompany" vs "Dismiss"):
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
