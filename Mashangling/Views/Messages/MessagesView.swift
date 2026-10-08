import SwiftUI

// MARK: - 消息中心（逐行复刻网页 Messages.tsx）
// 标题+一键已读 / 关键词搜索 / 9 胶囊 tab / 礼物记录(收发二级胶囊) / 私信会话 / 凭证大图预览
struct MessagesView: View {
    @EnvironmentObject var authManager: AuthManager

    private enum TabKey: String, CaseIterable {
        case all, like, postComment, want, repost, soldout, claim, address, gift, dm
        var label: String {
            switch self {
            case .all: return "全部"
            case .like: return "点赞"
            case .postComment: return "动态评论"
            case .want: return "想要/领到"
            case .repost: return "返图"
            case .soldout: return "补货"
            case .claim: return "领取申请"
            case .address: return "地址"
            case .gift: return "礼物"
            case .dm: return "私信"
            }
        }
    }

    /// 网页 2026-10-08：消息页顶部「消息 / 动态」分段
    private enum ViewKey: String {
        case messages, posts
        var label: String { self == .messages ? "消息" : "动态" }
    }

    /// 网页 TYPE_ICON → SF Symbols
    private func typeIcon(_ t: String) -> String {
        switch t {
        case "like", "postLike": return "heart"
        case "want", "restock": return "hand.raised"
        case "claimed", "claim_received", "claim_approved", "claim_rejected": return "checkmark.seal"
        case "repost": return "camera"
        case "soldout": return "slash.circle"
        case "dm": return "message"
        case "follow": return "star"
        case "address": return "mappin"
        case "gift": return "gift"
        case "postComment": return "message"
        default: return "tray"
        }
    }

    private static let wantTypes: Set<String> = ["want", "claimed", "restock"]
    private static let claimTypes: Set<String> = ["claim_received", "claim_approved", "claim_rejected"]

    private enum Route: Identifiable, Hashable {
        case showcase(Int)
        case claims
        case myShipments
        case shipping
        case shippingApprovals
        case approval(Int)
        case dm(Int, String)
        var id: String {
            switch self {
            case .showcase(let i): return "s\(i)"
            case .claims: return "claims"
            case .myShipments: return "ms"
            case .shipping: return "sp"
            case .shippingApprovals: return "sa"
            case .approval(let i): return "ap\(i)"
            case .dm(let i, _): return "dm\(i)"
            }
        }
    }

    @State private var view: ViewKey = .messages
    @State private var tab: TabKey = .all
    @State private var postsFeedKey = 0   // 发布动态后重建信息流刷新
    @State private var giftViewReceived = true   // 网页默认 received
    @State private var kw = ""
    @State private var messages: [MessageRow] = []
    @State private var listLoading = true
    @State private var conversations: [Conversation] = []
    @State private var dmLoaded = false
    @State private var dmLoading = false
    @State private var gifts: GiftRecords? = nil
    @State private var giftLoading = false
    @State private var markingAll = false
    @State private var route: Route? = nil
    @State private var previewImage: String? = nil

    var body: some View {
        NavigationStack {
            Group {
                if !authManager.isAuthenticated {
                    emptyHint("登录后查看消息")
                        .padding(.top, 24)
                        .padding(.horizontal, 16)
                } else {
                    ScrollView(showsIndicators: false) {
                        VStack(alignment: .leading, spacing: 0) {
                            topRow
                            if view == .posts {
                                // 网页：mt-4 space-y-3（PostComposer + PostsFeed）
                                VStack(spacing: 12) {
                                    PostComposerView(
                                        onPublished: { postsFeedKey += 1 },
                                        needLogin: {}
                                    )
                                    PostsFeedView(mode: "feed")
                                        .id(postsFeedKey)
                                }
                                .padding(.top, 16)
                            } else {
                                searchBar.padding(.top, 12)
                                tabRow.padding(.top, 16)
                                content.padding(.top, 16)
                            }
                            FooterView().padding(.top, 16)
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 24)
                        .padding(.bottom, 24)
                    }
                    .scrollDismissesKeyboard(.interactively)
                    .refreshable { await loadMessages() }
                }
            }
            .background(Color.appBackground)
            .webHeader()
            .task { await loadMessages() }
            // 悬浮提示卡「去看看」→ 切到「动态」分段
            .onReceive(NotificationCenter.default.publisher(for: .mslShowPosts)) { _ in
                view = .posts
            }
            .onChange(of: tab) { newTab in
                if newTab == .dm, !dmLoaded { Task { await loadConversations() } }
                if newTab == .gift, gifts == nil { Task { await loadGifts() } }
            }
            // iOS 16 兼容：用 isPresented 形式（item: 形式要 iOS 17）
            .navigationDestination(isPresented: Binding(get: { route != nil }, set: { if !$0 { route = nil } })) {
                if let r = route {
                    switch r {
                    case .showcase(let id): ShowcaseDetailView(showcaseId: id)
                    case .claims: ClaimsView()
                    case .myShipments: MyShipmentsView()
                    case .shipping: ShippingView()
                    case .shippingApprovals: ShippingApprovalsView()
                    case .approval(let aid): ApprovalDetailView(approvalId: aid)
                    case .dm(let pid, let name): DmThreadView(peerId: pid, peerName: name)
                    }
                }
            }
            .fullScreenCover(isPresented: Binding(get: { previewImage != nil },
                                                  set: { if !$0 { previewImage = nil } })) {
                // 网页：fixed inset-0 bg-black/70，点击任意处关闭，图片 max-h-85vh 等比
                if let img = previewImage {
                    ZStack {
                        Color.black.opacity(0.7).ignoresSafeArea()
                            .onTapGesture { previewImage = nil }
                        AppImage(path: img)
                            .aspectRatio(contentMode: .fit)
                            .cornerRadius(4)
                            .padding(16)
                    }
                }
            }
        }
    }

