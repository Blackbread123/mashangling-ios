import SwiftUI
import UIKit

// MARK: - 个人主页（逐行复刻网页 Profile.tsx + FollowStats/FollowList/FriendshipCard/
// FriendBadgesInline/ShareProfileDialog/UserCardsSection 组件）
struct ProfileView: View {
    let userId: Int

    @EnvironmentObject var authManager: AuthManager
    @State private var profile: ProfileData? = nil
    @State private var cards: UserCardsResponse? = nil
    @State private var badges: [PublicBadge] = []
    @State private var followStatus: FollowStatus? = nil
    @State private var followerCount = 0
    @State private var followingCount = 0
    @State private var friendCount = 0
    @State private var mutualCount = 0
    @State private var myFollowing: [FollowUser] = []
    @State private var soldouts: [SoldoutReceivedRow] = []
    @State private var requests: [RequestReceivedRow] = []
    @State private var loading = true
    @State private var isError = false
    @State private var showLogin = false
    @State private var followSheet: Int? = nil   // 0 粉丝 1 关注 2 好友 3 共同好友
    @State private var bioOpen = false
    @State private var shareOpen = false
    @State private var showcaseRoute: Int? = nil
    @State private var postCount: PostCountResponse? = nil   // 动态入口卡（2026-10-08 网页新功能）

