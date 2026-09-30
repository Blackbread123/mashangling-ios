import SwiftUI

// MARK: - 搜索页（复刻 SearchPage.tsx）
struct SearchView: View {
    @State private var input = ""
    @State private var q = ""            // 已提交的搜索词

    @State private var matchedTags: [Tag] = []
    @State private var matchedUsers: [FollowUser] = []
    @State private var cardPosts: [CardSearchResult] = []
    @State private var codeMatch: CardCodeMatch? = nil
    @State private var importing = false
    @State private var openPostId: Int? = nil

    @EnvironmentObject var authManager: AuthManager

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // 搜索框
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.appMutedFg)
                    TextField("搜索无料码 / 卡片码 / 卡片标题 / 用户昵称…", text: $input)
                        .font(.system(size: 13))
                        .autocapitalization(.none)
                        .onSubmit { submit() }
                    if !input.isEmpty {
                        Button { input = ""; q = "" } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.appMutedFg)
                        }
                    }
                }
                .padding(.horizontal, 14)
                .frame(height: 44)
                .background(Color.appCard)
                .overlay(Capsule().stroke(Color.appInput, lineWidth: 1))
                .clipShape(Capsule())

                if !q.isEmpty {
                    Text("「\(q)」的搜索结果")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.appForeground)
                    Text("优先匹配无料码，其次是发布人昵称和标题/简介关键词；也可直接搜用户昵称或用户 ID")
                        .font(.system(size: 11))
                        .foregroundColor(.appMutedFg)

                    // 相关用户
                    if !matchedUsers.isEmpty {
                        sectionTitle("相关用户")
                        ForEach(matchedUsers) { u in
                            NavigationLink { ProfileView(userId: u.userId) } label: {
                                HStack(spacing: 10) {
                                    AvatarView(path: u.avatar, name: u.name ?? "U", size: 40)
                                    VStack(alignment: .leading, spacing: 2) {
                                        HStack(spacing: 5) {
                                            Text(u.name ?? "未知用户")
                                                .font(.system(size: 13, weight: .medium))
                                                .foregroundColor(.appForeground)
                                            LevelBadgeView(level: u.level ?? 1)
                                            TitleBadgeView(equippedTitle: u.equippedTitle, plain: true)
                                        }
                                        Text("ID: \(u.userId) · \(u.followerCount ?? 0) 粉丝\((u.bio?.isEmpty == false) ? " · \(u.bio!)" : "")")
                                            .font(.system(size: 11))
                                            .foregroundColor(.appMutedFg)
                                            .lineLimit(1)
                                    }
                                    Spacer()
                                }
                                .padding(12)
                                .background(Color.appCard)
                                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.appBorder, lineWidth: 0.5))
                                .cornerRadius(12)
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    // 相关标签
                    if !matchedTags.isEmpty {
                        sectionTitle("相关标签")
                        FlowLayout(spacing: 6) {
                            ForEach(matchedTags) { t in
                                NavigationLink { TagDetailView(tagId: t.id) } label: {
                                    HStack(spacing: 3) {
                                        Text("# \(t.name)")
                                            .font(.system(size: 11))
                                        Text("·\(TagCategory.label(t.category))")
                                            .font(.system(size: 10))
                                            .foregroundColor(.appMutedFg)
                                    }
                                    .foregroundColor(.appForeground)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(Color.appCard)
                                    .overlay(Capsule().stroke(Color.appBorder, lineWidth: 1))
                                }
                            }
                        }
                    }

                    // 卡片码精确匹配
                    if let m = codeMatch {
                        HStack(spacing: 5) {
                            Image(systemName: "megaphone")
                                .font(.system(size: 12))
                            Text("卡片码匹配")
                        }
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.appMutedFg)

                        HStack(spacing: 14) {
                            if let cfg = m.config {
                                CardThemeThumbnailView(config: cfg)
                                    .frame(width: 84, height: 112)
                                    .cornerRadius(10)
                                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.appBorder, lineWidth: 0.5))
                            }
                            VStack(alignment: .leading, spacing: 4) {
                                Text(m.name)
                                    .font(.system(size: 13, weight: .bold))
                                    .foregroundColor(.appForeground)
                                    .lineLimit(1)
                                Text("来自 \(m.ownerName ?? "未知用户") 的设计")
                                    .font(.system(size: 11))
                                    .foregroundColor(.appMutedFg)
                                Button {
                                    guard authManager.isAuthenticated else {
                                        ToastCenter.shared.show("请先登录")
                                        return
                                    }
                                    Task { await importCard(m.code) }
                                } label: {
                                    Text(importing ? "导入中…" : "导入这套卡片")
                                        .font(.system(size: 12, weight: .medium))
                                        .foregroundColor(.appPrimaryFg)
                                        .padding(.horizontal, 14)
                                        .padding(.vertical, 7)
                                        .background(Color.appPrimary)
                                        .clipShape(Capsule())
                                }
                                .disabled(importing)
                                Text("导入会占用一套卡片位置（套数价格和自制相同）")
                                    .font(.system(size: 10))
                                    .foregroundColor(.appMutedFg)
                            }
                            Spacer(minLength: 0)
                        }
                        .padding(14)
                        .background(Color.appCard)
                        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.appBorder, lineWidth: 0.5))
                        .cornerRadius(16)
                    }

                    // 卡片广场
                    if !cardPosts.isEmpty {
                        HStack(spacing: 5) {
                            Image(systemName: "megaphone")
                                .font(.system(size: 12))
                            Text("卡片广场")
                        }
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.appMutedFg)

                        LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
                            ForEach(cardPosts) { p in
                                Button { openPostId = p.id } label: {
                                    VStack(alignment: .leading, spacing: 4) {
                                        ZStack(alignment: .topLeading) {
                                            if let cfg = p.config {
                                                CardThemeThumbnailView(config: cfg)
                                                    .cornerRadius(10)
                                            }
                                            Text("SHOW ONLY")
                                                .font(.system(size: 8, weight: .medium))
                                                .foregroundColor(.white)
                                                .padding(.horizontal, 6)
                                                .padding(.vertical, 2)
                                                .background(Color.black.opacity(0.55))
                                                .clipShape(Capsule())
                                                .padding(6)
                                        }
                                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.appBorder, lineWidth: 0.5))
                                        Text(p.title ?? "")
                                            .font(.system(size: 11, weight: .medium))
                                            .foregroundColor(.appForeground)
                                            .lineLimit(1)
                                        Text("\(p.author?.name ?? "匿名") · ❤ \(p.likeCount ?? 0) · 👁 \(p.viewCount ?? 0)")
                                            .font(.system(size: 10))
                                            .foregroundColor(.appMutedFg)
                                            .lineLimit(1)
                                    }
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }

                    // 橱窗信息流
                    FeedView(search: q, hideSortBar: false)
                        .id(q)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 16)
        }
        .background(Color.appBackground.ignoresSafeArea())
        .navigationTitle("搜索")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: Binding(get: { openPostId != nil }, set: { if !$0 { openPostId = nil } })) {
            if let pid = openPostId {
                CardDetailSheet(postId: pid) { }
            }
        }
    }

    private func sectionTitle(_ t: String) -> some View {
        Text(t)
            .font(.system(size: 13, weight: .medium))
            .foregroundColor(.appMutedFg)
    }

    private func submit() {
        let kw = input.trimmingCharacters(in: .whitespaces)
        guard !kw.isEmpty else { return }
        q = kw
        Task { await load() }
    }

    private func load() async {
        async let t = try? MashanglingAPI.shared.tag.search(q: q, limit: 8)
        async let u = try? MashanglingAPI.shared.follow.searchUsers(q: q, limit: 8)
        async let c = try? MashanglingAPI.shared.cardPlaza.search(q: q, limit: 12)
        matchedTags = await t ?? []
        matchedUsers = await u ?? []
        let cr = await c
        cardPosts = cr?.posts ?? []
        codeMatch = cr?.codeMatch
    }

    private func importCard(_ code: String) async {
        importing = true
        defer { importing = false }
        do {
            let r = try await MashanglingAPI.shared.card.importByCode(code: code)
            ToastCenter.shared.success(r.cost > 0
                ? "已导入「\(r.name)」（消耗 \(r.cost) 积分），去「个性化」页查看"
                : "已导入「\(r.name)」，去「个性化」页查看")
        } catch { ToastCenter.shared.error(error.localizedDescription) }
    }
}

