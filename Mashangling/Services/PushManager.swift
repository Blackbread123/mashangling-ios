import Foundation
import UserNotifications
import UIKit

// MARK: - 推送通知管理（iOS 16 兼容）
class PushManager: NSObject, ObservableObject {
    static let shared = PushManager()

    @Published var isRegistered = false
    @Published var deviceToken: String?

    /// 注册远程推送（应用启动时调用）
    func register() {
        UNUserNotificationCenter.current().delegate = self
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            DispatchQueue.main.async {
                self.isRegistered = granted
                if granted {
                    UIApplication.shared.registerForRemoteNotifications()
                }
            }
        }
    }

    /// 收到 deviceToken 后上传服务器
    func didRegisterForRemoteNotifications(withDeviceToken token: Data) {
        let tokenString = token.map { String(format: "%02.2hhx", $0) }.joined()
        deviceToken = tokenString
        // TODO: 上传到服务器
        // Task { await MashanglingAPI.shared.user.registerDeviceToken(tokenString) }
        print("[Push] deviceToken: \(tokenString)")
    }

    func didFailToRegister(error: Error) {
        print("[Push] 注册失败: \(error.localizedDescription)")
    }
}

// MARK: - UNUserNotificationCenterDelegate
extension PushManager: UNUserNotificationCenterDelegate {

    /// 应用在前台时收到通知
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        // iOS 16 用 .banner；iOS 14 及以下用 .alert
        if #available(iOS 15.0, *) {
            completionHandler([.banner, .sound, .badge])
        } else {
            completionHandler([.alert, .sound, .badge])
        }
    }

    /// 点击通知
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let userInfo = response.notification.request.content.userInfo
        // 解析通知类型跳转到对应页面
        if let type = userInfo["type"] as? String {
            handleNotificationTap(type: type, userInfo: userInfo)
        }
        completionHandler()
    }

    private func handleNotificationTap(type: String, userInfo: [AnyHashable: Any]) {
        // 通过 NotificationCenter 广播，由 View 层处理跳转
        NotificationCenter.default.post(
            name: .didReceivePush,
            object: nil,
            userInfo: ["type": type, "data": userInfo]
        )
    }
}

extension Notification.Name {
    static let didReceivePush = Notification.Name("didReceivePush")
}