    private var isMe: Bool { authManager.currentUser?.id == userId }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 0) {
                if loading {
                    LoadingView().frame(maxWidth: .infinity).padding(.top, 60)
                } else if isError || profile == nil {
                    Text("用户不存在")
                        .font(.system(size: 14))
                        .foregroundColor(.appMutedFg)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 80)
                } else if let p = profile, let a = p.author {
                    profileCard(a, p)

                    // 动态入口卡（网页 2026-10-08：emerald 渐变，ID 卡之后、数据看板之前）
                    postsEntryCard(a).padding(.top, 16)

                    // 数据看板（仅本人可见）
                    if isMe {
                        StatsDashboardView().padding(.top, 16)
                        CardStatsPanelView().padding(.top, 16)
                    }

                    entryCards.padding(.top, 16)

                    userCardsSection.padding(.top, 16)

                    // 鸡场（网页 ChickenFarm：h2 农场 + 说明）
                    VStack(alignment: .leading, spacing: 4) {
                        Text("农场")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(.appForeground)
                        Text("鸡产蛋 · 树结果 · 每天 23:00 结算积分利息")
                            .font(.system(size: 12))
                            .foregroundColor(.appMutedFg)
                        FarmView(userId: a.id, embedded: true)
                    }
                    .padding(.top, 32)

                    showcaseSection(p).padding(.top, 32)

                    if isMe {
                        bookmarksRow.padding(.top, 16)
                        MyFollowListSection(items: myFollowing, onChanged: { Task { await loadFollowLists() } })
                            .padding(.top, 40)
                        soldoutSection.padding(.top, 40)
                        requestsSection.padding(.top, 40)
                    }
                    FooterView().padding(.top, 16)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 24)
            .padding(.bottom, 24)
        }
        .background(Color.appBackground)
        .webHeader()
        .task { await load() }
        .refreshable { await load() }
        .sheet(isPresented: $showLogin) { LoginView() }
        .sheet(isPresented: Binding(get: { followSheet != nil }, set: { if !$0 { followSheet = nil } })) {
            FollowListSheet(userId: userId, mode: followSheet ?? 0)
        }
        .sheet(isPresented: $bioOpen) {
            BioSheet(current: profile?.author?.bio ?? "") {
                Task { await load() }
            }
        }
        .sheet(isPresented: $shareOpen) {
            ShareProfileSheet(profileUserId: userId, profileName: profile?.author?.name ?? "该用户")
        }
        .navigationDestination(isPresented: Binding(get: { showcaseRoute != nil }, set: { if !$0 { showcaseRoute = nil } })) {
            if let sid = showcaseRoute {
                ShowcaseDetailView(showcaseId: sid)
            }
        }
    }

    // MARK: 资料卡（网页：rounded-2xl border-border/60 bg-card p-5，相对定位含分享按钮）
    private func profileCard(_ a: ProfileData.ProfileAuthor, _ p: ProfileData) -> some View {
        ZStack(alignment: .bottomTrailing) {
            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .top, spacing: 16) {
                    // 头像 64px
                    ZStack {
                        Circle().fill(Color.appPrimary.opacity(0.1)).frame(width: 64, height: 64)
                        if let av = a.avatar, !av.isEmpty {
                            AppImage(path: av)
                                .aspectRatio(contentMode: .fill)
                                .frame(width: 64, height: 64)
                                .clipShape(Circle())
                        } else {
                            Text((a.name ?? "U").prefix(1).uppercased())
                                .font(.system(size: 24, weight: .bold))
                                .foregroundColor(.appPrimary)
                        }
                    }
                    VStack(alignment: .leading, spacing: 4) {
                        // 名字行：Lv + 好友徽章 + 官方/这是你
                        HStack(spacing: 8) {
                            Text(a.name ?? "未知用户")
                                .font(.system(size: 20, weight: .bold))
                                .foregroundColor(.appForeground)
                                .lineLimit(1)
                            if let lv = a.level { LevelBadgeView(level: lv) }
                            FriendBadgesInlineView(badges: badges)
                            if a.isBot == true {
                                Text("官方")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(.twSky700)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 2)
                                    .background(Color.twSky100)
                                    .clipShape(Capsule())
                            }
                            if isMe {
                                Text("这是你")
                                    .font(.system(size: 12))
                                    .foregroundColor(.appMutedFg)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 2)
                                    .background(Color.appSecondary)
                                    .clipShape(Capsule())
                            }
                        }
                        // 粉丝/关注/好友/共同好友（点击弹列表）
                        HStack(spacing: 14) {
                            followStat(followerCount, "粉丝") { followSheet = 0 }
                            followStat(followingCount, "关注") { followSheet = 1 }
                            followStat(friendCount, "好友") { followSheet = 2 }
                            if authManager.isAuthenticated, !isMe {
                                followStat(mutualCount, "共同好友") { followSheet = 3 }
                            }
                        }
                        .padding(.top, 2)
                        TitleBadgeView(equippedTitle: a.equippedTitle)
                    }
                    Spacer(minLength: 0)
                }

                // 签名 / 默认统计行 + 编辑签名按钮
                HStack(spacing: 0) {
                    Text(a.bio?.isEmpty == false
                         ? a.bio!
                         : "\(p.items?.count ?? 0) 个橱窗 · \(p.totalLikes ?? 0) 次获赞 · \(p.totalClaims ?? 0) 人被领到")
                        .font(.system(size: 14))
                        .foregroundColor(.appMutedFg)
                    if isMe {
                        Button { bioOpen = true } label: {
                            HStack(spacing: 2) {
                                Image(systemName: "pencil").font(.system(size: 9))
                                Text(a.bio?.isEmpty == false ? "编辑签名" : "写签名")
                                    .font(.system(size: 11))
                            }
                            .foregroundColor(.appMutedFg)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .overlay(Capsule().stroke(Color.appBorder, lineWidth: 0.5))
                        }
                        .buttonStyle(.plain)
                        .padding(.leading, 8)
                    }
                }
                .padding(.top, 12)

                // 有签名时的统计行
                if a.bio?.isEmpty == false {
                    Text("\(p.items?.count ?? 0) 个橱窗 · \(p.totalLikes ?? 0) 次获赞 · \(p.totalClaims ?? 0) 人被领到"
                         + ((p.cardFavCount ?? 0) > 0 ? " · 卡片被收藏 \(p.cardFavCount ?? 0) 次" : ""))
                        .font(.system(size: 12))
                        .foregroundColor(.appMutedFg)
                        .padding(.top, 4)
                }

                // 访客操作行（网页：FollowButton + 私信）
                if !isMe, authManager.isAuthenticated {
                    HStack(spacing: 8) {
                        if followStatus?.following == true {
                            Button { Task { await toggleSpecial() } } label: {
                                Image(systemName: followStatus?.special == true ? "star.fill" : "star")
                                    .font(.system(size: 14))
                                    .foregroundColor(followStatus?.special == true ? Color.twAmber500 : Color.appMutedFg)
                                    .frame(width: 36, height: 36)
                                    .background(followStatus?.special == true ? Color.twAmber50 : Color.clear)
                                    .overlay(Circle().stroke(followStatus?.special == true ? Color.twAmber300 : Color.appBorder, lineWidth: 0.5))
                                    .clipShape(Circle())
                            }
                            .buttonStyle(.plain)
                        }
                        Button { Task { await toggleFollow() } } label: {
                            HStack(spacing: 4) {
                                Image(systemName: followStatus?.following == true ? "checkmark" : "plus")
                                    .font(.system(size: 12))
                                Text(followStatus?.following == true
                                     ? (followStatus?.special == true ? "特别关注中" : "已关注")
                                     : "关注")
                                    .font(.system(size: 14, weight: .medium))
                            }
                            .foregroundColor(followStatus?.following == true ? Color.appForeground : Color.appPrimaryFg)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(followStatus?.following == true ? Color.clear : Color.appPrimary)
                            .overlay(Capsule().stroke(followStatus?.following == true ? Color.appBorder : Color.clear, lineWidth: 0.5))
                            .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)

                        if a.dmBlocked == true {
                            HStack(spacing: 4) {
                                Image(systemName: "message").font(.system(size: 12))
                                Text("私信已关闭").font(.system(size: 14))
                            }
                            .foregroundColor(.appMutedFg)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .overlay(Capsule().stroke(Color.appBorder, lineWidth: 0.5))
                        } else {
                            NavigationLink(destination: DmThreadView(peerId: userId, peerName: a.name ?? "")) {
                                HStack(spacing: 4) {
                                    Image(systemName: "message").font(.system(size: 12))
                                    Text("私信").font(.system(size: 14))
                                }
                                .foregroundColor(.appForeground)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .overlay(Capsule().stroke(Color.appBorder, lineWidth: 0.5))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.top, 16)
                }

                // 好友好感卡（仅互关可见，组件内部判断）
                if !isMe {
                    FriendshipCardView(peerId: userId).padding(.top, 16)
                }
            }
            .padding(20)
            .background(Color.appCard)
            .cornerRadius(5)
            .overlay(RoundedRectangle(cornerRadius: 5).stroke(Color.appBorder.opacity(0.6), lineWidth: 0.5))

            // 分享名片按钮（右下角）
            Button {
                guard authManager.isAuthenticated else {
                    ToastCenter.shared.info("请先登录后再分享名片")
                    showLogin = true
                    return
                }
                shareOpen = true
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "square.and.arrow.up").font(.system(size: 9))
                    Text("分享").font(.system(size: 11))
                }
                .foregroundColor(.appMutedFg)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(Color.appBackground.opacity(0.8))
                .overlay(Capsule().stroke(Color.appBorder, lineWidth: 0.5))
                .clipShape(Capsule())
            }
            .buttonStyle(.plain)
            .padding(12)
        }
    }

    private func followStat(_ n: Int, _ label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text("\(n)")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.appForeground)
                Text(label)
                    .font(.system(size: 14))
                    .foregroundColor(.appMutedFg)
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: 动态入口卡（逐行复刻网页 Profile.tsx 2026-10-08：emerald 渐变 + Sparkles + ChevronRight）
    private func postsEntryCard(_ a: ProfileData.ProfileAuthor) -> some View {
        NavigationLink(destination: UserPostsView(userId: a.id, name: a.name ?? "TA")) {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.twEmerald500.opacity(0.1))
                        .frame(width: 44, height: 44)
                    Image(systemName: "sparkles")
                        .font(.system(size: 20))
                        .foregroundColor(.twEmerald600)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text("动态")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.appForeground)
                    Text(postsEntrySubtitle)
                        .font(.system(size: 12))
                        .foregroundColor(.appMutedFg)
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                Image(systemName: "chevron.right")
                    .font(.system(size: 14))
                    .foregroundColor(.appMutedFg)
            }
            .padding(16)
            .background(
                LinearGradient(colors: [Color.twEmerald500.opacity(0.08), Color.clear],
                               startPoint: .leading, endPoint: .trailing)
            )
            .cornerRadius(16)
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.appBorder, lineWidth: 0.5))
        }
        .buttonStyle(.plain)
    }

    private var postsEntrySubtitle: String {
        guard let pc = postCount, pc.restricted != true else { return "关注后可见" }
        let c = pc.count ?? 0
        return c > 0 ? "共 \(c) 条动态，点进去看看" : "还没有动态"
    }

    // MARK: 醒目入口（网页：卡片广场 + 个性化分享卡片 渐变卡）
    private var entryCards: some View {
        VStack(spacing: 12) {
            NavigationLink(destination: CardPlazaView()) {
                entryCard(icon: "megaphone",
                          iconColor: .appPrimary, iconBg: Color.appPrimary.opacity(0.1),
                          gradientTint: Color.appPrimary.opacity(0.08),
                          title: "卡片广场",
                          subtitle: "看看大家设计的分享卡片，点赞评论蹲同款")
            }
            .buttonStyle(.plain)
            NavigationLink(destination: isMe ? AnyView(CardStudioView()) : AnyView(CardPlazaView())) {
                entryCard(icon: "paintpalette",
                          iconColor: .twAmber600, iconBg: Color.twAmber500.opacity(0.1),
                          gradientTint: Color.twAmber500.opacity(0.08),
                          title: isMe ? "个性化分享卡片" : "分享卡片",
                          subtitle: isMe ? "设计你的专属橱窗分享卡片，换色系、传素材" : "去卡片广场看看 TA 的卡片设计")
            }
            .buttonStyle(.plain)
        }
    }

    private func entryCard(icon: String, iconColor: Color, iconBg: Color,
                           gradientTint: Color, title: String, subtitle: String) -> some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 4).fill(iconBg).frame(width: 44, height: 44)
                Image(systemName: icon).font(.system(size: 17)).foregroundColor(iconColor)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.appForeground)
                Text(subtitle)
                    .font(.system(size: 12))
                    .foregroundColor(.appMutedFg)
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
            Image(systemName: "chevron.right")
                .font(.system(size: 13))
                .foregroundColor(.appMutedFg)
        }
        .padding(16)
        .background(
            LinearGradient(colors: [gradientTint, Color.clear],
                           startPoint: .leading, endPoint: .trailing)
                .background(Color.appCard)
        )
        .cornerRadius(5)
        .overlay(RoundedRectangle(cornerRadius: 5).stroke(Color.appBorder, lineWidth: 0.5))
    }

    // MARK: 卡片作品（网页 UserCardsSection：SHOW ONLY 网格 + 本人公开开关）
    @ViewBuilder
    private var userCardsSection: some View {
        if let c = cards, c.visible, (isMe || !(c.items ?? []).isEmpty) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 8) {
                    Image(systemName: "megaphone")
                        .font(.system(size: 17))
                        .foregroundColor(.appPrimary)
                    Text(isMe ? "我的卡片" : "TA 的卡片")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.appForeground)
                    Text("发布到卡片广场的设计")
                        .font(.system(size: 12))
                        .foregroundColor(.appMutedFg)
                    Spacer()
                    if isMe {
                        Button { Task { await toggleCardsPublic() } } label: {
                            HStack(spacing: 4) {
                                Image(systemName: (c.cardsPublic ?? true) ? "eye" : "eye.slash")
                                    .font(.system(size: 11))
                                Text((c.cardsPublic ?? true) ? "对外展示中" : "已私密")
                                    .font(.system(size: 12))
                            }
                            .foregroundColor(.appMutedFg)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 4)
                            .overlay(Capsule().stroke(Color.appBorder, lineWidth: 0.5))
                        }
                        .buttonStyle(.plain)
                    }
                }
                let items = c.items ?? []
                if items.isEmpty {
                    NavigationLink(destination: CardPlazaView()) {
                        Text("还没有发布到卡片广场的卡片，去「个性化」页制作一套并发布吧 →")
                            .font(.system(size: 14))
                            .foregroundColor(.appMutedFg)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 32)
                            .overlay(RoundedRectangle(cornerRadius: 4)
                                .stroke(Color.appBorder, style: StrokeStyle(lineWidth: 0.5, dash: [4, 3])))
                    }
                    .buttonStyle(.plain)
                } else {
                    LazyVGrid(columns: [GridItem(.flexible(), spacing: 12),
                                        GridItem(.flexible(), spacing: 12),
                                        GridItem(.flexible(), spacing: 12)], spacing: 12) {
                        ForEach(items) { item in
                            NavigationLink(destination: CardPlazaView(initialPostId: item.id)) {
                                VStack(alignment: .leading, spacing: 6) {
                                    CardThemeThumbnailView(config: item.config)
                                        .aspectRatio(3.0 / 4.0, contentMode: .fit)
                                        .cornerRadius(4)
                                        .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color.appBorder, lineWidth: 0.5))
                                        .overlay(alignment: .topLeading) {
                                            Text("SHOW ONLY")
                                                .font(.system(size: 9, weight: .medium))
                                                .foregroundColor(.white)
                                                .padding(.horizontal, 6)
                                                .padding(.vertical, 1)
                                                .background(Color.black.opacity(0.55))
                                                .clipShape(Capsule())
                                                .padding(6)
                                        }
                                    Text(item.title)
                                        .font(.system(size: 12, weight: .medium))
                                        .foregroundColor(.appForeground)
                                        .lineLimit(1)
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
    }

    // MARK: 橱窗网格（网页：grid-cols-2 gap-5）
    private func showcaseSection(_ p: ProfileData) -> some View {
        let items = p.items ?? []
        return Group {
            if items.isEmpty {
                Text(isMe ? "你还没有发布橱窗，点右上角「发布橱窗」开始吧" : "TA 还没有发布橱窗")
                    .font(.system(size: 14))
                    .foregroundColor(.appMutedFg)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 80)
                    .overlay(RoundedRectangle(cornerRadius: 4)
                        .stroke(Color.appBorder, style: StrokeStyle(lineWidth: 0.5, dash: [4, 3])))
            } else {
                LazyVGrid(columns: [GridItem(.flexible(), spacing: 20), GridItem(.flexible(), spacing: 20)], spacing: 20) {
                    ForEach(items) { item in
                        NavigationLink(destination: ShowcaseDetailView(showcaseId: item.id)) {
                            ShowcaseCardView(item: item, isOwner: isMe)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    // MARK: 我的领取清单入口（网页 /bookmarks 行）
    private var bookmarksRow: some View {
        NavigationLink(destination: BookmarksView()) {
            HStack {
                Text("我的领取清单")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.appForeground)
                Spacer()
                Text("查看待领取的橱窗 →")
                    .font(.system(size: 12))
                    .foregroundColor(.appMutedFg)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .background(Color.appCard)
            .cornerRadius(4)
            .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color.appBorder, lineWidth: 0.5))
        }
        .buttonStyle(.plain)
    }

    // MARK: 补货提醒（网页：amber-50/amber-200 行）
    @ViewBuilder
    private var soldoutSection: some View {
        if !soldouts.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 8) {
                    Text("补货提醒")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.appForeground)
                    Text("有用户反馈这些橱窗的码已无法领取")
                        .font(.system(size: 12))
                        .foregroundColor(.appMutedFg)
                }
                ForEach(soldouts) { r in
                    HStack(spacing: 8) {
                        Button { showcaseRoute = r.showcaseId } label: {
                            Text(r.showcaseTitle ?? "")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.appPrimary)
                                .lineLimit(1)
                        }
                        .buttonStyle(.plain)
                        Text("\(r.markerName ?? "有用户")反馈码已领完")
                            .font(.system(size: 14))
                            .foregroundColor(.appMutedFg)
                            .lineLimit(1)
                        Spacer()
                        Text(DateFmt.zhFull(r.createdAt))
                            .font(.system(size: 12))
                            .foregroundColor(.appMutedFg)
                    }
                    .padding(16)
                    .background(Color.twAmber50)
                    .cornerRadius(4)
                    .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color.twAmber200, lineWidth: 0.5))
                }
            }
        }
    }

    // MARK: 收到的「我想领」（网页：contact 等宽字体行）
    @ViewBuilder
    private var requestsSection: some View {
        if !requests.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                Text("收到的「我想领」")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.appForeground)
                Text("领取人发送的收货地址，请到对应橱窗页的「收到的地址」后台查看和导出。")
                    .font(.system(size: 11))
                    .foregroundColor(.appMutedFg)
                    .padding(.top, -8)
                ForEach(requests) { r in
                    HStack(spacing: 8) {
                        Button { showcaseRoute = r.showcaseId } label: {
                            Text(r.showcaseTitle ?? "")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.appPrimary)
                                .lineLimit(1)
                        }
                        .buttonStyle(.plain)
                        Text("\(r.requesterName ?? "匿名用户")：")
                            .font(.system(size: 14))
                            .foregroundColor(.appMutedFg)
                        Text(r.contact ?? "")
                            .font(.system(size: 14, design: .monospaced))
                            .foregroundColor(.appForeground.opacity(0.9))
                            .lineLimit(1)
                        Spacer()
                        Text(DateFmt.zhFull(r.createdAt))
                            .font(.system(size: 12))
                            .foregroundColor(.appMutedFg)
                    }
                    .padding(16)
                    .background(Color.appCard)
                    .cornerRadius(4)
                    .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color.appBorder, lineWidth: 0.5))
                }
            }
        }
    }

    // MARK: 数据
    private func load() async {
        loading = true
        // 全部并行请求（网页也是并发的），主信息回来就先上屏
        async let pReq = MashanglingAPI.shared.showcase.byUser(userId: userId)
        async let cReq = MashanglingAPI.shared.card.forUser(userId: userId)
        async let bReq = MashanglingAPI.shared.gift.publicBadges(userId: userId)
        async let f1 = MashanglingAPI.shared.follow.followers(userId: userId)
        async let f2 = MashanglingAPI.shared.follow.followingOf(userId: userId)
        async let f3 = MashanglingAPI.shared.follow.friends(userId: userId)
        async let meReq: [FollowUser]? = authManager.isAuthenticated && isMe
            ? MashanglingAPI.shared.follow.list() : nil
        async let soReq: [SoldoutReceivedRow]? = authManager.isAuthenticated && isMe
            ? MashanglingAPI.shared.soldout.received() : nil
        async let rqReq: [RequestReceivedRow]? = authManager.isAuthenticated && isMe
            ? MashanglingAPI.shared.request.received() : nil
        async let fsReq: FollowStatus? = authManager.isAuthenticated && !isMe
            ? MashanglingAPI.shared.follow.status(userId: userId) : nil
        async let muReq: MutualWithResponse? = authManager.isAuthenticated && !isMe
            ? MashanglingAPI.shared.follow.mutualWith(userId: userId) : nil
        async let pcReq = MashanglingAPI.shared.post.countByUser(userId: userId)

        if let p = try? await pReq {
            profile = p
            isError = false
        } else {
            isError = true
        }
        loading = false
        cards = try? await cReq
        badges = (try? await bReq) ?? []
        followerCount = (try? await f1)?.count ?? 0
        followingCount = (try? await f2)?.count ?? 0
        friendCount = (try? await f3)?.count ?? 0
        myFollowing = (try? await meReq) ?? []
        soldouts = (try? await soReq) ?? []
        requests = (try? await rqReq) ?? []
        followStatus = try? await fsReq
        mutualCount = (try? await muReq)?.count ?? 0
        postCount = try? await pcReq
    }

    private func loadFollowLists() async {
        async let f1 = MashanglingAPI.shared.follow.followers(userId: userId)
        async let f2 = MashanglingAPI.shared.follow.followingOf(userId: userId)
        async let f3 = MashanglingAPI.shared.follow.friends(userId: userId)
        followerCount = (try? await f1)?.count ?? 0
        followingCount = (try? await f2)?.count ?? 0
        friendCount = (try? await f3)?.count ?? 0
    }

    private func toggleFollow() async {
        do {
            let r = try await MashanglingAPI.shared.follow.toggle(userId: userId)
            followStatus = FollowStatus(following: r.following, special: r.special ?? false,
                                        followerCount: (followStatus?.followerCount ?? 0) + (r.following ? 1 : -1))
            ToastCenter.shared.success(r.following ? "已关注" : "已取消关注")
            await loadFollowLists()
        } catch { ToastCenter.shared.error(error.localizedDescription) }
    }

    private func toggleSpecial() async {
        let target = !(followStatus?.special ?? false)
        do {
            _ = try await MashanglingAPI.shared.follow.setSpecial(userId: userId, special: target)
            followStatus = FollowStatus(following: followStatus?.following ?? true,
                                        special: target, followerCount: followStatus?.followerCount)
            ToastCenter.shared.success(target ? "已设为特别关注，TA 发布/补码时会通知你" : "已取消特别关注")
        } catch { ToastCenter.shared.error(error.localizedDescription) }
    }

    private func toggleCardsPublic() async {
        do {
            let pub = try await MashanglingAPI.shared.card.togglePublic()
            ToastCenter.shared.success(pub ? "卡片已对外展示" : "卡片已设为仅自己可见")
            cards = try? await MashanglingAPI.shared.card.forUser(userId: userId)
        } catch { ToastCenter.shared.error(error.localizedDescription) }
    }
}

