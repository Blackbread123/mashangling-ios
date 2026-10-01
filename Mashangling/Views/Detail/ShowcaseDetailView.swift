import SwiftUI
import UIKit

// MARK: - 橱窗详情（对应网页 ShowcaseDetail.tsx）
struct ShowcaseDetailView: View {
    let showcaseId: Int

    @EnvironmentObject var authManager: AuthManager
    @Environment(\.dismiss) private var dismiss

    @State private var detail: ShowcaseDetailData? = nil
    @State private var loading = true
    @State private var liked = false
    @State private var likeCount = 0
    @State private var claimedByMe = false
    @State private var bookmarked = false
    @State private var requested = false
    @State private var markedSoldout = false
    @State private var reposts: [RepostRow] = []
    @State private var codes: MashanglingAPI.CodeService.CodeList? = nil
    @State private var busy = false
    @State private var showLogin = false
    @State private var showReport = false
    @State private var showMenu = false
    @State private var showClaimSheet = false
    @State private var showRepostSheet = false
    @State private var showAddressSheet = false
    @State private var showGiftSheet = false
    @State private var showEdit = false
    @State private var shareImage: ShareImageItem? = nil
    @State private var addresses: ReceivedAddresses? = nil
    @State private var addressExpanded = false
    @State private var newCode = ""
    @State private var showDeleteConfirm = false
    @State private var showDmAuthor = false

    struct ShareImageItem: Identifiable {
        let id = UUID()
        let image: UIImage
    }

