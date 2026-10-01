import SwiftUI

// MARK: - 法律文档与账号注销（App Store 上架要求新增，全部为新增内容）

/// 法律文档阅读页（隐私政策 / 用户协议与社区规范）
struct LegalView: View {
    let doc: LegalDoc

    var body: some View {
        ScrollView(showsIndicators: false) {
            Text(doc.body)
                .font(.system(size: 14))
                .lineSpacing(6)
                .foregroundColor(.appForeground)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 16)
                .padding(.vertical, 16)
        }
        .background(Color.appBackground)
        .navigationTitle(doc.title)
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct LegalDoc {
    let title: String
    let body: String

    static let privacy = LegalDoc(title: "隐私政策", body: """
生效日期：2026 年 10 月 1 日

「码上领」（以下简称"本应用"）是一个无料（粉丝自制周边）分享与领取社区。我们非常重视你的个人信息和隐私保护，本政策说明我们收集哪些信息、如何使用以及你的权利。

一、我们收集的信息

1. 账号信息：注册时你提供的邮箱地址、昵称，以及经加密哈希存储的密码（我们无法看到你的明文密码）。
2. 你主动发布的内容：橱窗标题、简介、封面图、标签、分享码、返图、评论、私信等。
3. 收货与寄件信息：你主动填写的收货地址（昵称、手机号、详细地址）、寄件地址、补邮支付宝账号。这些信息仅你本人可见；当你在某橱窗点击「发送地址」后，该地址仅发送给对应橱窗的发布者。
4. 使用数据：点赞、收藏、「我想要」、浏览历史、积分变动记录等，用于提供对应功能。

二、信息的使用

我们仅将上述信息用于：提供浏览、发布、领取、私信、快递寄送等核心功能；发送与你相关的站内通知和邮件（如补码提醒、审核结果）；改进产品体验。我们不会将你的个人信息出售给任何第三方。

三、信息的共享

除以下情形外，我们不会向他人共享你的个人信息：
1. 你主动向橱窗发布者发送收货地址时，该地址对该发布者可见；
2. 你发布「不包邮」外部无料时，你填写的补邮支付宝账号会随补邮通知发送给对应领取人；
3. 法律法规要求的情形。

四、第三方服务

本应用不接入任何广告、统计或跟踪类第三方 SDK。图片与数据均存储于本应用自有服务器。本应用不会出于广告目的跟踪你（App Tracking Transparency 意义上的"跟踪"不存在）。

五、你的权利

1. 你可以在「设置」中随时修改昵称、头像、地址、通知邮箱等信息；
2. 你可以在「设置 → 账号 → 注销账号」中永久删除你的账号及全部关联数据；
3. 你可以通过意见反馈渠道（QQ 3495379352）联系我们查询、更正或删除你的个人信息。

六、数据安全

密码经哈希加密存储；敏感信息（地址、支付宝账号）仅授权对象可见；服务端接口均通过 HTTPS 加密传输。

七、政策更新

本政策更新后会在应用内公示。继续使用本应用即表示你同意更新后的政策。

八、联系我们

制作者 / 问题反馈：QQ 3495379352
""")

    static let terms = LegalDoc(title: "用户协议与社区规范", body: """
生效日期：2026 年 10 月 1 日

欢迎使用「码上领」。使用本应用即表示你同意以下条款。

一、服务说明

本应用是无料（粉丝自制周边）的分享与领取信息平台，仅提供信息展示与传递通道，不参与任何制品的制作、交易与寄送过程。领取无料通常需自付制作与邮费，请以分享者说明为准。

二、账号

1. 你需要使用邮箱注册账号，并妥善保管密码；
2. 你可以随时在「设置 → 账号 → 注销账号」中永久注销账号，注销后你的全部数据将被删除且不可恢复；
3. 禁止转让、出借账号，禁止批量注册。

三、内容规范

你发布的内容（橱窗、图片、评论、私信等）不得包含：
1. 违反法律法规的内容；
2. 侵犯他人知识产权、肖像权的内容（无料分享请确保你有权分享对应制品）；
3. 欺诈、虚假宣传、诱导站外交易付款的内容；
4. 色情、暴力、歧视、人身攻击等不良信息；
5. 其他损害社区氛围的内容。

违反上述规范的内容将被下架，情节严重的账号将被封禁。你可以通过每个橱窗、每张卡片、每位用户旁的「举报」入口向我们报告违规内容，我们会在 24 小时内处理。

四、邮费与地址

1. 「不包邮」的外部无料，领取人需按发布者说明补邮费；补邮通过发布者的支付宝账号线下完成，平台不经手任何资金；
2. 你发送的收货地址仅对应橱窗发布者可见，请确认对方可信后再发送；
3. 对于发布者或领取人使用、保管地址不当造成的损失或纠纷，平台不承担责任，但我们会协助你进行处理。

五、积分与虚拟物品

积分、等级、头衔、农场小鸡、卡片主题等均为站内虚拟权益，不具有任何现实货币价值，不可兑换现金，不可转让变现。

六、免责声明

1. 站内橱窗内容由用户发布，平台不对其真实性、质量、交付时效承担责任；
2. 因不可抗力或第三方原因导致的服务中断，平台不承担赔偿责任。

七、协议修改

我们可能适时修改本协议，修改后会在应用内公示。若你不同意修改后的协议，可以停止使用并注销账号。

八、联系我们

制作者 / 问题反馈：QQ 3495379352
""")
}

// MARK: - 注销账号弹窗（App Store 审核硬性要求：App 内提供账号删除入口）
struct DeleteAccountSheet: View {
    @EnvironmentObject var authManager: AuthManager
    @Environment(\.dismiss) private var dismiss

