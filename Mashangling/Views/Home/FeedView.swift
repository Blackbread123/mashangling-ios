import SwiftUI

// MARK: - 橱窗信息流（对应网页 Feed.tsx）
struct FeedView: View {
    var tagId: Int? = nil
    var search: String? = nil
    var includeTagIds: [Int]? = nil
    var excludeTagIds: [Int]? = nil
    var hideSortBar: Bool = false
    var showPlatformToggle: Bool = false

    @EnvironmentObject var authManager: AuthManager
    @StateObject private var vm = FeedViewModel()
    @State private var showLogin = false
    @State private var openDetailId: Int? = nil

    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            if !hideSortBar {
                sortBar
            }

            if vm.loading && vm.items.isEmpty {
                LoadingView()
            } else if vm.items.isEmpty {
                emptyState
            } else {
                LazyVGrid(columns: columns, spacing: 12) {
                    ForEach(Array(vm.items.enumerated()), id: \.element.id) { idx, item in
                        ShowcaseCardView(
                            item: item,
                            rank: vm.sort == "hot" && (search ?? "").isEmpty && idx < 2 ? idx + 1 : nil,
                            onLike: { Task { await vm.toggleLike(item: item, authed: authManager.isAuthenticated, needLogin: { showLogin = true }) } }
                        )
                        .onTapGesture { openDetailId = item.id }
                    }
                }

                if vm.cursor > 0 {
                    Button {
                        Task { await vm.loadMore() }
                    } label: {
                        Text(vm.loadingMore ? "加载中…" : "加载更多")
                            .font(.system(size: 14))
                            .foregroundColor(.appForeground)
                            .padding(.horizontal, 24)
                            .padding(.vertical, 8)
                            .background(Color.appCard)
                            .cornerRadius(20)
                            .overlay(Capsule().stroke(Color.appBorder, lineWidth: 0.5))
                    }
                    .buttonStyle(.plain)
                    .frame(maxWidth: .infinity)
                    .disabled(vm.loadingMore)
                    .padding(.top, 8)
                }
            }
        }
        .onAppear { vm.configure(tagId: tagId, search: search, includeTagIds: includeTagIds, excludeTagIds: excludeTagIds, showPlatformToggle: showPlatformToggle) }
        .sheet(isPresented: $showLogin) { LoginView() }
        .navigationDestination(isPresented: Binding(
            get: { openDetailId != nil },
            set: { if !$0 { openDetailId = nil } }
        )) {
            if let id = openDetailId {
                ShowcaseDetailView(showcaseId: id)
            }
        }
    }

    // MARK: 排序栏
    private var sortBar: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 4) {
                sortPill(key: "hot", label: "推荐", icon: "flame")
                sortPill(key: "new", label: "最新", icon: "clock")
                sortPill(key: "foryou", label: "猜你喜欢", icon: "sparkles")
                if vm.sort == "foryou" {
                    Button {
                        vm.shuffle += 1
                        Task { await vm.reload() }
                    } label: {
                        HStack(spacing: 3) {
                            Image(systemName: "arrow.clockwise").font(.system(size: 11))
                            Text("换一批").font(.system(size: 11))
                        }
                        .foregroundColor(.appMutedFg)
                        .padding(.horizontal, 8).padding(.vertical, 6)
                    }
                    .buttonStyle(.plain)
                }
                Spacer(minLength: 0)
            }

            HStack(spacing: 6) {
                if vm.sort == "hot" {
                    ForEach(FeedViewModel.windows, id: \.key) { w in
                        PillButton(title: w.label, selected: vm.window == w.key) {
                            vm.window = w.key
                            Task { await vm.reload() }
                        }
                    }
                }
                Spacer(minLength: 0)
                if showPlatformToggle {
                    PillButton(title: "全部", selected: vm.platform == "all") {
                        vm.platform = "all"
                        Task { await vm.reload() }
                    }
                    PillButton(title: "外部无料", selected: vm.platform == "external") {
                        vm.platform = "external"
                        Task { await vm.reload() }
                    }
                }
            }
        }
    }

    private func sortPill(key: String, label: String, icon: String) -> some View {
        Button {
            if key == "foryou" && !authManager.isAuthenticated {
                showLogin = true
                return
            }
            vm.sort = key
            UserDefaults.standard.set(key, forKey: "msl_feed_sort")
            Task { await vm.reload() }
        } label: {
            HStack(spacing: 4) {
                Image(systemName: icon).font(.system(size: 11))
                Text(label).font(.system(size: 13, weight: vm.sort == key ? .semibold : .regular))
            }
            .foregroundColor(vm.sort == key ? .appForeground : .appMutedFg)
            .padding(.horizontal, 12).padding(.vertical, 6)
            .background(vm.sort == key ? Color.appCard : Color.clear)
            .cornerRadius(16)
            .shadow(color: vm.sort == key ? Color.black.opacity(0.08) : .clear, radius: 2, y: 1)
        }
        .buttonStyle(.plain)
        .padding(.vertical, 3)
        .padding(.horizontal, 2)
        .background(Color.appSecondary)
        .cornerRadius(18)
    }

    private var emptyState: some View {
        let text: String
        if vm.platform == "external" {
            text = "这里还没有外部无料，看看「全部」，或发布第一个需要寄快递的无料"
        } else if vm.sort == "foryou" {
            text = "还没有足够的浏览记录，先去逛逛感兴趣的橱窗，再来这里看为你推荐的内容"
        } else if vm.sort == "hot" && vm.window != "all" {
            text = "该时间范围内还没有发布的橱窗，补码也会重新计入，或切换到总榜看看"
        } else {
            text = "这里还没有橱窗，来发布第一个吧"
        }
        return Text(text)
            .font(.system(size: 13))
            .foregroundColor(.appMutedFg)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 60)
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.appBorder, style: StrokeStyle(lineWidth: 1, dash: [6])))
    }
}

