import SwiftUI
import Charts

// MARK: - 领取申请（发布者审批，对应网页 Claims.tsx）
struct ClaimsView: View {
    @State private var rows: [ClaimRow]? = nil
    @State private var busy = false
    @State private var previewImage: String? = nil

    private var pending: [ClaimRow] { (rows ?? []).filter { $0.status == "pending" } }
    private var resolved: [ClaimRow] { (rows ?? []).filter { $0.status != "pending" } }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 8) {
                    Text("领取申请")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(.appForeground)
                    if !pending.isEmpty {
                        Text("\(pending.count) 条待审核")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.appPrimaryFg)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 2)
                            .background(Color.appPrimary)
                            .clipShape(Capsule())
                    }
                }
                Text("批准或拒绝他人对你橱窗的领取申请，结果会通过站内信通知申请者。")
                    .font(.system(size: 14))
                    .foregroundColor(.appMutedFg)
                    .padding(.top, 4)

                if rows == nil {
                    VStack(spacing: 12) {
                        ForEach(0..<2, id: \.self) { _ in
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color.appSecondary)
                                .frame(height: 96)
                        }
                    }
                    .padding(.top, 24)
                } else if (rows ?? []).isEmpty {
                    Text("暂无领取申请")
                        .font(.system(size: 14))
                        .foregroundColor(.appMutedFg)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 64)
                        .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color.appBorder, style: StrokeStyle(lineWidth: 1, dash: [6])))
                        .padding(.top, 24)
                } else {
                    VStack(spacing: 10) {
                        ForEach(pending + resolved) { c in
                            claimCard(c)
                        }
                    }
                    .padding(.top, 24)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 24)
            .padding(.bottom, 24)
        }
        .background(Color.appBackground)
        .navigationTitle("领取申请")
        .navigationBarTitleDisplayMode(.inline)
        .task { rows = (try? await MashanglingAPI.shared.claim.received()) ?? [] }
        .refreshable { rows = (try? await MashanglingAPI.shared.claim.received()) ?? [] }
        .fullScreenCover(isPresented: Binding(
            get: { previewImage != nil },
            set: { if !$0 { previewImage = nil } }
        )) {
            if let img = previewImage {
                ImageViewerCover(path: img)
            }
        }
    }

    private func claimCard(_ c: ClaimRow) -> some View {
        let isPending = c.status == "pending"
        return VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 12) {
                NavigationLink(destination: ShowcaseDetailView(showcaseId: c.showcaseId ?? 0)) {
                    Text(c.showcaseTitle ?? "")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.appPrimary)
                        .lineLimit(1)
                }
                NavigationLink(destination: ProfileView(userId: c.applicantId ?? 0)) {
                    Text("\(c.applicantName ?? "未知用户") 申请领取")
                        .font(.system(size: 14))
                        .foregroundColor(.appMutedFg)
                        .lineLimit(1)
                }
                Spacer()
                statusBadge(c.status)
                Text(DateFmt.zhFull(c.createdAt))
                    .font(.system(size: 12))
                    .foregroundColor(.appMutedFg)
            }
            if let note = c.note, !note.isEmpty {
                Text(note)
                    .font(.system(size: 12))
                    .lineSpacing(4)
                    .foregroundColor(.appForeground.opacity(0.8))
                    .padding(.top, 8)
            }
            if let img = c.credentialImage, !img.isEmpty {
                Button { previewImage = img } label: {
                    AppImage(path: img, contentMode: .fit)
                        .frame(maxHeight: 128)
                        .cornerRadius(3)
                        .overlay(RoundedRectangle(cornerRadius: 3).stroke(Color.appBorder, lineWidth: 1))
                }
                .buttonStyle(.plain)
                .padding(.top, 8)
            }
            if isPending {
                HStack(spacing: 8) {
                    Button { Task { await resolve(c, action: "approve") } } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "checkmark")
                                .font(.system(size: 12))
                            Text("批准解锁")
                        }
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.appPrimaryFg)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.appPrimary)
                        .clipShape(Capsule())
                    }
                    .disabled(busy)
                    Button { Task { await resolve(c, action: "reject") } } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "xmark")
                                .font(.system(size: 12))
                            Text("拒绝")
                        }
                        .font(.system(size: 12))
                        .foregroundColor(.appForeground)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .overlay(Capsule().stroke(Color.appBorder, lineWidth: 1))
                    }
                    .disabled(busy)
                    NavigationLink(destination: DmThreadView(peerId: c.applicantId ?? 0, peerName: c.applicantName ?? "")) {
                        HStack(spacing: 4) {
                            Image(systemName: "message")
                                .font(.system(size: 12))
                            Text("私信 TA")
                        }
                        .font(.system(size: 12))
                        .foregroundColor(.appForeground)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                    }
                }
                .padding(.top, 12)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(isPending ? Color.appPrimary.opacity(0.03) : Color.appCard)
        .cornerRadius(4)
        .overlay(RoundedRectangle(cornerRadius: 4).stroke(isPending ? Color.appPrimary.opacity(0.4) : Color.appBorder, lineWidth: 1))
    }

    @ViewBuilder
    private func statusBadge(_ status: String?) -> some View {
        if status == "pending" {
            Text("待审核")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.appPrimary)
                .padding(.horizontal, 8)
                .padding(.vertical, 2)
                .background(Color.appPrimary.opacity(0.1))
                .clipShape(Capsule())
        } else if status == "approved" {
            Text("已通过")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.fixEmerald700)
                .padding(.horizontal, 8)
                .padding(.vertical, 2)
                .background(Color.fixEmerald100)
                .clipShape(Capsule())
        } else {
            Text("未通过")
                .font(.system(size: 12))
                .foregroundColor(.appMutedFg)
                .padding(.horizontal, 8)
                .padding(.vertical, 2)
                .background(Color.appSecondary)
                .clipShape(Capsule())
        }
    }

    private func resolve(_ r: ClaimRow, action: String) async {
        busy = true
        defer { busy = false }
        do {
            _ = try await MashanglingAPI.shared.claim.resolve(id: r.id, action: action)
            ToastCenter.shared.success(action == "approve" ? "已批准，申请者会收到站内信" : "已拒绝")
            rows = (try? await MashanglingAPI.shared.claim.received()) ?? []
        } catch { ToastCenter.shared.error(error.localizedDescription) }
    }
}

