import SwiftUI
import UserNotifications

// MARK: - 主 Tab 视图（逐行复刻网页 TabBar.tsx）
// 网页移动端底栏：通栏 h-14、顶部分隔线 border-border/60、bg-background/95 + 毛玻璃；
// 中间「发布」凸起 48 圆形主色按钮（上移 16）；选中态仅图标/文字变主色（无底块）；
// 消息带红色未读角标；消息/我的需登录。不用系统 TabView（新版 iOS 会渲染成悬浮胶囊）。
struct MainTabView: View {
    @StateObject private var unreadManager = UnreadManager.shared
    @EnvironmentObject var authManager: AuthManager
    @State private var tab = 0
    @State private var showLogin = false
    // 各 Tab 的重置序号：点 Tab 时 +1 强制回到该栏目根页面（防止头像菜单 push 的页面卡住）
    @State private var resetIDs = [0, 0, 0, 0, 0]

    var body: some View {
        GeometryReader { geo in
            let bottomPad = geo.safeAreaInsets.bottom * 0.12 // 贴近 Home 指示条（对齐 PWA 间距比例）
            let barHeight = 56 + bottomPad
            ZStack(alignment: .bottom) {
                // 内容区（五个 Tab 常驻保活，切换不重载；延伸进底部安全区，底栏高度由 padding 让出）
                ZStack {
                    HomeView()
                        .id(resetIDs[0])
                        .opacity(tab == 0 ? 1 : 0).allowsHitTesting(tab == 0)
                    PlazaView()
                        .id(resetIDs[1])
                        .opacity(tab == 1 ? 1 : 0).allowsHitTesting(tab == 1)
                    NavigationStack { PublishView() }
                        .opacity(tab == 2 ? 1 : 0).allowsHitTesting(tab == 2)
                    MessagesView()
                        .id(resetIDs[3])
                        .opacity(tab == 3 ? 1 : 0).allowsHitTesting(tab == 3)
                    NavigationStack { ProfileView(userId: authManager.currentUser?.id ?? 0) }
                        .id("\(authManager.currentUser?.id ?? 0)-\(resetIDs[4])")   // 登录态就绪/点 Tab 时重建回根页面
                        .opacity(tab == 4 ? 1 : 0).allowsHitTesting(tab == 4)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(.bottom, barHeight)
                .ignoresSafeArea(edges: .bottom)

                // 底栏（视觉总高对齐 PWA：56 + 安全区一半，不多不少）
                VStack(spacing: 0) {
                    Rectangle()
                        .fill(Color.appBorder.opacity(0.6))
                        .frame(height: 0.5)
                    HStack(spacing: 0) {
                        tabButton(index: 0, label: "首页", icon: "house")
                        tabButton(index: 1, label: "广场", icon: "square.grid.2x2")
                        publishButton
                        tabButton(index: 3, label: "消息", icon: "bubble.left",
                                  badge: unreadManager.totalUnread)
                        tabButton(index: 4, label: "我的", icon: "person")
                    }
                    .frame(height: 56)
                    Color.clear.frame(height: bottomPad)
                }
                .background(
                    ZStack {
                        Rectangle().fill(.ultraThinMaterial)
                        Color.appBackground.opacity(0.95)
                    }
                )
                .ignoresSafeArea(edges: .bottom) // 底栏延伸进 Home 指示条区，底部留白由 bottomPad 承担

                // 新功能悬浮提示卡（网页 PostFeatureTip：bottom-16 right-4 w-64，消息页不显示）
                HStack {
                    Spacer()
                    PostFeatureTipView(onMessagesTab: tab == 3) {
                        tab = 3
                        resetIDs[3] += 1
                        NotificationCenter.default.post(name: .mslShowPosts, object: nil)
                    }
                    .padding(.trailing, 16)
                    .padding(.bottom, barHeight + 8)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)

                // 封禁横幅（网页 BanBanner：fixed inset-x-0 top-0 bg-red-600/95 text-xs，z-60）
                if let ban = authManager.banInfo {
                    VStack(spacing: 0) {
                        HStack(spacing: 8) {
                            Image(systemName: "exclamationmark.shield.fill")
                                .font(.system(size: 12))
                            Text(Self.banText(ban))
                                .font(.system(size: 12, weight: .medium))
                                .multilineTextAlignment(.center)
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.horizontal, 16)
                        .padding(.top, geo.safeAreaInsets.top + 8)
                        .padding(.bottom, 8)
                        .background(Color(red: 220/255, green: 38/255, blue: 38/255).opacity(0.95))
                        Spacer(minLength: 0)
                    }
                    .ignoresSafeArea(edges: .top)
                }
            }
        }
        .ignoresSafeArea(.keyboard)
        .sheet(isPresented: $showLogin) { LoginView() }
        .onAppear { unreadManager.startPolling() }
        .onReceive(NotificationCenter.default.publisher(for: .mslSwitchTab)) { n in
            if let i = n.object as? Int { tab = i }
        }
        // 点击推送通知 → 落到消息页（回根页面，保证看到最新列表）
        .onReceive(NotificationCenter.default.publisher(for: .didReceivePush)) { _ in
            if authManager.isAuthenticated { tab = 3; resetIDs[3] += 1 }
        }
    }

    // MARK: 封禁文案（逐行复刻网页 BanBanner.tsx）
    static func banText(_ ban: BanInfo) -> String {
        if ban.permanent == true {
            return "账号已被永久封禁，期间仅可浏览公开内容"
        }
        var untilStr = ""
        if let until = ban.until, let d = DateFmt.parse(until) {
            let f = DateFormatter()
            f.locale = Locale(identifier: "zh_CN")
            f.dateFormat = "yyyy/M/d"
            untilStr = f.string(from: d)
        }
        return "账号已被封禁（剩余 \(ban.daysLeft ?? 0) 天，预计 \(untilStr) 恢复），期间仅可浏览公开内容"
    }

    // 普通标签：图标 24 + 文字 10，选中变主色（网页：active 仅 text-primary）
    private func tabButton(index: Int, label: String, icon: String, badge: Int = 0) -> some View {
        let active = tab == index
        return Button {
            if (index == 3 || index == 4) && !authManager.isAuthenticated {
                showLogin = true
            } else {
                tab = index
                // 无论何时点 Tab 都回到该栏目根页面（发布页除外，防止清空填写中的表单）
                if index != 2 { resetIDs[index] += 1 }
            }
        } label: {
            VStack(spacing: 2) {
                ZStack(alignment: .topTrailing) {
                    Image(systemName: icon)
                        .font(.system(size: 24, weight: .regular))
                    if badge > 0 {
                        Text(badge > 99 ? "99+" : "\(badge)")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(.white)
                            .padding(.horizontal, 4)
                            .frame(height: 16)
                            .background(Color.red)
                            .cornerRadius(8)
                            .offset(x: 10, y: -4)
                    }
                }
                .frame(height: 24)
                Text(label)
                    .font(.system(size: 10, weight: active ? .medium : .regular))
            }
            .foregroundColor(active ? .appPrimary : .appMutedFg)
            .frame(width: 64)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // 中间凸起「发布」：48 圆形主色底上移 16，下方 10px 小字（网页 -mt-4 h-12 w-12 shadow-md）
    private var publishButton: some View {
        Button {
            if authManager.isAuthenticated { tab = 2 } else { showLogin = true }
        } label: {
            VStack(spacing: 4) {
                Image(systemName: "plus")
                    .font(.system(size: 24, weight: .regular))
                    .foregroundColor(.appPrimaryFg)
                    .frame(width: 48, height: 48)
                    .background(Color.appPrimary)
                    .clipShape(Circle())
                    .shadow(color: .black.opacity(0.15), radius: 4, y: 2)
                Text("发布")
                    .font(.system(size: 10))
                    .foregroundColor(.appMutedFg)
            }
            .padding(.top, -16) // 网页 -mt-4：圆形按钮凸出底栏顶边
            .frame(width: 64)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - 未读消息轮询
@MainActor
class UnreadManager: ObservableObject {
    static let shared = UnreadManager()

    @Published var totalUnread = 0
    private var timer: Timer?

    func startPolling() {
        timer?.invalidate()
        Task { await fetchUnread() }
        timer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            Task { await self.fetchUnread() }
        }
    }

    func stopPolling() {
        timer?.invalidate()
        timer = nil
    }

    private func fetchUnread() async {
        guard AuthManager.shared.isAuthenticated else { return }
        do {
            let count = try await MashanglingAPI.shared.message.unreadCount()
            let previous = totalUnread
            totalUnread = count
            // 未读数增加 → 拉最新未读消息发 App 本地推送
            if count > previous { await notifyNewMessages() }
        } catch {
            // 静默失败
        }
    }

    /// 对新到的站内信发系统通知（网页只有邮件；App 用本地推送实现「APP推送」）
    private func notifyNewMessages() async {
        let center = UNUserNotificationCenter.current()
        let settings = try? await center.notificationSettings()
        guard settings?.authorizationStatus == .authorized else { return }
        guard let list = try? await MashanglingAPI.shared.message.list(type: "all") else { return }
        let defaults = UserDefaults.standard
        let key = "msl-last-notified-msg-id"
        var lastId = defaults.integer(forKey: key)
        if lastId == 0 {
            // 首次运行：以当前最大 id 为基线，不轰炸历史消息
            lastId = list.map(\.id).max() ?? 0
            defaults.set(lastId, forKey: key)
            return
        }
        let fresh = list.filter { !$0.read && $0.id > lastId }.sorted { $0.id < $1.id }
        for m in fresh {
            let content = UNMutableNotificationContent()
            content.title = m.title
            content.body = m.content ?? ""
            content.sound = .default
            content.userInfo = ["type": m.type, "messageId": m.id,
                                "link": m.link ?? "", "showcaseId": m.showcaseId ?? 0,
                                "fromUserId": m.fromUserId ?? 0]
            let req = UNNotificationRequest(identifier: "msl-msg-\(m.id)", content: content, trigger: nil)
            try? await center.add(req)
        }
        if let maxId = fresh.map(\.id).max() {
            defaults.set(maxId, forKey: key)
        }
    }

    /// 立即刷新未读数（后台刷新等场景调用）
    func refreshNow() async {
        await fetchUnread()
    }
}