    var body: some View {
        Group {
            if loading && detail == nil {
                LoadingView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let d = detail {
                content(d)
            } else {
                EmptyStateView(icon: "questionmark.square", title: "橱窗不存在或已下架")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .background(Color.appBackground.ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { toolbarContent }
        .task { await load() }
        .refreshable { await load() }
        .overlay(ToastOverlay())
        .sheet(isPresented: $showLogin) { LoginView() }
        .sheet(isPresented: $showReport) { ReportSheet(targetType: "showcase", targetId: showcaseId) }
        .sheet(isPresented: $showClaimSheet) {
            if let d = detail { ClaimSheet(detail: d) { Task { await load() } } }
        }
        .sheet(isPresented: $showRepostSheet) {
            RepostSheet(showcaseId: showcaseId) { Task { await loadReposts() } }
        }
        .sheet(isPresented: $showAddressSheet) {
            if let d = detail { AddressPickSheet(showcaseId: d.id) { Task { await load() } } }
        }
        .sheet(isPresented: $showGiftSheet) {
            GiftShareSheet(showcaseId: showcaseId)
        }
        .sheet(isPresented: $showEdit) {
            if let d = detail { PublishView(editing: d) }
        }
        .sheet(item: $shareImage) { item in
            ShareSheet(items: [item.image])
        }
        .confirmationDialog("确定删除这个橱窗吗？", isPresented: $showDeleteConfirm, titleVisibility: .visible) {
            Button("删除", role: .destructive) { Task { await removeShowcase() } }
            Button("取消", role: .cancel) {}
        } message: {
            Text("删除后不可恢复")
        }
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .navigationBarTrailing) {
            Menu {
                Button { Task { await makeShareCard() } } label: {
                    Label("生成分享卡片", systemImage: "square.and.arrow.up")
                }
                Button { showGiftSheet = true } label: {
                    Label("送给互关好友", systemImage: "gift")
                }
                Button { Task { await shareLink() } } label: {
                    Label("复制链接", systemImage: "link")
                }
                Divider()
                Button(role: .destructive) { showReport = true } label: {
                    Label("举报", systemImage: "flag")
                }
                if detail?.isMine == true {
                    Divider()
                    Button { showEdit = true } label: {
                        Label("编辑橱窗", systemImage: "pencil")
                    }
                    Button(role: .destructive) { Task { await removeShowcase() } } label: {
                        Label("删除橱窗", systemImage: "trash")
                    }
                }
            } label: {
                Image(systemName: "ellipsis.circle")
                    .foregroundColor(.appForeground)
            }
        }
    }

    // MARK: 主体（对应网页 ShowcaseDetail.tsx：封面自然比例 → 标题/作者/标签/简介/码区/操作栏）
    private func content(_ d: ShowcaseDetailData) -> some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 0) {
                // 封面：rounded 5px + 1px border-border/60，自然比例
                AppImage(path: d.coverImage, contentMode: .fit)
                    .frame(maxWidth: .infinity)
                    .background(Color.appCard)
                    .clipShape(RoundedRectangle(cornerRadius: 5))
                    .overlay(RoundedRectangle(cornerRadius: 5).stroke(Color.appBorder.opacity(0.6), lineWidth: 1))

                VStack(alignment: .leading, spacing: 0) {
                    titleRow(d)
                    authorRow(d)
                    tagsRow(d)
                    if let desc = d.description, !desc.isEmpty {
                        // 简介：裸文本不套卡，14px/24px，foreground 90%
                        Text(desc)
                            .font(.system(size: 14))
                            .lineSpacing(7)
                            .foregroundColor(.appForeground.opacity(0.9))
                            .fixedSize(horizontal: false, vertical: true)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.top, 16)
                    }
                    mainCodeSection(d)
                    actionsRow(d)
                }
                .padding(.top, 32) // 网页 grid gap-32

                codeSection(d)    // 补码区 mt-24
                addressSection(d) // 收到的地址 mt-24（仅本人+外部无料）
                repostSection(d)  // 返图 mt-40
                relatedSection(d) // 相关橱窗 mt-48
            }
            .padding(.horizontal, 16)
            .padding(.top, 24)
            .padding(.bottom, 24)
        }
        .background(dmAuthorLink)
    }

    // MARK: 标题行（24px 粗 + 平台/限时/浏览胶囊，gap 10）
    private func titleRow(_ d: ShowcaseDetailData) -> some View {
        HStack(alignment: .center, spacing: 10) {
            Text(d.title)
                .font(.system(size: 24, weight: .bold))
                .tracking(-0.6)
                .foregroundColor(.appForeground)
                .fixedSize(horizontal: false, vertical: true)
            Text(PlatformLabel.of(d.platform))
                .font(.system(size: 12))
                .foregroundColor(.appSecondaryFg)
                .padding(.horizontal, 10).padding(.vertical, 2)
                .background(Color.appSecondary)
                .clipShape(Capsule())
                .fixedSize()
            if d.expiresAt != nil { expiresPill(d) }
            if d.isMine == true { viewsPill(d) }
        }
    }

    private func expiresPill(_ d: ShowcaseDetailData) -> some View {
        let expired = d.expired == true
        return HStack(spacing: 4) {
            Image(systemName: "timer").font(.system(size: 14))
            Text(expired ? "已失效" : "限时 · \(d.expiresAtText ?? "") 失效")
                .font(.system(size: 12, weight: .medium))
                .lineLimit(1)
        }
        .foregroundColor(expired ? .fixZinc500 : .fixOrange700)
        .padding(.horizontal, 10).padding(.vertical, 2)
        .background(expired ? Color.fixZinc500.opacity(0.15) : Color.fixOrange100)
        .clipShape(Capsule())
        .fixedSize()
    }

    private func viewsPill(_ d: ShowcaseDetailData) -> some View {
        HStack(spacing: 4) {
            Image(systemName: "eye").font(.system(size: 14))
            Text("\(d.viewCount ?? 0) 次浏览").font(.system(size: 12)).lineLimit(1)
        }
        .foregroundColor(.appMutedFg)
        .padding(.horizontal, 10).padding(.vertical, 2)
        .background(Color.appSecondary)
        .clipShape(Capsule())
        .fixedSize()
    }

    // MARK: 作者行（mt-8：来自 X 的橱窗 + Lv.N + 头衔）
    private func authorRow(_ d: ShowcaseDetailData) -> some View {
        NavigationLink(destination: ProfileView(userId: d.author?.id ?? 0)) {
            HStack(spacing: 6) {
                Text("来自 \(d.author?.name ?? "未知用户") 的橱窗")
                    .font(.system(size: 14))
                    .foregroundColor(.appMutedFg)
                    .lineLimit(1)
                LevelBadgeView(level: d.author?.level ?? 1)
                TitleBadgeView(equippedTitle: d.author?.equippedTitle)
                Spacer(minLength: 0)
            }
        }
        .buttonStyle(.plain)
        .padding(.top, 8)
    }

    // MARK: 标签行（mt-12，胶囊 4/12 padding，名字 + ·分类）
    @ViewBuilder
    private func tagsRow(_ d: ShowcaseDetailData) -> some View {
        if let tags = d.tags, !tags.isEmpty {
            FlowLayout(spacing: 6) {
                ForEach(tags) { t in
                    NavigationLink(destination: TagDetailView(tagId: t.id)) {
                        HStack(spacing: 4) {
                            Text(t.name).foregroundColor(.appSecondaryFg)
                            Text("·\(TagCategory.labels[t.category ?? ""] ?? (t.category ?? ""))")
                                .foregroundColor(.appMutedFg)
                        }
                        .font(.system(size: 12))
                        .padding(.horizontal, 12).padding(.vertical, 4)
                        .background(Color.appSecondary)
                        .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.top, 12)
        }
    }

    // MARK: 码区（四种形态，分支条件与网页一致）
    @ViewBuilder
    private func mainCodeSection(_ d: ShowcaseDetailData) -> some View {
        if let rc = d.rouzaoCode, !rc.isEmpty {
            rouzaoCodeBox(d, code: rc)
        } else if d.expired == true && d.isMine != true {
            expiredBox(d)
        } else if (d.codeVisibility != "open" || d.quantity != nil) && d.isMine != true {
            lockedBox(d)
        } else {
            externalBox(d)
        }
    }

    // 琥珀色限定提示条
    private func limitedNotice() -> some View {
        HStack(spacing: 6) {
            Image(systemName: "lock").font(.system(size: 14))
            Text("限定橱窗一码一物，请勿告知他人")
                .font(.system(size: 12, weight: .medium))
        }
        .foregroundColor(.fixAmber700)
        .padding(.horizontal, 12).padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.fixAmber100.opacity(0.6))
        .cornerRadius(3)
        .overlay(RoundedRectangle(cornerRadius: 3).stroke(Color.fixAmber200, lineWidth: 1))
    }

    // 分隔线块：border-t + pt-8 + mt-8
    private func hairline<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Rectangle().fill(Color.appBorder.opacity(0.6)).frame(height: 1)
            content().padding(.top, 8)
        }
        .padding(.top, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func platformHint(_ d: ShowcaseDetailData) -> String {
        switch d.platform {
        case "rouzao":   return "复制后打开柔造小程序，粘贴即可下单同款。领取通常需自付制作与邮费。"
        case "yingtang": return "复制后到映糖粘贴领取。领取通常需自付制作与邮费。"
        default:         return "复制后按发布人说明领取。"
        }
    }

    private func claimModeNote(_ d: ShowcaseDetailData) -> String {
        switch d.claimMode {
        case "instant":
            return "你已设置「限量·无需审批」，访客点「领取」即自动解锁，无需你审批，领完即止。"
        case "points":
            return "你已设置「积分解锁」，访客支付 \(d.pointCost ?? 0) 积分即自动解锁（积分转入你的账户），无需审批，领完即止。"
        default:
            let t = d.codeVisibility == "request" ? "申请领取" : "凭证解锁"
            return "你已设置「\(t)」，访客需申请并经你批准后可见。审核入口在个人页「领取申请」。"
        }
    }

    private func expiryNote(_ d: ShowcaseDetailData) -> String {
        if d.expired == true {
            return "该橱窗已于 \(d.expiresAtText ?? "") 失效，访客已无法查看/领取；如需重新开放，可在编辑中清除或延后限时。"
        }
        return "你设置了限时：\(d.expiresAtText ?? "") 后失效，届时访客将无法再查看/领取。"
    }

    // 形态一：有平台码（本人/公开可见）
    private func rouzaoCodeBox(_ d: ShowcaseDetailData, code: String) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            if d.codeVisibility != "open" {
                limitedNotice().padding(.bottom, 12)
            }
            Text("\(PlatformLabel.of(d.platform))码")
                .font(.system(size: 12))
                .foregroundColor(.appMutedFg)
            HStack(alignment: .center, spacing: 12) {
                Text(code)
                    .font(.system(size: 18, weight: .semibold, design: .monospaced))
                    .tracking(0.45)
                    .foregroundColor(.appForeground)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
                Button {
                    UIPasteboard.general.string = code
                    ToastCenter.shared.success("已复制")
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "doc.on.doc").font(.system(size: 16))
                        Text("一键复制").font(.system(size: 14, weight: .medium))
                    }
                    .foregroundColor(.appPrimaryFg)
                    .padding(.horizontal, 16).frame(height: 36)
                    .background(Color.appPrimary)
                    .clipShape(Capsule())
                    .shadow(color: .black.opacity(0.05), radius: 1, y: 1)
                }
                .buttonStyle(.plain)
                .fixedSize()
            }
            .padding(.top, 6)
            Text(platformHint(d))
                .font(.system(size: 11))
                .lineSpacing(5)
                .foregroundColor(.appMutedFg)
                .padding(.top, 8)
            if d.isMine == true, let qty = d.quantity {
                hairline {
                    let rem = d.remaining ?? 0
                    let color: Color = d.isFullyClaimed == true ? .fixRed500 : .appEmerald
                    (Text("余量：") +
                     Text("\(rem)/\(qty)").fontWeight(.semibold).foregroundColor(color) +
                     Text(d.isFullyClaimed == true ? "（已领完）" : "（已领 \(qty - rem) 份）"))
                        .font(.system(size: 11))
                        .foregroundColor(.appMutedFg)
                }
            }
            if d.isMine == true, d.codeVisibility != "open" {
                hairline {
                    Text(claimModeNote(d))
                        .font(.system(size: 11)).lineSpacing(5).foregroundColor(.appMutedFg)
                }
            }
            if d.isMine == true, d.expiresAt != nil {
                hairline {
                    Text(expiryNote(d))
                        .font(.system(size: 11)).lineSpacing(5).foregroundColor(.appMutedFg)
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.appCard)
        .cornerRadius(4)
        .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color.appBorder, lineWidth: 1))
        .padding(.top, 24)
    }

    // 形态二：已失效（访客视角，zinc 灰框）
    private func expiredBox(_ d: ShowcaseDetailData) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 8) {
                Image(systemName: "timer").font(.system(size: 16)).foregroundColor(.fixZinc500)
                Text("已失效").font(.system(size: 14, weight: .medium)).foregroundColor(.fixZinc600)
            }
            Text("这是限时橱窗，已于 \(d.expiresAtText ?? "") 失效，不能再领取。")
                .font(.system(size: 11)).lineSpacing(5).foregroundColor(.appMutedFg)
                .padding(.top, 6)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.fixZinc50)
        .cornerRadius(4)
        .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color.fixZinc200, lineWidth: 1))
        .padding(.top, 24)
    }

    // 形态三：锁定框（需解锁/限量，访客视角）
    private func lockedBox(_ d: ShowcaseDetailData) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 8) {
                Image(systemName: "lock").font(.system(size: 16)).foregroundColor(.appPrimary)
                Text(lockHeadTitle(d))
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.appForeground)
                Spacer(minLength: 0)
                if let q = d.quantity {
                    Text("剩 \(d.remaining ?? 0)/\(q)")
                        .font(.system(size: 11))
                        .foregroundColor(.appMutedFg)
                        .padding(.horizontal, 8).padding(.vertical, 2)
                        .background(Color.appSecondary)
                        .clipShape(Capsule())
                        .fixedSize()
                }
            }
            lockBody(d).padding(.top, 12)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.appCard)
        .cornerRadius(4)
        .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color.appBorder, lineWidth: 1))
        .padding(.top, 24)
    }

    private func lockHeadTitle(_ d: ShowcaseDetailData) -> String {
        if d.claimMode == "points" { return "需 \(d.pointCost ?? 0) 积分解锁" }
        return d.platform == "external" ? "外部无料 · 限量领取" : "分享码需解锁"
    }

    // 全宽胶囊主按钮（锁定框内）
    private func fullPill(icon: String, label: String, bg: Color, fg: Color,
                          enabled: Bool = true, action: @escaping () -> Void = {}) -> some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: icon).font(.system(size: 16))
                Text(label).font(.system(size: 14, weight: .medium))
            }
            .foregroundColor(fg)
            .frame(maxWidth: .infinity)
            .frame(height: 36)
            .background(bg)
            .clipShape(Capsule())
            .shadow(color: enabled ? .black.opacity(0.05) : .clear, radius: 1, y: 1)
            .opacity(enabled ? 1 : 0.6)
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
    }

    private func disabledPill(icon: String, label: String) -> some View {
        fullPill(icon: icon, label: label, bg: .appSecondary, fg: .appSecondaryFg, enabled: false)
    }

    @ViewBuilder
    private func lockBody(_ d: ShowcaseDetailData) -> some View {
        let st = d.myClaimStatus
        if st == "approved" {
            VStack(alignment: .leading, spacing: 0) {
                limitedNotice().padding(.bottom, 12)
                disabledPill(icon: "checkmark", label: "已领取 ✓")
                (Text("该无料没有平台码，发布人会与你联系发放；也可以主动") +
                 Text("私信发布人").foregroundColor(.appPrimary) +
                 Text("沟通。"))
                    .font(.system(size: 11)).lineSpacing(5).foregroundColor(.appMutedFg)
                    .padding(.top, 8)
                    .onTapGesture { showDmAuthor = true }
            }
        } else if d.isFullyClaimed == true {
            VStack(alignment: .leading, spacing: 0) {
                disabledPill(icon: "xmark.circle", label: "已领完")
                Text("该橱窗限量 \(d.quantity ?? 0) 份，已全部领完。")
                    .font(.system(size: 11)).lineSpacing(5).foregroundColor(.appMutedFg)
                    .padding(.top, 8)
            }
        } else if d.claimMode == "points" {
            VStack(alignment: .leading, spacing: 0) {
                fullPill(icon: "centsign.circle", label: "支付 \(d.pointCost ?? 0) 积分解锁",
                         bg: .appAmber, fg: .white) {
                    Task { await unlockClaim() }
                }
                Text("解锁后积分转给发布者，无需审批"
                     + (d.quantity != nil ? "，限量 \(d.quantity ?? 0) 份领完即止" : "")
                     + (d.platform == "external" ? "；解锁后即可一键发送地址" : "，分享码立即露出") + "。")
                    .font(.system(size: 11)).lineSpacing(5).foregroundColor(.appMutedFg)
                    .padding(.top, 8)
            }
        } else if d.claimMode == "instant" {
            VStack(alignment: .leading, spacing: 0) {
                fullPill(icon: "shippingbox", label: "领取", bg: .appPrimary, fg: .appPrimaryFg) {
                    Task { await unlockClaim() }
                }
                Text("无需审批：点击「领取」分享码立即解锁，每人限领一次"
                     + (d.quantity != nil ? "，限量 \(d.quantity ?? 0) 份领完即止" : "") + "。")
                    .font(.system(size: 11)).lineSpacing(5).foregroundColor(.appMutedFg)
                    .padding(.top, 8)
            }
        } else if st == "pending" {
            VStack(alignment: .leading, spacing: 0) {
                disabledPill(icon: "hourglass", label: "申请审核中")
                Text("发布人正在审核你的申请，结果会通过站内信通知你。")
                    .font(.system(size: 11)).lineSpacing(5).foregroundColor(.appMutedFg)
                    .padding(.top, 8)
            }
        } else {
            let credential = (d.quantity != nil && d.claimMode == "request") || d.codeVisibility == "credential"
            VStack(alignment: .leading, spacing: 0) {
                fullPill(icon: "lock", label: "申请领取", bg: .appPrimary, fg: .appPrimaryFg) {
                    guard authManager.isAuthenticated else { showLogin = true; return }
                    showClaimSheet = true
                }
                Text(credential
                     ? "需上传凭证（照片或文字，至少一项）供发布人审核，通过后分享码自动解锁。"
                     : "点击申请，发布人批准后分享码自动解锁，结果会通过站内信通知你。")
                    .font(.system(size: 11)).lineSpacing(5).foregroundColor(.appMutedFg)
                    .padding(.top, 8)
            }
        }
    }

    // 形态四：外部无料 · 无平台码（虚线框）
    private func externalBox(_ d: ShowcaseDetailData) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 8) {
                Text("外部无料 · 无平台码")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.appForeground)
                if d.shippingFree == true {
                    shipBadge("包邮", bg: .fixEmerald100, fg: .fixEmerald700, brd: .fixEmerald300)
                }
                if d.shippingFree == false {
                    shipBadge("不包邮", bg: .fixAmber100, fg: .fixAmber700, brd: .fixAmber300)
                }
                Spacer(minLength: 0)
                if let q = d.quantity {
                    Text(d.isFullyClaimed == true ? "已领完" : "剩 \(d.remaining ?? 0)/\(q)")
                        .font(.system(size: 11))
                        .foregroundColor(.appMutedFg)
                        .padding(.horizontal, 8).padding(.vertical, 2)
                        .background(Color.appSecondary)
                        .clipShape(Capsule())
                        .fixedSize()
                }
            }
            Text(externalNote(d))
                .font(.system(size: 11)).lineSpacing(5).foregroundColor(.appMutedFg)
                .padding(.top, 4)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.appCard)
        .cornerRadius(4)
        .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color.appBorder, style: StrokeStyle(lineWidth: 1, dash: [6])))
        .padding(.top, 24)
    }

    private func shipBadge(_ text: String, bg: Color, fg: Color, brd: Color) -> some View {
        Text(text)
            .font(.system(size: 11, weight: .bold))
            .foregroundColor(fg)
            .padding(.horizontal, 8).padding(.vertical, 2)
            .background(bg)
            .clipShape(Capsule())
            .overlay(Capsule().stroke(brd, lineWidth: 1))
            .fixedSize()
    }

    private func externalNote(_ d: ShowcaseDetailData) -> String {
        if d.isMine == true {
            return d.quantity != nil
                ? "该无料不走柔造/映糖，已开启限量：访客需在上方点「领取」（或提交凭证经你批准）后计为已领，领完即止。"
                : "该无料不走柔造/映糖。访客点「我想领」后可一键发送收货地址，地址会出现在下方「收到的地址」后台和站内信「地址」分类（不发邮件）。"
        }
        if d.isFullyClaimed == true { return "该无料已领完。" }
        if d.addressSentByMe == true { return "你的收货地址已发送给发布者，请等待对方联系你寄件。" }
        if d.myRequested == true { return "已记录你想领。点下方「发送地址给发布者」，一键把收货地址发给对方（需先在「设置 → 地址」填好地址）。" }
        return "该无料不走柔造/映糖，点下方「我想领」即可；点完刷新一下页面，就能在这里一键发送收货地址给发布者。"
    }

    // MARK: 操作栏（mt-20，flex-wrap gap-8 胶囊横排 + 右侧 编辑/删除/举报）
    private func actionsRow(_ d: ShowcaseDetailData) -> some View {
        FlowLayout(spacing: 8) {
            // 点赞（激活：主色描边 + 10% 底 + 实心 + 600）
            actPill(icon: liked ? "heart.fill" : "heart",
                    label: "\(likeCount) 点赞",
                    tint: liked ? .appPrimary : .appForeground,
                    bg: liked ? Color.appPrimary.opacity(0.1) : .appCard,
                    brd: liked ? .appPrimary : .appBorder,
                    active: liked) { Task { await toggleLike() } }
            // 我领到了（激活：翠绿描边 + 浅绿底 + EM700）
            actPill(icon: "shippingbox",
                    label: (claimedByMe ? "已领到 ✓" : "我领到了") + ((d.claimCount ?? 0) > 0 ? " · \(d.claimCount ?? 0)" : ""),
                    tint: claimedByMe ? .fixEmerald700 : .appForeground,
                    bg: claimedByMe ? .fixEmerald100 : .appCard,
                    brd: claimedByMe ? .appEmerald : .appBorder,
                    active: claimedByMe) { Task { await toggleClaim() } }
            // 我想领 / 收到的想要
            if d.isMine == true {
                actPillLink(icon: "hand.raised",
                            label: "收到的想要" + ((d.wantCount ?? 0) > 0 ? " · \(d.wantCount ?? 0)" : ""),
                            dest: ClaimsView(initialTab: 1))
            } else if requested || d.isFullyClaimed == true {
                actPill(icon: "hand.raised",
                        label: d.isFullyClaimed == true ? "已领完" : "已想领 ✓",
                        tint: .appMutedFg, bg: .appSecondary, brd: .appBorder) {}
            } else {
                // 深色实心：foreground 底 + background 字
                actPill(icon: "hand.raised", label: "我想领",
                        suffix: d.remaining.map { "（剩 \($0)）" },
                        tint: .appBackground, bg: .appForeground, brd: nil) { Task { await wantIt() } }
            }
            // 清单（激活态同点赞）
            actPill(icon: bookmarked ? "bookmark.fill" : "bookmark",
                    label: bookmarked ? "已在清单" : "加入清单",
                    tint: bookmarked ? .appPrimary : .appForeground,
                    bg: bookmarked ? Color.appPrimary.opacity(0.1) : .appCard,
                    brd: bookmarked ? .appPrimary : .appBorder,
                    active: bookmarked) { Task { await toggleBookmark() } }
            // 返图
            actPill(icon: "camera", label: "返图") { showRepostSheet = true }
            // 分享（点按复制链接并打点）
            actPill(icon: "square.and.arrow.up",
                    label: "分享" + ((d.shareCount ?? 0) > 0 ? " · \(d.shareCount ?? 0)" : "")) {
                Task { await shareLink() }
            }
            // 没有了（外部无料不显示）
            if d.platform != "external" {
                if d.isMine == true {
                    actPillLink(icon: "nosign",
                                label: (d.soldoutCount ?? 0) > 0 ? "\(d.soldoutCount ?? 0) 人反馈没有了" : "没有了",
                                tint: .appMutedFg,
                                dest: ClaimsView(initialTab: 2))
                } else if markedSoldout {
                    actPill(icon: "nosign", label: "已反馈没有了",
                            tint: .appMutedFg, bg: .appSecondary, brd: .appBorder) {}
                } else {
                    actPill(icon: "nosign",
                            label: "没有了" + ((d.soldoutCount ?? 0) > 0 ? " · \(d.soldoutCount ?? 0)" : "")) {
                        Task { await markSoldout() }
                    }
                }
            }
            // 右侧：编辑/删除（本人）+ 举报，12px MUTED
            HStack(spacing: 12) {
                if d.isMine == true {
                    Button { showEdit = true } label: { miniAct("pencil", "编辑") }
                        .buttonStyle(.plain)
                    Button { showDeleteConfirm = true } label: { miniAct("trash", "删除") }
                        .buttonStyle(.plain)
                }
                Button { showReport = true } label: { miniAct("flag", "举报") }
                    .buttonStyle(.plain)
            }
        }
        .padding(.top, 20)
    }

    private func miniAct(_ icon: String, _ label: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon).font(.system(size: 14))
            Text(label).font(.system(size: 12))
        }
        .foregroundColor(.appMutedFg)
    }

    private func actPill(icon: String, label: String, suffix: String? = nil,
                         tint: Color = .appForeground, bg: Color = .appCard,
                         brd: Color? = .appBorder, active: Bool = false,
                         action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon).font(.system(size: 16))
                Text(label).font(.system(size: 14, weight: active ? .semibold : .regular))
                if let s = suffix { Text(s).font(.system(size: 11)).opacity(0.7) }
            }
            .foregroundColor(tint)
            .padding(.horizontal, 16).padding(.vertical, 8)
            .background(bg)
            .clipShape(Capsule())
            .overlay(Capsule().stroke(brd ?? .clear, lineWidth: brd == nil ? 0 : 1))
        }
        .buttonStyle(.plain)
    }

    private func actPillLink<Dest: View>(icon: String, label: String,
                                         tint: Color = .appForeground,
                                         bg: Color = .appCard, brd: Color? = .appBorder,
                                         dest: Dest) -> some View {
        NavigationLink(destination: dest) {
            HStack(spacing: 6) {
                Image(systemName: icon).font(.system(size: 16))
                Text(label).font(.system(size: 14))
            }
            .foregroundColor(tint)
            .padding(.horizontal, 16).padding(.vertical, 8)
            .background(bg)
            .clipShape(Capsule())
            .overlay(Capsule().stroke(brd ?? .clear, lineWidth: brd == nil ? 0 : 1))
        }
        .buttonStyle(.plain)
    }

    // MARK: 补码区（mt-24：锁定态 / 列表态 + 本人输入行）
    @ViewBuilder
    private func codeSection(_ d: ShowcaseDetailData) -> some View {
        if let c = codes {
            if c.locked && c.count > 0 {
                VStack(alignment: .leading, spacing: 0) {
                    HStack(spacing: 6) {
                        Image(systemName: "lock").font(.system(size: 16)).foregroundColor(.appPrimary)
                        Text("补码区").font(.system(size: 14, weight: .medium)).foregroundColor(.appForeground)
                        Text("· \(c.count) 个码已锁定").font(.system(size: 12)).foregroundColor(.appMutedFg)
                    }
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: d.myClaimStatus == "pending" ? "hourglass" : "lock")
                            .font(.system(size: 16))
                        Text(d.myClaimStatus == "pending"
                             ? "你的申请正在审核中，通过后补码与分享码将一起解锁。"
                             : "该橱窗的分享码需申请解锁，通过上方申请后即可查看全部补码。")
                            .font(.system(size: 13))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .foregroundColor(.appMutedFg)
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.appBackground)
                    .cornerRadius(3)
                    .overlay(RoundedRectangle(cornerRadius: 3).stroke(Color.appBorder, style: StrokeStyle(lineWidth: 1, dash: [6])))
                    .padding(.top, 12)
                }
                .padding(16)
                .background(Color.appCard)
                .cornerRadius(4)
                .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color.appBorder, lineWidth: 1))
                .padding(.top, 24)
            } else if d.isMine == true || !c.items.isEmpty {
                VStack(alignment: .leading, spacing: 0) {
                    HStack(spacing: 6) {
                        Image(systemName: "ticket").font(.system(size: 16)).foregroundColor(.appPrimary)
                        Text("补码区").font(.system(size: 14, weight: .medium)).foregroundColor(.appForeground)
                        if !c.items.isEmpty {
                            Text("· \(c.items.count) 个码").font(.system(size: 12)).foregroundColor(.appMutedFg)
                        }
                    }
                    ForEach(Array(c.items.reversed().enumerated()), id: \.element.id) { idx, item in
                        HStack(spacing: 12) {
                            Text(idx == 0 ? "最新" : "#\(c.items.count - idx)")
                                .font(.system(size: 11))
                                .foregroundColor(.appMutedFg)
                                .padding(.horizontal, 8).padding(.vertical, 2)
                                .background(Color.appSecondary)
                                .clipShape(Capsule())
                                .fixedSize()
                            Text(item.code)
                                .font(.system(size: 14, weight: .semibold, design: .monospaced))
                                .foregroundColor(.appForeground)
                                .lineLimit(2)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            Button {
                                UIPasteboard.general.string = item.code
                                ToastCenter.shared.success("已复制")
                            } label: {
                                Image(systemName: "doc.on.doc").font(.system(size: 16)).foregroundColor(.appMutedFg)
                            }
                            .buttonStyle(.plain)
                            if d.isMine == true {
                                Button { Task { await deleteCode(item.id) } } label: {
                                    Image(systemName: "trash").font(.system(size: 16)).foregroundColor(.appMutedFg)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal, 12).padding(.vertical, 10)
                        .background(Color.appBackground)
                        .cornerRadius(3)
                        .overlay(RoundedRectangle(cornerRadius: 3).stroke(Color.appBorder.opacity(0.7), lineWidth: 1))
                        .padding(.top, 8)
                    }
                    if d.isMine == true {
                        HStack(spacing: 8) {
                            TextField("粘贴新的分享码", text: $newCode)
                                .font(.system(size: 14, design: .monospaced))
                                .padding(.horizontal, 12)
                                .frame(height: 36)
                                .overlay(RoundedRectangle(cornerRadius: 2).stroke(Color.appInput, lineWidth: 1))
                            Button { Task { await addCode() } } label: {
                                HStack(spacing: 4) {
                                    Image(systemName: "plus").font(.system(size: 16))
                                    Text("补码").font(.system(size: 14, weight: .medium))
                                }
                                .foregroundColor(.appPrimaryFg)
                                .padding(.horizontal, 16).frame(height: 36)
                                .background(Color.appPrimary.opacity(newCode.trimmingCharacters(in: .whitespaces).isEmpty ? 0.5 : 1))
                                .clipShape(Capsule())
                            }
                            .buttonStyle(.plain)
                            .disabled(newCode.trimmingCharacters(in: .whitespaces).isEmpty || busy)
                        }
                        .padding(.top, 12)
                        Text("补码后，点过「我想要」和「没有了」的用户会收到站内信 + 邮件通知。")
                            .font(.system(size: 11)).lineSpacing(5).foregroundColor(.appMutedFg)
                            .padding(.top, 8)
                    }
                }
                .padding(16)
                .background(Color.appCard)
                .cornerRadius(4)
                .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color.appBorder, lineWidth: 1))
                .padding(.top, 24)
            }
        }
    }

    // MARK: 收到的地址（仅本人 + 外部无料，默认折叠）
    @ViewBuilder
    private func addressSection(_ d: ShowcaseDetailData) -> some View {
        if d.isMine == true, d.platform == "external" {
            VStack(alignment: .leading, spacing: 0) {
                Button { withAnimation { addressExpanded.toggle() } } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "mappin").font(.system(size: 16)).foregroundColor(.appPrimary)
                        Text("收到的地址").font(.system(size: 14, weight: .medium)).foregroundColor(.appForeground)
                        Text("\(addresses?.items?.count ?? 0) 条")
                            .font(.system(size: 11))
                            .foregroundColor(.appMutedFg)
                            .padding(.horizontal, 8).padding(.vertical, 2)
                            .background(Color.appSecondary)
                            .clipShape(Capsule())
                        Spacer()
                        Image(systemName: "chevron.down")
                            .font(.system(size: 16))
                            .foregroundColor(.appMutedFg)
                            .rotationEffect(.degrees(addressExpanded ? 180 : 0))
                    }
                    .padding(.horizontal, 16).padding(.vertical, 12)
                }
                .buttonStyle(.plain)
                if addressExpanded {
                    let items = addresses?.items ?? []
                    if items.isEmpty {
                        Text("还没有人发送地址")
                            .font(.system(size: 12))
                            .foregroundColor(.appMutedFg)
                            .padding(.horizontal, 16).padding(.bottom, 12)
                    } else {
                        ForEach(items) { it in
                            VStack(alignment: .leading, spacing: 4) {
                                Text(it.nickname)
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundColor(.appForeground)
                                Text(it.full ?? "\(it.address) \(it.phone)")
                                    .font(.system(size: 12))
                                    .foregroundColor(.appMutedFg)
                                if let t = it.createdAt {
                                    Text(DateFmt.short(t))
                                        .font(.system(size: 10))
                                        .foregroundColor(.appMutedFg)
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 16).padding(.vertical, 10)
                            .overlay(Rectangle().fill(Color.appBorder.opacity(0.6)).frame(height: 1).padding(.horizontal, 16),
                                     alignment: .top)
                        }
                    }
                }
            }
            .background(Color.appCard)
            .cornerRadius(4)
            .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color.appBorder, lineWidth: 1))
            .padding(.top, 24)
        }
    }

    // MARK: 返图（mt-40，h2 + 两列方图）
    @ViewBuilder
    private func repostSection(_ d: ShowcaseDetailData) -> some View {
        if !reposts.isEmpty {
            VStack(alignment: .leading, spacing: 16) {
                (Text("返图")
                    .font(.system(size: 18, weight: .bold))
                    .tracking(-0.45)
                    .foregroundColor(.appForeground)
                 + Text(" \(reposts.count) 位同好晒出了实物")
                    .font(.system(size: 14))
                    .foregroundColor(.appMutedFg))
                LazyVGrid(columns: [GridItem(.flexible(), spacing: 16), GridItem(.flexible(), spacing: 16)], spacing: 16) {
                    ForEach(reposts) { r in
                        VStack(alignment: .leading, spacing: 6) {
                            AppImage(path: r.image, contentMode: .fill)
                                .aspectRatio(1, contentMode: .fill)
                                .frame(maxWidth: .infinity)
                                .clipped()
                                .cornerRadius(4)
                                .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color.appBorder.opacity(0.6), lineWidth: 1))
                            HStack(alignment: .top, spacing: 8) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(r.userName ?? "匿名用户")
                                        .font(.system(size: 12, weight: .medium))
                                        .foregroundColor(.appForeground)
                                        .lineLimit(1)
                                    if let cm = r.comment, !cm.isEmpty {
                                        Text(cm)
                                            .font(.system(size: 12))
                                            .lineSpacing(4)
                                            .foregroundColor(.appMutedFg)
                                            .lineLimit(2)
                                    }
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                if canDeleteRepost(r, d) {
                                    Button { Task { await deleteRepost(r.id) } } label: {
                                        Image(systemName: "trash").font(.system(size: 14)).foregroundColor(.appMutedFg)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(.horizontal, 2)
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, 40)
        }
    }

    private func canDeleteRepost(_ r: RepostRow, _ d: ShowcaseDetailData) -> Bool {
        d.isMine == true || r.userId == authManager.currentUser?.id
    }

    // MARK: 相关橱窗（mt-48，两列 ShowcaseCard）
    @ViewBuilder
    private func relatedSection(_ d: ShowcaseDetailData) -> some View {
        if let related = d.related, !related.isEmpty {
            VStack(alignment: .leading, spacing: 16) {
                Text("相关橱窗")
                    .font(.system(size: 18, weight: .bold))
                    .tracking(-0.45)
                    .foregroundColor(.appForeground)
                LazyVGrid(columns: [GridItem(.flexible(), spacing: 20), GridItem(.flexible(), spacing: 20)], spacing: 20) {
                    ForEach(related.prefix(6)) { item in
                        NavigationLink(destination: ShowcaseDetailView(showcaseId: item.id)) {
                            ShowcaseCardView(item: item)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, 48)
        }
    }

    // 隐藏导航：私信发布人
    private var dmAuthorLink: some View {
        NavigationLink(destination: DmThreadView(peerId: detail?.author?.id ?? 0,
                                                 peerName: detail?.author?.name ?? ""),
                       isActive: $showDmAuthor) { EmptyView() }
            .hidden()
    }

    // MARK: 数据与操作
    private func load() async {
        loading = true
        defer { loading = false }
        do {
            let d = try await MashanglingAPI.shared.showcase.byId(id: showcaseId)
            detail = d
            liked = d.likedByMe ?? false
            likeCount = d.likeCount ?? 0
            claimedByMe = d.claimedByMe ?? false
            await loadReposts()
            if authManager.isAuthenticated {
                bookmarked = (try? await MashanglingAPI.shared.bookmark.mineFor(showcaseIds: [showcaseId]).contains(showcaseId)) ?? false
                requested = (try? await MashanglingAPI.shared.request.mineFor(showcaseId: showcaseId)) ?? false
                markedSoldout = (try? await MashanglingAPI.shared.soldout.mineFor(showcaseId: showcaseId)) ?? false
                codes = try? await MashanglingAPI.shared.code.list(showcaseId: showcaseId)
            }
            await loadAddresses()
        } catch {
            detail = nil
        }
    }

    private func loadReposts() async {
        reposts = (try? await MashanglingAPI.shared.repost.list(showcaseId: showcaseId)) ?? []
    }

    private func toggleLike() async {
        guard authManager.isAuthenticated else { showLogin = true; return }
        do {
            let now = try await MashanglingAPI.shared.interaction.toggleLike(showcaseId: showcaseId)
            liked = now
            likeCount += now ? 1 : -1
        } catch { ToastCenter.shared.error(error.localizedDescription) }
    }

    private func toggleClaim() async {
        guard authManager.isAuthenticated else { showLogin = true; return }
        do {
            let now = try await MashanglingAPI.shared.interaction.toggleClaim(showcaseId: showcaseId)
            claimedByMe = now
            ToastCenter.shared.success(now ? "已标记「我领到了」" : "已取消标记")
        } catch { ToastCenter.shared.error(error.localizedDescription) }
    }

    private func toggleBookmark() async {
        guard authManager.isAuthenticated else { showLogin = true; return }
        do {
            let now = try await MashanglingAPI.shared.bookmark.toggle(showcaseId: showcaseId)
            bookmarked = now
            ToastCenter.shared.success(now ? "已加入清单" : "已移出清单")
        } catch { ToastCenter.shared.error(error.localizedDescription) }
    }

    private func wantIt() async {
        guard authManager.isAuthenticated else { showLogin = true; return }
        guard !requested else { ToastCenter.shared.show("已经点过「我想要」啦"); return }
        do {
            _ = try await MashanglingAPI.shared.request.create(showcaseId: showcaseId)
            requested = true
            ToastCenter.shared.success("已告诉发布人「我想要」")
        } catch { ToastCenter.shared.error(error.localizedDescription) }
    }

    private func markSoldout() async {
        guard authManager.isAuthenticated else { showLogin = true; return }
        do {
            _ = try await MashanglingAPI.shared.soldout.mark(showcaseId: showcaseId)
            markedSoldout = true
            ToastCenter.shared.success("已提醒发布人补货")
        } catch { ToastCenter.shared.error(error.localizedDescription) }
    }

    private func shareLink() async {
        let link = "\(SiteConfig.baseURL)/showcase/\(showcaseId)"
        UIPasteboard.general.string = link
        ToastCenter.shared.success("链接已复制")
        _ = try? await MashanglingAPI.shared.share.mark(showcaseId: showcaseId, channel: "copy")
    }

    @MainActor
    private func makeShareCard() async {
        guard let d = detail else { return }
        ToastCenter.shared.show("正在生成分享卡片…")
        let cover = await CoverLoader.load(d.coverImage)
        let theme = try? await MashanglingAPI.shared.card.themeOf(userId: d.author?.id ?? 0)
        let canvas = ShareCardCanvas(
            title: d.title,
            cover: cover,
            platformLabel: PlatformLabel.of(d.platform),
            authorName: d.author?.name ?? "",
            tags: (d.tags ?? []).map { $0.name },
            theme: theme?.theme?.config
        )
        if let img = ViewSnapshot.image(of: canvas,
                                        size: CGSize(width: ShareCardCanvas.designW, height: ShareCardCanvas.designH)) {
            shareImage = ShareImageItem(image: img)
            _ = try? await MashanglingAPI.shared.share.mark(showcaseId: showcaseId, channel: "card")
        } else {
            ToastCenter.shared.error("生成失败")
        }
    }

    private func loadAddresses() async {
        guard let d = detail, d.isMine == true, d.platform == "external" else { addresses = nil; return }
        addresses = try? await MashanglingAPI.shared.address.received(showcaseId: showcaseId)
    }

    private func addCode() async {
        let c = newCode.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !c.isEmpty else { return }
        busy = true
        defer { busy = false }
        do {
            let n = try await MashanglingAPI.shared.code.add(showcaseId: showcaseId, code: c)
            newCode = ""
            ToastCenter.shared.success(n > 0 ? "补码成功，已通知 \(n) 人" : "补码成功")
            codes = try? await MashanglingAPI.shared.code.list(showcaseId: showcaseId)
        } catch { ToastCenter.shared.error(error.localizedDescription) }
    }

    private func deleteCode(_ id: Int) async {
        do {
            _ = try await MashanglingAPI.shared.code.remove(id: id)
            codes = try? await MashanglingAPI.shared.code.list(showcaseId: showcaseId)
            ToastCenter.shared.success("已删除")
        } catch { ToastCenter.shared.error(error.localizedDescription) }
    }

    private func deleteRepost(_ id: Int) async {
        do {
            _ = try await MashanglingAPI.shared.repost.remove(id: id)
            ToastCenter.shared.success("返图已删除")
            await loadReposts()
        } catch { ToastCenter.shared.error(error.localizedDescription) }
    }

    /// 限量即领 / 积分解锁：与网页一致，直接调 claim.create
    private func unlockClaim() async {
        guard authManager.isAuthenticated else { showLogin = true; return }
        busy = true
        defer { busy = false }
        do {
            _ = try await MashanglingAPI.shared.claim.create(showcaseId: showcaseId)
            ToastCenter.shared.success("领取成功")
            await load()
        } catch { ToastCenter.shared.error(error.localizedDescription) }
    }

    private func removeShowcase() async {
        busy = true
        defer { busy = false }
        do {
            _ = try await MashanglingAPI.shared.showcase.remove(id: showcaseId)
            ToastCenter.shared.success("橱窗已删除")
            dismiss()
        } catch { ToastCenter.shared.error(error.localizedDescription) }
    }
}

// MARK: - 领取弹窗（申请 / 凭证 / 积分解锁）
struct ClaimSheet: View {
    let detail: ShowcaseDetailData
    var onDone: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var note = ""
    @State private var credential: UIImage? = nil
    @State private var showPicker = false
    @State private var busy = false

    private var isPoints: Bool { detail.claimMode == "points" }
    private var needCredential: Bool { detail.claimMode == "request" }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 14) {
                Text(isPoints ? "将消耗 \(detail.pointCost ?? 0) 积分解锁无料码。" : "填写领取申请，发布人审核通过后会通知你。")
                    .font(.system(size: 12))
                    .foregroundColor(.appMutedFg)

                TextField("备注（给发布人的话，可选）…", text: $note, axis: .vertical)
                    .font(.system(size: 14))
                    .lineLimit(2...4)
                    .padding(10)
                    .background(Color.appInput)
                    .clipShape(RoundedRectangle(cornerRadius: 8))

                if needCredential {
                    Button { showPicker = true } label: {
                        HStack(spacing: 8) {
                            if let img = credential {
                                Image(uiImage: img)
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .frame(width: 44, height: 44)
                                    .clipped()
                                    .cornerRadius(8)
                                Text("已选择凭证图，点按更换")
                            } else {
                                Image(systemName: "photo.badge.plus")
                                Text("上传领取凭证（如关注截图，可选）")
                            }
                        }
                        .font(.system(size: 12))
                        .foregroundColor(.appMutedFg)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(10)
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.appBorder, style: StrokeStyle(lineWidth: 1, dash: [5])))
                    }
                    .buttonStyle(.plain)
                }

                Button { Task { await submit() } } label: {
                    Text(busy ? "提交中…" : (isPoints ? "确认解锁" : "提交申请"))
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.appPrimaryFg)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 11)
                        .background(Color.appPrimary)
                        .clipShape(Capsule())
                }
                .disabled(busy)
                Spacer()
            }
            .padding(20)
            .background(Color.appBackground)
            .navigationTitle(isPoints ? "积分解锁" : "申请领取")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("关闭") { dismiss() }
                        .font(.system(size: 13))
                        .foregroundColor(.appMutedFg)
                }
            }
            .sheet(isPresented: $showPicker) { ImagePicker(image: $credential) }
        }
        .presentationDetents([.medium])
    }

    private func submit() async {
        busy = true
        defer { busy = false }
        do {
            var dataURL: String? = nil
            if let img = credential {
                dataURL = ImageCodec.coverDataURL(from: img)
            }
            _ = try await MashanglingAPI.shared.claim.create(
                showcaseId: detail.id, note: note.trimmingCharacters(in: .whitespaces),
                credentialImage: dataURL)
            ToastCenter.shared.success(isPoints ? "解锁成功，无料码已可见" : "申请已提交，等待发布人审核")
            dismiss()
            onDone()
        } catch {
            ToastCenter.shared.error(error.localizedDescription)
        }
    }
}

