import SwiftUI
import UIKit

// MARK: - 设置（对应网页 Settings.tsx）
struct SettingsView: View {
    @EnvironmentObject var authManager: AuthManager
    @StateObject private var siteTheme = SiteThemeManager.shared

    @State private var data: SettingsData? = nil
    @State private var address: AddressData? = nil
    @State private var name = ""
    @State private var bio = ""
    @State private var notifyEmail = ""
    @State private var dmBlocked = false
    @State private var avatarImage: UIImage? = nil
    @State private var showAvatarPicker = false
    @State private var entries: [AddressData.AddressEntry] = []
    @State private var senderAddress = ""
    @State private var alipay = ""
    @State private var busy = false
    @State private var dmLoaded = false
    @State private var addressAgreed = UserDefaults.standard.bool(forKey: "msl-addr-agreed")
    @State private var showDeleteAccount = false

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 16) {
                profileSection
                themeSection
                notifySection
                addressSection
                securitySection
                aboutSection
                logoutSection
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
        }
        .background(Color.appBackground)
        .navigationTitle("设置")
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
        .sheet(isPresented: $showAvatarPicker) { ImagePicker(image: $avatarImage) }
        .sheet(isPresented: $showDeleteAccount) { DeleteAccountSheet() }
        .onChange(of: avatarImage) { img in
            if img != nil { Task { await uploadAvatar() } }
        }
    }

    // MARK: 个人资料
    private var profileSection: some View {
        SectionCard {
            VStack(alignment: .leading, spacing: 10) {
                Text("个人资料")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.appForeground)
                HStack(spacing: 12) {
                    Button { showAvatarPicker = true } label: {
                        ZStack(alignment: .bottomTrailing) {
                            if let img = avatarImage {
                                Image(uiImage: img)
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .frame(width: 56, height: 56)
                                    .clipShape(Circle())
                            } else {
                                AvatarView(path: data?.avatar, name: data?.name ?? "", size: 56)
                            }
                            Image(systemName: "camera.fill")
                                .font(.system(size: 10))
                                .foregroundColor(.white)
                                .padding(4)
                                .background(Color.appPrimary)
                                .clipShape(Circle())
                        }
                    }
                    .buttonStyle(.plain)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(data?.name ?? "")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(.appForeground)
                        Text(data?.email ?? "未绑定邮箱")
                            .font(.system(size: 11))
                            .foregroundColor(.appMutedFg)
                    }
                    Spacer()
                }
                HStack(spacing: 8) {
                    AppTextField(text: $name, placeholder: "昵称")
                    Button { Task { await saveName() } } label: {
                        Text("保存")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.appPrimaryFg)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 9)
                            .background(Color.appPrimary)
                            .clipShape(Capsule())
                    }
                    .disabled(busy || name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
                HStack(spacing: 8) {
                    AppTextField(text: $bio, placeholder: "个人简介（一句话介绍自己）")
                    Button { Task { await saveBio() } } label: {
                        Text("保存")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.appPrimaryFg)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 9)
                            .background(Color.appPrimary)
                            .clipShape(Capsule())
                    }
                    .disabled(busy)
                }
            }
        }
    }

    // MARK: 界面主题
    private var themeSection: some View {
        SectionCard {
            VStack(alignment: .leading, spacing: 10) {
                Text("界面主题")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.appForeground)
                Text("跟随账号，换设备也生效")
                    .font(.system(size: 10))
                    .foregroundColor(.appMutedFg)
                HStack(spacing: 10) {
                    ForEach(SiteThemeManager.themes, id: \.key) { t in
                        Button { siteTheme.apply(t.key) } label: {
                            VStack(spacing: 4) {
                                Circle()
                                    .fill(t.swatch)
                                    .frame(width: 30, height: 30)
                                    .overlay(
                                        Circle().stroke(Color.appPrimary,
                                                        lineWidth: siteTheme.theme == t.key ? 2.5 : 0)
                                    )
                                Text(t.label)
                                    .font(.system(size: 10))
                                    .foregroundColor(siteTheme.theme == t.key ? .appPrimary : .appMutedFg)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                    Spacer()
                }
            }
        }
    }

    // MARK: 通知与私信
    private var notifySection: some View {
        SectionCard {
            VStack(alignment: .leading, spacing: 10) {
                Text("通知与私信")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.appForeground)
                HStack(spacing: 8) {
                    AppTextField(text: $notifyEmail, placeholder: "通知邮箱（接收补货/审批邮件）", keyboard: .emailAddress)
                    Button { Task { await saveNotifyEmail() } } label: {
                        Text("保存")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.appPrimaryFg)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 9)
                            .background(Color.appPrimary)
                            .clipShape(Capsule())
                    }
                    .disabled(busy)
                }
                Toggle(isOn: $dmBlocked) {
                    Text("关闭私信（任何人都无法给我发私信）")
                        .font(.system(size: 13))
                        .foregroundColor(.appForeground)
                }
                .onChange(of: dmBlocked) { v in
                    guard dmLoaded else { return }
                    Task { await saveDmBlocked(v) }
                }
            }
        }
    }

    // MARK: 收货地址
    private var addressSection: some View {
        SectionCard {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("收货地址（最多 4 个）")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.appForeground)
                    Spacer()
                    if addressAgreed {
                        Button { Task { await saveAddresses() } } label: {
                            Text("保存全部")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.appPrimaryFg)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 6)
                                .background(Color.appPrimary)
                                .clipShape(Capsule())
                        }
                        .disabled(busy)
                    }
                }
                if !addressAgreed {
                    // 对应网页 Settings.tsx 的地址免责声明：同意后才允许填写
                    VStack(alignment: .leading, spacing: 8) {
                        Text("地址免责声明")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.fixAmber700)
                        Text("收货地址（昵称、手机号、详细地址）属于你的个人敏感信息。你在橱窗页点击「发送地址」后，地址将直接发送给对应橱窗的发布者，由发布者自行保管和使用，平台仅提供信息传递通道，不参与寄件过程。")
                            .font(.system(size: 12))
                            .foregroundColor(.appMutedFg)
                        Text("对于发布者使用、保管不当或泄露你的地址所造成的任何损失或纠纷，平台不承担任何责任。请确认对方可信后再发送地址；如发生地址泄露或滥用，请直接与发布者协商解决，必要时通过法律途径维权。")
                            .font(.system(size: 12))
                            .foregroundColor(.appMutedFg)
                        Button {
                            addressAgreed = true
                            UserDefaults.standard.set(true, forKey: "msl-addr-agreed")
                        } label: {
                            Text("我已阅读并同意，填写地址")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(.appPrimaryFg)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 9)
                                .background(Color.appPrimary)
                                .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(12)
                    .background(Color.fixAmber100.opacity(0.5))
                    .cornerRadius(8)
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.fixAmber300, lineWidth: 1))
                } else {
                ForEach(Array(entries.enumerated()), id: \.element.id) { idx, _ in
                    addressEntryEditor(idx)
                }
                if entries.count < 4 {
                    Button {
                        entries.append(AddressData.AddressEntry(nickname: "", address: "", phone: ""))
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "plus")
                            Text("添加地址")
                        }
                        .font(.system(size: 12))
                        .foregroundColor(.appPrimary)
                    }
                    .buttonStyle(.plain)
                }
                Divider()
                VStack(alignment: .leading, spacing: 6) {
                    Text("寄件地址（快递后台自动预估邮费用）")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.appForeground)
                    AppTextField(text: $senderAddress, placeholder: "如：浙江省杭州市 xx 区 xx 路 xx 号")
                }
                VStack(alignment: .leading, spacing: 6) {
                    Text("支付宝账号（补邮费收款用）")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.appForeground)
                    HStack(spacing: 8) {
                        AppTextField(text: $alipay, placeholder: "手机号 / 邮箱")
                        Button { Task { await saveAlipay() } } label: {
                            Text("保存")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.appPrimaryFg)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 9)
                                .background(Color.appPrimary)
                                .clipShape(Capsule())
                        }
                        .disabled(busy)
                    }
                }
                }
            }
        }
    }

    private func addressEntryEditor(_ idx: Int) -> some View {
        VStack(spacing: 6) {
            HStack(spacing: 6) {
                AppTextField(text: Binding(
                    get: { entries[idx].nickname },
                    set: { entries[idx] = AddressData.AddressEntry(nickname: $0, address: entries[idx].address, phone: entries[idx].phone) }
                ), placeholder: "收件人")
                AppTextField(text: Binding(
                    get: { entries[idx].phone },
                    set: { entries[idx] = AddressData.AddressEntry(nickname: entries[idx].nickname, address: entries[idx].address, phone: $0) }
                ), placeholder: "手机号", keyboard: .phonePad)
                Button { entries.remove(at: idx) } label: {
                    Image(systemName: "trash")
                        .font(.system(size: 12))
                        .foregroundColor(.appMutedFg)
                }
            }
            AppTextField(text: Binding(
                get: { entries[idx].address },
                set: { entries[idx] = AddressData.AddressEntry(nickname: entries[idx].nickname, address: $0, phone: entries[idx].phone) }
            ), placeholder: "详细地址")
        }
        .padding(8)
        .background(Color.appSecondary.opacity(0.3))
        .cornerRadius(10)
    }

    // MARK: 账号安全
    private var securitySection: some View {
        SectionCard {
            VStack(alignment: .leading, spacing: 8) {
                Text("账号")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.appForeground)
                NavigationLink(destination: BindEmailView()) {
                    HStack {
                        Text("绑定 / 换绑邮箱")
                            .font(.system(size: 13))
                            .foregroundColor(.appForeground)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.system(size: 11))
                            .foregroundColor(.appMutedFg)
                    }
                }
                .buttonStyle(.plain)
                // 注销账号（App Store 上架要求：App 内提供账号删除入口）
                Button { showDeleteAccount = true } label: {
                    HStack {
                        Text("注销账号")
                            .font(.system(size: 13))
                            .foregroundColor(.appDestructive)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.system(size: 11))
                            .foregroundColor(.appMutedFg)
                    }
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: 关于与协议（App Store 上架要求新增）
    private var aboutSection: some View {
        SectionCard {
            VStack(alignment: .leading, spacing: 8) {
                Text("关于与协议")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.appForeground)
                aboutRow("隐私政策", icon: "hand.raised", dest: AnyView(LegalView(doc: .privacy)))
                aboutRow("用户协议与社区规范", icon: "doc.text", dest: AnyView(LegalView(doc: .terms)))
                Button {
                    UIPasteboard.general.string = "3495379352"
                    ToastCenter.shared.success("QQ 号已复制")
                } label: {
                    HStack {
                        Text("意见反馈（QQ 3495379352）")
                            .font(.system(size: 13))
                            .foregroundColor(.appForeground)
                        Spacer()
                        Image(systemName: "doc.on.doc")
                            .font(.system(size: 11))
                            .foregroundColor(.appMutedFg)
                    }
                }
                .buttonStyle(.plain)
                HStack {
                    Text("当前版本")
                        .font(.system(size: 13))
                        .foregroundColor(.appForeground)
                    Spacer()
                    Text(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0")
                        .font(.system(size: 12))
                        .foregroundColor(.appMutedFg)
                }
            }
        }
    }

    private func aboutRow(_ title: String, icon: String, dest: AnyView) -> some View {
        NavigationLink(destination: dest) {
            HStack {
                Text(title)
                    .font(.system(size: 13))
                    .foregroundColor(.appForeground)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 11))
                    .foregroundColor(.appMutedFg)
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: 退出登录
    private var logoutSection: some View {
        Button {
            Task {
                await authManager.logout()
                ToastCenter.shared.success("已退出登录")
            }
        } label: {
            Text("退出登录")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.appDestructive)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(Color.appCard)
                .cornerRadius(12)
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.appDestructive.opacity(0.4), lineWidth: 1))
        }
        .buttonStyle(.plain)
        .padding(.bottom, 30)
    }

    // MARK: 数据
    private func load() async {
        data = try? await MashanglingAPI.shared.settings.get()
        name = data?.name ?? ""
        bio = data?.bio ?? ""
        notifyEmail = data?.notifyEmail ?? data?.email ?? ""
        dmBlocked = data?.dmBlocked ?? false
        address = try? await MashanglingAPI.shared.address.get()
        entries = address?.entries ?? []
        senderAddress = address?.senderAddress ?? ""
        alipay = address?.alipayAccount ?? ""
        dmLoaded = true
    }

    private func saveName() async {
        busy = true
        defer { busy = false }
        do {
            _ = try await MashanglingAPI.shared.settings.updateName(name.trimmingCharacters(in: .whitespaces))
            ToastCenter.shared.success("昵称已更新")
            await AuthManager.shared.checkAuth()
        } catch { ToastCenter.shared.error(error.localizedDescription) }
    }

    private func saveBio() async {
        busy = true
        defer { busy = false }
        do {
            _ = try await MashanglingAPI.shared.settings.updateBio(bio.trimmingCharacters(in: .whitespaces))
            ToastCenter.shared.success("简介已更新")
        } catch { ToastCenter.shared.error(error.localizedDescription) }
    }

    private func saveNotifyEmail() async {
        busy = true
        defer { busy = false }
        do {
            _ = try await MashanglingAPI.shared.settings.updateNotifyEmail(notifyEmail.trimmingCharacters(in: .whitespaces))
            ToastCenter.shared.success("通知邮箱已更新")
        } catch { ToastCenter.shared.error(error.localizedDescription) }
    }

    private func saveDmBlocked(_ v: Bool) async {
        do {
            _ = try await MashanglingAPI.shared.settings.updateDmBlocked(v)
            ToastCenter.shared.success(v ? "已关闭私信" : "已开启私信")
        } catch { ToastCenter.shared.error(error.localizedDescription) }
    }

    private func uploadAvatar() async {
        guard let img = avatarImage, let dataURL = ImageCodec.coverDataURL(from: img) else { return }
        busy = true
        defer { busy = false }
        do {
            _ = try await MashanglingAPI.shared.settings.updateAvatar(dataURL)
            ToastCenter.shared.success("头像已更新")
            await AuthManager.shared.checkAuth()
            data = try? await MashanglingAPI.shared.settings.get()
        } catch { ToastCenter.shared.error(error.localizedDescription) }
    }

    private func saveAddresses() async {
        let valid = entries.filter {
            !$0.nickname.trimmingCharacters(in: .whitespaces).isEmpty &&
            !$0.address.trimmingCharacters(in: .whitespaces).isEmpty &&
            !$0.phone.trimmingCharacters(in: .whitespaces).isEmpty
        }
        busy = true
        defer { busy = false }
        do {
            _ = try await MashanglingAPI.shared.address.save(
                entries: valid,
                senderAddress: senderAddress.trimmingCharacters(in: .whitespaces).isEmpty ? nil : senderAddress)
            entries = valid
            ToastCenter.shared.success("地址已保存")
        } catch { ToastCenter.shared.error(error.localizedDescription) }
    }

    private func saveAlipay() async {
        busy = true
        defer { busy = false }
        do {
            _ = try await MashanglingAPI.shared.address.saveAlipay(alipay.trimmingCharacters(in: .whitespaces))
            ToastCenter.shared.success("支付宝账号已保存")
        } catch { ToastCenter.shared.error(error.localizedDescription) }
    }
}

// MARK: - 绑定 / 换绑邮箱
struct BindEmailView: View {
    @State private var email = ""
    @State private var password = ""
    @State private var busy = false

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("绑定邮箱后可以用邮箱 + 密码登录；换绑需要验证当前密码。")
                .font(.system(size: 12))
                .foregroundColor(.appMutedFg)
            AppTextField(text: $email, placeholder: "新邮箱", keyboard: .emailAddress)
            AppTextField(text: $password, placeholder: "当前密码", secure: true)
            Button { Task { await submit() } } label: {
                Text(busy ? "提交中…" : "确认绑定")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.appPrimaryFg)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 11)
                    .background(Color.appPrimary)
                    .clipShape(Capsule())
            }
            .disabled(email.isEmpty || password.isEmpty || busy)
            Spacer()
        }
        .padding(20)
        .background(Color.appBackground)
        .navigationTitle("绑定邮箱")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func submit() async {
        busy = true
        defer { busy = false }
        do {
            _ = try await MashanglingAPI.shared.settings.bindEmail(
                email: email.trimmingCharacters(in: .whitespaces), password: password)
            ToastCenter.shared.success("邮箱绑定成功")
        } catch { ToastCenter.shared.error(error.localizedDescription) }
    }
}
