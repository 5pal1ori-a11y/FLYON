import SwiftUI
import UIKit

/// 앱 아이콘을 길게 눌렀을 때 나오는 바로가기
final class ShortcutRouter: ObservableObject {
    static let shared = ShortcutRouter()
    @Published var action: String?
    func handle(_ item: UIApplicationShortcutItem) { action = item.type }
    static func install() {
        UIApplication.shared.shortcutItems = [
            UIApplicationShortcutItem(type: "add", localizedTitle: "구독 추가", localizedSubtitle: nil, icon: UIApplicationShortcutIcon(systemImageName: "plus.circle.fill")),
            UIApplicationShortcutItem(type: "ask", localizedTitle: "이번 달 얼마?", localizedSubtitle: "AI에게 물어보기", icon: UIApplicationShortcutIcon(systemImageName: "sparkles")),
            UIApplicationShortcutItem(type: "report", localizedTitle: "월간 리포트", localizedSubtitle: nil, icon: UIApplicationShortcutIcon(systemImageName: "chart.bar.doc.horizontal")),
        ]
    }
}

final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication, configurationForConnecting connectingSceneSession: UISceneSession, options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        if let item = options.shortcutItem { ShortcutRouter.shared.handle(item) }
        let c = UISceneConfiguration(name: nil, sessionRole: connectingSceneSession.role)
        c.delegateClass = SceneDelegate.self
        return c
    }
}

final class SceneDelegate: NSObject, UIWindowSceneDelegate {
    func windowScene(_ windowScene: UIWindowScene, performActionFor shortcutItem: UIApplicationShortcutItem, completionHandler: @escaping (Bool) -> Void) {
        ShortcutRouter.shared.handle(shortcutItem)
        completionHandler(true)
    }
}