// MARK: - 我的清单（对应网页 Bookmarks.tsx）
struct BookmarksView: View {
    @State private var data: BookmarkListResponse? = nil
    @State private var loading = true

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 8) {
                    Image(systemName: "bookmark")
                        .font(.system(size: 18))
                        .foregroundColor(.appPrimary)
                    Text("我的领取清单")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(.appForeground)
                }
                Text("待领取的橱窗都在这儿，点进去复制码或联系发布人。已下架的橱窗会标灰。")
                    .font(.system(size: 14))
                    .foregroundColor(.appMutedFg)
                    .padding(.top, 6)

                if loading {
                    LazyVGrid(columns: [GridItem(.flexible(), spacing: 20), GridItem(.flexible(), spacing: 20)], spacing: 20) {
                        ForEach(0..<5, id: \.self) { _ in
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color.appSecondary)
                                .aspectRatio(4.0 / 3.0, contentMode: .fit)
                        }
                    }
                    .padding(.top, 24)
                } else if (data?.items ?? []).isEmpty {
                    Text("清单还是空的。看到想领的橱窗，点详情页的「加入清单」就会出现在这里。")
                        .font(.system(size: 14))
                        .foregroundColor(.appMutedFg)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 80)
                        .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color.appBorder, style: StrokeStyle(lineWidth: 1, dash: [6])))
                        .padding(.top, 24)
                } else {
                    LazyVGrid(columns: [GridItem(.flexible(), spacing: 20), GridItem(.flexible(), spacing: 20)], spacing: 20) {
                        ForEach(data?.items ?? []) { b in
                            if b.status == "removed" {
                                VStack(alignment: .leading, spacing: 0) {
                                    NavigationLink(destination: ShowcaseDetailView(showcaseId: b.id)) {
                                        ShowcaseCardView(item: b.asShowcase)
                                    }
                                    .buttonStyle(.plain)
                                    Text("该橱窗已下架")
                                        .font(.system(size: 11))
                                        .foregroundColor(.appMutedFg)
                                        .padding(.horizontal, 2)
                                        .padding(.top, 4)
                                }
                                .opacity(0.45)
                            } else {
                                NavigationLink(destination: ShowcaseDetailView(showcaseId: b.id)) {
                                    ShowcaseCardView(item: b.asShowcase)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    .padding(.top, 24)
                }

                // 收藏的卡片
                if !loading, let cards = data?.cards, !cards.isEmpty {
                    VStack(alignment: .leading, spacing: 0) {
                        HStack(spacing: 8) {
                            Image(systemName: "megaphone")
                                .font(.system(size: 18))
                                .foregroundColor(.appPrimary)
                            Text("收藏的卡片")
                                .font(.system(size: 18, weight: .bold))
                                .foregroundColor(.appForeground)
                        }
                        Text("在卡片广场收藏的设计，点开可直接查看；已下架的会标灰。")
                            .font(.system(size: 12))
                            .foregroundColor(.appMutedFg)
                            .padding(.top, 4)
                        LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                            ForEach(cards) { c in
                                cardCell(c)
                            }
                        }
                        .padding(.top, 16)
                    }
                    .padding(.top, 40)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 24)
            .padding(.bottom, 24)
        }
        .background(Color.appBackground)
        .navigationTitle("我的领取清单")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            data = try? await MashanglingAPI.shared.bookmark.list()
            loading = false
        }
        .refreshable {
            data = try? await MashanglingAPI.shared.bookmark.list()
        }
    }

    @ViewBuilder
    private func cardCell(_ c: FavoriteCardRow) -> some View {
        let thumb = ZStack(alignment: .topLeading) {
            CardThemeThumbnailView(config: c.config)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            if c.removed == true {
                ZStack {
                    Color.black.opacity(0.4)
                    Text("已下架")
                        .font(.system(size: 12))
                        .foregroundColor(.white)
                }
            } else {
                Text("SHOW ONLY")
                    .font(.system(size: 9, weight: .medium))
                    .foregroundColor(.white)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 1)
                    .background(Color.black.opacity(0.55))
                    .clipShape(Capsule())
                    .padding(6)
            }
        }
        .aspectRatio(3.0 / 4.0, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: 4))
        .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color.appBorder, lineWidth: 1))

        let cell = VStack(alignment: .leading, spacing: 0) {
            thumb
            Text(c.title)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.appForeground)
                .lineLimit(1)
                .padding(.top, 6)
            Text(c.authorName ?? "匿名")
                .font(.system(size: 11))
                .foregroundColor(.appMutedFg)
                .lineLimit(1)
        }

        if c.removed == true {
            cell.opacity(0.5)
        } else {
            NavigationLink(destination: CardPlazaView(initialPostId: c.postId)) {
                cell
            }
            .buttonStyle(.plain)
        }
    }
}