// MARK: - 名字旁好友徽章（网页 FriendBadgesInline：24px 图标，点开看详情）
struct FriendBadgesInlineView: View {
    let badges: [PublicBadge]
    @State private var active: PublicBadge? = nil

    var body: some View {
        if !badges.isEmpty {
            HStack(spacing: 4) {
                ForEach(badges) { b in
                    Button { active = b } label: {
                        AppImage(path: b.image, contentMode: .fit)
                            .frame(width: 24, height: 24)
                    }
                    .buttonStyle(.plain)
                }
            }
            .sheet(item: $active) { b in
                BadgeDetailSheet(badge: b)
            }
        }
    }
}

struct BadgeDetailSheet: View {
    let badge: PublicBadge
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                AppImage(path: badge.image, contentMode: .fit)
                    .frame(maxWidth: 80, maxHeight: 80)
                    .padding(8)
                    .background(Color.white)
                    .cornerRadius(5)
                    .overlay(RoundedRectangle(cornerRadius: 5).stroke(Color.appBorder, lineWidth: 0.5))
                    .padding(.top, 8)
                Text("这是与好友 \(badge.friendName ?? "") 的徽章")
                    .font(.system(size: 14))
                    .foregroundColor(.appForeground)
                    .padding(.top, 12)
                Text("好友好感 Lv.\(badge.level ?? 0) · \(badge.uploadedByMe == true ? "由本人上传" : "由 \(badge.friendName ?? "") 上传")")
                    .font(.system(size: 12))
                    .foregroundColor(.appMutedFg)
                    .padding(.top, 4)
            }
            .padding(20)
            .background(Color.appBackground)
            .navigationTitle("好友徽章")
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
    }
}

