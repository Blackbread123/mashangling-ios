import UIKit

// MARK: - AppDelegate（处理推送回调等 UIApplicationDelegate 事件）
class AppDelegate: NSObject, UIApplicationDelegate {

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        // 清理过期缓存
        Task { await CacheManager.shared.cleanExpiredCache() }
        // cleanExpiredCache 是 actor 方法，需要在 Task 中调用
        return true
    }

    // MARK: 推送注册回调
    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        PushManager.shared.didRegisterForRemoteNotifications(withDeviceToken: deviceToken)
    }

    func application(
        _ application: UIApplication,
        didFailToRegisterForRemoteNotificationsWithError error: Error
    ) {
        PushManager.shared.didFailToRegister(error: error)
    }

    // MARK: 后台刷新
    func application(
        _ application: UIApplication,
        performFetchWithCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void
    ) {
        Task { @MainActor in
            await UnreadManager.shared.refreshNow()
            completionHandler(.newData)
        }
    }
}
