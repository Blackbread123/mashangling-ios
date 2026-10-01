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
    @State private var showClaimSheet = false
    @State private var claimCredentialMode = false
    @State private var showRepostSheet = false
    @State private var showAddressSheet = false
    @State private var showGiftSheet = false
    @State private var showFriendShare = false
    @State private var showEdit = false
    @State private var shareImage: ShareImageItem? = nil
    @State private var shareBusy = false
    @State private var addresses: ReceivedAddresses? = nil
    @State private var addressExpanded = false
    @State private var csvShare: CSVShareItem? = nil
    @State private var newCode = ""
    @State private var showDeleteConfirm = false
    @State private var showDmAuthor = false
    @State private var copiedMain = false
    @State private var copiedCodeId: Int? = nil
    @State private var repostViewer: ViewerItem? = nil
    @State private var repostDelete: RepostRow? = nil
    @State private var repostReport: IntItem? = nil

    struct ShareImageItem: Identifiable {
        let id = UUID()
        let image: UIImage
    }
    struct CSVShareItem: Identifiable {
        let id = UUID()
        let url: URL
    }
    struct ViewerItem: Identifiable {
        let id = UUID()
        let path: String
    }
    struct IntItem: Identifiable {
        let id: Int
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
        .task { await load() }
        .refreshable { await load() }
        .sheet(isPresented: $showLogin) { LoginView() }
        .sheet(isPresented: $showReport) { ReportSheet(targetType: "showcase", targetId: showcaseId) }
        .sheet(item: $repostReport) { item in ReportSheet(targetType: "repost", targetId: item.id) }
        .sheet(isPresented: $showClaimSheet) {
            if let d = detail { ClaimSheet(detail: d, credential: claimCredentialMode) { Task { await load() } } }
        }
        .sheet(isPresented: $showRepostSheet) {
            RepostSheet(showcaseId: showcaseId) { Task { await loadReposts() } }
        }
        .sheet(isPresented: $showAddressSheet) {
            AddressPickSheet(showcaseId: showcaseId) { Task { await load() } }
        }
        .sheet(isPresented: $showGiftSheet) {
            GiftShareSheet(showcaseId: showcaseId)
        }
        .sheet(isPresented: $showFriendShare) {
            ShareToFriendsSheet(showcaseId: showcaseId)
        }
        .sheet(isPresented: $showEdit) {
            if let d = detail { PublishView(editing: d) }
        }
        .sheet(item: $shareImage) { item in
            ShareSheet(items: [item.image])
        }
        .sheet(item: $csvShare) { item in
            ShareSheet(items: [item.url])
        }
        .fullScreenCover(item: $repostViewer) { item in
            ImageViewerCover(path: item.path)
        }
        .confirmationDialog("删除这个橱窗？", isPresented: $showDeleteConfirm, titleVisibility: .visible) {
            Button("确认删除", role: .destructive) { Task { await removeShowcase() } }
            Button("取消", role: .cancel) {}
        } message: {
            Text("删除后其他用户将无法再看到这个橱窗和它的柔造码。")
        }
        .confirmationDialog("删除这张返图？", isPresented: Binding(
            get: { repostDelete != nil },
            set: { if !$0 { repostDelete = nil } }
        ), titleVisibility: .visible) {
            Button("确认删除", role: .destructive) {
                if let r = repostDelete { Task { await deleteRepost(r.id) } }
            }
            Button("取消", role: .cancel) {}
        } message: {
            Text("删除后无法恢复。")
        }
    }

    // MARK: 主体（对应网页 ShowcaseDetail.tsx：封面自然比例 → 标题/作者/标签/简介/码区/操作栏）
    private func content(_ d: ShowcaseDetailData) -> some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 0) {
                // 封面：rounded-2xl(5px) + 1px border-border/60，自然比例
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
                .padding(.top, 32) // 网页 grid gap-8

                codeSection(d)    // 补码区 mt-6
                addressSection(d) // 收到的地址 mt-6（仅本人+外部无料）
                repostSection(d)  // 返图 mt-10
                relatedSection(d) // 相关橱窗 mt-12
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

    // MARK: 作者行（mt-2：来自 X 的橱窗 + Lv.N + 头衔）
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

    // MARK: 标签行（mt-3，胶囊 4/12 padding，名字 + ·分类）
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

    // 分隔线块：border-t + pt-2 + mt-2
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
                    copiedMain = true
                    ToastCenter.shared.success("无料码已复制，去对应平台粘贴领取吧")
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) { copiedMain = false }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: copiedMain ? "checkmark" : "doc.on.doc").font(.system(size: 16))
                        Text(copiedMain ? "已复制" : "一键复制").font(.system(size: 14, weight: .medium))
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
                    let color: Color = d.isFullyClaimed == true ? .fixRed500 : .twEmerald600
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
            if let gift = d.myGift {
                giftBlock(d, gift: gift)
            }
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

    // 礼物领取块（brand-300 边框 + brand-50/60 底 + brand-500 按钮）
    private func giftBlock(_ d: ShowcaseDetailData, gift: ShowcaseDetailData.GiftRef) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 8) {
                Image(systemName: "gift").font(.system(size: 16)).foregroundColor(.appBrand500)
                Text("\(gift.fromName) 把这份无料作为礼物送给了你")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.appForeground)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Text("礼物可跳过审批直接领取，仍占用限量名额" + (d.platform == "external" ? "；地址填写时限不变" : "") + "。")
                .font(.system(size: 11))
                .lineSpacing(5)
                .foregroundColor(.appMutedFg)
                .padding(.top, 4)
            Button { Task { await claimGift(gift.id) } } label: {
                HStack(spacing: 4) {
                    Image(systemName: "gift").font(.system(size: 16))
                    Text(d.isFullyClaimed == true ? "已领完" : (busy ? "领取中…" : "领取礼物"))
                        .font(.system(size: 14, weight: .medium))
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 36)
                .background(Color.appBrand500)
                .clipShape(Capsule())
                .opacity(d.isFullyClaimed == true ? 0.6 : 1)
            }
            .buttonStyle(.plain)
            .disabled(busy || d.isFullyClaimed == true)
            .padding(.top, 10)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.appBrand50.opacity(0.6))
        .cornerRadius(4)
        .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color.appBrand300, lineWidth: 1))
        .padding(.bottom, 12)
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

    // 「…也可以私信发布人沟通。」注释行
    private func dmNote(_ prefix: String, _ d: ShowcaseDetailData) -> some View {
        (Text(prefix) +
         Text("私信发布人").foregroundColor(.appPrimary) +
         Text("沟通。"))
            .font(.system(size: 11)).lineSpacing(5).foregroundColor(.appMutedFg)
            .padding(.top, 8)
            .onTapGesture {
                guard authManager.isAuthenticated else { showLogin = true; return }
                showDmAuthor = true
            }
    }

    // 包邮/不包邮徽标（对应网页 ShippingFreeBadge）
    @ViewBuilder
    private func shippingFreeBadge(_ free: Bool?) -> some View {
        if let free = free {
            Text(free
                 ? "包邮 · 发送地址后无需任何操作，坐等收货"
                 : "不包邮 · 发布者下单后会通过站内信和邮件通知你补邮，并需上传支付宝转账凭证，请留意")
                .font(.system(size: 11, weight: .semibold))
                .lineSpacing(3)
                .multilineTextAlignment(.center)
                .foregroundColor(free ? .fixEmerald700 : .fixAmber700)
                .padding(.horizontal, 12).padding(.vertical, 6)
                .frame(maxWidth: .infinity)
                .background(free ? Color.fixEmerald100 : Color.fixAmber100)
                .cornerRadius(3)
                .overlay(RoundedRectangle(cornerRadius: 3)
                    .stroke(free ? Color.fixEmerald300 : Color.fixAmber300, lineWidth: 1))
        }
    }

    // 地址区（approved / 已领完 / 外部无料共用，对应网页 addressEligible 块）
    @ViewBuilder
    private func addressBlock(_ d: ShowcaseDetailData) -> some View {
        if d.addressEligible == true {
            if d.addressDeadlineExpired == true {
                VStack(spacing: 0) {
                    disabledPill(icon: "mappin", label: "已超时 · 地址填写已截止")
                    Text("发布者限定的填写时间截止至 \(d.addressDeadlineText ?? "")")
                        .font(.system(size: 11))
                        .foregroundColor(.appMutedFg)
                        .frame(maxWidth: .infinity)
                        .multilineTextAlignment(.center)
                        .padding(.top, 6)
                }
                .padding(.top, 12)
            } else {
                VStack(spacing: 0) {
                    shippingFreeBadge(d.shippingFree)
                    Button {
                        guard authManager.isAuthenticated else { showLogin = true; return }
                        showAddressSheet = true
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "mappin").font(.system(size: 16))
                            Text(d.addressSentByMe == true ? "地址已发送 ✓" : "发送地址给发布者")
                                .font(.system(size: 14, weight: .medium))
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 36)
                        .background(Color.twAmber500)
                        .clipShape(Capsule())
                        .opacity(d.addressSentByMe == true ? 0.6 : 1)
                    }
                    .buttonStyle(.plain)
                    .disabled(d.addressSentByMe == true)
                    .padding(.top, 12)
                    if let t = d.addressDeadlineText {
                        Text("请在 \(t) 前发送地址")
                            .font(.system(size: 11))
                            .foregroundColor(.appMutedFg)
                            .frame(maxWidth: .infinity)
                            .multilineTextAlignment(.center)
                            .padding(.top, 6)
                    }
                }
                .padding(.top, d.shippingFree != nil ? 0 : 12)
            }
        }
    }

    @ViewBuilder
    private func lockBody(_ d: ShowcaseDetailData) -> some View {
        let st = d.myClaimStatus
        if st == "approved" {
            VStack(alignment: .leading, spacing: 0) {
                limitedNotice().padding(.bottom, 12)
                disabledPill(icon: "checkmark", label: "已领取 ✓")
                dmNote("该无料没有平台码，发布人会与你联系发放；也可以主动", d)
                addressBlock(d)
            }
        } else if d.isFullyClaimed == true {
            VStack(alignment: .leading, spacing: 0) {
                disabledPill(icon: "xmark.circle", label: "已领完")
                Text("该橱窗限量 \(d.quantity ?? 0) 份，已全部领完。")
                    .font(.system(size: 11)).lineSpacing(5).foregroundColor(.appMutedFg)
                    .padding(.top, 8)
                addressBlock(d)
            }
        } else if d.claimMode == "points" {
            VStack(alignment: .leading, spacing: 0) {
                fullPill(icon: "centsign.circle", label: busy ? "解锁中…" : "支付 \(d.pointCost ?? 0) 积分解锁",
                         bg: .twAmber500, fg: .white, enabled: !busy) {
                    guard authManager.isAuthenticated else { showLogin = true; return }
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
                fullPill(icon: "shippingbox", label: busy ? "领取中…" : "领取",
                         bg: .appPrimary, fg: .appPrimaryFg, enabled: !busy) {
                    guard authManager.isAuthenticated else { showLogin = true; return }
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
        } else if st == "rejected" {
            rejectedBody(d)
        } else {
            let credential = (d.quantity != nil && d.claimMode == "request") || d.codeVisibility == "credential"
            VStack(alignment: .leading, spacing: 0) {
                fullPill(icon: "lock", label: "申请领取", bg: .appPrimary, fg: .appPrimaryFg) {
                    guard authManager.isAuthenticated else {
                        ToastCenter.info("登录后即可申请领取")
                        showLogin = true
                        return
                    }
                    claimCredentialMode = credential
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

    // 申请被拒：24 小时后可重新申请（对应网页 rejected 分支）
    @ViewBuilder
    private func rejectedBody(_ d: ShowcaseDetailData) -> some View {
        let retryAt = DateFmt.parse(d.myClaimResolvedAt)?.addingTimeInterval(24 * 60 * 60)
        let canRetry = retryAt == nil || Date() >= retryAt!
        VStack(alignment: .leading, spacing: 0) {
            if canRetry {
                fullPill(icon: "lock", label: "申请领取", bg: .appPrimary, fg: .appPrimaryFg) {
                    guard authManager.isAuthenticated else {
                        ToastCenter.info("登录后即可申请领取")
                        showLogin = true
                        return
                    }
                    claimCredentialMode = d.codeVisibility == "credential"
                    showClaimSheet = true
                }
                dmNote("上次申请未通过，已间隔一天，可以重新申请。也可以", d)
            } else {
                disabledPill(icon: "xmark.circle", label: "申请未通过")
                let hours = max(1, Int(ceil((retryAt!.timeIntervalSinceNow) / 3600.0)))
                dmNote("可在约 \(hours) 小时后重新申请；如有疑问可以", d)
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
            addressBlock(d)
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

    // MARK: 操作栏（mt-5，flex-wrap gap-2 胶囊横排 + 右侧 ml-auto 编辑/删除/举报）
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
                    brd: claimedByMe ? .twEmerald600 : .appBorder,
                    active: claimedByMe) { Task { await toggleClaim() } }
            // 我想领 / 收到的想要
            if d.isMine == true {
                // 网页：跳转到自己的个人页查看收到的联系方式
                actPillLink(icon: "hand.raised",
                            label: "收到的想要" + ((d.wantCount ?? 0) > 0 ? " · \(d.wantCount ?? 0)" : ""),
                            dest: ProfileView(userId: d.author?.id ?? 0))
            } else if requested || d.isFullyClaimed == true {
                actPill(icon: "hand.raised",
                        label: d.isFullyClaimed == true ? "已领完" : "已想领 ✓",
                        tint: .appMutedFg, bg: .appSecondary, brd: .appBorder) {}
            } else {
                // 深色实心：foreground 底 + background 字
                actPill(icon: "hand.raised", label: busy ? "提交中…" : "我想领",
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
            actPill(icon: "camera", label: "返图") {
                guard authManager.isAuthenticated else { showLogin = true; return }
                showRepostSheet = true
            }
            // 分享（下拉：分享链接 / 分享图片 / 分享给好友… / 本人加「以礼物分享…」）
            shareMenu(d)
            // 没有了（外部无料不显示）
            if d.platform != "external" {
                if d.isMine == true {
                    // 网页：本人只读展示，不可点击
                    actPillStatic(icon: "nosign",
                                  label: (d.soldoutCount ?? 0) > 0 ? "\(d.soldoutCount ?? 0) 人反馈没有了" : "没有了",
                                  tint: .appMutedFg)
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
            // 右侧 ml-auto：编辑/删除（本人）+ 举报，12px MUTED
            HStack(spacing: 12) {
                if d.isMine == true {
                    Button { showEdit = true } label: { miniAct("pencil", "编辑") }
                        .buttonStyle(.plain)
                    Button { showDeleteConfirm = true } label: { miniAct("trash", "删除") }
                        .buttonStyle(.plain)
                }
                Button {
                    guard authManager.isAuthenticated else { showLogin = true; return }
                    showReport = true
                } label: { miniAct("flag", "举报") }
                    .buttonStyle(.plain)
            }
        }
        .padding(.top, 20)
    }

    // 分享下拉（对应网页 shareOpen 菜单：w-44 rounded-xl border bg-card shadow-lg）
    private func shareMenu(_ d: ShowcaseDetailData) -> some View {
        Menu {
            Button { Task { await shareLink() } } label: {
                Label("分享链接", systemImage: "link")
            }
            Button { Task { await makeShareCard() } } label: {
                Label("分享图片", systemImage: "photo.on.rectangle")
            }
            Button {
                guard authManager.isAuthenticated else { showLogin = true; return }
                showFriendShare = true
            } label: {
                Label("分享给好友…", systemImage: "person.2")
            }
            if d.isMine == true {
                Button { showGiftSheet = true } label: {
                    Label("以礼物分享…", systemImage: "gift")
                }
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "square.and.arrow.up").font(.system(size: 16))
                Text(shareBusy ? "生成中…" : "分享" + ((d.shareCount ?? 0) > 0 ? " · \(d.shareCount ?? 0)" : ""))
                    .font(.system(size: 14))
            }
            .foregroundColor(.appForeground)
            .padding(.horizontal, 16).padding(.vertical, 8)
            .background(Color.appCard)
            .clipShape(Capsule())
            .overlay(Capsule().stroke(Color.appBorder, lineWidth: 1))
            .opacity(shareBusy ? 0.6 : 1)
        }
        .disabled(shareBusy)
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
            pillBody(icon: icon, label: label, suffix: suffix, tint: tint, bg: bg, brd: brd, active: active)
        }
        .buttonStyle(.plain)
    }

    private func actPillStatic(icon: String, label: String,
                               tint: Color = .appForeground, bg: Color = .appCard,
                               brd: Color? = .appBorder) -> some View {
        pillBody(icon: icon, label: label, suffix: nil, tint: tint, bg: bg, brd: brd, active: false)
    }

    private func pillBody(icon: String, label: String, suffix: String?,
                          tint: Color, bg: Color, brd: Color?, active: Bool) -> some View {
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

    // MARK: 补码区（mt-6：锁定态 / 列表态 + 本人输入行）
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
                            Text(DateFmt.short(item.createdAt))
                                .font(.system(size: 11))
                                .foregroundColor(.appMutedFg)
                                .fixedSize()
                            Button {
                                UIPasteboard.general.string = item.code
                                copiedCodeId = item.id
                                ToastCenter.shared.success("码已复制")
                                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                                    if copiedCodeId == item.id { copiedCodeId = nil }
                                }
                            } label: {
                                Image(systemName: copiedCodeId == item.id ? "checkmark" : "doc.on.doc")
                                    .font(.system(size: 16))
                                    .foregroundColor(copiedCodeId == item.id ? .twEmerald600 : .appMutedFg)
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
                                .onChange(of: newCode) { v in
                                    if v.count > 128 { newCode = String(v.prefix(128)) }
                                }
                            Button { Task { await addCode() } } label: {
                                HStack(spacing: 4) {
                                    Image(systemName: "plus").font(.system(size: 16))
                                    Text(busy ? "提交中…" : "补码").font(.system(size: 14, weight: .medium))
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

    // MARK: 收到的地址（仅本人 + 外部无料，默认折叠；对应网页 AddressSection）
    @ViewBuilder
    private func addressSection(_ d: ShowcaseDetailData) -> some View {
        if d.isMine == true, d.platform == "external" {
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 8) {
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
                        }
                    }
                    .buttonStyle(.plain)
                    Spacer(minLength: 0)
                    if addressExpanded, let items = addresses?.items, !items.isEmpty {
                        Button { copyAllAddresses() } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "doc.on.doc").font(.system(size: 12))
                                Text("复制全部").font(.system(size: 11))
                            }
                            .foregroundColor(.appMutedFg)
                            .padding(.horizontal, 10).padding(.vertical, 4)
                            .overlay(Capsule().stroke(Color.appBorder, lineWidth: 1))
                        }
                        .buttonStyle(.plain)
                        Button { exportAddressCSV() } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "square.and.arrow.down").font(.system(size: 12))
                                Text("导出 Excel").font(.system(size: 11))
                            }
                            .foregroundColor(.appMutedFg)
                            .padding(.horizontal, 10).padding(.vertical, 4)
                            .overlay(Capsule().stroke(Color.appBorder, lineWidth: 1))
                        }
                        .buttonStyle(.plain)
                    }
                    Button { withAnimation { addressExpanded.toggle() } } label: {
                        Image(systemName: addressExpanded ? "chevron.up" : "chevron.down")
                            .font(.system(size: 16))
                            .foregroundColor(.appMutedFg)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 16).padding(.vertical, 12)
                if addressExpanded {
                    let items = addresses?.items ?? []
                    VStack(alignment: .leading, spacing: 0) {
                        Rectangle().fill(Color.appBorder.opacity(0.6)).frame(height: 1)
                        if items.isEmpty {
                            Text("还没有人发送地址——领取人解锁后会在橱窗页看到「发送地址」按钮")
                                .font(.system(size: 12))
                                .foregroundColor(.appMutedFg)
                                .frame(maxWidth: .infinity)
                                .multilineTextAlignment(.center)
                                .padding(.vertical, 16)
                        } else {
                            VStack(spacing: 8) {
                                ForEach(items) { it in
                                    HStack(spacing: 8) {
                                        Text(it.full ?? "\(it.nickname) \(it.phone) \(it.address)")
                                            .font(.system(size: 12))
                                            .lineSpacing(6)
                                            .foregroundColor(.appForeground)
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                        Button {
                                            UIPasteboard.general.string = it.full ?? "\(it.nickname) \(it.phone) \(it.address)"
                                            ToastCenter.shared.success("地址已复制")
                                        } label: {
                                            Image(systemName: "doc.on.doc")
                                                .font(.system(size: 14))
                                                .foregroundColor(.appMutedFg)
                                                .frame(width: 28, height: 28)
                                        }
                                        .buttonStyle(.plain)
                                    }
                                    .padding(.horizontal, 12).padding(.vertical, 8)
                                    .background(Color.appBackground)
                                    .cornerRadius(3)
                                    .overlay(RoundedRectangle(cornerRadius: 3).stroke(Color.appBorder.opacity(0.6), lineWidth: 1))
                                }
                            }
                            Text("每条地址格式为「昵称 手机号 地址」，可直接整段粘贴到快递单。")
                                .font(.system(size: 11))
                                .foregroundColor(.appMutedFg)
                                .padding(.top, 12)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                    .padding(.bottom, 16)
                }
            }
            .background(Color.appCard)
            .cornerRadius(4)
            .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color.appBorder, lineWidth: 1))
            .padding(.top, 24)
        }
    }

    // MARK: 返图（mt-10，h2 + 两列方图；对应网页 RepostGallery）
    @ViewBuilder
    private func repostSection(_ d: ShowcaseDetailData) -> some View {
        if !reposts.isEmpty {
            VStack(alignment: .leading, spacing: 16) {
                (Text("返图")
                    .font(.system(size: 18, weight: .bold))
                    .tracking(-0.45)
                    .foregroundColor(.appForeground)
                 + Text("  \(reposts.count) 位同好晒出了实物")
                    .font(.system(size: 14))
                    .foregroundColor(.appMutedFg))
                LazyVGrid(columns: [GridItem(.flexible(), spacing: 16), GridItem(.flexible(), spacing: 16)], spacing: 16) {
                    ForEach(reposts) { r in
                        VStack(alignment: .leading, spacing: 6) {
                            Button { repostViewer = ViewerItem(path: r.image) } label: {
                                AppImage(path: r.image, contentMode: .fill)
                                    .aspectRatio(1, contentMode: .fill)
                                    .frame(maxWidth: .infinity)
                                    .clipped()
                                    .cornerRadius(4)
                                    .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color.appBorder.opacity(0.6), lineWidth: 1))
                            }
                            .buttonStyle(.plain)
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
                                // 网页：仅返图本人或管理员可删（删除前确认）
                                if canDeleteRepost(r) {
                                    Button { repostDelete = r } label: {
                                        Image(systemName: "trash").font(.system(size: 14)).foregroundColor(.appMutedFg)
                                    }
                                    .buttonStyle(.plain)
                                }
                                // 网页：登录用户可举报他人的返图
                                if authManager.isAuthenticated, r.userId != authManager.currentUser?.id {
                                    Button { repostReport = IntItem(id: r.id) } label: {
                                        Image(systemName: "flag").font(.system(size: 12)).foregroundColor(.appMutedFg)
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

    private func canDeleteRepost(_ r: RepostRow) -> Bool {
        r.userId == authManager.currentUser?.id || authManager.currentUser?.isAdmin == true
    }

    // MARK: 相关橱窗（mt-12，两列 ShowcaseCard）
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

    /// 静默刷新详情（点赞/领到/想领/反馈后同步计数，对应网页 detail.refetch()）
    private func silentReload() async {
        if let d = try? await MashanglingAPI.shared.showcase.byId(id: showcaseId) {
            detail = d
            liked = d.likedByMe ?? false
            likeCount = d.likeCount ?? 0
            claimedByMe = d.claimedByMe ?? false
        }
    }

    private func loadReposts() async {
        reposts = (try? await MashanglingAPI.shared.repost.list(showcaseId: showcaseId)) ?? []
    }

    private func toggleLike() async {
        guard authManager.isAuthenticated else { showLogin = true; return }
        do {
            _ = try await MashanglingAPI.shared.interaction.toggleLike(showcaseId: showcaseId)
            await silentReload()
        } catch { ToastCenter.shared.error(error.localizedDescription) }
    }

    private func toggleClaim() async {
        guard authManager.isAuthenticated else { showLogin = true; return }
        do {
            _ = try await MashanglingAPI.shared.interaction.toggleClaim(showcaseId: showcaseId)
            await silentReload()
        } catch { ToastCenter.shared.error(error.localizedDescription) }
    }

    private func toggleBookmark() async {
        guard authManager.isAuthenticated else {
            ToastCenter.info("注册后可以使用清单功能，稍后领取")
            showLogin = true
            return
        }
        do {
            let now = try await MashanglingAPI.shared.bookmark.toggle(showcaseId: showcaseId)
            bookmarked = now
            ToastCenter.shared.success(now ? "已加入清单，去个人页查看" : "已移出清单")
        } catch { ToastCenter.shared.error(error.localizedDescription) }
    }

    private func wantIt() async {
        guard authManager.isAuthenticated else { showLogin = true; return }
        guard !requested else { return }
        busy = true
        defer { busy = false }
        do {
            _ = try await MashanglingAPI.shared.request.create(showcaseId: showcaseId)
            requested = true
            ToastCenter.shared.success("已想领！刷新一下页面，就能在上方一键发送收货地址给发布者")
            await silentReload()
        } catch { ToastCenter.shared.error(error.localizedDescription) }
    }

    private func markSoldout() async {
        guard authManager.isAuthenticated else { showLogin = true; return }
        do {
            let r = try await MashanglingAPI.shared.soldout.mark(showcaseId: showcaseId)
            markedSoldout = true
            ToastCenter.shared.success(r.mailed == true
                                       ? "已反馈，发布人会收到补货提醒邮件"
                                       : "已反馈，发布人会在站内看到补货提醒")
            await silentReload()
        } catch { ToastCenter.shared.error(error.localizedDescription) }
    }

    private func shareLink() async {
        guard let d = detail else { return }
        let url = "\(SiteConfig.baseURL)/showcase/\(showcaseId)"
        UIPasteboard.general.string = "【码上领】\(d.title)｜无料分享，快来领取！\n\(url)"
        ToastCenter.shared.success("分享文案和链接已复制，去微博 / QQ 粘贴吧")
        if authManager.isAuthenticated {
            _ = try? await MashanglingAPI.shared.share.mark(showcaseId: showcaseId, channel: "link")
        }
    }

    @MainActor
    private func makeShareCard() async {
        guard let d = detail, !shareBusy else { return }
        shareBusy = true
        defer { shareBusy = false }
        ToastCenter.shared.show("正在生成分享图片…")
        let cover = await CoverLoader.load(d.coverImage)
        let theme = try? await MashanglingAPI.shared.card.themeOf(userId: d.author?.id ?? 0)
        let canvas = ShareCardCanvas(
            title: d.title,
            cover: cover,
            platformLabel: PlatformLabel.of(d.platform),
            authorName: d.author?.name ?? "未知用户",
            tags: (d.tags ?? []).map { $0.name },
            theme: theme?.theme?.config
        )
        if let img = ViewSnapshot.image(of: canvas,
                                        size: CGSize(width: ShareCardCanvas.designW, height: ShareCardCanvas.designH)) {
            shareImage = ShareImageItem(image: img)
            ToastCenter.shared.success("分享图片已生成")
            if authManager.isAuthenticated {
                _ = try? await MashanglingAPI.shared.share.mark(showcaseId: showcaseId, channel: "image")
            }
        } else {
            ToastCenter.shared.error("图片生成失败，请重试")
        }
    }

    private func loadAddresses() async {
        guard let d = detail, d.isMine == true, d.platform == "external" else { addresses = nil; return }
        addresses = try? await MashanglingAPI.shared.address.received(showcaseId: showcaseId)
    }

    private func copyAllAddresses() {
        guard let items = addresses?.items, !items.isEmpty else { return }
        UIPasteboard.general.string = items.map { $0.full ?? "\($0.nickname) \($0.phone) \($0.address)" }.joined(separator: "\n")
        ToastCenter.shared.success("已复制全部 \(items.count) 条地址")
    }

    private func exportAddressCSV() {
        guard let items = addresses?.items, !items.isEmpty else { return }
        let title = addresses?.showcaseTitle ?? "橱窗"
        let esc: (String) -> String = { "\"" + $0.replacingOccurrences(of: "\"", with: "\"\"") + "\"" }
        var lines = ["\"橱窗名\",\"地址\""]
        for i in items {
            lines.append("\(esc(title)),\(esc(i.full ?? "\(i.nickname) \(i.phone) \(i.address)"))")
        }
        let csv = "\u{FEFF}" + lines.joined(separator: "\r\n")
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("\(title)-收货地址.csv")
        do {
            try csv.write(to: url, atomically: true, encoding: .utf8)
            csvShare = CSVShareItem(url: url)
            ToastCenter.shared.success("已导出，用 Excel 打开即可")
        } catch {
            ToastCenter.shared.error("导出失败")
        }
    }

    private func addCode() async {
        let c = newCode.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !c.isEmpty else { return }
        busy = true
        defer { busy = false }
        do {
            let n = try await MashanglingAPI.shared.code.add(showcaseId: showcaseId, code: c)
            newCode = ""
            ToastCenter.shared.success(n > 0 ? "补码成功，已通知 \(n) 位关注的用户" : "补码成功")
            codes = try? await MashanglingAPI.shared.code.list(showcaseId: showcaseId)
        } catch { ToastCenter.shared.error(error.localizedDescription) }
    }

    private func deleteCode(_ id: Int) async {
        do {
            _ = try await MashanglingAPI.shared.code.remove(id: id)
            codes = try? await MashanglingAPI.shared.code.list(showcaseId: showcaseId)
            ToastCenter.shared.success("已删除该补码")
        } catch { ToastCenter.shared.error(error.localizedDescription) }
    }

    private func deleteRepost(_ id: Int) async {
        do {
            _ = try await MashanglingAPI.shared.repost.remove(id: id)
            ToastCenter.shared.success("返图已删除")
            await loadReposts()
        } catch { ToastCenter.shared.error(error.localizedDescription) }
    }

    /// 领取礼物（对应网页 claimGift）
    private func claimGift(_ giftId: Int) async {
        guard authManager.isAuthenticated else { showLogin = true; return }
        busy = true
        defer { busy = false }
        do {
            _ = try await MashanglingAPI.shared.gift.claim(giftId: giftId)
            ToastCenter.shared.success("礼物领取成功！")
            await load()
        } catch { ToastCenter.shared.error(error.localizedDescription) }
    }

    /// 限量即领 / 积分解锁：与网页一致，直接调 claim.create
    private func unlockClaim() async {
        let isPoints = detail?.claimMode == "points"
        busy = true
        defer { busy = false }
        do {
            _ = try await MashanglingAPI.shared.claim.create(showcaseId: showcaseId)
            ToastCenter.shared.success(isPoints ? "解锁成功，积分已转给发布者" : "领取成功，分享码已解锁")
            await load()
        } catch {
            let msg = error.localizedDescription
            if msg.contains("积分不足") {
                ToastCenter.shared.error("\(msg)。获取积分的方式：每日签到与任务、发布橱窗或卡片、收到点赞/返图/「领到了」、分享橱窗、集满浏览量等。")
            } else {
                ToastCenter.shared.error(msg)
            }
        }
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

// MARK: - 领取申请弹窗（对应网页 ClaimDialog：申请 / 凭证两种模式）
struct ClaimSheet: View {
    let detail: ShowcaseDetailData
    /// true=凭证解锁（照片或文字至少一项）；false=普通申请
    let credential: Bool
    var onDone: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var note = ""
    @State private var credentialImage: UIImage? = nil
    @State private var showPicker = false
    @State private var busy = false

    private var canSubmit: Bool {
        credential
            ? (!note.trimmingCharacters(in: .whitespaces).isEmpty || credentialImage != nil)
            : true
    }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 14) {
                Text(credential
                     ? "请上传凭证供发布人审核：照片或文字至少提供一项。审核结果会通过站内信通知你，通过后分享码自动解锁。"
                     : "提交申请后，发布人会在站内收到通知并审核。通过后你将收到站内信，分享码自动解锁。每个橱窗只能申请一次。")
                    .font(.system(size: 12))
                    .lineSpacing(7)
                    .foregroundColor(.appMutedFg)

                TextField(credential ? "文字凭证 / 给发布人的说明（照片或文字至少一项）" : "给发布人的留言（可选）",
                          text: $note, axis: .vertical)
                    .font(.system(size: 14))
                    .lineLimit(3...6)
                    .padding(10)
                    .background(Color.appInput)
                    .clipShape(RoundedRectangle(cornerRadius: 2))
                    .onChange(of: note) { v in if v.count > 500 { note = String(v.prefix(500)) } }

                if credential {
                    if let img = credentialImage {
                        ZStack(alignment: .topTrailing) {
                            Image(uiImage: img)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(maxWidth: .infinity)
                                .frame(maxHeight: 192)
                                .clipped()
                                .cornerRadius(4)
                                .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color.appBorder, lineWidth: 1))
                            Button { credentialImage = nil } label: {
                                Image(systemName: "xmark")
                                    .font(.system(size: 14))
                                    .foregroundColor(.white)
                                    .frame(width: 28, height: 28)
                                    .background(Color.black.opacity(0.6))
                                    .clipShape(Circle())
                            }
                            .buttonStyle(.plain)
                            .padding(8)
                        }
                    } else {
                        Button { showPicker = true } label: {
                            VStack(spacing: 6) {
                                Image(systemName: "photo.badge.plus").font(.system(size: 24))
                                Text("上传凭证照片（可选）").font(.system(size: 12))
                            }
                            .foregroundColor(.appMutedFg)
                            .frame(maxWidth: .infinity)
                            .frame(height: 96)
                            .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color.appInput, style: StrokeStyle(lineWidth: 1, dash: [6])))
                        }
                        .buttonStyle(.plain)
                    }
                }

                Button { Task { await submit() } } label: {
                    Text(busy ? "提交中…" : "提交申请")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.appPrimaryFg)
                        .frame(maxWidth: .infinity)
                        .frame(height: 36)
                        .background(Color.appPrimary)
                        .clipShape(Capsule())
                        .opacity(canSubmit ? 1 : 0.6)
                }
                .buttonStyle(.plain)
                .disabled(!canSubmit || busy)
                Spacer()
            }
            .padding(20)
            .background(Color.appBackground)
            .navigationTitle(credential ? "申请领取（需凭证）" : "申请领取")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("关闭") { dismiss() }
                        .font(.system(size: 13))
                        .foregroundColor(.appMutedFg)
                }
            }
            .sheet(isPresented: $showPicker) { ImagePicker(image: $credentialImage) }
        }
        .presentationDetents([.medium, .large])
    }

    private func submit() async {
        busy = true
        defer { busy = false }
        do {
            var dataURL: String? = nil
            if let img = credentialImage {
                dataURL = ImageCodec.coverDataURL(from: img)
            }
            _ = try await MashanglingAPI.shared.claim.create(
                showcaseId: detail.id, note: note.trimmingCharacters(in: .whitespaces),
                credentialImage: dataURL)
            ToastCenter.shared.success("申请已提交，审核结果会通过站内信通知你")
            dismiss()
            onDone()
        } catch {
            ToastCenter.shared.error(error.localizedDescription)
        }
    }
}