// MARK: - 好友好感卡（网页 FriendshipCard：仅互关可见，brand 色系）
struct FriendshipCardView: View {
    let peerId: Int

    @State private var info: FriendshipInfo? = nil
    @State private var showPicker = false
    @State private var pickImage: UIImage? = nil
    @State private var editingBadgeId: Int? = nil
    @State private var busy = false

    var body: some View {
        Group {
            if let d = info, d.mutual {
                cardContent(d)
            }
        }
        .task { await load() }
        .sheet(isPresented: $showPicker) { ImagePicker(image: $pickImage) }
        .onChange(of: pickImage) { img in
            if let img = img { Task { await uploadBadge(img) } }
        }
    }

    @ViewBuilder
    private func cardContent(_ d: FriendshipInfo) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            friendshipHeader(d)
            friendshipProgress(d)
            Text("涨好感：互赠礼物（最快）、给彼此的橱窗/卡片点赞、想领/想要、收藏、评论、领到反馈")
                .font(.system(size: 11))
                .foregroundColor(.appMutedFg)
                .padding(.top, 6)
            badgeWall(d)
            HStack(spacing: 4) {
                Image(systemName: "gift").font(.system(size: 9))
                Text("赠礼是涨好感最快的方式：去对方橱窗点「分享 → 以礼物分享」，或让对方赠礼给你")
                    .font(.system(size: 11))
            }
            .foregroundColor(.appMutedFg)
            .padding(.top, 8)
        }
        .padding(16)
        .background(Color.appBrand50.opacity(0.5))
        .cornerRadius(5)
        .overlay(RoundedRectangle(cornerRadius: 5).stroke(Color.appBrand200, lineWidth: 0.5))
    }

    private func friendshipHeader(_ d: FriendshipInfo) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "heart.fill")
                .font(.system(size: 13))
                .foregroundColor(.appBrand400)
            Text("好友好感 Lv.\(d.level ?? 0)")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.appForeground)
            Spacer()
            Text("累计 \(d.total ?? 0) · 可用 \(d.balance ?? 0)")
                .font(.system(size: 12))
                .foregroundColor(.appMutedFg)
        }
    }

    private func friendshipProgress(_ d: FriendshipInfo) -> some View {
        let into = (d.total ?? 0) - (d.levelStart ?? 0)
        let need = max(1, d.nextNeed ?? 1)
        return VStack(alignment: .leading, spacing: 6) {
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.appBrand100).frame(height: 6)
                    Capsule().fill(Color.appBrand400)
                        .frame(width: geo.size.width * min(1, CGFloat(into) / CGFloat(need)), height: 6)
                }
            }
            .frame(height: 6)
            Text("再互赠 \(need - into) 点好感升到 Lv.\((d.level ?? 0) + 1)（升级不扣好感）")
                .font(.system(size: 11))
                .foregroundColor(.appMutedFg)
        }
        .padding(.top, 8)
    }

    private func badgeWall(_ d: FriendshipInfo) -> some View {
        HStack(spacing: 8) {
            ForEach(d.badges ?? []) { b in
                badgeCell(b)
            }
            Button {
                editingBadgeId = nil
                showPicker = true
            } label: {
                Image(systemName: "plus.square")
                    .font(.system(size: 14))
                    .foregroundColor(.appBrand400)
                    .frame(width: 56, height: 56)
                    .overlay(RoundedRectangle(cornerRadius: 4)
                        .stroke(Color.appBrand300, style: StrokeStyle(lineWidth: 0.5, dash: [4, 3])))
            }
            .buttonStyle(.plain)
            .disabled(busy)
            Text((d.badges ?? []).isEmpty
                 ? "上传好友徽章（PNG），第 1 个消耗 \(d.nextBadgeCost ?? 0) 好感"
                 : "下一个徽章消耗 \(d.nextBadgeCost ?? 0) 好感")
                .font(.system(size: 11))
                .foregroundColor(.appMutedFg)
        }
        .padding(.top, 12)
    }

    private func badgeCell(_ b: FriendshipInfo.Badge) -> some View {
        ZStack(alignment: .topTrailing) {
            AppImage(path: b.image, contentMode: .fit)
                .frame(width: 56, height: 56)
                .opacity(b.isPublic == false ? 0.7 : 1)
            HStack(spacing: 2) {
                Button {
                    editingBadgeId = b.id
                    showPicker = true
                } label: {
                    Image(systemName: "pencil")
                        .font(.system(size: 8))
                        .foregroundColor(.appPrimaryFg)
                        .frame(width: 20, height: 20)
                        .background(Color.appPrimary)
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                Button { Task { await setBadgePublic(b) } } label: {
                    Image(systemName: b.isPublic == false ? "eye" : "eye.slash")
                        .font(.system(size: 8))
                        .foregroundColor(.appForeground)
                        .frame(width: 20, height: 20)
                        .background(Color.appSecondary)
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
            }
            .offset(x: 4, y: -4)
            if b.isPublic == false {
                Image(systemName: "eye.slash")
                    .font(.system(size: 8))
                    .foregroundColor(.appMutedFg)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
            }
        }
    }

    private func load() async {
        info = try? await MashanglingAPI.shared.gift.friendshipInfo(peerId: peerId)
    }

    private func uploadBadge(_ img: UIImage) async {
        pickImage = nil
        guard let dataURL = ImageCodec.pngDataURL(from: img, maxSide: 256) else {
            ToastCenter.shared.error("图片处理失败"); return
        }
        if dataURL.count * 3 / 4 > 300 * 1024 {
            ToastCenter.shared.error("图片不能超过 300KB"); return
        }
        busy = true
        defer { busy = false }
        do {
            if let bid = editingBadgeId {
                _ = try await MashanglingAPI.shared.gift.updateBadge(badgeId: bid, image: dataURL)
                ToastCenter.shared.success("徽章已更新")
            } else {
                let cost = try await MashanglingAPI.shared.gift.uploadBadge(peerId: peerId, image: dataURL)
                ToastCenter.shared.success("徽章已上传（消耗 \(cost) 好感）")
            }
            await load()
        } catch { ToastCenter.shared.error(error.localizedDescription) }
    }

    private func setBadgePublic(_ b: FriendshipInfo.Badge) async {
        let target = !(b.isPublic ?? false)
        do {
            _ = try await MashanglingAPI.shared.gift.setBadgePublic(badgeId: b.id, isPublic: target)
            ToastCenter.shared.success(target ? "徽章已对外展示" : "徽章已隐藏，仅你们双方可见")
            await load()
        } catch { ToastCenter.shared.error(error.localizedDescription) }
    }
}

// MARK: - 分享名片弹窗（网页 ShareProfileDialog：好友 + 已有私信会话）
struct ShareProfileSheet: View {
    let profileUserId: Int
    let profileName: String

    @Environment(\.dismiss) private var dismiss
    @State private var recipients: [(id: Int, name: String, avatar: String?)] = []
    @State private var loading = true
    @State private var sentTo: Set<Int> = []
    @State private var sending = false

    var body: some View {
        NavigationStack {
            Group {
                if loading {
                    LoadingView().frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if recipients.isEmpty {
                    Text("还没有可分享的人——去对方的个人页发一条私信，或互相关注成为好友后就能分享名片了")
                        .font(.system(size: 14))
                        .foregroundColor(.appMutedFg)
                        .multilineTextAlignment(.center)
                        .padding(24)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List(recipients, id: \.id) { r in
                        HStack(spacing: 12) {
                            ZStack {
                                Circle().fill(Color.appSecondary).frame(width: 36, height: 36)
                                if let av = r.avatar, !av.isEmpty {
                                    AppImage(path: av)
                                        .aspectRatio(contentMode: .fill)
                                        .frame(width: 36, height: 36)
                                        .clipShape(Circle())
                                } else {
                                    Image(systemName: "person")
                                        .font(.system(size: 13))
                                        .foregroundColor(.appMutedFg)
                                }
                            }
                            Text(r.name)
                                .font(.system(size: 14))
                                .foregroundColor(.appForeground)
                                .lineLimit(1)
                            Spacer()
                            Button { Task { await share(r.id) } } label: {
                                HStack(spacing: 4) {
                                    Image(systemName: "paperplane").font(.system(size: 9))
                                    Text(sentTo.contains(r.id) ? "已分享" : "分享")
                                        .font(.system(size: 12, weight: sentTo.contains(r.id) ? .regular : .medium))
                                }
                                .foregroundColor(sentTo.contains(r.id) ? Color.appMutedFg : Color.appPrimaryFg)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(sentTo.contains(r.id) ? Color.appSecondary : Color.appPrimary)
                                .clipShape(Capsule())
                            }
                            .buttonStyle(.plain)
                            .disabled(sentTo.contains(r.id) || sending)
                        }
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                    }
                    .listStyle(.plain)
                }
            }
            .background(Color.appBackground)
            .navigationTitle("分享「\(profileName)」的名片")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("关闭") { dismiss() }
                        .font(.system(size: 13))
                        .foregroundColor(.appMutedFg)
                }
            }
            .safeAreaInset(edge: .bottom) {
                Text("对方会在私信里收到这张名片，点开即可进入「\(profileName)」的个人主页。")
                    .font(.system(size: 11))
                    .foregroundColor(.appMutedFg)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 8)
            }
        }
        .presentationDetents([.medium, .large])
        .task {
            let friends = (try? await MashanglingAPI.shared.follow.mutuals()) ?? []
            let convos = (try? await MashanglingAPI.shared.dm.conversations()) ?? []
            var seen = Set<Int>()
            var list: [(id: Int, name: String, avatar: String?)] = []
            for f in friends where f.userId != profileUserId && !seen.contains(f.userId) {
                seen.insert(f.userId)
                list.append((f.userId, f.name ?? "", f.avatar))
            }
            for c in convos where c.peerId != profileUserId && !seen.contains(c.peerId) {
                seen.insert(c.peerId)
                list.append((c.peerId, c.peerName ?? "", c.peerAvatar))
            }
            recipients = list
            loading = false
        }
    }

    private func share(_ toUserId: Int) async {
        sending = true
        defer { sending = false }
        do {
            _ = try await MashanglingAPI.shared.dm.shareProfile(toUserId: toUserId, profileUserId: profileUserId)
            sentTo.insert(toUserId)
            ToastCenter.shared.success("名片已发送到私信")
        } catch { ToastCenter.shared.error(error.localizedDescription) }
    }
}