    @State private var password = ""
    @State private var confirmed = false
    @State private var busy = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // 警示区
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 8) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.system(size: 20))
                                .foregroundColor(.fixRed500)
                            Text("注销后不可恢复")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(.appForeground)
                        }
                        Text("注销账号将永久删除：")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.appForeground)
                        Text("· 你的账号、昵称、头像与登录邮箱\n· 你发布的全部橱窗、返图、评论与私信\n· 你的积分、等级、农场与卡片数据\n· 你的收货地址与补邮账号等个人信息")
                            .font(.system(size: 13))
                            .lineSpacing(5)
                            .foregroundColor(.appMutedFg)
                    }
                    .padding(14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.fixRed500.opacity(0.08))
                    .cornerRadius(12)
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.fixRed500.opacity(0.3), lineWidth: 1))

                    // 密码确认
                    VStack(alignment: .leading, spacing: 6) {
                        Text("输入登录密码确认身份")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.appForeground)
                        AppTextField(text: $password, placeholder: "登录密码", secure: true)
                    }

                    // 确认勾选
                    Button { confirmed.toggle() } label: {
                        HStack(alignment: .top, spacing: 8) {
                            Image(systemName: confirmed ? "checkmark.square.fill" : "square")
                                .font(.system(size: 18))
                                .foregroundColor(confirmed ? .appPrimary : .appMutedFg)
                            Text("我已知晓注销的后果，确认永久注销我的账号")
                                .font(.system(size: 13))
                                .foregroundColor(.appForeground)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    .buttonStyle(.plain)

                    Button { Task { await doDelete() } } label: {
                        Text(busy ? "注销中…" : "永久注销账号")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(Color.appDestructive)
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                    .disabled(busy || !confirmed || password.isEmpty)
                    .opacity((confirmed && !password.isEmpty) ? 1 : 0.5)

                    Text("如忘记密码，可先通过登录页找回。注销后如需重新使用，请重新注册。")
                        .font(.system(size: 11))
                        .foregroundColor(.appMutedFg)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 20)
            }
            .background(Color.appBackground)
            .navigationTitle("注销账号")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("取消") { dismiss() }
                        .font(.system(size: 13))
                        .foregroundColor(.appMutedFg)
                }
            }
            .overlay(ToastOverlay())
        }
    }

    private func doDelete() async {
        busy = true
        defer { busy = false }
        do {
            try await authManager.deleteAccount(password: password)
            ToastCenter.shared.success("账号已注销，感谢陪伴")
            dismiss()
        } catch {
            ToastCenter.shared.error(error.localizedDescription)
        }
    }
}