// MARK: - 返图弹窗（对应网页 RepostDialog）
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
                Text("收到无料了？晒一张实拍图，让分享者开心一下。")
                    .font(.system(size: 12))
                    .lineSpacing(7)
                    .foregroundColor(.appMutedFg)

                if let img = image {
                    ZStack(alignment: .topTrailing) {
                        Image(uiImage: img)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(maxWidth: .infinity)
                            .frame(maxHeight: 224)
                            .clipped()
                            .cornerRadius(3)
                            .overlay(RoundedRectangle(cornerRadius: 3).stroke(Color.appBorder, lineWidth: 1))
                        Button { image = nil } label: {
                            Image(systemName: "xmark")
                                .font(.system(size: 14))
                                .foregroundColor(.white)
                                .frame(width: 28, height: 28)
                                .background(Color.black.opacity(0.6))
                                .clipShape(Circle())
                        }
                        .buttonStyle(.plain)
                        .padding(8)
                    }
                } else {
                    Button { showPicker = true } label: {
                        VStack(spacing: 6) {
                            Image(systemName: "photo.badge.plus").font(.system(size: 24))
                            Text("上传实拍图（自动压缩）").font(.system(size: 12))
                        }
                        .foregroundColor(.appMutedFg)
                        .frame(maxWidth: .infinity)
                        .frame(height: 128)
                        .overlay(RoundedRectangle(cornerRadius: 3).stroke(Color.appInput, style: StrokeStyle(lineWidth: 1, dash: [6])))
                    }
                    .buttonStyle(.plain)
                }

                TextField("说点什么吧：质感如何、包装怎么样…（可不填）", text: $comment, axis: .vertical)
                    .font(.system(size: 14))
                    .lineLimit(3...6)
                    .padding(10)
                    .background(Color.appInput)
                    .clipShape(RoundedRectangle(cornerRadius: 2))
                    .onChange(of: comment) { v in if v.count > 500 { comment = String(v.prefix(500)) } }

                Button { Task { await submit() } } label: {
                    Text(busy ? "发布中…" : "发布返图")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.appPrimaryFg)
                        .frame(maxWidth: .infinity)
                        .frame(height: 36)
                        .background(Color.appPrimary)
                        .clipShape(Capsule())
                        .opacity(image == nil ? 0.6 : 1)
                }
                .buttonStyle(.plain)
                .disabled(image == nil || busy)
                Spacer()
            }
            .padding(20)
            .background(Color.appBackground)
            .navigationTitle("返图")
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
        .presentationDetents([.medium, .large])
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
            ToastCenter.shared.success("返图已发布，感谢分享！")
            dismiss()
            onDone()
        } catch { ToastCenter.shared.error(error.localizedDescription) }
    }
}

