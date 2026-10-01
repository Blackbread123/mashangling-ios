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