// MARK: - Feed ViewModel
@MainActor
class FeedViewModel: ObservableObject {
    static let windows: [(key: String, label: String)] = [
        ("day", "日榜"), ("week", "周榜"), ("month", "月榜"), ("all", "总榜"),
    ]

    @Published var sort: String = UserDefaults.standard.string(forKey: "msl_feed_sort") ?? "hot"
    @Published var window = "week"
    @Published var platform = "all"
    @Published var shuffle = 0
    @Published var items: [Showcase] = []
    @Published var cursor = 0
    @Published var loading = false
    @Published var loadingMore = false

    private var tagId: Int? = nil
    private var search: String? = nil
    private var includeTagIds: [Int]? = nil
    private var excludeTagIds: [Int]? = nil
    private var configured = false

    func configure(tagId: Int?, search: String?, includeTagIds: [Int]?, excludeTagIds: [Int]?, showPlatformToggle: Bool) {
        guard !configured else { return }
        configured = true
        self.tagId = tagId
        self.search = search
        self.includeTagIds = includeTagIds
        self.excludeTagIds = excludeTagIds
        Task { await reload() }
    }

    func reload() async {
        loading = true
        do {
            let r = try await MashanglingAPI.shared.showcase.feed(
                sort: sort, window: window, tagId: tagId,
                includeTagIds: includeTagIds, excludeTagIds: excludeTagIds,
                q: search, platform: platform == "external" ? "external" : nil,
                shuffle: sort == "foryou" ? shuffle : nil,
                cursor: 0, limit: 24
            )
            items = r.items
            cursor = r.nextCursor ?? -1
        } catch {
            ToastCenter.error(error.localizedDescription)
        }
        loading = false
    }

    func loadMore() async {
        guard cursor > 0, !loadingMore else { return }
        loadingMore = true
        do {
            let r = try await MashanglingAPI.shared.showcase.feed(
                sort: sort, window: window, tagId: tagId,
                includeTagIds: includeTagIds, excludeTagIds: excludeTagIds,
                q: search, platform: platform == "external" ? "external" : nil,
                shuffle: sort == "foryou" ? shuffle : nil,
                cursor: cursor, limit: 24
            )
            items.append(contentsOf: r.items)
            cursor = r.nextCursor ?? -1
        } catch {}
        loadingMore = false
    }

    func toggleLike(item: Showcase, authed: Bool, needLogin: () -> Void) async {
        guard authed else { needLogin(); return }
        do {
            let liked = try await MashanglingAPI.shared.interaction.toggleLike(showcaseId: item.id)
            if let idx = items.firstIndex(where: { $0.id == item.id }) {
                var copy = items
                let old = copy[idx]
                copy[idx] = Showcase(
                    id: old.id, title: old.title, platform: old.platform, coverImage: old.coverImage,
                    pinned: old.pinned, stockStatus: old.stockStatus, quantity: old.quantity,
                    remaining: old.remaining, pointCost: old.pointCost, expiresAt: old.expiresAt,
                    isFullyClaimed: old.isFullyClaimed, createdAt: old.createdAt,
                    author: old.author, tags: old.tags,
                    likeCount: (old.likeCount ?? 0) + (liked ? 1 : -1),
                    claimCount: old.claimCount, codeCount: old.codeCount,
                    likedByMe: liked, claimedByMe: old.claimedByMe,
                    addressSentByMe: old.addressSentByMe, addressCount: old.addressCount
                )
                items = copy
            }
        } catch {
            ToastCenter.error(error.localizedDescription)
        }
    }
}