// MARK: - 返图大图查看（对应网页 RepostGallery 的 viewer）
struct ImageViewerCover: View {
    let path: String
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Color.black.opacity(0.8).ignoresSafeArea()
            AppImage(path: path, contentMode: .fit)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(16)
            Button { dismiss() } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 20))
                    .foregroundColor(.white)
                    .padding(8)
                    .background(Color.white.opacity(0.1))
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
            .padding(16)
        }
        .onTapGesture { dismiss() }
    }
}

// MARK: - 发送地址弹窗（对应网页 AddressPickerDialog：点选即发送）
struct AddressPickSheet: View {
    let showcaseId: Int
    var onDone: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var entries: [AddressData.AddressEntry] = []
    @State private var busy = false
    @State private var loading = true

    var body: some View {
        NavigationStack {
            Group {
                if loading {
                    LoadingView()
                } else if entries.isEmpty {
                    VStack(spacing: 12) {
                        Text("还没有保存地址，先去「设置 → 地址」添加")
                            .font(.system(size: 12))
                            .foregroundColor(.appMutedFg)
                            .multilineTextAlignment(.center)
                            .padding(20)
                            .frame(maxWidth: .infinity)
                            .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color.appBorder, style: StrokeStyle(lineWidth: 1, dash: [6])))
                        NavigationLink(destination: SettingsView()) {
                            Text("去填写地址")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(.appForeground)
                                .padding(.horizontal, 16).padding(.vertical, 8)
                                .overlay(Capsule().stroke(Color.appBorder, lineWidth: 1))
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(16)
                } else {
                    VStack(spacing: 8) {
                        ForEach(Array(entries.enumerated()), id: \.element.id) { idx, e in
                            Button { Task { await send(idx) } } label: {
                                HStack(spacing: 10) {
                                    Image(systemName: "mappin")
                                        .font(.system(size: 16))
                                        .foregroundColor(.appMutedFg)
                                    HStack(spacing: 8) {
                                        Text(e.nickname.isEmpty ? "未填昵称" : e.nickname)
                                            .font(.system(size: 14, weight: .medium))
                                            .foregroundColor(.appForeground)
                                        if !e.phone.isEmpty {
                                            Text(e.phone)
                                                .font(.system(size: 12))
                                                .foregroundColor(.appMutedFg)
                                        }
                                    }
                                    .lineLimit(1)
                                    Spacer(minLength: 0)
                                    Text("发送")
                                        .font(.system(size: 12))
                                        .foregroundColor(.appPrimary)
                                }
                                .padding(.horizontal, 14).padding(.vertical, 10)
                                .background(Color.appCard)
                                .cornerRadius(4)
                                .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color.appBorder, lineWidth: 1))
                                .opacity(busy ? 0.5 : 1)
                            }
                            .buttonStyle(.plain)
                            .disabled(busy)
                        }
                        Button { dismiss() } label: {
                            Text("取消")
                                .font(.system(size: 13))
                                .foregroundColor(.appMutedFg)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                        }
                        .buttonStyle(.plain)
                        .padding(.top, 4)
                    }
                    .padding(16)
                }
            }
            .background(Color.appBackground)
            .navigationTitle("选择要发送的地址")
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