// MARK: - 返图弹窗
struct RepostSheet: View {
    let showcaseId: Int
    var onDone: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var image: UIImage? = nil
    @State private var comment = ""
    @State private var showPicker = false
    @State private var busy = false

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 14) {
                Button { showPicker = true } label: {
                    if let img = image {
                        Image(uiImage: img)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(maxWidth: .infinity, maxHeight: 220)
                            .cornerRadius(10)
                    } else {
                        VStack(spacing: 8) {
                            Image(systemName: "photo.badge.plus").font(.system(size: 28))
                            Text("选择返图照片").font(.system(size: 13))
                        }
                        .foregroundColor(.appMutedFg)
                        .frame(maxWidth: .infinity, minHeight: 160)
                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.appBorder, style: StrokeStyle(lineWidth: 1, dash: [6])))
                    }
                }
                .buttonStyle(.plain)

                TextField("说点什么（可选）…", text: $comment, axis: .vertical)
                    .font(.system(size: 14))
                    .lineLimit(2...4)
                    .padding(10)
                    .background(Color.appInput)
                    .clipShape(RoundedRectangle(cornerRadius: 8))

                Button { Task { await submit() } } label: {
                    Text(busy ? "发布中…" : "发布返图")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.appPrimaryFg)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 11)
                        .background(Color.appPrimary)
                        .clipShape(Capsule())
                }
                .disabled(image == nil || busy)
                Spacer()
            }
            .padding(20)
            .background(Color.appBackground)
            .navigationTitle("发布返图")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("关闭") { dismiss() }
                        .font(.system(size: 13))
                        .foregroundColor(.appMutedFg)
                }
            }
            .sheet(isPresented: $showPicker) { ImagePicker(image: $image) }
        }
        .presentationDetents([.large])
    }

    private func submit() async {
        guard let img = image, let dataURL = ImageCodec.coverDataURL(from: img) else {
            ToastCenter.shared.error("图片处理失败"); return
        }
        busy = true
        defer { busy = false }
        do {
            _ = try await MashanglingAPI.shared.repost.create(
                showcaseId: showcaseId, image: dataURL,
                comment: comment.trimmingCharacters(in: .whitespaces))
            ToastCenter.shared.success("返图已发布")
            dismiss()
            onDone()
        } catch { ToastCenter.shared.error(error.localizedDescription) }
    }
}