// MARK: - 浏览记录（对应网页 BrowseHistory.tsx）
struct BrowseHistoryView: View {
    @State private var showcases: [Showcase]? = nil
    @State private var cards: [CardBrowseHistoryItem] = []
    @State private var cardsLoaded = false
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 8) {
                    Image(systemName: "clock.arrow.circlepath")
                        .font(.system(size: 18))
                        .foregroundColor(.appPrimary)
                    Text("浏览记录")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(.appForeground)
                }
                Text("记录你最近一天看过的橱窗，按最近浏览排序。")
                    .font(.system(size: 14))
                    .foregroundColor(.appMutedFg)
                    .padding(.top, 6)

                if showcases == nil {
                    LazyVGrid(columns: [GridItem(.flexible(), spacing: 20), GridItem(.flexible(), spacing: 20)], spacing: 20) {
                        ForEach(0..<10, id: \.self) { _ in
                            VStack(alignment: .leading, spacing: 0) {
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(Color.appSecondary)
                                    .aspectRatio(4.0 / 3.0, contentMode: .fit)
                                RoundedRectangle(cornerRadius: 2)
                                    .fill(Color.appSecondary)
                                    .frame(height: 16)
                                    .padding(.trailing, 40)
                                    .padding(.top, 10)
                                RoundedRectangle(cornerRadius: 2)
                                    .fill(Color.appSecondary)
                                    .frame(height: 12)
                                    .padding(.trailing, 90)
                                    .padding(.top, 6)
                            }
                        }
                    }
                    .padding(.top, 24)
                } else if (showcases ?? []).isEmpty {
                    VStack(spacing: 8) {
                        Text("最近一天还没有浏览记录，去首页逛逛吧")
                            .font(.system(size: 14))
                            .foregroundColor(.appMutedFg)
                        Button {
                            dismiss()
                            NotificationCenter.default.post(name: .mslSwitchTab, object: 0)
                        } label: {
                            Text("回到首页")
                                .font(.system(size: 14))
                                .foregroundColor(.appForeground)
                                .padding(.horizontal, 20)
                                .padding(.vertical, 6)
                                .background(Color.appCard)
                                .clipShape(Capsule())
                                .overlay(Capsule().stroke(Color.appBorder, lineWidth: 1))
                        }
                        .buttonStyle(.plain)
                        .padding(.top, 8)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 80)
                    .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color.appBorder, style: StrokeStyle(lineWidth: 1, dash: [6])))
                    .padding(.top, 24)
                } else {
                    LazyVGrid(columns: [GridItem(.flexible(), spacing: 20), GridItem(.flexible(), spacing: 20)], spacing: 20) {
                        ForEach(showcases ?? []) { s in
                            NavigationLink(destination: ShowcaseDetailView(showcaseId: s.id)) {
                                ShowcaseCardView(item: s)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.top, 24)
                }

                // 看过的卡片
                if cardsLoaded && !cards.isEmpty {
                    VStack(alignment: .leading, spacing: 0) {
                        HStack(spacing: 8) {
                            Image(systemName: "megaphone")
                                .font(.system(size: 18))
                                .foregroundColor(.appPrimary)
                            Text("看过的卡片")
                                .font(.system(size: 18, weight: .bold))
                                .foregroundColor(.appForeground)
                        }
                        Text("在卡片广场点开过的作品，按最近浏览排序。")
                            .font(.system(size: 12))
                            .foregroundColor(.appMutedFg)
                            .padding(.top, 4)
                        LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                            ForEach(cards) { c in
                                cardCell(c)
                            }
                        }
                        .padding(.top, 16)
                    }
                    .padding(.top, 40)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 24)
            .padding(.bottom, 24)
        }
        .background(Color.appBackground)
        .navigationTitle("浏览记录")
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
        .refreshable { await load() }
    }

    @ViewBuilder
    private func cardCell(_ c: CardBrowseHistoryItem) -> some View {
        let thumb = ZStack {
            if let cfg = c.config {
                CardThemeThumbnailView(config: cfg)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            if c.removed == true {
                ZStack {
                    Color.black.opacity(0.4)
                    Text("已下架")
                        .font(.system(size: 12))
                        .foregroundColor(.white)
                }
            }
        }
        .aspectRatio(3.0 / 4.0, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: 4))
        .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color.appBorder, lineWidth: 1))

        let cell = VStack(alignment: .leading, spacing: 0) {
            thumb
            Text(c.title ?? "")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.appForeground)
                .lineLimit(1)
                .padding(.top, 6)
            Text(DateFmt.short(c.lastAt))
                .font(.system(size: 11))
                .foregroundColor(.appMutedFg)
                .lineLimit(1)
        }

        if c.removed == true {
            cell.opacity(0.5)
        } else {
            NavigationLink(destination: CardPlazaView(initialPostId: c.postId)) {
                cell
            }
            .buttonStyle(.plain)
        }
    }

    private func load() async {
        async let s = try? MashanglingAPI.shared.showcase.browseHistory()
        async let c = try? MashanglingAPI.shared.cardPlaza.browseHistory()
        showcases = await s ?? []
        cards = await c ?? []
        cardsLoaded = true
    }
}