    private func send(_ index: Int) async {
        busy = true
        defer { busy = false }
        do {
            _ = try await MashanglingAPI.shared.address.send(showcaseId: showcaseId, addressIndex: index)
            ToastCenter.shared.success("地址已发送给发布者")
            dismiss()
            onDone()
        } catch { ToastCenter.shared.error(error.localizedDescription) }
    }
}

// MARK: - 好友列表行（礼物分享 / 分享给好友共用样式）
private struct FriendRow: View {
    let friend: FollowUser
    let actionLabel: String
    let actionIcon: String
    let sent: Bool
    let busy: Bool
    let onAvatar: () -> Void
    let onSend: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Button(action: onAvatar) {
                AvatarView(path: friend.avatar, name: friend.name ?? "", size: 36)
            }
            .buttonStyle(.plain)
            Text(friend.name ?? "")
                .font(.system(size: 14))
                .foregroundColor(.appForeground)
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)
            Button(action: onSend) {
                HStack(spacing: 4) {
                    Image(systemName: actionIcon).font(.system(size: 12))
                    Text(sent ? actionLabel + "过" : actionLabel)
                        .font(.system(size: 12, weight: sent ? .regular : .semibold))
                }
                .foregroundColor(sent ? .appMutedFg : .appPrimaryFg)
                .padding(.horizontal, 12).padding(.vertical, 6)
                .background(sent ? Color.appSecondary : Color.appPrimary)
                .clipShape(Capsule())
                .opacity(!sent && busy ? 0.6 : 1)
            }
            .buttonStyle(.plain)
            .disabled(sent || busy)
        }
        .padding(.horizontal, 8).padding(.vertical, 8)
    }
}

