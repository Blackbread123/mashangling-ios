import SwiftUI

// MARK: - 登录 / 注册页（对应网页 Login.tsx，邮箱 + 密码）
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
            ScrollView {
                VStack(spacing: 20) {
                    // 品牌区
                    VStack(spacing: 10) {
                        Image("AppIcon")
                            .resizable()
                            .frame(width: 72, height: 72)
                            .cornerRadius(16)
                        Text("码上领")
                            .font(.system(size: 24, weight: .bold))
                            .foregroundColor(.appForeground)
                        Text("无料分享 · 快来领取")
                            .font(.system(size: 12))
                            .foregroundColor(.appMutedFg)
                    }
                    .padding(.top, 36)

                    // 模式切换
                    HStack(spacing: 0) {
                        modeTab(.login, label: "登录")
                        modeTab(.register, label: "注册")
                    }
                    .padding(3)
                    .background(Color.appSecondary)
                    .cornerRadius(12)

                    VStack(spacing: 12) {
                        AppTextField(text: $email, placeholder: "邮箱", keyboard: .emailAddress)
                        AppTextField(text: $password, placeholder: "密码（至少 6 位）", secure: true)
                        if mode == .register {
                            AppTextField(text: $name, placeholder: "昵称（展示给大家的名字）")
                        }

                        if let err = errorText {
                            Text(err)
                                .font(.system(size: 12))
                                .foregroundColor(.appDestructive)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }

                        Button {
                            Task { await submit() }
                        } label: {
                            Text(busy ? "请稍候…" : (mode == .login ? "登录" : "注册并登录"))
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundColor(.appPrimaryFg)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(Color.appPrimary)
                                .cornerRadius(12)
                        }
                        .disabled(busy || !formValid)
                        .opacity(formValid ? 1 : 0.6)
                    }
                    .padding(.horizontal, 4)

                    Text("登录即表示同意站点的社区规范；注册后可在「设置」里换绑邮箱。")
                        .font(.system(size: 10))
                        .foregroundColor(.appMutedFg)
                        .multilineTextAlignment(.center)

                    Spacer(minLength: 40)
                }
                .padding(.horizontal, 24)
            }
            .background(Color.appBackground.ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("关闭") { dismiss() }
                        .font(.system(size: 13))
                        .foregroundColor(.appMutedFg)
                }
            }
        }
        .overlay(ToastOverlay())
        .onChange(of: authManager.isAuthenticated) { ok in
            if ok { dismiss() }
        }
    }

    private var formValid: Bool {
        let emailOK = email.contains("@") && email.contains(".")
        let pwdOK = password.count >= 6
        if mode == .register {
            return emailOK && pwdOK && !name.trimmingCharacters(in: .whitespaces).isEmpty
        }
        return emailOK && pwdOK
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
                .padding(.vertical, 9)
                .background(mode == m ? Color.appCard : Color.clear)
                .cornerRadius(10)
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
                ToastCenter.shared.success("欢迎回来")
            case .register:
                try await authManager.registerWithEmail(
                    email: email.trimmingCharacters(in: .whitespaces),
                    password: password,
                    name: name.trimmingCharacters(in: .whitespaces))
                ToastCenter.shared.success("注册成功，欢迎加入")
            }
        } catch {
            errorText = error.localizedDescription
        }
    }
}