// MARK: - 我的评论（对应网页 MyComments.tsx：返图 + 卡片评论按时间倒序）
struct MyCommentsView: View {
    private struct Entry: Identifiable {
        enum Kind { case repost, cardComment }
        let kind: Kind
        let entryId: Int
        let at: Date
        let atRaw: String?
        let text: String
        let image: String?
        let showcaseId: Int?
        let postId: Int?
        let title: String
        let removed: Bool
        var id: String { "\(kind)-\(entryId)" }
    }

    @State private var reposts: [MyRepostsResponse.MyRepostRow]? = nil
    @State private var comments: [MyCommentsResponse.MyCommentRow]? = nil

    private var loading: Bool { reposts == nil || comments == nil }

    private var entries: [Entry] {
        var list: [Entry] = []
        for r in reposts ?? [] {
            list.append(Entry(kind: .repost, entryId: r.id,
                              at: DateFmt.parse(r.createdAt) ?? .distantPast,
                              atRaw: r.createdAt,
                              text: r.comment ?? "", image: r.image,
                              showcaseId: r.showcaseId, postId: nil,
                              title: r.showcaseTitle ?? "",
                              removed: r.showcaseStatus != "active"))
        }
        for c in comments ?? [] {
            list.append(Entry(kind: .cardComment, entryId: c.id,
                              at: DateFmt.parse(c.createdAt) ?? .distantPast,
                              atRaw: c.createdAt,
                              text: c.content, image: nil,
                              showcaseId: nil, postId: c.postId,
                              title: c.postTitle ?? "",
                              removed: c.postStatus != "active"))
        }
        return list.sorted { $0.at > $1.at }
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 8) {
                    Image(systemName: "text.bubble")
                        .font(.system(size: 18))
                        .foregroundColor(.appPrimary)
                    Text("我的评论")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(.appForeground)
                }
                Text("你发布过的所有返图和卡片评论，按最新排序。")
                    .font(.system(size: 14))
                    .foregroundColor(.appMutedFg)
                    .padding(.top, 6)