// MARK: - 发送地址弹窗（领取外部无料后）
struct AddressPickSheet: View {
    let showcaseId: Int
    var onDone: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var entries: [AddressData.AddressEntry] = []
    @State private var selected: Int = 0
    @State private var busy = false
    @State private var loading = true

    var body: some View {
        NavigationStack {
            Group {
                if loading {
                    LoadingView()
                } else if entries.isEmpty {
                    VStack(spacing: 12) {
                        Text("还没有收货地址")
                            .font(.system(size: 14))
                            .foregroundColor(.appForeground)
                        Text("请先到「设置 → 收货地址」里添加")
                            .font(.system(size: 12))
                            .foregroundColor(.appMutedFg)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    VStack(spacing: 10) {
                        ForEach(Array(entries.enumerated()), id: \.element.id) { idx, e in
                            Button { selected = idx } label: {
                                HStack(alignment: .top, spacing: 8) {
                                    Image(systemName: selected == idx ? "checkmark.circle.fill" : "circle")
                                        .foregroundColor(selected == idx ? .appPrimary : .appMutedFg)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("\(e.nickname)  \(e.phone)")
                                            .font(.system(size: 13, weight: .medium))
                                            .foregroundColor(.appForeground)
                                        Text(e.address)
                                            .font(.system(size: 12))
                                            .foregroundColor(.appMutedFg)
                                    }
                                    Spacer()
                                }
                                .padding(12)
                                .background(Color.appCard)
                                .cornerRadius(10)
                                .overlay(RoundedRectangle(cornerRadius: 10).stroke(selected == idx ? Color.appPrimary : Color.appBorder, lineWidth: 1))
                            }
                            .buttonStyle(.plain)
                        }
                        Button { Task { await send() } } label: {
                            Text(busy ? "发送中…" : "发送给发布人")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.appPrimaryFg)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 11)
                                .background(Color.appPrimary)
                                .clipShape(Capsule())
                        }
                        .disabled(busy)
                    }
                    .padding(16)
                }
            }
            .background(Color.appBackground)
            .navigationTitle("发送收货地址")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("关闭") { dismiss() }
                        .font(.system(size: 13))
                        .foregroundColor(.appMutedFg)
                }
            }
        }
        .presentationDetents([.medium])
        .task {
            entries = (try? await MashanglingAPI.shared.address.get().entries) ?? []
            loading = false
        }
    }

    private func send() async {
        busy = true
        defer { busy = false }
        do {
            _ = try await MashanglingAPI.shared.address.send(showcaseId: showcaseId, addressIndex: selected)
            ToastCenter.shared.success("地址已发送给发布人")
            dismiss()
            onDone()
        } catch { ToastCenter.shared.error(error.localizedDescription) }
    }
}