    // MARK: 顶部分段「消息 / 动态」+ 一键已读（网页 2026-10-08：rounded-full border bg-secondary/60 p-1）
    private var topRow: some View {
        HStack {
            HStack(spacing: 0) {
                ForEach([ViewKey.messages, ViewKey.posts], id: \.self) { v in
                    Button { view = v } label: {
                        Text(v.label)
                            .font(.system(size: 14, weight: view == v ? .medium : .regular))
                            .foregroundColor(view == v ? Color.appPrimaryFg : Color.appMutedFg)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 6)
                            .background(view == v ? Color.appPrimary : Color.clear)
                            .clipShape(Capsule())
                            .shadow(color: view == v ? Color.black.opacity(0.06) : .clear, radius: 2, y: 1)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(4)
            .background(Color.appSecondary.opacity(0.6))
            .overlay(Capsule().stroke(Color.appBorder, lineWidth: 0.5))
            .clipShape(Capsule())
            Spacer()
            if view == .messages && tab != .dm {
                Button { Task { await markAll() } } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "checkmark")
                            .font(.system(size: 10, weight: .semibold))
                        Text(markingAll ? "处理中…" : (unreadInView > 0 ? "一键已读（\(unreadInView)）" : "一键已读"))
                            .font(.system(size: 12, weight: unreadInView > 0 ? .medium : .regular))
                    }
                    .foregroundColor(unreadInView > 0 ? Color.appPrimary : Color.appMutedFg.opacity(0.6))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 6)
                    .background(unreadInView > 0 ? Color.appPrimary.opacity(0.05) : Color.clear)
                    .overlay(Capsule().stroke(unreadInView > 0 ? Color.appPrimary.opacity(0.4) : Color.appBorder.opacity(0.5), lineWidth: 0.5))
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
                .disabled(markingAll || unreadInView == 0)
            }
        }
    }

    // MARK: 关键词搜索（网页：rounded-full border bg-card pl-9 pr-9，左侧放大镜右侧清空）
    private var searchBar: some View {
        HStack(spacing: 0) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 14))
                .foregroundColor(.appMutedFg)
                .padding(.leading, 12)
            TextField("搜索消息关键词（标题 / 内容 / 发送人）", text: $kw)
                .font(.system(size: 16)) // iOS：字号 ≥16 聚焦不自动放大
                .foregroundColor(.appForeground)
                .padding(.leading, 8)
                .padding(.vertical, 8)
            if !kw.isEmpty {
                Button { kw = "" } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 12))
                        .foregroundColor(.appMutedFg)
                        .padding(6)
                }
                .buttonStyle(.plain)
                .padding(.trailing, 6)
            } else {
                Spacer().frame(width: 12)
            }
        }
        .background(Color.appCard)
        .overlay(Capsule().stroke(Color.appBorder, lineWidth: 0.5))
        .clipShape(Capsule())
    }

    // MARK: 9 胶囊 tab（网页：rounded-full px-3.5 py-1.5 text-sm，选中 bg-primary）
    private var tabRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(TabKey.allCases, id: \.self) { t in
                    Button { tab = t } label: {
                        Text(t.label)
                            .font(.system(size: 14, weight: tab == t ? .medium : .regular))
                            .foregroundColor(tab == t ? Color.appPrimaryFg : Color.appForeground)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 6)
                            .background(tab == t ? Color.appPrimary : Color.appSecondary)
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.bottom, 4)
        }
    }

    // MARK: 过滤逻辑（与网页一致：点赞 = like + postLike；动态评论 = postComment）
    private var items: [MessageRow] {
        messages.filter { m in
            switch tab {
            case .all: return true
            case .like: return m.type == "like" || m.type == "postLike"
            case .postComment: return m.type == "postComment"
            case .claim: return Self.claimTypes.contains(m.type)
            case .want: return Self.wantTypes.contains(m.type)
            case .dm: return m.type == "dm"
            default: return m.type == tab.rawValue
            }
        }
    }

    private var kwNorm: String { kw.trimmingCharacters(in: .whitespaces).lowercased() }

    private func matchKw(_ fields: String?...) -> Bool {
        kwNorm.isEmpty || fields.contains { ($0 ?? "").lowercased().contains(kwNorm) }
    }

    private var viewItems: [MessageRow] {
        kwNorm.isEmpty ? items : items.filter { matchKw($0.title, $0.content, $0.fromUserName) }
    }

    private var dmItems: [Conversation] {
        kwNorm.isEmpty ? conversations : conversations.filter { matchKw($0.peerName, $0.lastContent) }
    }

    private var giftItems: [GiftRecords.GiftRow] {
        let src = giftViewReceived ? (gifts?.received ?? []) : (gifts?.sent ?? [])
        return kwNorm.isEmpty ? src : src.filter { matchKw($0.showcaseTitle, $0.peer?.name) }
    }

    private var unreadInView: Int { items.filter { !$0.read }.count }

    // MARK: 内容区
    @ViewBuilder
    private var content: some View {
        if tab == .gift {
            giftSection
        } else if tab == .dm {
            dmSection
        } else if listLoading {
            LoadingView().frame(maxWidth: .infinity).padding(.top, 40)
        } else if viewItems.isEmpty {
            emptyHint(kwNorm.isEmpty ? "暂无消息" : "没有找到包含「\(kw.trimmingCharacters(in: .whitespaces))」的消息")
        } else {
            VStack(spacing: 8) {
                ForEach(viewItems) { m in messageRow(m) }
            }
        }
    }

    // MARK: 消息行（网页：图标圆 32 + 标题/未读点 + 两行内容 + link 胶囊 + 凭证图 + 发送人·时间）
    private func messageRow(_ m: MessageRow) -> some View {
        Button { open(m) } label: {
            HStack(alignment: .top, spacing: 12) {
                ZStack {
                    Circle()
                        .fill(m.read ? Color.appSecondary : Color.appPrimary.opacity(0.1))
                        .frame(width: 32, height: 32)
                    Image(systemName: typeIcon(m.type))
                        .font(.system(size: 13))
                        .foregroundColor(m.read ? Color.appMutedFg : Color.appPrimary)
                }
                .padding(.top, 2)

                VStack(alignment: .leading, spacing: 0) {
                    HStack(spacing: 8) {
                        Text(m.title)
                            .font(.system(size: 14, weight: m.read ? .regular : .semibold))
                            .foregroundColor(m.read ? Color.appForeground.opacity(0.8) : Color.appForeground)
                            .lineLimit(1)
                        if !m.read {
                            Circle().fill(Color.appPrimary).frame(width: 8, height: 8)
                        }
                    }
                    if let c = m.content, !c.isEmpty {
                        Text(c)
                            .font(.system(size: 12))
                            .foregroundColor(.appMutedFg)
                            .lineLimit(2)
                            .lineSpacing(8) // 网页 leading-5（20px 行高）
                            .padding(.top, 2)
                    }
                    if let link = m.link, !link.isEmpty {
                        Text(linkLabel(link, type: m.type) + " →")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(.appPrimary)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(Color.appPrimary.opacity(0.1))
                            .clipShape(Capsule())
                            .padding(.top, 6)
                    }
                    if let img = m.image, !img.isEmpty {
                        Button {
                            if !m.read { Task { await markRead(m.id) } }
                            previewImage = img
                        } label: {
                            AppImage(path: img)
                                .aspectRatio(contentMode: .fit)
                                .frame(maxHeight: 112)
                                .cornerRadius(3)
                                .overlay(RoundedRectangle(cornerRadius: 3).stroke(Color.appBorder, lineWidth: 0.5))
                        }
                        .buttonStyle(.plain)
                        .padding(.top, 8)
                    }
                    Text((m.fromUserName.map { "\($0) · " } ?? "") + DateFmt.zhFull(m.createdAt))
                        .font(.system(size: 11))
                        .foregroundColor(.appMutedFg)
                        .padding(.top, 4)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(16)
            .background(m.read ? Color.appCard : Color.appPrimary.opacity(0.03))
            .cornerRadius(4)
            .overlay(RoundedRectangle(cornerRadius: 4)
                .stroke(m.read ? Color.appBorder.opacity(0.6) : Color.appPrimary.opacity(0.4), lineWidth: 0.5))
        }
        .buttonStyle(.plain)
    }

    private func linkLabel(_ link: String, type: String) -> String {
        if link.contains("/my-shipments") { return "去需补邮" }
        if link.contains("/shipping/approval/") { return "去上传凭证 / 审批" }
        if type == "gift" { return "去领取礼物" }
        return "去处理"
    }

    // MARK: 礼物 tab（网页：二级胶囊 收到的礼物/赠礼 + 记录行）
    private var giftSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 6) {
                giftSubPill(true, "收到的礼物")
                giftSubPill(false, "赠礼")
            }
            if giftLoading && gifts == nil {
                LoadingView().frame(maxWidth: .infinity).padding(.top, 40)
            } else if giftItems.isEmpty {
                emptyHint(kwNorm.isEmpty
                          ? (giftViewReceived ? "还没有收到礼物" : "还没有送出过礼物")
                          : "没有找到包含「\(kw.trimmingCharacters(in: .whitespaces))」的礼物消息")
                    .padding(.top, 12)
            } else {
                VStack(spacing: 8) {
                    ForEach(giftItems) { g in giftRow(g) }
                }
                .padding(.top, 12)
            }
        }
    }

    private func giftSubPill(_ received: Bool, _ title: String) -> some View {
        Button { giftViewReceived = received } label: {
            Text(title)
                .font(.system(size: 12, weight: giftViewReceived == received ? .medium : .regular))
                .foregroundColor(giftViewReceived == received ? Color.appBackground : Color.appMutedFg)
                .padding(.horizontal, 12)
                .padding(.vertical, 4)
                .background(giftViewReceived == received ? Color.appForeground : Color.appSecondary)
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    private func giftRow(_ g: GiftRecords.GiftRow) -> some View {
        let removed = g.removed ?? false
        return Button {
            if !removed { route = .showcase(g.showcaseId) }
        } label: {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color.appSecondary)
                        .frame(width: 48, height: 48)
                    if let cover = g.coverImage, !cover.isEmpty {
                        AppImage(path: cover)
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 48, height: 48)
                            .clipShape(RoundedRectangle(cornerRadius: 3))
                    } else {
                        Image(systemName: "gift")
                            .font(.system(size: 16))
                            .foregroundColor(.appMutedFg)
                    }
                }
                VStack(alignment: .leading, spacing: 0) {
                    Text(g.showcaseTitle ?? "")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.appForeground)
                        .lineLimit(1)
                    Text((giftViewReceived
                          ? "\(g.peer?.name ?? "好友") 赠送"
                          : "赠送给 \(g.peer?.name ?? "好友")") + " · " + DateFmt.zhDate(g.createdAt))
                        .font(.system(size: 12))
                        .foregroundColor(.appMutedFg)
                        .padding(.top, 2)
                    if let exp = DateFmt.parse(g.expiresAt) {
                        Text(exp < Date()
                             ? "限时橱窗 · 已于 \(DateFmt.mddhm(exp)) 失效"
                             : "限时橱窗 · \(DateFmt.mddhm(exp)) 后失效，逾期无法领取")
                            .font(.system(size: 11))
                            .foregroundColor(.twOrange600)
                            .padding(.top, 2)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                Text(removed ? "已下架" : (g.claimed ? "已领取" : "待领取"))
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(removed ? Color.appMutedFg : (g.claimed ? Color.twEmerald600 : Color.appPrimary))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(removed ? Color.appSecondary : (g.claimed ? Color.twEmerald500.opacity(0.1) : Color.appPrimary.opacity(0.1)))
                    .clipShape(Capsule())
            }
            .padding(14)
            .background(Color.appCard)
            .cornerRadius(4)
            .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color.appBorder, lineWidth: 0.5))
            .opacity(removed ? 0.6 : 1)
        }
        .buttonStyle(.plain)
    }

    // MARK: 私信 tab（网页：字母圆形头像 + 昵称 + 我：前缀 + 右侧日期）
    private var dmSection: some View {
        Group {
            if dmLoading && conversations.isEmpty {
                LoadingView().frame(maxWidth: .infinity).padding(.top, 40)
            } else if dmItems.isEmpty {
                emptyHint(kwNorm.isEmpty
                          ? "还没有私信会话，去别人的主页点「私信」开始聊天吧"
                          : "没有找到包含「\(kw.trimmingCharacters(in: .whitespaces))」的私信会话")
            } else {
                VStack(spacing: 8) {
                    ForEach(dmItems) { c in dmRow(c) }
                }
            }
        }
    }

    private func dmRow(_ c: Conversation) -> some View {
        Button { route = .dm(c.peerId, c.peerName ?? "") } label: {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(Color.appPrimary.opacity(0.1))
                        .frame(width: 40, height: 40)
                    Text((c.peerName ?? "U").prefix(1).uppercased())
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.appPrimary)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(c.peerName ?? "")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.appForeground)
                    Text((c.fromMe == true ? "我：" : "") + (c.lastContent ?? ""))
                        .font(.system(size: 12))
                        .foregroundColor(.appMutedFg)
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                Text(DateFmt.zhDate(c.lastAt))
                    .font(.system(size: 11))
                    .foregroundColor(.appMutedFg)
            }
            .padding(16)
            .background(Color.appCard)
            .cornerRadius(4)
            .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color.appBorder, lineWidth: 0.5))
        }
        .buttonStyle(.plain)
    }

    // MARK: 空态（网页 EmptyHint：虚线边框圆角卡 py-16）
    private func emptyHint(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 14))
            .foregroundColor(.appMutedFg)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 64)
            .overlay(
                RoundedRectangle(cornerRadius: 4)
                    .stroke(Color.appBorder, style: StrokeStyle(lineWidth: 0.5, dash: [4, 3]))
            )
    }

    // MARK: 打开消息（网页 openMessage：link 优先 > dm > claim_received→/claims > address/showcaseId→/s/:id）
    private func open(_ m: MessageRow) {
        if !m.read { Task { await markRead(m.id) } }
        if let link = m.link, !link.isEmpty {
            // 动态点赞/评论通知 → 切到「动态」分段（网页：/messages?tab=posts）
            if link.contains("tab=posts") {
                view = .posts
                return
            }
            if link.contains("/my-shipments") {
                route = .myShipments
            } else if link.contains("/shipping/approval/"), let aid = Self.idFromPath(link, prefix: "/shipping/approval/") {
                route = .approval(aid)
            } else if link.contains("/shipping/approvals") {
                route = .shippingApprovals
            } else if link.contains("/shipping") {
                route = .shipping
            } else if let sid = Self.showcaseIdFromPath(link) {
                route = .showcase(sid)
            } else if let sid = m.showcaseId {
                route = .showcase(sid)
            }
            return
        }
        if m.type == "dm", let from = m.fromUserId {
            route = .dm(from, m.fromUserName ?? "")
        } else if m.type == "claim_received" {
            route = .claims
        } else if m.type == "address", let sid = m.showcaseId {
            route = .showcase(sid)
        } else if let sid = m.showcaseId {
            route = .showcase(sid)
        }
    }

    private static func showcaseIdFromPath(_ link: String) -> Int? {
        idFromPath(link, prefix: "/s/")
    }

    private static func idFromPath(_ link: String, prefix: String) -> Int? {
        guard let range = link.range(of: prefix) else { return nil }
        let tail = link[range.upperBound...]
        let digits = tail.prefix { $0.isNumber }
        return Int(digits)
    }

    // MARK: 数据
    private func loadMessages() async {
        guard authManager.isAuthenticated else { listLoading = false; return }
        listLoading = true
        messages = (try? await MashanglingAPI.shared.message.list(type: "all")) ?? []
        listLoading = false
    }

    private func loadConversations() async {
        dmLoading = true
        conversations = (try? await MashanglingAPI.shared.dm.conversations()) ?? []
        dmLoaded = true
        dmLoading = false
    }

    private func loadGifts() async {
        giftLoading = true
        gifts = try? await MashanglingAPI.shared.gift.records()
        giftLoading = false
    }

    private func markRead(_ id: Int) async {
        try? await MashanglingAPI.shared.message.markRead(id: id)
        if let idx = messages.firstIndex(where: { $0.id == id }) {
            messages[idx] = messages[idx].asRead()
        }
    }

    private func markAll() async {
        markingAll = true
        try? await MashanglingAPI.shared.message.markAllRead()
        await loadMessages()
        markingAll = false
        ToastCenter.shared.success("已全部标记为已读")
    }
}

private extension MessageRow {
    /// 本地置为已读（MessageRow 字段全 let，这里重建一份）
    func asRead() -> MessageRow {
        MessageRow(id: id, type: type, title: title, content: content, image: image,
                   link: link, read: true, createdAt: createdAt,
                   fromUserId: fromUserId, showcaseId: showcaseId, fromUserName: fromUserName)
    }
}
