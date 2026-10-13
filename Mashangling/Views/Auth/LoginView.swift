import SwiftUI

// MARK: - 登录 / 注册页（逐行复刻网页 Login.tsx）
struct LoginView: View {
    @EnvironmentObject var authManager: AuthManager
    @Environment(\.dismiss) private var dismiss

    @State private var mode: Mode = .login
    @State private var email = ""
    @State private var password = ""
    @State private var name = ""
    @State private var busy = false
    @State private var errorText: String? = nil
    @State private var showForgot = false

    enum Mode { case login, register }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // 顶栏（对应网页 header：border-b h-16 + 「码上领」标题链回首页）
                HStack {
                    Button { dismiss() } label: {
                        Text("码上领")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(.appForeground)
                    }
                    .buttonStyle(.plain)
                    Spacer()
                    Button("关闭") { dismiss() }
                        .font(.system(size: 13))
                        .foregroundColor(.appMutedFg)
                }
                .padding(.horizontal, 16)
                .frame(height: 64)
                .overlay(alignment: .bottom) {
                    Rectangle()
                        .fill(Color.appBorder.opacity(0.7))
                        .frame(height: 0.5)
                }

                ScrollView(showsIndicators: false) {
                    // 居中卡片 max-w-sm
                    VStack(spacing: 0) {
                        // CardHeader pb-4 text-center
                        Text(mode == .login ? "登录码上领" : "注册码上领")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundColor(.appForeground)
                        Text("游客可以直接浏览，登录后才能发布橱窗、点赞和标记已领到")
                            .font(.system(size: 12))
                            .foregroundColor(.appMutedFg)
                            .multilineTextAlignment(.center)
                            .padding(.top, 4)

                        // CardContent space-y-3
                        VStack(spacing: 12) {
                            // 模式切换：rounded-full bg-secondary p-1
                            HStack(spacing: 0) {
                                modeTab(.login, label: "登录")
                                modeTab(.register, label: "注册")
                            }
                            .padding(4)
                            .background(Color.appSecondary)
                            .clipShape(Capsule())

                            if mode == .register {
                                AppTextField(text: $name, placeholder: "昵称（可选，默认可用邮箱前缀）")
                            }
                            AppTextField(text: $email, placeholder: "邮箱", keyboard: .emailAddress)
                            if mode == .register {
                                Text("这个邮箱会用来接收重要信息：领取审批、补邮通知、发货单号、地址时限变更等，请填写常用邮箱。注册后可在「设置 → 发信邮箱」里更换通知邮箱。")
                                    .font(.system(size: 11))
                                    .lineSpacing(2)
                                    .foregroundColor(.appMutedFg)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(.top, -4)
                            }
                            AppTextField(
                                text: $password,
                                placeholder: mode == .register ? "密码（至少 8 位）" : "密码",
                                secure: true
                            )

                            // 网页 2026-10-13：密码框下「忘记密码？」链接（仅登录模式）
                            if mode == .login {
                                HStack {
                                    Spacer()
                                    Button { showForgot = true } label: {
                                        Text("忘记密码？")
                                            .font(.system(size: 12))
                                            .foregroundColor(.appPrimary)
                                    }
                                    .buttonStyle(.plain)
                                }
                                .padding(.top, -4)
                            }

                            if let err = errorText {
                                Text(err)
                                    .font(.system(size: 12))
                                    .foregroundColor(.appDestructive)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }

                            // 主按钮：w-full rounded-full size lg（h-10）
                            Button {
                                Task { await submit() }
                            } label: {
                                Text(busy ? "请稍候…" : (mode == .login ? "登录" : "注册并登录"))
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(.appPrimaryFg)
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 40)
                                    .background(Color.appPrimary)
                                    .clipShape(Capsule())
                            }
                            .disabled(busy || email.isEmpty || password.isEmpty)
                            .opacity((busy || email.isEmpty || password.isEmpty) ? 0.5 : 1)

                            // 分隔线「或」
                            HStack(spacing: 12) {
                                Rectangle().fill(Color.appBorder).frame(height: 0.5)
                                Text("或")
                                    .font(.system(size: 12))
                                    .foregroundColor(.appMutedFg)
                                Rectangle().fill(Color.appBorder).frame(height: 0.5)
                            }
                            .padding(.vertical, 4)

                            // Kimi 账号登录（网页走 OAuth 跳转；App 内提示用邮箱）
                            Button {
                                ToastCenter.shared.show("App 内请使用邮箱登录；Kimi 账号登录请在网页版操作")
                            } label: {
                                Text("使用 Kimi 账号登录")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(.appForeground)
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 36)
                                    .clipShape(Capsule())
                                    .overlay(Capsule().stroke(Color.appBorder, lineWidth: 1))
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.top, 20)
                    }
                    .padding(24)
                    .background(Color.appCard)
                    .cornerRadius(4)
                    .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color.appBorder, lineWidth: 1))
                    .padding(.horizontal, 16)
                    .padding(.top, 40)

                    // 上架合规：协议与隐私入口（网页在注册邮箱提示中说明换绑，协议链为 App 新增）
                    VStack(spacing: 4) {
                        HStack(spacing: 2) {
                            Text("登录即表示同意")
                            NavigationLink(destination: LegalView(doc: .terms)) {
                                Text("《用户协议与社区规范》").foregroundColor(.appPrimary)
                            }
                            Text("和")
                            NavigationLink(destination: LegalView(doc: .privacy)) {
                                Text("《隐私政策》").foregroundColor(.appPrimary)
                            }
                        }
                    }
                    .font(.system(size: 10))
                    .foregroundColor(.appMutedFg)
                    .multilineTextAlignment(.center)
                    .padding(.top, 20)
                    .padding(.bottom, 40)
                }
            }
            .background(Color.appBackground.ignoresSafeArea())
            .navigationBarHidden(true)
        }
        .onChange(of: authManager.isAuthenticated) { ok in
            if ok { dismiss() }
        }
        .sheet(isPresented: $showForgot) {
            ForgotPasswordView(prefillEmail: email)
        }
    }

    private func modeTab(_ m: Mode, label: String) -> some View {
        Button {
            mode = m
            errorText = nil
        } label: {
            Text(label)
                .font(.system(size: 14, weight: mode == m ? .semibold : .regular))
                .foregroundColor(mode == m ? .appForeground : .appMutedFg)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 6)
                .background(mode == m ? Color.appCard : Color.clear)
                .clipShape(Capsule())
                .shadow(color: mode == m ? .black.opacity(0.08) : .clear, radius: 1, y: 1)
        }
        .buttonStyle(.plain)
    }

    private func submit() async {
        busy = true
        errorText = nil
        defer { busy = false }
        do {
            switch mode {
            case .login:
                try await authManager.loginWithEmail(
                    email: email.trimmingCharacters(in: .whitespaces), password: password)
            case .register:
                // 对应网页：name 为空时用邮箱前缀
                let trimmed = name.trimmingCharacters(in: .whitespaces)
                let fallback = email.split(separator: "@").first.map(String.init) ?? ""
                try await authManager.registerWithEmail(
                    email: email.trimmingCharacters(in: .whitespaces),
                    password: password,
                    name: trimmed.isEmpty ? fallback : trimmed)
            }
        } catch {
            errorText = error.localizedDescription
        }
    }
}