// MARK: - 我的关注（网页 FollowList：特别关注一组 + 普通一组，星标/取关按钮）
struct MyFollowListSection: View {
    let items: [FollowUser]
    var onChanged: () -> Void

    @State private var busy = false

    var body: some View {
        if !items.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 8) {
                    Text("我的关注")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.appForeground)
                    Text("\(items.count) 人")
                        .font(.system(size: 14))
                        .foregroundColor(.appMutedFg)
                }
                let specials = items.filter { $0.special == true }
                let normals = items.filter { $0.special != true }
                if !specials.isEmpty {
                    HStack(spacing: 6) {
                        Image(systemName: "star.fill")
                            .font(.system(size: 11))
                            .foregroundColor(.twAmber400)
                        Text("特别关注")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.twAmber600)
                        Text("TA 发布新橱窗或补码时，你会收到站内信 + 邮件")
                            .font(.system(size: 12))
                            .foregroundColor(.appMutedFg)
                            .lineLimit(1)
                    }
                    ForEach(specials) { u in followRow(u) }
                }
                ForEach(normals) { u in followRow(u) }
            }
        }
    }

    private func followRow(_ u: FollowUser) -> some View {
        HStack(spacing: 12) {
            NavigationLink(destination: ProfileView(userId: u.userId)) {
                HStack(spacing: 12) {
                    ZStack {
                        Circle().fill(Color.appPrimary.opacity(0.1)).frame(width: 40, height: 40)
                        if let av = u.avatar, !av.isEmpty {
                            AppImage(path: av)
                                .aspectRatio(contentMode: .fill)
                                .frame(width: 40, height: 40)
                                .clipShape(Circle())
                        } else {
                            Text((u.name ?? "U").prefix(1).uppercased())
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(.appPrimary)
                        }
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 6) {
                            Text(u.name ?? "")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.appForeground)
                            if let lv = u.level { LevelBadgeView(level: lv) }
                            TitleBadgeView(equippedTitle: u.equippedTitle)
                        }
                        if let bio = u.bio, !bio.isEmpty {
                            Text(bio)
                                .font(.system(size: 12))
                                .foregroundColor(.appMutedFg)
                                .lineLimit(1)
                        }
                    }
                }
            }
            .buttonStyle(.plain)
            Spacer()
            Button { Task { await setSpecial(u) } } label: {
                Image(systemName: u.special == true ? "star.fill" : "star")
                    .font(.system(size: 14))
                    .foregroundColor(u.special == true ? Color.twAmber500 : Color.appMutedFg)
                    .frame(width: 32, height: 32)
                    .background(u.special == true ? Color.twAmber50 : Color.clear)
                    .overlay(Circle().stroke(u.special == true ? Color.twAmber300 : Color.appBorder, lineWidth: 0.5))
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
            .disabled(busy)
            Button { Task { await unfollow(u) } } label: {
                Image(systemName: "person.badge.minus")
                    .font(.system(size: 13))
                    .foregroundColor(.appMutedFg)
                    .frame(width: 32, height: 32)
                    .overlay(Circle().stroke(Color.appBorder, lineWidth: 0.5))
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
            .disabled(busy)
        }
        .padding(12)
        .background(Color.appCard)
        .cornerRadius(4)
        .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color.appBorder, lineWidth: 0.5))
    }

    private func setSpecial(_ u: FollowUser) async {
        busy = true
        defer { busy = false }
        do {
            _ = try await MashanglingAPI.shared.follow.setSpecial(userId: u.userId, special: u.special != true)
            ToastCenter.shared.success(u.special == true ? "已取消特别关注" : "已设为特别关注，TA 发布/补码时会通知你")
            onChanged()
        } catch { ToastCenter.shared.error(error.localizedDescription) }
    }

    private func unfollow(_ u: FollowUser) async {
        busy = true
        defer { busy = false }
        do {
            _ = try await MashanglingAPI.shared.follow.toggle(userId: u.userId)
            ToastCenter.shared.success("已取消关注")
            onChanged()
        } catch { ToastCenter.shared.error(error.localizedDescription) }
    }
}

