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

    // MARK: 主体
    private func content(_ d: ShowcaseDetailData) -> some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 14) {
                // 封面
                ZStack(alignment: .topLeading) {
                    AppImage(path: d.coverImage)
                        .aspectRatio(1, contentMode: .fit)
                        .frame(maxWidth: .infinity)
                        .background(Color.appSecondary)
                        .cornerRadius(12)
                    MiniBadge(text: PlatformLabel.of(d.platform), fg: .white, bg: Color.black.opacity(0.55))
                        .padding(10)
                }

                // 标题 + 作者
                VStack(alignment: .leading, spacing: 8) {
                    Text(d.title)
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.appForeground)
                    HStack(spacing: 8) {
                        NavigationLink(destination: ProfileView(userId: d.author?.id ?? 0)) {
                            HStack(spacing: 6) {
                                AvatarView(path: d.author?.avatar, name: d.author?.name ?? "", size: 26)
                                Text(d.author?.name ?? "未知用户")
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundColor(.appForeground)
                                if let lv = d.author?.level {
                                    LevelBadgeView(level: lv)
                                }
                                TitleBadgeView(equippedTitle: d.author?.equippedTitle)
                            }
                        }
                        .buttonStyle(.plain)
                        Spacer()
                        Text(DateFmt.short(d.createdAt))
                            .font(.system(size: 11))
                            .foregroundColor(.appMutedFg)
                    }
                    // 标签
                    if let tags = d.tags, !tags.isEmpty {
                        FlowLayout(spacing: 6) {
                            ForEach(tags) { t in
                                NavigationLink(destination: TagDetailView(tagId: t.id)) {
                                    Text("# \(t.name)")
                                        .font(.system(size: 11))
                                        .foregroundColor(.appForeground)
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 5)
                                        .background(Color.appSecondary)
                                        .cornerRadius(12)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }

                // 领取状态 / 关键信息
                statusCard(d)

                // 描述
                if let desc = d.description, !desc.isEmpty {
                    SectionCard {
                        Text(desc)
                            .font(.system(size: 13))
                            .foregroundColor(.appForeground.opacity(0.9))
                            .lineSpacing(4)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }

                // 无料码区
                codeSection(d)

                // 操作区
                actionRow(d)

                // 返图区
                repostSection(d)

                // 相关橱窗
                if let related = d.related, !related.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("相关橱窗")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.appForeground)
                        LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                            ForEach(related.prefix(6)) { item in
                                NavigationLink(destination: ShowcaseDetailView(showcaseId: item.id)) {
                                    ShowcaseCardView(item: item)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
        }
    }

    // MARK: 状态卡
    private func statusCard(_ d: ShowcaseDetailData) -> some View {
        SectionCard {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    if d.expired == true {
                        MiniBadge(text: "已失效", fg: .white, bg: .appDestructive)
                    }
                    switch d.stockStatus {
                    case "soldout": MiniBadge(text: "领完即止", fg: .appRedFg, bg: .appSecondary)
                    case "restock": MiniBadge(text: "可补码", fg: .appEmeraldFg, bg: .appEmeraldBg)
                    case "limited":
                        MiniBadge(text: "限量 \(d.quantity ?? 0) 份", fg: .appAmberFg, bg: .appAmberBg)
                    default: EmptyView()
                    }
                    if let pc = d.pointCost, pc > 0 {
                        MiniBadge(text: "\(pc) 积分解锁", fg: .appAmberFg, bg: .appAmberBg)
                    }
                    if d.shippingFree == true {
                        MiniBadge(text: "包邮", fg: .appEmeraldFg, bg: .appEmeraldBg)
                    }
                    Spacer()
                }
                HStack(spacing: 14) {
                    Text("👁 \(d.viewCount ?? 0)").font(.system(size: 11)).foregroundColor(.appMutedFg)
                    Text("❤️ \(likeCount)").font(.system(size: 11)).foregroundColor(.appMutedFg)
                    Text("✅ \(d.claimCount ?? 0) 人领到").font(.system(size: 11)).foregroundColor(.appMutedFg)
                    if let q = d.quantity, let r = d.remaining {
                        Text("余量 \(r)/\(q)").font(.system(size: 11)).foregroundColor(.appMutedFg)
                    }
                    Spacer()
                }
                if let t = d.expiresAtText ?? d.expiresAt.map({ DateFmt.full($0) }), d.expiresAt != nil {
                    Text(d.expired == true ? "已于 \(t) 失效" : "限时 · \(t) 失效")
                        .font(.system(size: 11))
                        .foregroundColor(d.expired == true ? .appRedFg : .appAmberFg)
                }
                if let st = d.myClaimStatus {
                    HStack(spacing: 4) {
                        Image(systemName: st == "approved" ? "checkmark.circle.fill" : (st == "rejected" ? "xmark.circle.fill" : "clock.fill"))
                            .font(.system(size: 11))
                        Text(st == "approved" ? "领取申请已通过" : (st == "rejected" ? "领取申请被拒绝" : "领取申请审核中"))
                            .font(.system(size: 11, weight: .medium))
                    }
                    .foregroundColor(st == "approved" ? .appEmeraldFg : (st == "rejected" ? .appDestructive : .appAmberFg))
                }
                if claimedByMe {
                    Text("✓ 你已标记「我领到了」")
                        .font(.system(size: 11))
                        .foregroundColor(.appEmeraldFg)
                }
                if let deadline = d.addressDeadlineText, d.addressEligible == true {
                    Text("请在 \(deadline) 前发送收货地址")
                        .font(.system(size: 11))
                        .foregroundColor(.appAmberFg)
                }
            }
        }
    }

    // MARK: 无料码区
    @ViewBuilder
    private func codeSection(_ d: ShowcaseDetailData) -> some View {
        let canSeeCode = d.isMine == true || claimedByMe || d.myClaimStatus == "approved"
            || (d.codeVisibility == "public")
        SectionCard {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("无料码")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.appForeground)
                    Spacer()
                    if let c = codes {
                        Text("共 \(c.count) 个")
                            .font(.system(size: 11))
                            .foregroundColor(.appMutedFg)
                    }
                }
                if canSeeCode {
                    if let list = codes, !list.items.isEmpty {
                        ForEach(list.items) { c in
                            HStack {
                                Text(c.code)
                                    .font(.system(size: 13, design: .monospaced))
                                    .foregroundColor(.appForeground)
                                    .lineLimit(1)
                                Spacer()
                                Button {
                                    UIPasteboard.general.string = c.code
                                    ToastCenter.shared.success("已复制")
                                } label: {
                                    Image(systemName: "doc.on.doc")
                                        .font(.system(size: 12))
                                        .foregroundColor(.appPrimary)
                                }
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 7)
                            .background(Color.appSecondary.opacity(0.4))
                            .cornerRadius(8)
                        }
                    } else if let rc = d.rouzaoCode, !rc.isEmpty {
                        HStack {
                            Text(rc)
                                .font(.system(size: 13, design: .monospaced))
                                .foregroundColor(.appForeground)
                            Spacer()
                            Button {
                                UIPasteboard.general.string = rc
                                ToastCenter.shared.success("已复制")
                            } label: {
                                Image(systemName: "doc.on.doc")
                                    .font(.system(size: 12))
                                    .foregroundColor(.appPrimary)
                            }
                        }
                    } else {
                        Text("暂无可用无料码，点「没有了」可提醒发布人补码")
                            .font(.system(size: 12))
                            .foregroundColor(.appMutedFg)
                    }
                } else {
                    Text(d.codeVisibility == "claim" ? "领取后可见无料码" : "无料码仅领取人可见，先去领取吧")
                        .font(.system(size: 12))
                        .foregroundColor(.appMutedFg)
                }
            }
        }
    }

    // MARK: 操作行
    private func actionRow(_ d: ShowcaseDetailData) -> some View {
        VStack(spacing: 10) {
            HStack(spacing: 8) {
                // 点赞
                actionButton(icon: liked ? "heart.fill" : "heart",
                             label: "\(likeCount)",
                             tint: liked ? .appRedFg : .appMutedFg) {
                    Task { await toggleLike() }
                }
                // 我领到了
                actionButton(icon: claimedByMe ? "checkmark.circle.fill" : "checkmark.circle",
                             label: "我领到了",
                             tint: claimedByMe ? .appEmeraldFg : .appMutedFg) {
                    Task { await toggleClaim() }
                }
                // 收藏
                actionButton(icon: bookmarked ? "bookmark.fill" : "bookmark",
                             label: "清单",
                             tint: bookmarked ? .appPrimary : .appMutedFg) {
                    Task { await toggleBookmark() }
                }
                // 我想要
                actionButton(icon: requested ? "hand.raised.fill" : "hand.raised",
                             label: "我想要",
                             tint: requested ? .appAmberFg : .appMutedFg) {
                    Task { await wantIt() }
                }
                // 没有了
                actionButton(icon: "bell",
                             label: "没有了",
                             tint: markedSoldout ? .appAmberFg : .appMutedFg) {
                    Task { await markSoldout() }
                }
            }

            // 主操作按钮
            HStack(spacing: 10) {
                if d.expired == true {
                    Text("已失效，无法领取")
                        .font(.system(size: 13))
                        .foregroundColor(.appMutedFg)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 11)
                        .background(Color.appSecondary)
                        .cornerRadius(12)
                } else if d.isFullyClaimed == true && d.stockStatus != "restock" {
                    Text("已领完")
                        .font(.system(size: 13))
                        .foregroundColor(.appMutedFg)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 11)
                        .background(Color.appSecondary)
                        .cornerRadius(12)
                } else if d.isMine == true {
                    NavigationLink(destination: ClaimsView()) {
                        Text("查看领取申请")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.appPrimaryFg)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 11)
                            .background(Color.appPrimary)
                            .cornerRadius(12)
                    }
                    .buttonStyle(.plain)
                } else {
                    Button {
                        guard authManager.isAuthenticated else { showLogin = true; return }
                        showClaimSheet = true
                    } label: {
                        Text(claimButtonLabel(d))
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.appPrimaryFg)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 11)
                            .background(Color.appPrimary)
                            .cornerRadius(12)
                    }
                    .disabled(busy || d.myClaimStatus == "pending")
                }

                if d.addressEligible == true && d.addressSentByMe != true {
                    Button {
                        guard authManager.isAuthenticated else { showLogin = true; return }
                        showAddressSheet = true
                    } label: {
                        Text("发地址")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.appPrimary)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 11)
                            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.appPrimary, lineWidth: 1))
                    }
                }

                Button {
                    showRepostSheet = true
                } label: {
                    Text("返图")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.appPrimary)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 11)
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.appPrimary, lineWidth: 1))
                }
            }
        }
    }

    private func claimButtonLabel(_ d: ShowcaseDetailData) -> String {
        switch d.claimMode {
        case "points": return "积分解锁（\(d.pointCost ?? 0) 积分）"
        case "instant": return "立即领取"
        default:
            if d.myClaimStatus == "pending" { return "申请审核中" }
            if d.myClaimStatus == "approved" { return "已通过" }
            return "申请领取"
        }
    }

    private func actionButton(icon: String, label: String, tint: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 3) {
                Image(systemName: icon).font(.system(size: 16))
                Text(label).font(.system(size: 9))
            }
            .foregroundColor(tint)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(Color.appCard)
            .cornerRadius(10)
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.appBorder, lineWidth: 0.5))
        }
        .buttonStyle(.plain)
    }

    // MARK: 返图区
    private func repostSection(_ d: ShowcaseDetailData) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("返图（\(reposts.count)）")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.appForeground)
                Spacer()
            }
            if reposts.isEmpty {
                Text("还没有返图，领到后晒一张吧")
                    .font(.system(size: 12))
                    .foregroundColor(.appMutedFg)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 20)
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.appBorder, style: StrokeStyle(lineWidth: 1, dash: [6])))
            } else {
                ForEach(reposts) { r in
                    SectionCard {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack(spacing: 8) {
                                AvatarView(path: r.userAvatar, name: r.userName ?? "", size: 24)
                                Text(r.userName ?? "")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(.appForeground)
                                Spacer()
                                Text(DateFmt.short(r.createdAt))
                                    .font(.system(size: 10))
                                    .foregroundColor(.appMutedFg)
                            }
                            AppImage(path: r.image)
                                .aspectRatio(contentMode: .fit)
                                .frame(maxWidth: .infinity)
                                .cornerRadius(8)
                            if let c = r.comment, !c.isEmpty {
                                Text(c)
                                    .font(.system(size: 12))
                                    .foregroundColor(.appForeground.opacity(0.9))
                            }
                        }
                    }
                }
            }
        }
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