                if loading {
                    VStack(spacing: 12) {
                        ForEach(0..<4, id: \.self) { _ in
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color.appSecondary)
                                .frame(height: 80)
                        }
                    }
                    .padding(.top, 24)
                } else if entries.isEmpty {
                    Text("还没有发布过返图或评论")
                        .font(.system(size: 14))
                        .foregroundColor(.appMutedFg)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 80)
                        .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color.appBorder, style: StrokeStyle(lineWidth: 1, dash: [6])))
                        .padding(.top, 24)
                } else {
                    VStack(spacing: 12) {
                        ForEach(entries) { e in
                            entryRow(e)
                        }
                    }
                    .padding(.top, 24)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 24)
            .padding(.bottom, 24)
        }
        .background(Color.appBackground)
        .navigationTitle("我的评论")
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
        .refreshable { await load() }
    }

    @ViewBuilder
    private func entryRow(_ e: Entry) -> some View {
        let content = HStack(alignment: .top, spacing: 12) {
            if e.kind == .repost {
                AppImage(path: e.image)
                    .frame(width: 56, height: 56)
                    .cornerRadius(3)
            } else {
                ZStack {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color.appPrimary.opacity(0.1))
                    Image(systemName: "megaphone")
                        .font(.system(size: 18))
                        .foregroundColor(.appPrimary)
                }
                .frame(width: 56, height: 56)
            }
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 6) {
                    HStack(spacing: 4) {
                        Image(systemName: e.kind == .repost ? "photo" : "megaphone")
                            .font(.system(size: 10))
                        Text(e.kind == .repost ? "返图" : "卡片评论")
                    }
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.appSecondaryFg)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(Color.appSecondary)
                    .clipShape(Capsule())
                    Text(e.kind == .repost ? "橱窗「\(e.title)」" : "卡片「\(e.title)」")
                        .font(.system(size: 12))
                        .foregroundColor(.appMutedFg)
                        .lineLimit(1)
                    if e.removed {
                        Text("已下架")
                            .font(.system(size: 10))
                            .foregroundColor(.appMutedFg)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 1)
                            .background(Color.appSecondary)
                            .clipShape(Capsule())
                    }
                    Spacer()
                    Text(DateFmt.short(e.atRaw))
                        .font(.system(size: 12))
                        .foregroundColor(.appMutedFg)
                }
                Text(e.text.isEmpty ? "（无文字）" : e.text)
                    .font(.system(size: 14))
                    .foregroundColor(.appForeground)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 6)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.appCard)
        .cornerRadius(4)
        .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color.appBorder, lineWidth: 1))

        if e.kind == .repost {
            NavigationLink(destination: ShowcaseDetailView(showcaseId: e.showcaseId ?? 0)) {
                content
            }
            .buttonStyle(.plain)
        } else if !e.removed {
            NavigationLink(destination: CardPlazaView(initialPostId: e.postId ?? 0)) {
                content
            }
            .buttonStyle(.plain)
        } else {
            content
        }
    }

    private func load() async {
        async let r = try? MashanglingAPI.shared.repost.mine()
        async let c = try? MashanglingAPI.shared.cardPlaza.myComments()
        reposts = await r?.items ?? []
        comments = await c?.items ?? []
    }
}

// MARK: - 积分与等级（对应网页 Points.tsx）
struct PointsView: View {
    @State private var my: PointsMy? = nil
    @State private var busy = false

