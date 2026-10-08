import SwiftUI

// MARK: - 搜索页（复刻 SearchPage.tsx）
struct SearchView: View {
    var initialQuery: String = ""
    @State private var input = ""
    @State private var q = ""            // 已提交的搜索词

    @State private var matchedTags: [Tag] = []
    @State private var matchedUsers: [FollowUser] = []
    @State private var cardPosts: [CardSearchResult] = []
    @State private var codeMatch: CardCodeMatch? = nil
    @State private var importing = false
    @State private var showLogin = false

    @EnvironmentObject var authManager: AuthManager

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 0) {
                // 搜索框（h-11 rounded-full border-input bg-card pl-10）
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 16))
                        .foregroundColor(.appMutedFg)
                    TextField("搜索无料码 / 卡片码 / 卡片标题 / 用户昵称…", text: $input)
                        .font(.system(size: 14))
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                        .onSubmit { submit() }
                }
                .padding(.leading, 14)
                .padding(.trailing, 16)
                .frame(height: 44)
                .background(Color.appCard)
                .clipShape(Capsule())
                .overlay(Capsule().stroke(Color.appInput, lineWidth: 1))

                if !q.isEmpty {
                    Text("「\(q)」的搜索结果")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(.appForeground)
                        .padding(.top, 24)
                    Text("优先匹配无料码，其次是发布人昵称和标题/简介关键词；也可直接搜用户昵称或用户 ID")
                        .font(.system(size: 12))
                        .foregroundColor(.appMutedFg)
                        .padding(.top, 4)

                    // 相关用户
                    if !matchedUsers.isEmpty {
                        Text("相关用户")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.appMutedFg)
                            .padding(.top, 24)
                        VStack(spacing: 10) {
                            ForEach(matchedUsers) { u in
                                NavigationLink { ProfileView(userId: u.userId) } label: {
                                    HStack(spacing: 12) {
                                        AvatarView(path: u.avatar, name: u.name ?? "U", size: 40)
                                        VStack(alignment: .leading, spacing: 2) {
                                            HStack(spacing: 6) {
                                                Text(u.name ?? "未知用户")
                                                    .font(.system(size: 14, weight: .medium))
                                                    .foregroundColor(.appForeground)
                                                LevelBadgeView(level: u.level ?? 1)
                                                TitleBadgeView(equippedTitle: u.equippedTitle, plain: true)
                                            }
                                            Text("ID: \(u.userId) · \(u.followerCount ?? 0) 粉丝\((u.bio?.isEmpty == false) ? " · \(u.bio!)" : "")")
                                                .font(.system(size: 12))
                                                .foregroundColor(.appMutedFg)
                                                .lineLimit(1)
                                        }
                                        Spacer()
                                    }
                                    .padding(12)
                                    .background(Color.appCard)
                                    .cornerRadius(4)
                                    .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color.appBorder, lineWidth: 1))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.top, 8)
                    }

                    // 相关标签
                    if !matchedTags.isEmpty {
                        Text("相关标签")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.appMutedFg)
                            .padding(.top, 24)
                        FlowLayout(spacing: 6) {
                            ForEach(matchedTags) { t in
                                NavigationLink { TagDetailView(tagId: t.id) } label: {
                                    HStack(spacing: 4) {
                                        Text("# \(t.name)")
                                        Text("·\(TagCategory.label(t.category))")
                                            .foregroundColor(.appMutedFg)
                                    }
                                    .font(.system(size: 12))
                                    .foregroundColor(.appForeground)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(Color.appCard)
                                    .clipShape(Capsule())
                                    .overlay(Capsule().stroke(Color.appBorder, lineWidth: 1))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.top, 8)
                    }

                    // 卡片码精确匹配
                    if let m = codeMatch {
                        HStack(spacing: 6) {
                            Image(systemName: "megaphone")
                                .font(.system(size: 14))
                            Text("卡片码匹配")
                        }
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.appMutedFg)
                        .padding(.top, 24)

                        HStack(spacing: 16) {
                            if let cfg = m.config {
                                CardThemeThumbnailView(config: cfg)
                                    .frame(width: 84, height: 112)
                                    .clipShape(RoundedRectangle(cornerRadius: 4))
                                    .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color.appBorder, lineWidth: 1))
                            }
                            VStack(alignment: .leading, spacing: 0) {
                                Text(m.name)
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundColor(.appForeground)
                                    .lineLimit(1)
                                Text("来自 \(m.ownerName ?? "未知用户") 的设计")
                                    .font(.system(size: 12))
                                    .foregroundColor(.appMutedFg)
                                    .padding(.top, 2)
                                Button {
                                    guard authManager.isAuthenticated else {
                                        showLogin = true
                                        return
                                    }
                                    Task { await importCard(m.code) }
                                } label: {
                                    Text(importing ? "导入中…" : "导入这套卡片")
                                        .font(.system(size: 12, weight: .medium))
                                        .foregroundColor(.appPrimaryFg)
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 6)
                                        .background(Color.appPrimary)
                                        .clipShape(Capsule())
                                }
                                .disabled(importing)
                                .padding(.top, 10)
                                Text("导入会占用一套卡片位置（套数价格和自制相同）")
                                    .font(.system(size: 11))
                                    .foregroundColor(.appMutedFg)
                                    .padding(.top, 6)
                            }
                            Spacer(minLength: 0)
                        }
                        .padding(16)
                        .background(Color.appCard)
                        .cornerRadius(5)
                        .overlay(RoundedRectangle(cornerRadius: 5).stroke(Color.appBorder, lineWidth: 1))
                        .padding(.top, 8)
                    }

                    // 卡片广场结果
                    if !cardPosts.isEmpty {
                        HStack(spacing: 6) {
                            Image(systemName: "megaphone")
                                .font(.system(size: 14))
                            Text("卡片广场")
                        }
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.appMutedFg)
                        .padding(.top, 24)

                        LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                            ForEach(cardPosts) { p in
                                NavigationLink { CardPlazaView(initialPostId: p.id) } label: {
                                    VStack(alignment: .leading, spacing: 0) {
                                        ZStack(alignment: .topLeading) {
                                            if let cfg = p.config {
                                                CardThemeThumbnailView(config: cfg)
                                                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                                            }
                                            Text("SHOW ONLY")
                                                .font(.system(size: 9, weight: .medium))
                                                .foregroundColor(.white)
                                                .padding(.horizontal, 6)
                                                .padding(.vertical, 1)
                                                .background(Color.black.opacity(0.55))
                                                .clipShape(Capsule())
                                                .padding(6)
                                        }
                                        .aspectRatio(3.0 / 4.0, contentMode: .fit)
                                        .clipShape(RoundedRectangle(cornerRadius: 4))
                                        .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color.appBorder, lineWidth: 1))
                                        Text(p.title ?? "")
                                            .font(.system(size: 12, weight: .medium))
                                            .foregroundColor(.appForeground)
                                            .lineLimit(1)
                                            .padding(.top, 6)
                                        Text("\(p.author?.name ?? "匿名") · ❤ \(p.likeCount ?? 0) · 👁 \(p.viewCount ?? 0)")
                                            .font(.system(size: 11))
                                            .foregroundColor(.appMutedFg)
                                            .lineLimit(1)
                                    }
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.top, 8)
                    }

                    // 橱窗信息流
                    FeedView(search: q, hideSortBar: false)
                        .id(q)
                        .padding(.top, 16)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 24)
            .padding(.bottom, 24)
        }
        .scrollDismissesKeyboard(.interactively)
        .background(Color.appBackground.ignoresSafeArea())
        .navigationTitle("搜索")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showLogin) { LoginView() }
        .onAppear {
            if q.isEmpty && !initialQuery.isEmpty {
                input = initialQuery
                submit()
            }
        }
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
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .bottom, spacing: 12) {
                    VStack(alignment: .leading, spacing: 0) {
                        HStack(spacing: 10) {
                            Text("# \(tag?.name ?? "…")")
                                .font(.system(size: 24, weight: .bold))
                                .foregroundColor(.appForeground)
                            if let t = tag {
                                Text(TagCategory.label(t.category))
                                    .font(.system(size: 12))
                                    .foregroundColor(.appSecondaryFg)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 2)
                                    .background(Color.appSecondary)
                                    .clipShape(Capsule())
                            }
                        }
                        if let t = tag {
                            Text("共 \(t.showcaseCount ?? 0) 个橱窗 · 本周新增 \(t.weekNew ?? 0)")
                                .font(.system(size: 14))
                                .foregroundColor(.appMutedFg)
                                .padding(.top, 6)
                        }
                    }
                    Spacer()
                    if tag != nil {
                        Button { showReport = true } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "flag")
                                    .font(.system(size: 12))
                                Text("举报")
                            }
                            .font(.system(size: 12))
                            .foregroundColor(.appMutedFg)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.bottom, 24)

                FeedView(tagId: tagId, hideSortBar: false)
            }
            .padding(.horizontal, 16)
            .padding(.top, 24)
            .padding(.bottom, 24)
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