// MARK: - 签名编辑弹窗（网页 bioOpen Dialog：限 200 字）
struct BioSheet: View {
    let current: String
    var onSaved: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var draft = ""
    @State private var busy = false

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 0) {
                TextEditor(text: $draft)
                    .font(.system(size: 14))
                    .foregroundColor(.appForeground)
                    .frame(height: 120)
                    .padding(8)
                    .background(Color.appCard)
                    .cornerRadius(4)
                    .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color.appInput, lineWidth: 0.5))
                    .onChange(of: draft) { v in
                        if v.count > 200 { draft = String(v.prefix(200)) }
                    }
                Text("\(draft.count)/200")
                    .font(.system(size: 11))
                    .foregroundColor(.appMutedFg)
                    .frame(maxWidth: .infinity, alignment: .trailing)
                    .padding(.top, 4)
                HStack(spacing: 8) {
                    Button("取消") { dismiss() }
                        .font(.system(size: 14))
                        .foregroundColor(.appForeground)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .overlay(Capsule().stroke(Color.appBorder, lineWidth: 0.5))
                    Button { Task { await save() } } label: {
                        Text(busy ? "保存中…" : "保存签名")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.appPrimaryFg)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(Color.appPrimary)
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                    .disabled(busy)
                }
                .padding(.top, 8)
                Spacer()
            }
            .padding(20)
            .background(Color.appBackground)
            .navigationTitle("个人签名")
            .navigationBarTitleDisplayMode(.inline)
        }
        .presentationDetents([.medium])
        .onAppear { draft = current }
    }

    private func save() async {
        busy = true
        defer { busy = false }
        do {
            _ = try await MashanglingAPI.shared.settings.updateBio(draft)
            ToastCenter.shared.success("签名已更新")
            dismiss()
            onSaved()
        } catch { ToastCenter.shared.error(error.localizedDescription) }
    }
}

