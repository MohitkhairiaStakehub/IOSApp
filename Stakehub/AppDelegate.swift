import UIKit
import FirebaseCore
import FirebaseMessaging
import UserNotifications

final class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate, MessagingDelegate {

    private func handleDeepLink(_ url: URL) {
           // cache for first render
           DeepLinkManager.shared.pendingURL = url
           // also broadcast for warm/foreground cases
           NotificationCenter.default.post(name: .openDeepLink, object: url)
       }
    
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        FirebaseApp.configure()

        // Ask notif permission and register for APNs
        UNUserNotificationCenter.current().delegate = self
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in
            DispatchQueue.main.async {
                UIApplication.shared.registerForRemoteNotifications()
            }
        }

        Messaging.messaging().delegate = self
        
        // 👇 If the app was launched by tapping a push, extract click_url here too
        if let payload = launchOptions?[.remoteNotification] as? [AnyHashable: Any],
           let urlStr = (payload["click_url"] as? String) ??               // if you put it at root
                        ((payload["aps"] as? [String: Any])?["click_url"] as? String), // or inside aps
           let url = URL(string: urlStr) {
            handleDeepLink(url)
        }
        
        return true
    }

    // APNs token -> FCM
    func application(_ application: UIApplication,
                     didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        Messaging.messaging().apnsToken = deviceToken
    }

    func application(_ application: UIApplication,
                     didFailToRegisterForRemoteNotificationsWithError error: Error) {
        print("APNs registration failed: \(error)")
    }

    // FCM token (initial + on refresh/rotate)
    func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
        guard let token = fcmToken, !token.isEmpty else { return }
        print("FCM token (iOS): \(token)")
        // Broadcast to SwiftUI layer
        NotificationCenter.default.post(name: .fcmTokenUpdated, object: token)
    }

    // Foreground presentation behavior
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification,
                                withCompletionHandler completion: @escaping (UNNotificationPresentationOptions) -> Void) {
        completion([.banner, .sound, .badge])
    }

    // Tap on notification -> open click_url inside WebView
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                 didReceive response: UNNotificationResponse,
                                 withCompletionHandler completion: @escaping () -> Void) {
         let userInfo = response.notification.request.content.userInfo

         // You already send click_url in your APNs root payload:
         if let click = userInfo["click_url"] as? String, let url = URL(string: click) {
             handleDeepLink(url)
         }
         completion()
     }

}

extension Notification.Name {
    static let fcmTokenUpdated = Notification.Name("StakehubFcmTokenUpdated")
    static let openDeepLink = Notification.Name("StakehubOpenDeepLink")
}
