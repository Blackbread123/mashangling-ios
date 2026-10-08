import Foundation
import BackgroundTasks
import UIKit

// MARK: - 后台刷新管理（iOS 16 兼容）
// 作用：App 退到后台/锁屏后，由系统定期唤醒，拉取未读消息并发本地推送。
// 说明：唤醒频率由 iOS 按使用习惯调度（通常几十分钟一次），不是实时推送；
//      实时推送需要服务端接 APNs，网页后端暂不支持，这是目前最优方案。
enum BackgroundRefreshManager {
    static let taskId = "com.mashangling.app.unreadRefresh"

    /// 注册任务并排队下一次（必须在 didFinishLaunching 早期调用）
    static func register() {
        BGTaskScheduler.shared.register(forTaskWithIdentifier: taskId, using: nil) { task in
            guard let refresh = task as? BGAppRefreshTask else { return }
            handle(refresh)
        }
        schedule()
    }

    /// 排队下一次后台唤醒（最早 15 分钟后，具体由系统决定）
    static func schedule() {
        let req = BGAppRefreshTaskRequest(identifier: taskId)
        req.earliestBeginDate = Date(timeIntervalSinceNow: 15 * 60)
        try? BGTaskScheduler.shared.submit(req)
    }

    private static func handle(_ task: BGAppRefreshTask) {
        schedule() // 先排下一次，保证链条不断
        let work = Task { @MainActor in
            // refreshNow 内部：未读数增加 → 拉最新消息 → 发本地推送
            await UnreadManager.shared.refreshNow()
        }
        task.expirationHandler = { work.cancel() }
        Task {
            _ = await work.result
            task.setTaskCompleted(success: !work.isCancelled)
        }
    }
}