// MARK: - 粉丝 / 关注 / 好友 / 共同好友列表弹窗（网页 FollowStats 弹层）
struct FollowListSheet: View {
    let userId: Int
    var mode: Int = 0   // 0 粉丝 1 关注 2 好友 3 共同好友

    @Environment(\.dismiss) private var dismiss
    @State private var items: [FollowUser] = []
    @State private var count = 0
    @State private var loading = true

    private var title: String {
        switch mode { case 1: return "关注"; case 2: return "好友"; case 3: return "共同好友"; default: return "粉丝" }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if mode == 2 {
                    Text("互相关注才是好友；分享橱窗、卡片码、转发卡片都仅限好友之间。")
                        .font(.system(size: 11))
                        .foregroundColor(.appMutedFg)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 8)
                        .background(Color.appSecondary.opacity(0.4))
                }
                Group {
                    if loading {
                        Text("加载中…")
                            .font(.system(size: 14))
                            .foregroundColor(.appMutedFg)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else if items.isEmpty {
                        Text(mode == 0 ? "还没有粉丝"
                             : mode == 1 ? "还没有关注任何人"
                             : mode == 3 ? "你们还没有共同好友"
                             : "还没有好友——互相关注即成为好友")
                            .font(.system(size: 14))
                            .foregroundColor(.appMutedFg)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else {
                        ScrollView {
                            VStack(spacing: 10) {
                                ForEach(items) { u in
                                    NavigationLink(destination: ProfileView(userId: u.userId)) {
                                        HStack(spacing: 12) {
                                            ZStack {
                                                Circle().fill(Color.appPrimary.opacity(0.1)).frame(width: 40, height: 40)
                                                if let av = u.avatar, !av.isEmpty {
                                                    AppImage(path: av)
                                                        .aspectRatio(contentMode: .fill)
                                                        .frame(width: 40, height: 40)
                                                        .clipShape(Circle())
                                                } else {
                                                    Text((u.name ?? "U").prefix(1).uppercased())
                                                        .font(.system(size: 14, weight: .bold))
                                                        .foregroundColor(.appPrimary)
                                                }
                                            }
                                            VStack(alignment: .leading, spacing: 2) {
                                                HStack(spacing: 6) {
                                                    Text(u.name ?? "")
                                                        .font(.system(size: 14, weight: .medium))
                                                        .foregroundColor(.appForeground)
                                                    if let lv = u.level, mode != 3 { LevelBadgeView(level: lv) }
                                                    if mode != 3 { TitleBadgeView(equippedTitle: u.equippedTitle) }
                                                    if mode == 1, u.special == true {
                                                        Image(systemName: "star.fill")
                                                            .font(.system(size: 11))
                                                            .foregroundColor(.twAmber400)
                                                    }
                                                }
                                                if let bio = u.bio, !bio.isEmpty {
                                                    Text(bio)
                                                        .font(.system(size: 12))
                                                        .foregroundColor(.appMutedFg)
                                                        .lineLimit(1)
                                                }
                                            }
                                            Spacer()
                                        }
                                        .padding(12)
                                        .background(Color.appCard)
                                        .cornerRadius(4)
                                        .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color.appBorder, lineWidth: 0.5))
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(16)
                        }
                    }
                }
            }
            .background(Color.appBackground)
            .navigationTitle("\(title) \(count) 人")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 14))
                            .foregroundColor(.appMutedFg)
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .task {
            switch mode {
            case 1:
                let r = try? await MashanglingAPI.shared.follow.followingOf(userId: userId)
                items = r?.items ?? []; count = r?.count ?? items.count
            case 2:
                items = (try? await MashanglingAPI.shared.follow.friends(userId: userId)) ?? []
                count = items.count
            case 3:
                let r = try? await MashanglingAPI.shared.follow.mutualWith(userId: userId)
                items = r?.items ?? []; count = r?.count ?? items.count
            default:
                let r = try? await MashanglingAPI.shared.follow.followers(userId: userId)
                items = r?.items ?? []; count = r?.count ?? items.count
            }
            loading = false
        }
    }
}
