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

    var body: some View {
        GeometryReader { geo in
            let bottomPad = geo.safeAreaInsets.bottom * 0.5 // 网页：paddingBottom = 安全区 * 0.5
            let barHeight = 56 + bottomPad
            ZStack(alignment: .bottom) {
                // 内容区
                Group {
                    switch tab {
                    case 0: HomeView()
                    case 1: PlazaView()
                    case 2: NavigationStack { PublishView() }
                    case 3: MessagesView()
                    default: NavigationStack { ProfileView(userId: authManager.currentUser?.id ?? 0) }
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(.bottom, barHeight)

                // 底栏
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
                    .ignoresSafeArea(edges: .bottom)
                )
            }
        }
        .ignoresSafeArea(.keyboard)
        .sheet(isPresented: $showLogin) { LoginView() }
        .onAppear { unreadManager.startPolling() }
        .onReceive(NotificationCenter.default.publisher(for: .mslSwitchTab)) { n in
            if let i = n.object as? Int { tab = i }
        }
        // 点击推送通知 → 落到消息页
        .onReceive(NotificationCenter.default.publisher(for: .didReceivePush)) { _ in
            if authManager.isAuthenticated { tab = 3 }
        }
    }

    // 普通标签：图标 24 + 文字 10，选中变主色（网页：active 仅 text-primary）
    private func tabButton(index: Int, label: String, icon: String, badge: Int = 0) -> some View {
        let active = tab == index
        return Button {
            if (index == 3 || index == 4) && !authManager.isAuthenticated {
                showLogin = true
            } else {
                tab = index
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
