import SwiftUI

// MARK: - 个人主页（对应网页 Profile.tsx / UserPage.tsx）
struct ProfileView: View {
    let userId: Int

    @EnvironmentObject var authManager: AuthManager
    @State private var profile: ProfileData? = nil
    @State private var points: PointsMy? = nil
    @State private var followStatus: FollowStatus? = nil
    @State private var cards: UserCardsResponse? = nil
    @State private var badges: [PublicBadge] = []
    @State private var loading = true
    @State private var showLogin = false
    @State private var showFollowList = false
    @State private var followListMode = 0 // 0 粉丝 1 关注 2 好友

    private var isMe: Bool { authManager.currentUser?.id == userId }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 16) {
                if let p = profile, let a = p.author {
                    header(a, p)
                } else if loading {
                    LoadingView()
                } else {
                    EmptyStateView(icon: "person", title: "用户不存在")
                }

                if isMe {
                    // 数据看板 + 卡片广场数据（仅本人可见，对应网页 StatsDashboard / CardStatsPanel）
                    StatsDashboardView()
                    CardStatsPanelView()
                    myShortcuts
                }

                // 农场
                if let a = profile?.author {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("农场")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(.appForeground)
                        FarmView(userId: a.id, embedded: true)
                    }
                }

                // 卡片作品
                if let c = cards, c.visible, let items = c.items, !items.isEmpty {
                    cardsSection(items)
                }

                // 好友徽章
                if !badges.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("好友徽章")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(.appForeground)
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(badges) { b in
                                    VStack(spacing: 3) {
                                        AppImage(path: b.image)
                                            .frame(width: 44, height: 44)
                                            .cornerRadius(8)
                                        Text(b.friendName ?? "")
                                            .font(.system(size: 9))
                                            .foregroundColor(.appMutedFg)
                                            .lineLimit(1)
                                    }
                                }
                            }
                        }
                    }
                }

                // 橱窗列表
                if let p = profile {
                    showcaseSection(p)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
        }
        .background(Color.appBackground.ignoresSafeArea())
        .navigationTitle(isMe ? "我的" : (profile?.author?.name ?? "主页"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if isMe {
                ToolbarItem(placement: .navigationBarTrailing) {
                    NavigationLink(destination: SettingsView()) {
                        Image(systemName: "gearshape")
                            .foregroundColor(.appForeground)
                    }
                }
            }
        }
        .task { await load() }
        .refreshable { await load() }
        .sheet(isPresented: $showLogin) { LoginView() }
        .sheet(isPresented: $showFollowList) {
            FollowListSheet(userId: userId, mode: followListMode)
        }
    }

    // MARK: 头部
    private func header(_ a: ProfileData.ProfileAuthor, _ p: ProfileData) -> some View {
        VStack(spacing: 12) {
            HStack(spacing: 14) {
                AvatarView(path: a.avatar, name: a.name ?? "", size: 64)
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text(a.name ?? "未知用户")
                            .font(.system(size: 19, weight: .bold))
                            .foregroundColor(.appForeground)
                        if a.isBot == true {
                            MiniBadge(text: "官方", fg: .appPrimaryFg, bg: .appPrimary)
                        }
                    }
                    HStack(spacing: 6) {
                        if let lv = a.level { LevelBadgeView(level: lv) }
                        TitleBadgeView(equippedTitle: a.equippedTitle)
                    }
                    if let bio = a.bio, !bio.isEmpty {
                        Text(bio)
                            .font(.system(size: 12))
                            .foregroundColor(.appMutedFg)
                            .lineLimit(2)
                    }
                }
                Spacer()
            }

            // 数据行
            HStack(spacing: 0) {
                statCell("\(p.items?.count ?? 0)", label: "橱窗")
                Button { followListMode = 0; showFollowList = true } label: {
                    statCell("\(a.followerCount ?? 0)", label: "粉丝")
                }
                .buttonStyle(.plain)
                statCell("\(p.totalLikes ?? 0)", label: "获赞")
                statCell("\(p.totalClaims ?? 0)", label: "被领到")
                statCell("\(p.cardFavCount ?? 0)", label: "卡片收藏")
            }
            .padding(.vertical, 10)
            .background(Color.appCard)
            .cornerRadius(12)
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.appBorder, lineWidth: 0.5))

            // 积分概览（仅自己）
            if isMe, let pt = points {
                SectionCard {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("积分 \(pt.points)")
                                .font(.system(size: 15, weight: .bold))
                                .foregroundColor(.appForeground)
                            Text("可用 \(pt.available)")
                                .font(.system(size: 11))
                                .foregroundColor(.appMutedFg)
                            Spacer()
                            NavigationLink(destination: PointsView()) {
                                Text("积分与等级 →")
                                    .font(.system(size: 12))
                                    .foregroundColor(.appPrimary)
                            }
                        }
                        // 等级进度
                        let lv = Levels.levelFromPoints(pt.points)
                        VStack(alignment: .leading, spacing: 3) {
                            ProgressView(value: lv.need > 0 ? Double(lv.into) / Double(lv.need) : 1)
                                .tint(.appPrimary)
                            Text("Lv.\(lv.level) \(Levels.band(of: lv.level))" +
                                 (lv.need > 0 ? " · 距下一级 \(lv.need - lv.into)" : " · 已满级"))
                                .font(.system(size: 10))
                                .foregroundColor(.appMutedFg)
                        }
                    }
                }
            }

            // 操作行（他人主页）
            if !isMe {
                HStack(spacing: 10) {
                    Button {
                        guard authManager.isAuthenticated else { showLogin = true; return }
                        Task { await toggleFollow() }
                    } label: {
                        Text(followStatus?.following == true
                             ? (followStatus?.special == true ? "★ 特别关注" : "已关注")
                             : "关注")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(followStatus?.following == true ? .appForeground : .appPrimaryFg)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(followStatus?.following == true ? Color.appSecondary : Color.appPrimary)
                            .cornerRadius(12)
                    }
                    NavigationLink(destination: DmThreadView(peerId: userId, peerName: a.name ?? "")) {
                        Text("私信")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.appPrimary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.appPrimary, lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func statCell(_ value: String, label: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.system(size: 15, weight: .bold))
                .foregroundColor(.appForeground)
            Text(label)
                .font(.system(size: 10))
                .foregroundColor(.appMutedFg)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: 我的快捷入口
    private var myShortcuts: some View {
        let isAdmin = authManager.currentUser?.isAdmin == true
        return LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
            shortcut("领取申请", icon: "checkmark.rectangle", dest: AnyView(ClaimsView()))
            shortcut("快递后台", icon: "shippingbox", dest: AnyView(ShippingView()))
            shortcut("我的快递", icon: "cube.box", dest: AnyView(MyShipmentsView()))
            shortcut("我的清单", icon: "bookmark", dest: AnyView(BookmarksView()))
            shortcut("浏览记录", icon: "clock.arrow.circlepath", dest: AnyView(BrowseHistoryView()))
            shortcut("我的评论", icon: "text.bubble", dest: AnyView(MyCommentsView()))
            shortcut("积分等级", icon: "trophy", dest: AnyView(PointsView()))
            shortcut("个性化", icon: "paintpalette", dest: AnyView(CardStudioView()))
            // 管理员入口（对应网页头像菜单的管理员项）
            if isAdmin {
                shortcut("举报处理", icon: "shield", dest: AnyView(AdminView()))
                shortcut("标签管理", icon: "tag", dest: AnyView(AdminTagsView()))
            }
        }
    }

    private func shortcut(_ label: String, icon: String, dest: AnyView) -> some View {
        NavigationLink(destination: dest) {
            VStack(spacing: 5) {
                Image(systemName: icon)
                    .font(.system(size: 15))
                    .foregroundColor(.appPrimary)
                    .frame(width: 34, height: 34)
                    .background(Color.appSecondary)
                    .cornerRadius(9)
                Text(label)
                    .font(.system(size: 10))
                    .foregroundColor(.appForeground)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(Color.appCard)
            .cornerRadius(10)
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.appBorder, lineWidth: 0.5))
        }
        .buttonStyle(.plain)
    }

    // MARK: 卡片作品
    private func cardsSection(_ items: [UserCardsResponse.UserCardItem]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("卡片作品")
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(.appForeground)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(items) { c in
                        VStack(alignment: .leading, spacing: 4) {
                            CardThemeThumbnailView(config: c.config)
                                .frame(width: 110)
                                .cornerRadius(10)
                                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.appBorder, lineWidth: 0.5))
                            Text(c.title)
                                .font(.system(size: 10, weight: .medium))
                                .foregroundColor(.appForeground)
                                .lineLimit(1)
                                .frame(width: 110, alignment: .leading)
                        }
                    }
                }
            }
        }
    }

    // MARK: 橱窗列表
    private func showcaseSection(_ p: ProfileData) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(isMe ? "我发布的橱窗" : "TA 的橱窗")
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(.appForeground)
            if (p.items ?? []).isEmpty {
                Text("还没有发布橱窗")
                    .font(.system(size: 13))
                    .foregroundColor(.appMutedFg)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 30)
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.appBorder, style: StrokeStyle(lineWidth: 1, dash: [6])))
            } else {
                LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                    ForEach(p.items ?? []) { item in
                        NavigationLink(destination: ShowcaseDetailView(showcaseId: item.id)) {
                            ShowcaseCardView(item: item, isOwner: isMe)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    // MARK: 数据
    private func load() async {
        loading = true
        defer { loading = false }
        profile = try? await MashanglingAPI.shared.showcase.byUser(userId: userId)
        cards = try? await MashanglingAPI.shared.card.forUser(userId: userId)
        badges = (try? await MashanglingAPI.shared.gift.publicBadges(userId: userId)) ?? []
        if authManager.isAuthenticated {
            if isMe {
                points = try? await MashanglingAPI.shared.points.my()
            } else {
                followStatus = try? await MashanglingAPI.shared.follow.status(userId: userId)
            }
        }
    }

    private func toggleFollow() async {
        do {
            let r = try await MashanglingAPI.shared.follow.toggle(userId: userId)
            followStatus = FollowStatus(following: r.following, special: r.special ?? false,
                                        followerCount: (followStatus?.followerCount ?? 0) + (r.following ? 1 : -1))
            ToastCenter.shared.success(r.following ? "已关注" : "已取消关注")
        } catch { ToastCenter.shared.error(error.localizedDescription) }
    }
}

// MARK: - 粉丝 / 关注 / 好友列表弹窗
struct FollowListSheet: View {
    let userId: Int
    var mode: Int = 0

    @Environment(\.dismiss) private var dismiss
    @State private var items: [FollowUser] = []
    @State private var count = 0
    @State private var loading = true

    private var title: String {
        switch mode { case 1: return "关注"; case 2: return "好友"; default: return "粉丝" }
    }

    var body: some View {
        NavigationStack {
            Group {
                if loading {
                    LoadingView()
                } else if items.isEmpty {
                    Text("暂无数据")
                        .font(.system(size: 13))
                        .foregroundColor(.appMutedFg)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List(items) { u in
                        NavigationLink(destination: ProfileView(userId: u.userId)) {
                            HStack(spacing: 10) {
                                AvatarView(path: u.avatar, name: u.name ?? "", size: 36)
                                VStack(alignment: .leading, spacing: 2) {
                                    HStack(spacing: 5) {
                                        Text(u.name ?? "").font(.system(size: 13, weight: .medium))
                                        if let lv = u.level { LevelBadgeView(level: lv) }
                                        TitleBadgeView(equippedTitle: u.equippedTitle, plain: true)
                                    }
                                    if let bio = u.bio, !bio.isEmpty {
                                        Text(bio).font(.system(size: 11)).foregroundColor(.appMutedFg).lineLimit(1)
                                    }
                                }
                                Spacer()
                                if u.mutual == true {
                                    MiniBadge(text: "互关", fg: .appPrimary, bg: .appPrimary.opacity(0.1))
                                }
                            }
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .background(Color.appBackground)
            .navigationTitle("\(title)（\(count)）")
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
            switch mode {
            case 1:
                let r = try? await MashanglingAPI.shared.follow.followingOf(userId: userId)
                items = r?.items ?? []; count = r?.count ?? items.count
            case 2:
                items = (try? await MashanglingAPI.shared.follow.friends(userId: userId)) ?? []
                count = items.count
            default:
                let r = try? await MashanglingAPI.shared.follow.followers(userId: userId)
                items = r?.items ?? []; count = r?.count ?? items.count
            }
            loading = false
        }
    }
}