// MARK: - 礼物分享弹窗（送给互关好友）
struct GiftShareSheet: View {
    let showcaseId: Int

    @Environment(\.dismiss) private var dismiss
    @State private var friends: [FollowUser] = []
    @State private var loading = true
    @State private var busy = false

    var body: some View {
        NavigationStack {
            Group {
                if loading {
                    LoadingView()
                } else if friends.isEmpty {
                    Text("还没有互关好友，先去关注别人吧")
                        .font(.system(size: 13))
                        .foregroundColor(.appMutedFg)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List(friends) { f in
                        HStack(spacing: 10) {
                            AvatarView(path: f.avatar, name: f.name ?? "", size: 36)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(f.name ?? "").font(.system(size: 14, weight: .medium))
                                if let bio = f.bio, !bio.isEmpty {
                                    Text(bio).font(.system(size: 11)).foregroundColor(.appMutedFg).lineLimit(1)
                                }
                            }
                            Spacer()
                            Button { Task { await send(to: f.userId) } } label: {
                                Text("送给TA")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(.appPrimaryFg)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(Color.appPrimary)
                                    .clipShape(Capsule())
                            }
                            .disabled(busy)
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .background(Color.appBackground)
            .navigationTitle("作为礼物送出")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("关闭") { dismiss() }
                        .font(.system(size: 13))
                        .foregroundColor(.appMutedFg)
                }
            }
        }
        .presentationDetents([.medium, .large])
        .task {
            friends = (try? await MashanglingAPI.shared.follow.mutuals()) ?? []
            loading = false
        }
    }

    private func send(to userId: Int) async {
        busy = true
        defer { busy = false }
        do {
            let lv = try await MashanglingAPI.shared.gift.share(showcaseId: showcaseId, toUserId: userId)
            ToastCenter.shared.success("礼物已送出，当前好感等级 Lv.\(lv)")
            dismiss()
        } catch { ToastCenter.shared.error(error.localizedDescription) }
    }
}