// MARK: - 礼物分享弹窗（对应网页 GiftShareDialog：仅发布者，赠送给互关好友）
struct GiftShareSheet: View {
    let showcaseId: Int

    @Environment(\.dismiss) private var dismiss
    @State private var friends: [FollowUser] = []
    @State private var loading = true
    @State private var busy = false
    @State private var sentTo: [Int] = []
    @State private var navProfile: Int? = nil

    var body: some View {
        NavigationStack {
            Group {
                if loading {
                    LoadingView()
                } else if friends.isEmpty {
                    Text("还没有好友——互相关注后即成为好友，可以去对方的个人页点「关注」")
                        .font(.system(size: 14))
                        .foregroundColor(.appMutedFg)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .padding(24)
                } else {
                    ScrollView {
                        VStack(spacing: 4) {
                            ForEach(friends) { f in
                                FriendRow(friend: f,
                                          actionLabel: "赠送",
                                          actionIcon: "gift",
                                          sent: sentTo.contains(f.userId),
                                          busy: busy,
                                          onAvatar: { navProfile = f.userId },
                                          onSend: { Task { await send(to: f.userId) } })
                            }
                        }
                        .padding(.horizontal, 12).padding(.vertical, 8)
                    }
                }
            }
            .background(Color.appBackground)
            .navigationTitle("以礼物分享")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("关闭") { dismiss() }
                        .font(.system(size: 13))
                        .foregroundColor(.appMutedFg)
                }
            }
            .background(
                NavigationLink(destination: ProfileView(userId: navProfile ?? 0),
                               isActive: Binding(get: { navProfile != nil }, set: { if !$0 { navProfile = nil } })) { EmptyView() }
                    .hidden()
            )
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
            sentTo.append(userId)
            ToastCenter.shared.success("礼物已送出，好感 +10（当前 \(lv) 级）")
        } catch { ToastCenter.shared.error(error.localizedDescription) }
    }
}

