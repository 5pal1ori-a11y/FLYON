import Observation
import UIKit
import UserNotifications

/// 푸시 알림 권한과 기기 토큰 관리
@Observable
final class PushManager {
    static let shared = PushManager()

    private(set) var deviceToken: String? = UserDefaults.standard.string(forKey: "flyon.pushToken")
    var authorizationStatus: UNAuthorizationStatus = .notDetermined
    /// 알림을 눌러 열어야 할 노선
    var openedRoute: FavoriteRoute?
    var openedDate: Date?

    var isAuthorized: Bool { authorizationStatus == .authorized || authorizationStatus == .provisional }

    func refreshStatus() async {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        authorizationStatus = settings.authorizationStatus
    }

    /// 권한을 요청하고 기기 토큰을 받는다. 거부되면 nil.
    @MainActor
    func requestAndRegister() async -> String? {
        let granted = (try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge])) ?? false
        await refreshStatus()
        guard granted else { return nil }
        UIApplication.shared.registerForRemoteNotifications()
        for _ in 0..<40 {
            if let deviceToken { return deviceToken }
            try? await Task.sleep(for: .milliseconds(150))
        }
        return deviceToken
    }

    func setToken(_ data: Data) {
        let token = data.map { String(format: "%02x", $0) }.joined()
        deviceToken = token
        UserDefaults.standard.set(token, forKey: "flyon.pushToken")
    }
}

final class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        Task { @MainActor in
            await PushManager.shared.refreshStatus()
            if PushManager.shared.isAuthorized { application.registerForRemoteNotifications() }
        }
        return true
    }

    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        PushManager.shared.setToken(deviceToken)
    }

    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        print("[push] register failed: \(error.localizedDescription)")
    }

    // 앱을 보고 있을 때도 배너로 보여 준다
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification,
                                withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .sound])
    }

    // 알림을 누르면 해당 노선을 연다
    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse,
                                withCompletionHandler completionHandler: @escaping () -> Void) {
        let info = response.notification.request.content.userInfo
        if let origin = info["origin"] as? String, let destination = info["destination"] as? String {
            let date = (info["date"] as? String).flatMap { ServerPriceProvider.dayParser.date(from: $0) }
            DispatchQueue.main.async {
                PushManager.shared.openedDate = date
                PushManager.shared.openedRoute = FavoriteRoute(originCode: origin, destinationCode: destination)
            }
        }
        completionHandler()
    }
}
