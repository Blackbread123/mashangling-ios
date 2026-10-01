import SwiftUI
import UIKit

// MARK: - 设置（逐行复刻网页 Settings.tsx）
struct SettingsView: View {
    @EnvironmentObject var authManager: AuthManager

    @State private var d: SettingsData? = nil
    @State private var loading = true
    @State private var address: AddressData? = nil

    @State private var name = ""
    @State private var notifyEmail = ""
    @State private var entries: [AddressData.AddressEntry] = []
    @State private var addrFilled = false
    @State private var alipay = ""
    @State private var addrAgreed = UserDefaults.standard.bool(forKey: "msl-addr-agreed")
    @State private var senderSynced = false

    @State private var avatarImage: UIImage? = nil
    @State private var showAvatarPicker = false
    @State private var uploadingAvatar = false
    @State private var savingName = false
    @State private var savingEmail = false
    @State private var savingAddr = false
    @State private var savingAlipay = false
    @State private var dmUpdating = false
    @State private var bindEmail = ""
    @State private var bindPassword = ""
    @State private var binding = false
    @State private var showDeleteAccount = false
    @State private var emailOff = UserDefaults.standard.bool(forKey: "msl-email-notify-off")

    private var nameDirty: Bool {
        name.trimmingCharacters(in: .whitespaces) != (d?.name ?? "")
    }
    private var emailDirty: Bool {
        notifyEmail.trimmingCharacters(in: .whitespaces) != (d?.notifyEmail ?? "")
    }
    private var alipaySaved: Bool {
        let saved = address?.alipayAccount ?? ""
        return !saved.isEmpty && alipay.trimmingCharacters(in: .whitespaces) == saved
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 0) {
                Text("设置")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(.appForeground)

                if loading {
                    HStack(spacing: 8) {
                        ProgressView()
                            .scaleEffect(0.8)
                        Text("加载中…")
                            .font(.system(size: 14))
                            .foregroundColor(.appMutedFg)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 32)
                } else if d != nil {
                    VStack(alignment: .leading, spacing: 32) {
                        avatarSection
                        nameSection
                        notifyEmailSection
                        if (d?.email ?? "").isEmpty { bindEmailSection }
                        addressSection
                        alipaySection
                        dmSection
                    }
                    .padding(.top, 24)
                }

                // App 新增（上架合规）：关于与协议 / 注销 / 退出
                aboutSection
                    .padding(.top, 32)
                logoutSection
                    .padding(.top, 16)
            }
            .padding(.horizontal, 16)
            .padding(.top, 32)
            .padding(.bottom, 32)
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
        .onChange(of: name) { v in
            if v.count > 30 { name = String(v.prefix(30)) }
        }
    }

    private func sectionLabel(_ t: String) -> some View {
        Text(t)
            .font(.system(size: 14, weight: .medium))
            .foregroundColor(.appForeground)
            .padding(.bottom, 8)
    }

    // MARK: 头像
    private var avatarSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            sectionLabel("头像")
            HStack(spacing: 16) {
                Button { showAvatarPicker = true } label: {
                    ZStack {
                        if let img = avatarImage {
                            Image(uiImage: img)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: 80, height: 80)
                                .clipShape(Circle())
                        } else {
                            AvatarView(path: d?.avatar, name: d?.name ?? "", size: 80)
                        }
                    }
                }
                .buttonStyle(.plain)
                VStack(alignment: .leading, spacing: 0) {
                    Button { showAvatarPicker = true } label: {
                        Text(uploadingAvatar ? "上传中…" : "更换头像")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.appForeground)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .overlay(Capsule().stroke(Color.appBorder, lineWidth: 1))
                    }
                    .disabled(uploadingAvatar)
                    Text("本地上传图片，自动压缩。")
                        .font(.system(size: 11))
                        .foregroundColor(.appMutedFg)
                        .padding(.top, 6)
                }
            }
        }
    }

    // MARK: 昵称
    private var nameSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            sectionLabel("昵称")
            HStack(spacing: 8) {
                AppTextField(text: $name, placeholder: "输入新昵称")
                    .overlay(alignment: .trailing) {
                        Text("\(name.count)/30")
                            .font(.system(size: 11))
                            .foregroundColor(.appMutedFg)
                            .padding(.trailing, 12)
                    }
                Button { Task { await saveName() } } label: {
                    Text(savingName ? "保存中…" : "保存")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.appPrimaryFg)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Color.appPrimary)
                        .clipShape(Capsule())
                }
                .disabled(!nameDirty || savingName)
                .opacity(!nameDirty || savingName ? 0.5 : 1)
            }
            Text("昵称是别人看到的你的名字，全站唯一，最多 30 个字（英文字母按 1 个字计）。")
                .font(.system(size: 11))
                .lineSpacing(2)
                .foregroundColor(.appMutedFg)
                .padding(.top, 6)
        }
    }

    // MARK: 发信邮箱
    private var notifyEmailSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            sectionLabel("发信邮箱")
            // 邮件总开关（App 侧新增）：关闭后清空发信邮箱，不再发邮件，App 推送不受影响
            HStack {
                Text("邮件通知")
                    .font(.system(size: 14))
                    .foregroundColor(.appForeground)
                Spacer()
                Toggle("", isOn: Binding(
                    get: { !emailOff },
                    set: { on in Task { await setEmailNotify(on) } }
                ))
                .labelsHidden()
                .tint(.appPrimary)
                .disabled(savingEmail)
            }
            .padding(.bottom, 8)
            if emailOff {
                Text("已关闭邮件通知；站内消息仍会通过 App 推送提醒你。")
                    .font(.system(size: 11))
                    .foregroundColor(.appMutedFg)
                    .padding(.bottom, 6)
            }
            HStack(spacing: 8) {
                AppTextField(
                    text: $notifyEmail,
                    placeholder: (d?.email?.isEmpty == false) ? d!.email! : "输入接收通知的邮箱",
                    keyboard: .emailAddress
                )
                .disabled(emailOff)
                .opacity(emailOff ? 0.5 : 1)
                Button { Task { await saveNotifyEmail() } } label: {
                    Text(savingEmail ? "保存中…" : "保存")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.appPrimaryFg)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Color.appPrimary)
                        .clipShape(Capsule())
                }
                .disabled(emailOff || !emailDirty || savingEmail)
                .opacity(emailOff || !emailDirty || savingEmail ? 0.5 : 1)
            }
            (Text("站内通知邮件（补码提醒、每晚未读摘要等）会发到这个邮箱。")
                .foregroundColor(.appMutedFg)
            + Text("它与注册邮箱不同，更换发信邮箱不影响登录账号。")
                .foregroundColor(.appForeground.opacity(0.7))
            + Text("留空则恢复为注册邮箱。")
                .foregroundColor(.appMutedFg))
                .font(.system(size: 11))
                .lineSpacing(2)
                .padding(.top, 6)
        }
    }

    // MARK: 绑定登录邮箱（Kimi 用户 → App 登录用；仅未绑定邮箱时显示）
    private var bindEmailSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("绑定邮箱 · 用于 iOS App 登录")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.fixSky900)
            Text("设置邮箱和密码后，即可在 iOS App 上用邮箱+密码登录。\n绑定后不可自行更换，如需修改请联系站长。")
                .font(.system(size: 12))
                .lineSpacing(3)
                .foregroundColor(.fixSky800.opacity(0.8))
                .padding(.top, 4)
            VStack(spacing: 8) {
                AppTextField(text: $bindEmail, placeholder: "输入邮箱", keyboard: .emailAddress)
                    .background(RoundedRectangle(cornerRadius: 2).fill(Color.white))
                AppTextField(text: $bindPassword, placeholder: "设置密码（至少 8 位）", secure: true)
                    .background(RoundedRectangle(cornerRadius: 2).fill(Color.white))
                Button { Task { await doBindEmail() } } label: {
                    Text(binding ? "绑定中…" : "绑定邮箱")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.appPrimaryFg)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Color.appPrimary)
                        .clipShape(Capsule())
                }
                .disabled(!bindEmail.contains("@") || bindPassword.count < 8 || binding)
                .opacity(!bindEmail.contains("@") || bindPassword.count < 8 || binding ? 0.5 : 1)
            }
            .padding(.top, 12)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.fixSky50)
        .cornerRadius(4)
        .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color.fixSky50, lineWidth: 1))
    }

    // MARK: 地址
    private var addressSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            sectionLabel("地址（最多 4 个，仅自己可见，非必填）")
            if !addrAgreed {
                VStack(alignment: .leading, spacing: 0) {
                    Text("填写前请阅读免责声明")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.fixAmber900)
                    Text("收货地址（昵称、手机号、详细地址）属于你的个人敏感信息。你在橱窗页点击「发送地址」后，地址将直接发送给对应橱窗的发布者，由发布者自行保管和使用，平台仅提供信息传递通道，不参与寄件过程。")
                        .font(.system(size: 12))
                        .lineSpacing(3)
                        .foregroundColor(.fixAmber900.opacity(0.8))
                        .padding(.top, 8)
                    Text("对于发布者使用、保管不当或泄露你的地址所造成的任何损失或纠纷，平台不承担任何责任。请确认对方可信后再发送地址；如发生地址泄露或滥用，请直接与发布者协商解决，必要时通过法律途径维权。")
                        .font(.system(size: 12))
                        .lineSpacing(3)
                        .foregroundColor(.fixAmber900.opacity(0.8))
                        .padding(.top, 6)
                    Button {
                        addrAgreed = true
                        UserDefaults.standard.set(true, forKey: "msl-addr-agreed")
                    } label: {
                        Text("我已阅读并同意，填写地址")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.white)
                            .padding(.horizontal, 16)
                            .frame(height: 36)
                            .background(Color.fixAmber500)
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                    .padding(.top, 12)
                }
                .padding(16)
                .background(Color.fixAmber100)
                .cornerRadius(4)
                .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color.fixAmber200, lineWidth: 1))
            } else {
                VStack(spacing: 12) {
                    ForEach(Array(entries.enumerated()), id: \.element.id) { idx, _ in
                        addressEntryEditor(idx)
                    }
                    if entries.count < 4 {
                        HStack {
                            Button {
                                entries.append(AddressData.AddressEntry(nickname: "", address: "", phone: ""))
                            } label: {
                                HStack(spacing: 4) {
                                    Image(systemName: "plus")
                                        .font(.system(size: 12))
                                    Text("新增地址（\(entries.count)/4）")
                                }
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.appForeground)
                                .padding(.horizontal, 12)
                                .frame(height: 32)
                                .overlay(Capsule().stroke(Color.appBorder, lineWidth: 1))
                            }
                            .buttonStyle(.plain)
                            Spacer()
                        }
                    }
                    HStack {
                        Spacer()
                        Button { Task { await saveAddresses() } } label: {
                            Text(savingAddr ? "保存中…" : (addrFilled ? "保存地址" : "加载中…"))
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.appPrimaryFg)
                                .padding(.horizontal, 16)
                                .frame(height: 36)
                                .background(Color.appPrimary)
                                .clipShape(Capsule())
                        }
                        .disabled(savingAddr || !addrFilled)
                        .opacity(savingAddr || !addrFilled ? 0.5 : 1)
                    }
                }
                Text("领取外部无料后，橱窗页会出现「发送地址」按钮，一键把地址发给发布者用于寄件。除你和对应橱窗的发布者外，任何人都看不到。你已同意《地址免责声明》：平台不对发布者使用或泄露地址的行为承担责任。")
                    .font(.system(size: 11))
                    .lineSpacing(2)
                    .foregroundColor(.appMutedFg)
                    .padding(.top, 6)
            }
        }
    }

    private func addressEntryEditor(_ idx: Int) -> some View {
        VStack(spacing: 8) {
            HStack {
                Text("地址 \(idx + 1)")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.appMutedFg)
                Spacer()
                if entries.count > 1 {
                    Button { entries.remove(at: idx) } label: {
                        Text("删除")
                            .font(.system(size: 12))
                            .foregroundColor(.appMutedFg)
                    }
                    .buttonStyle(.plain)
                }
            }
            AppTextField(text: Binding(
                get: { entries[idx].nickname },
                set: { entries[idx] = AddressData.AddressEntry(nickname: $0, address: entries[idx].address, phone: entries[idx].phone) }
            ), placeholder: "昵称（收件人称呼）")
            AppTextField(text: Binding(
                get: { entries[idx].phone },
                set: { entries[idx] = AddressData.AddressEntry(nickname: entries[idx].nickname, address: entries[idx].address, phone: $0) }
            ), placeholder: "手机号", keyboard: .phonePad)
            AppTextField(text: Binding(
                get: { entries[idx].address },
                set: { entries[idx] = AddressData.AddressEntry(nickname: entries[idx].nickname, address: $0, phone: entries[idx].phone) }
            ), placeholder: "地址（省市区 + 详细地址）")
        }
        .padding(12)
        .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color.appBorder, lineWidth: 1))
    }

    // MARK: 补邮支付宝账号
    private var alipaySection: some View {
        VStack(alignment: .leading, spacing: 0) {
            sectionLabel("补邮账号（仅限支付宝，仅自己可见）")
            HStack(spacing: 8) {
                AppTextField(text: $alipay, placeholder: "支付宝账号（手机号或邮箱）")
                Button { Task { await saveAlipay() } } label: {
                    Text(savingAlipay ? "保存中…" : (alipaySaved ? "已保存" : "保存"))
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(alipaySaved ? .appSecondaryFg : .appPrimaryFg)
                        .padding(.horizontal, 16)
                        .frame(height: 36)
                        .background(alipaySaved ? Color.appSecondary : Color.appPrimary)
                        .clipShape(Capsule())
                }
                .disabled(savingAlipay || !addrFilled || alipay.trimmingCharacters(in: .whitespaces).isEmpty || alipaySaved)
                .opacity(savingAlipay || !addrFilled || alipay.trimmingCharacters(in: .whitespaces).isEmpty || alipaySaved ? 0.5 : 1)
            }
            (Text(alipaySaved ? "✓ 当前已保存此账号，修改后按钮会变为可点。 " : "")
                .foregroundColor(.fixEmerald600)
            + Text("发布")
                .foregroundColor(.appMutedFg)
            + Text("不包邮")
                .foregroundColor(.appForeground.opacity(0.7))
            + Text("的外部无料时，下单后系统会通过站内信和邮件把这个账号发给对应领取人用于补邮。")
                .foregroundColor(.appMutedFg)
            + Text("请先在支付宝「转账 → 搜索账号」里确认能搜到该账号再保存。")
                .foregroundColor(.fixAmber600)
            + Text("账号不会在站内公开展示，只有你和收到补邮通知的领取人能看到。")
                .foregroundColor(.appMutedFg))
                .font(.system(size: 11))
                .lineSpacing(2)
                .padding(.top, 6)
        }
    }

    // MARK: 私信开关
    private var dmSection: some View {
        HStack(alignment: .top, spacing: 16) {
            VStack(alignment: .leading, spacing: 0) {
                Text("私信")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.appForeground)
                Text("关闭后其他用户无法给你发私信，个人页的「私信」按钮会隐藏；已有会话保留，重新开启即可恢复。")
                    .font(.system(size: 11))
                    .lineSpacing(2)
                    .foregroundColor(.appMutedFg)
                    .padding(.top, 4)
            }
            Spacer()
            let on = !(d?.dmBlocked ?? false)
            Button { Task { await toggleDm() } } label: {
                ZStack(alignment: on ? .trailing : .leading) {
                    Capsule()
                        .fill(on ? Color.appPrimary : Color.appSecondary)
                        .frame(width: 44, height: 24)
                    Circle()
                        .fill(Color.white)
                        .frame(width: 20, height: 20)
                        .shadow(color: .black.opacity(0.15), radius: 1, y: 1)
                        .padding(2)
                }
                .frame(width: 44, height: 24)
            }
            .buttonStyle(.plain)
            .disabled(dmUpdating)
            .opacity(dmUpdating ? 0.5 : 1)
            .animation(.easeInOut(duration: 0.15), value: on)
        }
    }

    // MARK: 关于与协议（App Store 上架要求新增）
    private var aboutSection: some View {
        SectionCard {
            VStack(alignment: .leading, spacing: 8) {
                Text("关于与协议")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.appForeground)
                aboutRow("隐私政策", dest: AnyView(LegalView(doc: .privacy)))
                aboutRow("用户协议与社区规范", dest: AnyView(LegalView(doc: .terms)))
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

    private func aboutRow(_ title: String, dest: AnyView) -> some View {
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
                .cornerRadius(4)
                .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color.appDestructive.opacity(0.4), lineWidth: 1))
        }
        .buttonStyle(.plain)
        .padding(.bottom, 30)
    }

    // MARK: 数据
    private func load() async {
        d = try? await MashanglingAPI.shared.settings.get()
        loading = false
        name = d?.name ?? ""
        notifyEmail = d?.notifyEmail ?? ""
        let a = try? await MashanglingAPI.shared.address.get()
        address = a
        if let a = a, !addrFilled {
            let list = a.entries ?? []
            entries = list.isEmpty
                ? [AddressData.AddressEntry(nickname: "", address: "", phone: "")]
                : list
            alipay = a.alipayAccount ?? ""
            addrFilled = true
            // 对应网页 syncSender：表单回填后把首个完整收货地址只补不写地同步为寄件地址
            if !senderSynced {
                senderSynced = true
                if let first = list.first(where: {
                    !$0.nickname.isEmpty && !$0.address.isEmpty && !$0.phone.isEmpty
                }) {
                    await MashanglingAPI.shared.address.saveSenderQuietly(
                        "\(first.nickname) \(first.address) \(first.phone)", onlyIfEmpty: true)
                }
            }
        }
    }

    private func saveName() async {
        savingName = true
        defer { savingName = false }
        do {
            _ = try await MashanglingAPI.shared.settings.updateName(name.trimmingCharacters(in: .whitespaces))
            ToastCenter.shared.success("昵称已更新")
            d = try? await MashanglingAPI.shared.settings.get()
            await AuthManager.shared.checkAuth()
        } catch { ToastCenter.shared.error(error.localizedDescription) }
    }

    /// 邮件通知总开关：关=清空发信邮箱（本地暂存以便恢复）；开=恢复暂存邮箱
    private func setEmailNotify(_ on: Bool) async {
        savingEmail = true
        defer { savingEmail = false }
        let defaults = UserDefaults.standard
        do {
            if on {
                let stash = defaults.string(forKey: "msl-notify-email-stash") ?? ""
                _ = try await MashanglingAPI.shared.settings.updateNotifyEmail(stash)
                defaults.removeObject(forKey: "msl-notify-email-stash")
                defaults.set(false, forKey: "msl-email-notify-off")
                emailOff = false
                ToastCenter.shared.success("已开启邮件通知")
            } else {
                let current = notifyEmail.trimmingCharacters(in: .whitespaces).isEmpty
                    ? (d?.notifyEmail ?? "")
                    : notifyEmail.trimmingCharacters(in: .whitespaces)
                if !current.isEmpty { defaults.set(current, forKey: "msl-notify-email-stash") }
                _ = try await MashanglingAPI.shared.settings.updateNotifyEmail("")
                defaults.set(true, forKey: "msl-email-notify-off")
                emailOff = true
                ToastCenter.shared.success("已关闭邮件通知，App 推送不受影响")
            }
            d = try? await MashanglingAPI.shared.settings.get()
            notifyEmail = d?.notifyEmail ?? ""
        } catch { ToastCenter.shared.error(error.localizedDescription) }
    }

    private func saveNotifyEmail() async {
        savingEmail = true
        defer { savingEmail = false }
        do {
            _ = try await MashanglingAPI.shared.settings.updateNotifyEmail(notifyEmail.trimmingCharacters(in: .whitespaces))
            ToastCenter.shared.success("发信邮箱已更新")
            d = try? await MashanglingAPI.shared.settings.get()
        } catch { ToastCenter.shared.error(error.localizedDescription) }
    }

    private func doBindEmail() async {
        binding = true
        defer { binding = false }
        do {
            _ = try await MashanglingAPI.shared.settings.bindEmail(
                email: bindEmail.trimmingCharacters(in: .whitespaces), password: bindPassword)
            ToastCenter.shared.success("邮箱绑定成功！现在可以在 iOS App 上用邮箱+密码登录了")
            bindEmail = ""
            bindPassword = ""
            d = try? await MashanglingAPI.shared.settings.get()
        } catch { ToastCenter.shared.error(error.localizedDescription) }
    }

    private func toggleDm() async {
        let newBlocked = !(d?.dmBlocked ?? false)
        dmUpdating = true
        defer { dmUpdating = false }
        do {
            _ = try await MashanglingAPI.shared.settings.updateDmBlocked(newBlocked)
            ToastCenter.shared.success(newBlocked ? "已关闭私信，别人无法再私信你" : "已开启私信")
            d = try? await MashanglingAPI.shared.settings.get()
        } catch { ToastCenter.shared.error(error.localizedDescription) }
    }

    private func uploadAvatar() async {
        guard let img = avatarImage, let dataURL = ImageCodec.coverDataURL(from: img) else { return }
        uploadingAvatar = true
        defer { uploadingAvatar = false }
        do {
            _ = try await MashanglingAPI.shared.settings.updateAvatar(dataURL)
            ToastCenter.shared.success("头像已更新")
            d = try? await MashanglingAPI.shared.settings.get()
            await AuthManager.shared.checkAuth()
        } catch { ToastCenter.shared.error(error.localizedDescription) }
    }

    private func saveAddresses() async {
        savingAddr = true
        defer { savingAddr = false }
        do {
            _ = try await MashanglingAPI.shared.address.save(entries: entries)
            ToastCenter.shared.success("地址已保存")
            address = try? await MashanglingAPI.shared.address.get()
        } catch { ToastCenter.shared.error(error.localizedDescription) }
    }

    private func saveAlipay() async {
        savingAlipay = true
        defer { savingAlipay = false }
        do {
            _ = try await MashanglingAPI.shared.address.saveAlipay(alipay.trimmingCharacters(in: .whitespaces))
            ToastCenter.shared.success("补邮账号已保存")
            address = try? await MashanglingAPI.shared.address.get()
        } catch { ToastCenter.shared.error(error.localizedDescription) }
    }
}