// MARK: - 分享给好友弹窗（对应网页 ShareToFriendsDialog：私信一条橱窗快照）
struct ShareToFriendsSheet: View {
    let showcaseId: Int

    @Environment(\.dismiss) private var dismiss
    @State private var friends: [FollowUser] = []
    @State private var loading = true
    @State private var busy = false
    @State private var sentTo: [Int] = []
    @State private var navProfile: Int? = nil

    var body: some View {
        NavigationStack {
            Group {
                if loading {
                    LoadingView()
                } else if friends.isEmpty {
                    Text("还没有好友——互相关注后即成为好友，可以去对方的个人页点「关注」")
                        .font(.system(size: 14))
                        .foregroundColor(.appMutedFg)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .padding(24)
                } else {
                    ScrollView {
                        VStack(spacing: 4) {
                            ForEach(friends) { f in
                                FriendRow(friend: f,
                                          actionLabel: "分享",
                                          actionIcon: "paperplane",
                                          sent: sentTo.contains(f.userId),
                                          busy: busy,
                                          onAvatar: { navProfile = f.userId },
                                          onSend: { Task { await send(to: f.userId) } })
                            }
                        }
                        .padding(.horizontal, 12).padding(.vertical, 8)
                        Text("好友 = 互相关注的人。分享后对方会在私信里收到橱窗快照，点开即可跳转。")
                            .font(.system(size: 11))
                            .lineSpacing(5)
                            .foregroundColor(.appMutedFg)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 20)
                            .padding(.bottom, 16)
                    }
                }
            }
            .background(Color.appBackground)
            .navigationTitle("分享给好友")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("关闭") { dismiss() }
                        .font(.system(size: 13))
                        .foregroundColor(.appMutedFg)
                }
            }
            .background(
                NavigationLink(destination: ProfileView(userId: navProfile ?? 0),
                               isActive: Binding(get: { navProfile != nil }, set: { if !$0 { navProfile = nil } })) { EmptyView() }
                    .hidden()
            )
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
            _ = try await MashanglingAPI.shared.dm.shareShowcase(toUserId: userId, showcaseId: showcaseId)
            sentTo.append(userId)
            _ = try? await MashanglingAPI.shared.share.mark(showcaseId: showcaseId, channel: "friend")
            ToastCenter.shared.success("已分享到私信")
        } catch { ToastCenter.shared.error(error.localizedDescription) }
    }
}