    /// TITLES 固定顺序（对应 contracts/levels.ts 的 Object.entries 顺序）
    private let titleOrder = ["eggking", "buyking", "weeklyking", "seveneggs"]

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 0) {
                Text("积分与等级")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(.appForeground)
                Text("发布橱窗 +10 · 被返图 +5 · 被领到了 +3 · 被点赞 +2 · 发布返图 +1（「没有了」「我想要」不计分）")
                    .font(.system(size: 14))
                    .foregroundColor(.appMutedFg)
                    .padding(.top, 6)

                levelCard
                    .padding(.top, 24)
                titlesCard
                    .padding(.top, 24)
                levelsTableCard
                    .padding(.top, 24)
            }
            .padding(.horizontal, 16)
            .padding(.top, 32)
            .padding(.bottom, 32)
        }
        .background(Color.appBackground)
        .navigationTitle("积分与等级")
        .navigationBarTitleDisplayMode(.inline)
        .task { my = try? await MashanglingAPI.shared.points.my() }
        .refreshable { my = try? await MashanglingAPI.shared.points.my() }
    }

    // 我的等级卡
    private var levelCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let m = my {
                HStack(spacing: 16) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 5)
                            .fill(Color.appPrimary.opacity(0.1))
                        Image(systemName: "oval")
                            .font(.system(size: 24))
                            .foregroundColor(.appPrimary)
                    }
                    .frame(width: 56, height: 56)
                    VStack(alignment: .leading, spacing: 0) {
                        HStack(alignment: .firstTextBaseline, spacing: 8) {
                            Text("Lv.\(m.level)")
                                .font(.system(size: 30, weight: .bold))
                                .foregroundColor(.appForeground)
                            Text(m.band)
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.appPrimary)
                        }
                        Text("总积分 \(m.points) · 本周 \(m.weekPoints ?? 0) · 本月 \(m.monthPoints ?? 0)")
                            .font(.system(size: 14))
                            .foregroundColor(.appMutedFg)
                            .padding(.top, 6)
                    }
                }
                if m.maxLevel == true {
                    HStack(spacing: 6) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 14))
                        Text("已达满级 30 级，传说鸡舍主！")
                    }
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.fixAmber600)
                    .padding(.top, 16)
                } else {
                    let pct: Double = m.need > 0 ? min(1.0, Double(m.into) / Double(m.need)) : 1.0
                    Capsule()
                        .fill(Color.appSecondary)
                        .frame(height: 10)
                        .overlay(alignment: .leading) {
                            GeometryReader { g in
                                Capsule()
                                    .fill(Color.appPrimary)
                                    .frame(width: g.size.width * pct)
                            }
                        }
                        .padding(.top, 16)
                    Text("距 Lv.\(m.level + 1) 还需 \(m.need - m.into) 分（本级 \(m.into)/\(m.need)）")
                        .font(.system(size: 12))
                        .foregroundColor(.appMutedFg)
                        .padding(.top, 6)
                }
            } else {
                Text("加载中…")
                    .font(.system(size: 14))
                    .foregroundColor(.appMutedFg)
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.appCard)
        .cornerRadius(5)
        .overlay(RoundedRectangle(cornerRadius: 5).stroke(Color.appBorder, lineWidth: 1))
    }

    // 头衔卡
    private var titlesCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 6) {
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .font(.system(size: 18))
                    .foregroundColor(.appPrimary)
                Text("头衔")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.appForeground)
            }
            Text("无料达人周榜按农场可用积分（总积分-已消耗）排名，每周日 23:59 定榜，第一名获得「周榜冠军」头衔和 100 积分奖励；头衔佩戴后全站可见。")
                .font(.system(size: 12))
                .foregroundColor(.appMutedFg)
                .padding(.top, 4)
            VStack(spacing: 10) {
                ForEach(titleOrder, id: \.self) { key in
                    let meta = Levels.titles[key] ?? (key, "🏅", "")
                    let owned = my?.titles?.first(where: { $0.key == key })
                    titleRow(meta: meta, owned: owned, key: key)
                }
            }
            .padding(.top, 16)
        }
        .padding(24)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.appCard)
        .cornerRadius(5)
        .overlay(RoundedRectangle(cornerRadius: 5).stroke(Color.appBorder, lineWidth: 1))
    }

    private func titleRow(meta: (label: String, icon: String, desc: String), owned: PointsMy.TitleItem?, key: String) -> some View {
        HStack(spacing: 12) {
            Text(meta.icon)
                .font(.system(size: 24))
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 8) {
                    Text(meta.label)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.appForeground)
                    if owned?.equipped == true {
                        Text("佩戴中")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.fixAmber700)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(Color.fixAmber100)
                            .clipShape(Capsule())
                    }
                }
                Text(meta.desc)
                    .font(.system(size: 12))
                    .foregroundColor(.appMutedFg)
                if let o = owned {
                    Text("获得于 \(DateFmt.zhDate(o.earnedAt))")
                        .font(.system(size: 11))
                        .foregroundColor(.appMutedFg)
                }
            }
            Spacer()
            if let o = owned {
                Button { Task { await equip(key: key, currentlyEquipped: o.equipped) } } label: {
                    Text(o.equipped ? "取下" : "佩戴")
                        .font(.system(size: 13, weight: o.equipped ? .regular : .medium))
                        .foregroundColor(o.equipped ? .appForeground : .appPrimaryFg)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 7)
                        .background(o.equipped ? Color.clear : Color.appPrimary)
                        .clipShape(Capsule())
                        .overlay(Capsule().stroke(o.equipped ? Color.appBorder : Color.clear, lineWidth: 1))
                }
                .disabled(busy)
            } else {
                Text("未获得")
                    .font(.system(size: 12))
                    .foregroundColor(.appMutedFg)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color.appBorder, lineWidth: 1))
    }

    // 等级一览（30 级）
    private var levelsTableCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("等级一览（30 级）")
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(.appForeground)
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)], spacing: 8) {
                ForEach(levelRows(), id: \.0) { row in
                    let current = my?.level == row.0
                    VStack(alignment: .leading, spacing: 0) {
                        HStack(spacing: 6) {
                            Text("Lv.\(row.0)")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(.appForeground)
                            if current {
                                Text("当前")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundColor(.appPrimary)
                            }
                        }
                        Text(row.1)
                            .font(.system(size: 12))
                            .foregroundColor(.appMutedFg)
                        Text("累计 \(row.2.formatted(.number.grouping(.automatic))) 分")
                            .font(.system(size: 11))
                            .monospacedDigit()
                            .foregroundColor(.appMutedFg)
                            .padding(.top, 2)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(current ? Color.appPrimary.opacity(0.05) : Color.clear)
                    .cornerRadius(4)
                    .overlay(RoundedRectangle(cornerRadius: 4).stroke(current ? Color.appPrimary : Color.appBorder, lineWidth: 1))
                    .overlay(current ? RoundedRectangle(cornerRadius: 5).stroke(Color.appPrimary.opacity(0.3), lineWidth: 1).padding(-1) : nil)
                }
            }
            .padding(.top, 16)
        }
        .padding(24)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.appCard)
        .cornerRadius(5)
        .overlay(RoundedRectangle(cornerRadius: 5).stroke(Color.appBorder, lineWidth: 1))
    }

    /// LEVEL_TABLE：从 1 级升到每一级所需的累计积分
    private func levelRows() -> [(Int, String, Int)] {
        (1...Levels.maxLevel).map { lv in
            var cum = 0
            for n in 1..<lv { cum += Levels.needForLevel(n) }
            return (lv, Levels.band(of: lv), cum)
        }
    }

    private func equip(key: String, currentlyEquipped: Bool) async {
        busy = true
        defer { busy = false }
        do {
            _ = try await MashanglingAPI.shared.points.equipTitle(currentlyEquipped ? nil : key)
            ToastCenter.shared.success(currentlyEquipped ? "已取下头衔" : "已佩戴头衔")
            my = try? await MashanglingAPI.shared.points.my()
            await AuthManager.shared.checkAuth()
        } catch { ToastCenter.shared.error(error.localizedDescription) }
    }
}

