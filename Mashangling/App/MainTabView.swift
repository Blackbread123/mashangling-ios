import SwiftUI

// MARK: - 主 Tab 视图（对应网页 TabBar）
// iOS 16 兼容：使用 UITabBarController 外观 + SwiftUI TabView
struct MainTabView: View {
    @StateObject private var unreadManager = UnreadManager.shared
    @EnvironmentObject var authManager: AuthManager

    var body: some View {
        TabView {
            HomeView()
                .tabItem {
                    Label("首页", systemImage: "house.fill")
                }
                .tag(0)

            PlazaView()
                .tabItem {
                    Label("广场", systemImage: "square.grid.2x2.fill")
                }
                .tag(1)

            NavigationStack {
                PublishView()
            }
                .tabItem {
                    Label("发布", systemImage: "plus.circle.fill")
                }
                .tag(2)

            MessagesView()
                .tabItem {
                    Label("消息", systemImage: "message.fill")
                }
                .badge(unreadManager.totalUnread)
                .tag(3)

            ProfileView(userId: authManager.currentUser?.id ?? 0)
                .tabItem {
                    Label("我的", systemImage: "person.fill")
                }
                .tag(4)
        }
        .accentColor(.appPrimary)
        .onAppear {
            unreadManager.startPolling()
        }
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
            totalUnread = count
        } catch {
            // 静默失败
        }
    }

    /// 立即刷新未读数（后台刷新等场景调用）
    func refreshNow() async {
        await fetchUnread()
    }
}