// MARK: - 忘记密码（对应网页 2026-10-13 ResetPassword.tsx：无 token=申请页，有 token=设新密码页）
struct ForgotPasswordView: View {
    let prefillEmail: String

    @EnvironmentObject var authManager: AuthManager
    @Environment(\.dismiss) private var dismiss

    @State private var email = ""
    @State private var resetLink = ""      // 粘贴邮件里的重置链接（从中解析 token）
    @State private var newPassword = ""
    @State private var busy = false
    @State private var errorText: String? = nil

    /// 从粘贴的链接里解析 token 参数（格式：{SITE_URL}/#/reset-password?token=...）
    private var parsedToken: String? {
        let s = resetLink.trimmingCharacters(in: .whitespaces)
        guard !s.isEmpty else { return nil }
        if let comp = URLComponents(string: s.replacingOccurrences(of: "#/reset-password", with: "reset-password")),
           let t = comp.queryItems?.first(where: { $0.name == "token" })?.value, !t.isEmpty {
            return t
        }
        // 直接粘贴 64 位 hex token 的情况
        if s.range(of: "^[0-9a-fA-F]{64}$", options: .regularExpression) != nil { return s }
        return nil
    }

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 12) {
                    // 申请重置
                    Text("输入注册邮箱，我们会发一封含重置链接的邮件（30 分钟内有效，仅可使用一次）。")
                        .font(.system(size: 12))
                        .lineSpacing(2)
                        .foregroundColor(.appMutedFg)
                    AppTextField(text: $email, placeholder: "邮箱", keyboard: .emailAddress)
                    Button { Task { await sendReset() } } label: {
                        Text(busy ? "请稍候…" : "发送重置邮件")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.appPrimaryFg)
                            .frame(maxWidth: .infinity)
                            .frame(height: 40)
                            .background(Color.appPrimary)
                            .clipShape(Capsule())
                    }
                    .disabled(busy || email.trimmingCharacters(in: .whitespaces).isEmpty)
                    .opacity((busy || email.trimmingCharacters(in: .whitespaces).isEmpty) ? 0.5 : 1)

                    // 分隔线「已收到邮件？」
                    HStack(spacing: 12) {
                        Rectangle().fill(Color.appBorder).frame(height: 0.5)
                        Text("已收到邮件")
                            .font(.system(size: 12))
                            .foregroundColor(.appMutedFg)
                        Rectangle().fill(Color.appBorder).frame(height: 0.5)
                    }
                    .padding(.vertical, 8)

                    Text("打开邮件里的重置链接即可在浏览器中设置新密码；也可以把链接粘贴到下面，在 App 内直接重置。")
                        .font(.system(size: 12))
                        .lineSpacing(2)
                        .foregroundColor(.appMutedFg)
                    AppTextField(text: $resetLink, placeholder: "粘贴邮件里的重置链接")
                    if parsedToken != nil {
                        AppTextField(text: $newPassword, placeholder: "新密码（至少 8 位）", secure: true)
                        Button { Task { await doReset() } } label: {
                            Text(busy ? "请稍候…" : "重置密码并登录")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.appPrimaryFg)
                                .frame(maxWidth: .infinity)
                                .frame(height: 40)
                                .background(Color.appPrimary)
                                .clipShape(Capsule())
                        }
                        .disabled(busy || newPassword.count < 8)
                        .opacity((busy || newPassword.count < 8) ? 0.5 : 1)
                    } else if !resetLink.trimmingCharacters(in: .whitespaces).isEmpty {
                        Text("没有从链接里识别出 token，请确认粘贴的是完整链接")
                            .font(.system(size: 12))
                            .foregroundColor(.appDestructive)
                    }

                    if let err = errorText {
                        Text(err)
                            .font(.system(size: 12))
                            .foregroundColor(.appDestructive)
                    }
                }
                .padding(20)
            }
            .background(Color.appBackground)
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle("忘记密码")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("关闭") { dismiss() }
                }
            }
        }
        .onAppear {
            if email.isEmpty { email = prefillEmail }
        }
    }

    private func sendReset() async {
        busy = true
        errorText = nil
        defer { busy = false }
        do {
            _ = try await MashanglingAPI.shared.emailAuth.forgotPassword(
                email: email.trimmingCharacters(in: .whitespaces))
            // 网页文案：防枚举，无论是否注册统一此提示
            ToastCenter.shared.success("如果该邮箱已注册，重置链接已发送")
        } catch {
            errorText = error.localizedDescription
        }
    }

    private func doReset() async {
        guard let token = parsedToken else { return }
        busy = true
        errorText = nil
        defer { busy = false }
        do {
            _ = try await MashanglingAPI.shared.emailAuth.resetPassword(token: token, password: newPassword)
            // 网页：resetPassword 成功即签发会话 Cookie，前端无需再登录
            await authManager.checkAuth()
            ToastCenter.shared.success("密码已重置，已自动登录")
            dismiss()
        } catch {
            errorText = error.localizedDescription
        }
    }
}