// MARK: - 积分记录（对应网页 PointRecords.tsx）
struct PointRecordsView: View {
    private let filters: [(key: String, label: String)] = [
        ("all", "全部"), ("interact", "互动收入"), ("publish", "发布"), ("task", "任务/签到"),
        ("browse", "浏览兑换"), ("heart", "心选橱窗"), ("farm", "农场储蓄"), ("spend", "支出"),
    ]

    @State private var kind = "all"
    @State private var showChart = false
    @State private var records: [PointLogRow]? = nil
    @State private var my: PointsMy? = nil

    private struct ChartPoint: Identifiable {
        let id = UUID()
        let time: String
        let balance: Int
        let delta: Int
        let label: String
    }

    private var filtered: [PointLogRow] {
        (records ?? []).filter { kind == "all" || $0.kind == kind }
    }

    private func sumFor(_ key: String) -> Int {
        (records ?? []).filter { key == "all" || $0.kind == key }.reduce(0) { $0 + $1.delta }
    }

    /// 「全部」= 从当前余额倒推真实余额轨迹；分类 = 从 0 起净累计
    private var chartData: [ChartPoint] {
        let all = records ?? []
        let isAll = kind == "all"
        let cur = my?.points ?? 0
        var balAfter = [Int](repeating: 0, count: all.count)
        var acc = 0
        for i in 0..<all.count {
            balAfter[i] = cur - acc
            acc += all[i].delta
        }
        var points: [ChartPoint] = []
        var catBal = 0
        if all.count > 0 {
            for i in stride(from: all.count - 1, through: 0, by: -1) {
                let r = all[i]
                if !(kind == "all" || r.kind == kind) { continue }
                catBal += r.delta
                points.append(ChartPoint(time: Self.mdhm(r.createdAt), balance: isAll ? balAfter[i] : catBal, delta: r.delta, label: r.label))
            }
        }
        return points
    }

    private static func mdhm(_ s: String?) -> String {
        guard let d = DateFmt.parse(s) else { return "" }
        let f = DateFormatter()
        f.dateFormat = "MM-dd HH:mm"
        return f.string(from: d)
    }

    private var kindLabel: String {
        filters.first(where: { $0.key == kind })?.label ?? ""
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 8) {
                    Image(systemName: "doc.text")
                        .font(.system(size: 22))
                        .foregroundColor(.appPrimary)
                    Text("积分记录")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(.appForeground)
                }
                Text("展示最近 200 条积分增减（含来源），仅自己可见。")
                    .font(.system(size: 12))
                    .foregroundColor(.appMutedFg)
                    .padding(.top, 4)

