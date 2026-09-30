import SwiftUI

// MARK: - 码上领 iOS App（iOS 16+）
@main
struct MashanglingApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var authManager = AuthManager.shared
    @StateObject private var pushManager = PushManager.shared
    @StateObject private var siteTheme = SiteThemeManager.shared

    init() {
        // 配置全局外观
        MashanglingApp.configureAppearance(theme: SiteThemeManager.shared.theme)
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(authManager)
                .environmentObject(pushManager)
                .environmentObject(siteTheme)
                .id(siteTheme.theme)   // 主题切换时整树重建，颜色全面生效
                .preferredColorScheme(nil) // 跟随系统
                .onChange(of: siteTheme.theme) { t in
                    MashanglingApp.configureAppearance(theme: t)
                }
                .onChange(of: authManager.isAuthenticated) { loggedIn in
                    if loggedIn { Task { await SiteThemeManager.shared.syncFromServer() } }
                }
        }
    }

    static func configureAppearance(theme: String = "blue") {
        let palette = AppTheme.palette(theme)
        // 导航栏外观
        let navAppearance = UINavigationBarAppearance()
        navAppearance.configureWithOpaqueBackground()
        navAppearance.backgroundColor = UIColor(palette.background)
        navAppearance.titleTextAttributes = [
            .foregroundColor: UIColor(palette.foreground),
            .font: UIFont.systemFont(ofSize: 17, weight: .semibold)
        ]
        UINavigationBar.appearance().standardAppearance = navAppearance
        UINavigationBar.appearance().scrollEdgeAppearance = navAppearance
        UINavigationBar.appearance().compactAppearance = navAppearance

        // TabBar 外观
        let tabAppearance = UITabBarAppearance()
        tabAppearance.configureWithOpaqueBackground()
        tabAppearance.backgroundColor = UIColor(palette.background)
        UITabBar.appearance().standardAppearance = tabAppearance
        UITabBar.appearance().scrollEdgeAppearance = tabAppearance

        // 开启推送
        PushManager.shared.register()
    }
}

// MARK: - 根视图
struct ContentView: View {
    @EnvironmentObject var authManager: AuthManager

    var body: some View {
        Group {
            if authManager.isLoading {
                // 启动屏
                ZStack {
                    Color.appBackground.ignoresSafeArea()
                    VStack(spacing: 16) {
                        Image("AppIcon")
                            .resizable()
                            .frame(width: 80, height: 80)
                            .cornerRadius(16)
                        Text("码上领")
                            .font(.title2)
                            .fontWeight(.semibold)
                            .foregroundColor(.appForeground)
                        ProgressView()
                            .tint(.appPrimary)
                    }
                }
            } else if authManager.isAuthenticated {
                MainTabView()
            } else {
                LoginView()
            }
        }
        .overlay(ToastOverlay())
    }
}