// MARK: - 标签页（复刻 TagPage.tsx）
struct TagDetailView: View {
    let tagId: Int

    @State private var tag: TagDetail? = nil
    @State private var showReport = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .bottom, spacing: 8) {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 8) {
                            Text("# \(tag?.name ?? "…")")
                                .font(.system(size: 21, weight: .bold))
                                .foregroundColor(.appForeground)
                            if let t = tag {
                                Text(TagCategory.label(t.category))
                                    .font(.system(size: 11))
                                    .foregroundColor(.appSecondaryFg)
                                    .padding(.horizontal, 9)
                                    .padding(.vertical, 3)
                                    .background(Color.appSecondary)
                                    .clipShape(Capsule())
                            }
                        }
                        if let t = tag {
                            Text("共 \(t.showcaseCount ?? 0) 个橱窗 · 本周新增 \(t.weekNew ?? 0)")
                                .font(.system(size: 12))
                                .foregroundColor(.appMutedFg)
                        }
                    }
                    Spacer()
                    if tag != nil {
                        Button { showReport = true } label: {
                            Image(systemName: "flag")
                                .font(.system(size: 12))
                                .foregroundColor(.appMutedFg)
                        }
                    }
                }

                FeedView(tagId: tagId, hideSortBar: false)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 16)
        }
        .background(Color.appBackground.ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
        .task {
            tag = try? await MashanglingAPI.shared.tag.byId(id: tagId)
        }
        .sheet(isPresented: $showReport) {
            ReportSheet(targetType: "tag", targetId: tagId)
        }
    }
}