                // 分类胶囊 + 图表切换
                FlowLayout(spacing: 6) {
                    ForEach(filters, id: \.key) { f in
                        Button { kind = f.key } label: {
                            HStack(spacing: 4) {
                                Text(f.label)
                                if (records?.count ?? 0) > 0 {
                                    let s = sumFor(f.key)
                                    Text(s >= 0 ? "+\(s)" : "\(s)")
                                        .monospacedDigit()
                                        .foregroundColor(kind == f.key ? Color.appPrimaryFg.opacity(0.8) : .appMutedFg)
                                }
                            }
                            .font(.system(size: 12, weight: kind == f.key ? .medium : .regular))
                            .foregroundColor(kind == f.key ? .appPrimaryFg : .appSecondaryFg)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 4)
                            .background(kind == f.key ? Color.appPrimary : Color.appSecondary)
                            .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                    Button { showChart.toggle() } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "chart.xyaxis.line")
                                .font(.system(size: 12))
                            Text(showChart ? "查看列表" : "切换图表")
                        }
                        .font(.system(size: 12, weight: showChart ? .medium : .regular))
                        .foregroundColor(showChart ? .appPrimaryFg : .appSecondaryFg)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 4)
                        .background(showChart ? Color.appPrimary : Color.appSecondary)
                        .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
                .padding(.top, 12)

                if showChart {
                    chartCard
                        .padding(.top, 16)
                }

                if records == nil {
                    VStack(spacing: 8) {
                        ForEach(0..<3, id: \.self) { _ in
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color.appSecondary)
                                .frame(height: 56)
                        }
                    }
                    .padding(.top, 16)
                } else if showChart {
                    EmptyView()
                } else if filtered.isEmpty {
                    Text("该分类下还没有积分记录")
                        .font(.system(size: 14))
                        .foregroundColor(.appMutedFg)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 64)
                        .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color.appBorder, style: StrokeStyle(lineWidth: 1, dash: [6])))
                        .padding(.top, 16)
                } else {
                    VStack(spacing: 6) {
                        ForEach(filtered) { r in
                            recordRow(r)
                        }
                    }
                    .padding(.top, 16)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 24)
            .padding(.bottom, 24)
        }
        .background(Color.appBackground)
        .navigationTitle("积分记录")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            async let rec = try? MashanglingAPI.shared.points.records()
            async let m = try? MashanglingAPI.shared.points.my()
            records = await rec ?? []
            my = await m
        }
        .refreshable {
            async let rec = try? MashanglingAPI.shared.points.records()
            async let m = try? MashanglingAPI.shared.points.my()
            records = await rec ?? []
            my = await m
        }
    }

    private var chartCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(kind == "all"
                 ? "积分余额曲线（全部；展示最近 \(filtered.count) 条记录）"
                 : "分类净积分曲线（\(kindLabel)，从 0 起累计；展示最近 \(filtered.count) 条记录）")
                .font(.system(size: 12))
                .foregroundColor(.appMutedFg)
                .padding(.bottom, 8)
            if filtered.count < 2 {
                Text("该分类下记录不足，无法生成曲线")
                    .font(.system(size: 12))
                    .foregroundColor(.appMutedFg)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 40)
            } else {
                Chart(chartData) { p in
                    LineMark(
                        x: .value("时间", p.time),
                        y: .value("积分", p.balance)
                    )
                    .interpolationMethod(.catmullRom)
                    .foregroundStyle(Color(h: 337, s: 80, l: 61))
                    .lineStyle(StrokeStyle(lineWidth: 2))
                }
                .chartXAxis {
                    AxisMarks { _ in
                        AxisValueLabel()
                            .font(.system(size: 10))
                    }
                }
                .chartYAxis {
                    AxisMarks { _ in
                        AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [3, 3]))
                            .foregroundStyle(Color.appBorder)
                        AxisValueLabel()
                            .font(.system(size: 10))
                    }
                }
                .frame(height: 208)
            }
        }
        .padding(16)
        .background(Color.appCard)
        .cornerRadius(4)
        .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color.appBorder, lineWidth: 1))
    }

    @ViewBuilder
    private func recordRow(_ r: PointLogRow) -> some View {
        let earn = r.delta > 0
        let content = HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(earn ? Color.fixEmerald600.opacity(0.1) : Color.fixRed500.opacity(0.1))
                Image(systemName: earn ? "arrow.up.right" : "arrow.down.right")
                    .font(.system(size: 14))
                    .foregroundColor(earn ? .fixEmerald600 : .fixRed500)
            }
            .frame(width: 32, height: 32)
            VStack(alignment: .leading, spacing: 2) {
                Text(r.label)
                    .font(.system(size: 14))
                    .foregroundColor(.appForeground)
                    .lineLimit(1)
                Text(DateFmt.zhFull(r.createdAt))
                    .font(.system(size: 11))
                    .foregroundColor(.appMutedFg)
            }
            Spacer()
            Text(earn ? "+\(r.delta)" : "\(r.delta)")
                .font(.system(size: 14, weight: .bold))
                .monospacedDigit()
                .foregroundColor(earn ? .fixEmerald600 : .fixRed500)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color.appCard)
        .cornerRadius(4)
        .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color.appBorder, lineWidth: 1))

        if let sid = r.showcaseId {
            NavigationLink(destination: ShowcaseDetailView(showcaseId: sid)) {
                content
            }
            .buttonStyle(.plain)
        } else {
            content
        }
    }
}
