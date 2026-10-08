import Foundation
import Combine

// MARK: - 认证状态管理
@MainActor
class AuthManager: ObservableObject {
    static let shared = AuthManager()

    @Published var currentUser: User? = nil
    @Published var isLoading = false
    @Published var isAuthenticated = false
    /// 封禁状态（2026-10-08 网页 BanBanner）：非 nil 表示封禁中，仅可浏览公开内容
    @Published var banInfo: BanInfo? = nil

    private var banTimer: Timer?

    private init() {
        Task { await checkAuth() }
        // 网页：banInfo 每 5 分钟轮询
        banTimer = Timer.scheduledTimer(withTimeInterval: 300, repeats: true) { [weak self] _ in
            Task { await self?.refreshBanInfo() }
        }
    }

    /// 检查登录状态（URLSession 自动管理 Cookie，尝试直接拉取用户信息）
    func checkAuth() async {
        isLoading = true
        defer { isLoading = false }
        do {
            let user = try await MashanglingAPI.shared.auth.me()
            currentUser = user
            isAuthenticated = true
        } catch APIError.unauthorized {
            isAuthenticated = false
            currentUser = nil
        } catch {
            // 网络错误时不清除状态，下次再试
            isAuthenticated = false
        }
        await refreshBanInfo()
    }

    /// 拉取封禁状态（publicQuery：即使 auth.me 失败/被封禁也能拿到）
    func refreshBanInfo() async {
        do {
            let info: BanInfo? = try await MashanglingAPI.shared.auth.banInfo()
            banInfo = (info?.banned == true) ? info : nil
        } catch {
            // 静默失败：保持当前状态
        }
    }

    /// 邮箱+密码登录
    func loginWithEmail(email: String, password: String) async throws {
        _ = try await MashanglingAPI.shared.emailAuth.login(email: email, password: password)
        await checkAuth()
    }

    /// 邮箱注册
    func registerWithEmail(email: String, password: String, name: String) async throws {
        _ = try await MashanglingAPI.shared.emailAuth.register(email: email, password: password, name: name)
        await checkAuth()
    }

    func logout() async {
        _ = try? await MashanglingAPI.shared.auth.logout()
        currentUser = nil
        isAuthenticated = false
    }

    /// 注销账号（App Store 上架要求）：成功后清空本地登录态
    func deleteAccount(password: String) async throws {
        let ok = try await MashanglingAPI.shared.auth.deleteAccount(password: password)
        guard ok else {
            throw NSError(domain: "AuthManager", code: 1,
                          userInfo: [NSLocalizedDescriptionKey: "注销失败，请检查密码是否正确"])
        }
        await APIClient.shared.setToken(nil)
        currentUser = nil
        isAuthenticated = false
    }
}
