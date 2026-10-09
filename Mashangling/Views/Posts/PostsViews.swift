import SwiftUI
import PhotosUI

// MARK: - 动态功能（逐行复刻网页 2026-10-08 更新：PostCard/PostComposer/PostsFeed/UserPosts/PostFeatureTip）

/// 相对时间（逐行复刻 PostCard.tsx timeAgo）
func postTimeAgo(_ d: String) -> String {
    guard let t = DateFmt.parse(d) else { return "" }
    let m = Int(Date().timeIntervalSince(t) / 60)
    if m < 1 { return "刚刚" }
    if m < 60 { return "\(m) 分钟前" }
    let h = m / 60
    if h < 24 { return "\(h) 小时前" }
    let day = h / 24
    if day < 7 { return "\(day) 天前" }
    return DateFmt.zhDate(d)
}

extension Notification.Name {
    /// 悬浮提示卡「去看看」→ 消息页切到「动态」分段
    static let mslShowPosts = Notification.Name("mslShowPosts")
}

// MARK: - 多图选择器（发帖配图，最多 9 张；PHPicker iOS 16 原生多选）
struct MultiImagePicker: UIViewControllerRepresentable {
    let selectionLimit: Int
    let onPicked: ([UIImage]) -> Void

    func makeUIViewController(context: Context) -> PHPickerViewController {
        var config = PHPickerConfiguration()
        config.filter = .images
        config.selectionLimit = selectionLimit
        let picker = PHPickerViewController(configuration: config)
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: PHPickerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    class Coordinator: NSObject, PHPickerViewControllerDelegate {
        let parent: MultiImagePicker
        init(_ parent: MultiImagePicker) { self.parent = parent }

        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            picker.dismiss(animated: true)
            guard !results.isEmpty else { return }
            var images: [UIImage?] = Array(repeating: nil, count: results.count)
            let group = DispatchGroup()
            for (i, result) in results.enumerated() {
                let provider = result.itemProvider
                guard provider.canLoadObject(ofClass: UIImage.self) else { continue }
                group.enter()
                provider.loadObject(ofClass: UIImage.self) { image, _ in
                    images[i] = image as? UIImage
                    group.leave()
                }
            }
            group.notify(queue: .main) {
                self.parent.onPicked(images.compactMap { $0 })
            }
        }
    }
}

// MARK: - 动态卡片（逐行复刻 PostCard.tsx：rounded-xl border bg-card p-4）
struct PostCardView: View {
    let post: Post
    var onPreview: (String) -> Void = { _ in }
    var onChanged: () -> Void = {}        // 点赞/置顶/删除/评论后刷新外层
    var onDeleted: (Int) -> Void = { _ in }
    var needLogin: () -> Void = {}

    @EnvironmentObject var authManager: AuthManager
    @State private var liked: Bool
    @State private var likeCount: Int
    @State private var commentCount: Int
    @State private var pinned: Bool
    @State private var commentsOpen = false
    @State private var comments: [PostComment] = []
    @State private var commentsLoading = false
    @State private var menuOpen = false
    @State private var confirmDelete = false
    @State private var deleting = false
    @State private var reportPost = false
    @State private var reportCommentId: Int? = nil
    @State private var draft = ""
    @State private var replyTo: (id: Int, name: String)? = nil
    @State private var sending = false
    @State private var pushShowcase = false

    init(post: Post, onPreview: @escaping (String) -> Void = { _ in },
         onChanged: @escaping () -> Void = {}, onDeleted: @escaping (Int) -> Void = { _ in },
         needLogin: @escaping () -> Void = {}) {
        self.post = post
        self.onPreview = onPreview
        self.onChanged = onChanged
        self.onDeleted = onDeleted
        self.needLogin = needLogin
        _liked = State(initialValue: post.likedByMe ?? false)
        _likeCount = State(initialValue: post.likeCount ?? 0)
        _commentCount = State(initialValue: post.commentCount ?? 0)
        _pinned = State(initialValue: post.pinned ?? false)
    }

    private var mine: Bool { post.mine ?? false }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            authorRow
            // 正文（网页：mt-2.5 text-sm leading-6 whitespace-pre-wrap）
            Text(post.content)
                .font(.system(size: 14))
                .lineSpacing(10) // leading-6 = 24px 行高
                .foregroundColor(.appForeground)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, 10)
            imageGrid
            showcaseCard
            actionRow
            if commentsOpen { commentsSection }
        }
        .padding(16)
        .background(Color.appCard)
        .cornerRadius(12)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.appBorder, lineWidth: 0.5))
        .navigationDestination(isPresented: $pushShowcase) {
            ShowcaseDetailView(showcaseId: post.showcase?.id ?? 0)
        }
        // 「⋯」下拉菜单（网页：absolute right-0 top-full mt-1 w-28 rounded-xl border bg-background shadow-lg py-1）
        .overlay {
            if menuOpen {
                Color.black.opacity(0.001)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .contentShape(Rectangle())
                    .onTapGesture { menuOpen = false }
                    .padding(-1200)
            }
        }
        .overlay(alignment: .topTrailing) {
            if menuOpen {
                menuView
                    .padding(.top, 48)
                    .padding(.trailing, 16)
            }
        }
        // 删除确认（网页：fixed inset-0 bg-black/50，max-w-xs rounded-2xl p-5）
        .overlay {
            if confirmDelete {
                ZStack {
                    Color.black.opacity(0.5)
                        .onTapGesture { confirmDelete = false }
                    confirmDeleteView
                }
                .padding(-1200)
            }
        }
        .zIndex(menuOpen || confirmDelete ? 30 : 0)
        .sheet(isPresented: $reportPost) {
            ReportSheet(targetType: "post", targetId: post.id)
        }
        .sheet(isPresented: Binding(get: { reportCommentId != nil }, set: { if !$0 { reportCommentId = nil } })) {
            ReportSheet(targetType: "postComment", targetId: reportCommentId ?? 0)
        }
    }

    // MARK: 作者行（40 圆头像 + 名字/Lv/头衔 + 11px 时间行 + ⋯）
    private var authorRow: some View {
        HStack(alignment: .top, spacing: 12) {
            NavigationLink(destination: ProfileView(userId: post.author?.id ?? 0)) {
                ZStack {
                    Circle().fill(Color.appPrimary.opacity(0.1)).frame(width: 40, height: 40)
                    if let av = post.author?.avatar, !av.isEmpty {
                        AppImage(path: av)
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 40, height: 40)
                            .clipShape(Circle())
                    } else {
                        Text((post.author?.name ?? "U").prefix(1).uppercased())
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.appPrimary)
                    }
                }
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 8) {
                    NavigationLink(destination: ProfileView(userId: post.author?.id ?? 0)) {
                        Text(post.author?.name ?? "未知用户")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.appForeground)
                            .lineLimit(1)
                    }
                    .buttonStyle(.plain)
                    if let lv = post.author?.level { LevelBadgeView(level: lv) }
                    if let t = post.author?.equippedTitle, !t.isEmpty {
                        TitleBadgeView(equippedTitle: t)
                    }
                }
                HStack(spacing: 6) {
                    if pinned {
                        HStack(spacing: 2) {
                            Image(systemName: "pin.fill").font(.system(size: 10))
                            Text("置顶").font(.system(size: 10, weight: .medium))
                        }
                        .foregroundColor(.twAmber600)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 1)
                        .background(Color.twAmber500.opacity(0.1))
                        .clipShape(Capsule())
                    }
                    Text(postTimeAgo(post.createdAt))
                        .font(.system(size: 11))
                        .foregroundColor(.appMutedFg)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Button { menuOpen.toggle() } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 14))
                    .foregroundColor(.appMutedFg)
                    .padding(6)
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: 联动橱窗快照卡（2026-10-09：发布橱窗自动发动态；active=false 置灰、点击提示不可见）
    @ViewBuilder
    private var showcaseCard: some View {
        if let sc = post.showcase {
            let active = sc.active ?? false
            Button {
                if active {
                    pushShowcase = true
                } else {
                    ToastCenter.info("橱窗已不可见")
                }
            } label: {
                HStack(spacing: 10) {
                    AppImage(path: sc.coverUrl)
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 48, height: 48)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.appBorder, lineWidth: 0.5))
                    VStack(alignment: .leading, spacing: 3) {
                        Text(sc.title ?? "")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(active ? .appForeground : .appMutedFg)
                            .lineLimit(1)
                        Text(active ? "橱窗 · 点击查看" : "橱窗已不可见")
                            .font(.system(size: 11))
                            .foregroundColor(.appMutedFg)
                    }
                    Spacer()
                    if active {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(.appMutedFg)
                    }
                }
                .padding(8)
                .background(Color.appSecondary.opacity(0.5))
                .cornerRadius(10)
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.appBorder, lineWidth: 0.5))
            }
            .buttonStyle(.plain)
            .opacity(active ? 1 : 0.6)
            .padding(.top, 10)
        }
    }

    // MARK: 配图网格（单图原比例限高 320；2 图两列；≥3 图三列正方形）
    @ViewBuilder
    private var imageGrid: some View {
        let images = post.images ?? []
        if !images.isEmpty {
            if images.count == 1 {
                Button { onPreview(images[0]) } label: {
                    AppImage(path: images[0])
                        .aspectRatio(contentMode: .fit)
                        .frame(maxHeight: 320)
                        .cornerRadius(8)
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.appBorder, lineWidth: 0.5))
                }
                .buttonStyle(.plain)
                .padding(.top, 10)
            } else {
                let cols = Array(repeating: GridItem(.flexible(), spacing: 6), count: images.count == 2 ? 2 : 3)
                LazyVGrid(columns: cols, spacing: 6) {
                    ForEach(Array(images.enumerated()), id: \.offset) { _, src in
                        Button { onPreview(src) } label: {
                            AppImage(path: src)
                                .aspectRatio(contentMode: .fill)
                                .aspectRatio(1, contentMode: .fit)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.appBorder, lineWidth: 0.5))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.top, 10)
            }
        }
    }

    // MARK: 操作行（网页：mt-3 border-t border-border/60 pt-2.5，赞 + 评论）
    private var actionRow: some View {
        VStack(spacing: 0) {
            Rectangle().fill(Color.appBorder.opacity(0.6)).frame(height: 0.5)
            HStack(spacing: 16) {
                Button {
                    guard authManager.isAuthenticated else { needLogin(); return }
                    Task { await toggleLike() }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: liked ? "heart.fill" : "heart")
                            .font(.system(size: 16))
                        Text(likeCount > 0 ? "\(likeCount)" : "赞")
                            .font(.system(size: 12, weight: liked ? .medium : .regular))
                    }
                    .foregroundColor(liked ? Color.twRed500 : Color.appMutedFg)
                }
                .buttonStyle(.plain)

                Button {
                    commentsOpen.toggle()
                    if commentsOpen { Task { await loadComments() } }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "message")
                            .font(.system(size: 16))
                        Text(commentCount > 0 ? "评论 \(commentCount)" : "评论")
                            .font(.system(size: 12, weight: commentsOpen ? .medium : .regular))
                    }
                    .foregroundColor(commentsOpen ? Color.appPrimary : Color.appMutedFg)
                }
                .buttonStyle(.plain)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, 10)
        }
        .padding(.top, 12)
    }

    // MARK: 评论区（网页：mt-2.5 rounded-lg bg-secondary/50 p-3 space-y-2.5）
    private var commentsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            if commentsLoading && comments.isEmpty {
                Text("加载中…")
                    .font(.system(size: 12))
                    .foregroundColor(.appMutedFg)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
            } else if comments.isEmpty {
                Text("还没有评论，来抢沙发")
                    .font(.system(size: 12))
                    .foregroundColor(.appMutedFg)
                    .padding(.vertical, 4)
            } else {
                ForEach(comments) { c in commentRow(c) }
            }

            if let r = replyTo {
                HStack(spacing: 6) {
                    Text("回复 ")
                        .font(.system(size: 12))
                        .foregroundColor(.appMutedFg)
                    + Text("@\(r.name)")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.appPrimary)
                    Button { replyTo = nil } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 10))
                            .foregroundColor(.appMutedFg)
                            .padding(2)
                    }
                    .buttonStyle(.plain)
                }
            }

            HStack(spacing: 8) {
                TextField(replyTo.map { "回复 @\($0.name)…" } ?? "说点什么…", text: $draft)
                    .font(.system(size: 14))
                    .foregroundColor(.appForeground)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 6)
                    .background(Color.appBackground)
                    .overlay(Capsule().stroke(Color.appBorder, lineWidth: 0.5))
                    .clipShape(Capsule())
                    .onChange(of: draft) { v in if v.count > 500 { draft = String(v.prefix(500)) } }
                    .onSubmit { Task { await submitComment() } }
                Button { Task { await submitComment() } } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "paperplane.fill").font(.system(size: 10))
                        Text("发送").font(.system(size: 12, weight: .medium))
                    }
                    .foregroundColor(.appPrimaryFg)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.appPrimary)
                    .clipShape(Capsule())
                    .opacity(draft.trimmingCharacters(in: .whitespaces).isEmpty || sending ? 0.4 : 1)
                }
                .buttonStyle(.plain)
                .disabled(draft.trimmingCharacters(in: .whitespaces).isEmpty || sending)
            }
            .padding(.top, 4)
        }
        .padding(12)
        .background(Color.appSecondary.opacity(0.5))
        .cornerRadius(8)
        .padding(.top, 10)
    }

    // MARK: 评论行（网页：名字主色 semibold + 内容 + 10px 时间 + 回复/删除/举报）
    private func commentRow(_ c: PostComment) -> some View {
        let replyPrefix: Text = c.replyTo.map {
            Text("回复 ").foregroundColor(.appMutedFg)
            + Text("@\($0.name ?? "未知用户")").foregroundColor(.appPrimary.opacity(0.8)).fontWeight(.medium)
            + Text("：").foregroundColor(.appMutedFg)
        } ?? Text("")
        return HStack(alignment: .top, spacing: 8) {
            Text(c.author?.name ?? "未知用户")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.appPrimary)
            (replyPrefix + Text(c.content).foregroundColor(.appForeground.opacity(0.9)))
                .font(.system(size: 12))
                .lineSpacing(8) // leading-5
                .frame(maxWidth: .infinity, alignment: .leading)
            Text(postTimeAgo(c.createdAt))
                .font(.system(size: 10))
                .foregroundColor(.appMutedFg)
            Button {
                guard authManager.isAuthenticated else { needLogin(); return }
                replyTo = (c.id, c.author?.name ?? "未知用户")
            } label: {
                Image(systemName: "message")
                    .font(.system(size: 10))
                    .foregroundColor(.appMutedFg)
            }
            .buttonStyle(.plain)
            if c.canDelete == true {
                Button { Task { await deleteComment(c.id) } } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 11))
                        .foregroundColor(.appMutedFg)
                }
                .buttonStyle(.plain)
            } else {
                Button {
                    guard authManager.isAuthenticated else { needLogin(); return }
                    reportCommentId = c.id
                } label: {
                    Image(systemName: "flag")
                        .font(.system(size: 10))
                        .foregroundColor(.appMutedFg)
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: 「⋯」菜单（自己的：置顶/取消置顶 + 删除；别人的：举报）
    private var menuView: some View {
        VStack(alignment: .leading, spacing: 0) {
            if mine {
                Button {
                    menuOpen = false
                    Task { await togglePin() }
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: pinned ? "pin.slash" : "pin")
                            .font(.system(size: 12))
                        Text(pinned ? "取消置顶" : "置顶")
                            .font(.system(size: 12))
                    }
                    .foregroundColor(.appMutedFg)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(.plain)
                Button {
                    menuOpen = false
                    confirmDelete = true
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "trash").font(.system(size: 12))
                        Text("删除").font(.system(size: 12))
                    }
                    .foregroundColor(.twRed500)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(.plain)
            } else {
                Button {
                    menuOpen = false
                    guard authManager.isAuthenticated else { needLogin(); return }
                    reportPost = true
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "flag").font(.system(size: 12))
                        Text("举报").font(.system(size: 12))
                    }
                    .foregroundColor(.appMutedFg)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, 4)
        .frame(width: 112)
        .background(Color.appBackground)
        .cornerRadius(12)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.appBorder, lineWidth: 0.5))
        .shadow(color: .black.opacity(0.15), radius: 8, y: 3)
    }

    // MARK: 删除确认弹窗（网页：max-w-xs rounded-2xl bg-background p-5）
    private var confirmDeleteView: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("删除这条动态？")
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(.appForeground)
            Text("删除后不可恢复，点赞和评论会一并隐藏。")
                .font(.system(size: 12))
                .lineSpacing(8)
                .foregroundColor(.appMutedFg)
                .padding(.top, 6)
            HStack(spacing: 8) {
                Button { confirmDelete = false } label: {
                    Text("取消")
                        .font(.system(size: 12))
                        .foregroundColor(.appForeground)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .overlay(Capsule().stroke(Color.appBorder, lineWidth: 0.5))
                }
                .buttonStyle(.plain)
                Button { Task { await deletePost() } } label: {
                    Text(deleting ? "删除中…" : "确认删除")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(Color.twRed500)
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
                .disabled(deleting)
            }
            .padding(.top, 16)
        }
        .padding(20)
        .frame(width: 288) // max-w-xs
        .background(Color.appBackground)
        .cornerRadius(16)
        .onTapGesture {}
    }

    // MARK: 数据操作
    private func toggleLike() async {
        do {
            let nowLiked = try await MashanglingAPI.shared.post.toggleLike(postId: post.id)
            liked = nowLiked
            likeCount += nowLiked ? 1 : -1
        } catch {
            ToastCenter.error(error.localizedDescription)
        }
    }

    private func togglePin() async {
        do {
            let nowPinned = try await MashanglingAPI.shared.post.togglePin(id: post.id)
            pinned = nowPinned
            ToastCenter.success(nowPinned ? "已置顶，再置顶一条会替换它" : "已取消置顶")
            onChanged()
        } catch {
            ToastCenter.error(error.localizedDescription)
        }
    }

    private func deletePost() async {
        deleting = true
        do {
            _ = try await MashanglingAPI.shared.post.delete(id: post.id)
            ToastCenter.success("动态已删除")
            confirmDelete = false
            onDeleted(post.id)
        } catch {
            ToastCenter.error(error.localizedDescription)
        }
        deleting = false
    }

    private func loadComments() async {
        commentsLoading = true
        comments = (try? await MashanglingAPI.shared.post.comments(postId: post.id)) ?? []
        commentsLoading = false
    }

    private func submitComment() async {
        let content = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !content.isEmpty else { return }
        guard authManager.isAuthenticated else { needLogin(); return }
        sending = true
        do {
            _ = try await MashanglingAPI.shared.post.addComment(
                postId: post.id, content: content, replyToCommentId: replyTo?.id)
            draft = ""
            replyTo = nil
            await loadComments()
            commentCount = comments.count
            onChanged()
        } catch {
            ToastCenter.error(error.localizedDescription)
        }
        sending = false
    }

    private func deleteComment(_ id: Int) async {
        do {
            _ = try await MashanglingAPI.shared.post.deleteComment(id: id)
            ToastCenter.success("评论已删除")
            await loadComments()
            commentCount = comments.count
            onChanged()
        } catch {
            ToastCenter.error(error.localizedDescription)
        }
    }
}


// MARK: - 发动态输入框（逐行复刻 PostComposer.tsx：rounded-xl border bg-card p-4）
struct PostComposerView: View {
    var onPublished: () -> Void = {}
    var needLogin: () -> Void = {}

    @EnvironmentObject var authManager: AuthManager
    @State private var content = ""
    @State private var images: [String] = []   // 压缩后的 dataURL
    @State private var picking = false
    @State private var sending = false

    private let maxImages = 9
    private let maxChars = 2000

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // 输入区（网页：textarea 3 行 bg-secondary/60 rounded-lg）
            ZStack(alignment: .topLeading) {
                if content.isEmpty {
                    Text("分享此刻…（你的粉丝和互关好友可见）")
                        .font(.system(size: 14))
                        .foregroundColor(.appMutedFg.opacity(0.7))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 12)
                }
                TextEditor(text: $content)
                    .font(.system(size: 14))
                    .foregroundColor(.appForeground)
                    .frame(height: 66)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .scrollContentBackground(.hidden)
                    .onChange(of: content) { v in
                        if v.count > maxChars { content = String(v.prefix(maxChars)) }
                    }
            }
            .background(Color.appSecondary.opacity(0.6))
            .cornerRadius(8)

            // 已选配图（网页：grid-cols-3 gap-1.5 aspect-square，右上 X）
            if !images.isEmpty {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 3), spacing: 6) {
                    ForEach(Array(images.enumerated()), id: \.offset) { i, dataUrl in
                        ZStack(alignment: .topTrailing) {
                            DataUrlImage(dataUrl: dataUrl)
                                .aspectRatio(contentMode: .fill)
                                .aspectRatio(1, contentMode: .fit)
                                .clipShape(RoundedRectangle(cornerRadius: 6))
                            Button { images.remove(at: i) } label: {
                                Image(systemName: "xmark")
                                    .font(.system(size: 8, weight: .bold))
                                    .foregroundColor(.white)
                                    .frame(width: 20, height: 20)
                                    .background(Color.black.opacity(0.6))
                                    .clipShape(Circle())
                            }
                            .buttonStyle(.plain)
                            .padding(2)
                        }
                    }
                }
                .padding(.top, 8)
            }

            // 底部：配图按钮 + 字数 + 发布（网页：ImagePlus「配图 n/9」+ n/2000 + 发布胶囊）
            HStack(spacing: 0) {
                Button {
                    guard authManager.isAuthenticated else { needLogin(); return }
                    picking = true
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "photo")
                            .font(.system(size: 14))
                        Text("配图\(images.isEmpty ? "" : " \(images.count)/\(maxImages)")")
                            .font(.system(size: 12))
                    }
                    .foregroundColor(.appMutedFg)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 6)
                }
                .buttonStyle(.plain)
                .disabled(images.count >= maxImages)

                Text("\(content.count)/\(maxChars)")
                    .font(.system(size: 11))
                    .foregroundColor(.appMutedFg)
                    .padding(.leading, 8)

                Spacer(minLength: 0)

                Button { Task { await publish() } } label: {
                    Text(sending ? "发布中…" : "发布")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.appPrimaryFg)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 6)
                        .background(Color.appPrimary)
                        .clipShape(Capsule())
                        .opacity(canPublish ? 1 : 0.4)
                }
                .buttonStyle(.plain)
                .disabled(!canPublish || sending)
            }
            .padding(.top, 8)
        }
        .padding(16)
        .background(Color.appCard)
        .cornerRadius(12)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.appBorder, lineWidth: 0.5))
        .sheet(isPresented: $picking) {
            MultiImagePicker(selectionLimit: maxImages - images.count) { uiImages in
                for img in uiImages {
                    if images.count >= maxImages { break }
                    if let dataUrl = ImageCodec.coverDataURL(from: img) {
                        images.append(dataUrl)
                    }
                }
            }
        }
    }

    private var canPublish: Bool {
        !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func publish() async {
        guard authManager.isAuthenticated else { needLogin(); return }
        sending = true
        do {
            _ = try await MashanglingAPI.shared.post.create(
                content: content.trimmingCharacters(in: .whitespacesAndNewlines),
                images: images)
            content = ""
            images = []
            ToastCenter.success("动态已发布")
            onPublished()
        } catch {
            ToastCenter.error(error.localizedDescription)
        }
        sending = false
    }
}

// MARK: - dataURL 图片渲染（发帖配图本地预览）
struct DataUrlImage: View {
    let dataUrl: String

    var body: some View {
        if let img = Self.decode(dataUrl) {
            Image(uiImage: img)
                .resizable()
        } else {
            Color.appSecondary
        }
    }

    static func decode(_ dataUrl: String) -> UIImage? {
        guard let range = dataUrl.range(of: "base64,"),
              let data = Data(base64Encoded: String(dataUrl[range.upperBound...])) else { return nil }
        return UIImage(data: data)
    }
}

// MARK: - 动态信息流（逐行复刻 PostsFeed.tsx：每页 10 条 + 手动加载更多）
struct PostsFeedView: View {
    let mode: String            // "feed" | "user"
    var userId: Int = 0
    var restricted: Bool = false

    @EnvironmentObject var authManager: AuthManager
    @State private var items: [Post] = []
    @State private var nextCursor: Int? = nil
    @State private var restrictedState: Bool
    @State private var loading = true
    @State private var failed = false
    @State private var loadingMore = false
    @State private var showLogin = false
    @State private var preview: String? = nil

    init(mode: String, userId: Int = 0, restricted: Bool = false) {
        self.mode = mode
        self.userId = userId
        self.restricted = restricted
        _restrictedState = State(initialValue: restricted)
    }

    var body: some View {
        Group {
            if mode == "user" && restrictedState {
                restrictedView
            } else if loading {
                skeletons
            } else if failed {
                stateBox("加载失败，请稍后重试")
            } else if items.isEmpty {
                stateBox(mode == "feed" ? "还没有动态。发布一条，或去关注更多人吧" : "TA 还没有发布动态")
            } else {
                listView
            }
        }
        .task { await reload() }
        .sheet(isPresented: $showLogin) { LoginView() }
        .fullScreenCover(isPresented: Binding(get: { preview != nil }, set: { if !$0 { preview = nil } })) {
            // 网页：fixed inset-0 bg-black/80，点击关闭，max-h-85vh
            if let img = preview {
                ZStack {
                    Color.black.opacity(0.8).ignoresSafeArea()
                        .onTapGesture { preview = nil }
                    AppImage(path: img)
                        .aspectRatio(contentMode: .fit)
                        .cornerRadius(12)
                        .padding(16)
                }
            }
        }
    }

    // MARK: 受限态（网页：dashed border py-16，Users 图标 + 提示 + 去登录）
    private var restrictedView: some View {
        VStack(spacing: 0) {
            Image(systemName: "person.2")
                .font(.system(size: 32))
                .foregroundColor(.appMutedFg.opacity(0.5))
            Text("关注 TA 之后即可查看动态")
                .font(.system(size: 14))
                .foregroundColor(.appMutedFg)
                .padding(.top, 12)
            if !authManager.isAuthenticated {
                Button { showLogin = true } label: {
                    Text("去登录")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.appPrimaryFg)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 6)
                        .background(Color.appPrimary)
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
                .padding(.top, 16)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 64)
        .overlay(RoundedRectangle(cornerRadius: 12)
            .stroke(Color.appBorder, style: StrokeStyle(lineWidth: 0.5, dash: [4, 3])))
    }

    // MARK: 骨架（网页：3 张 h-36 rounded-xl Skeleton）
    private var skeletons: some View {
        VStack(spacing: 12) {
            ForEach(0..<3, id: \.self) { _ in
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.appSecondary)
                    .frame(height: 144)
            }
        }
    }

    private func stateBox(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 14))
            .foregroundColor(.appMutedFg)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 64)
            .overlay(RoundedRectangle(cornerRadius: 12)
                .stroke(Color.appBorder, style: StrokeStyle(lineWidth: 0.5, dash: [4, 3])))
    }

    // MARK: 列表（网页：space-y-3 + 加载更多按钮 / — 到底啦 —）
    private var listView: some View {
        VStack(spacing: 12) {
            ForEach(items) { p in
                PostCardView(
                    post: p,
                    onPreview: { preview = $0 },
                    onChanged: { Task { await reload() } },
                    onDeleted: { id in items.removeAll { $0.id == id } },
                    needLogin: { showLogin = true }
                )
            }
            if loadingMore {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.appSecondary)
                    .frame(height: 144)
            }
            if nextCursor != nil {
                Button { Task { await loadMore() } } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "chevron.down").font(.system(size: 12))
                        Text(loadingMore ? "加载中…" : "加载更多")
                            .font(.system(size: 12))
                    }
                    .foregroundColor(.appMutedFg)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.appBorder, lineWidth: 0.5))
                }
                .buttonStyle(.plain)
                .disabled(loadingMore)
            } else if items.count > 5 {
                Text("— 到底啦 —")
                    .font(.system(size: 11))
                    .foregroundColor(.appMutedFg)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
            }
        }
    }

    // MARK: 数据
    private func fetch(cursor: Int) async throws -> PostFeedResponse {
        if mode == "feed" {
            return try await MashanglingAPI.shared.post.feed(cursor: cursor, limit: 10)
        }
        return try await MashanglingAPI.shared.post.byUser(userId: userId, cursor: cursor, limit: 10)
    }

    func reload() async {
        if mode == "feed", !authManager.isAuthenticated { loading = false; failed = false; return }
        loading = items.isEmpty
        failed = false
        do {
            let r = try await fetch(cursor: 0)
            items = r.items ?? []
            nextCursor = r.nextCursor
            if r.restricted == true { restrictedState = true }
        } catch {
            failed = items.isEmpty
        }
        loading = false
    }

    private func loadMore() async {
        guard let cursor = nextCursor, !loadingMore else { return }
        loadingMore = true
        do {
            let r = try await fetch(cursor: cursor)
            items.append(contentsOf: r.items ?? [])
            nextCursor = r.nextCursor
        } catch {}
        loadingMore = false
    }
}

// MARK: - 某人的动态页（逐行复刻 UserPosts.tsx：/u/:id/posts）
struct UserPostsView: View {
    let userId: Int
    let name: String

    @Environment(\.dismiss) private var dismiss
    @State private var count: Int? = nil
    @State private var restricted = false

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 0) {
                // 网页：「← 返回主页」
                Button { dismiss() } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left").font(.system(size: 12, weight: .medium))
                        Text("返回主页").font(.system(size: 14))
                    }
                    .foregroundColor(.appMutedFg)
                }
                .buttonStyle(.plain)

                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text("\(name) 的动态")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.appForeground)
                    if let c = count {
                        Text("共 \(c) 条")
                            .font(.system(size: 12))
                            .foregroundColor(.appMutedFg)
                    }
                }
                .padding(.top, 12)

                PostsFeedView(mode: "user", userId: userId, restricted: restricted)
                    .padding(.top, 16)
            }
            .padding(.horizontal, 16)
            .padding(.top, 24)
            .padding(.bottom, 24)
        }
        .background(Color.appBackground)
        .webHeader()
        .navigationBarBackButtonHidden(true)
        .task {
            if let r = try? await MashanglingAPI.shared.post.countByUser(userId: userId) {
                count = r.count ?? 0
                restricted = r.restricted ?? false
            }
        }
    }
}

// MARK: - 新功能悬浮提示（逐行复刻 PostFeatureTip.tsx：bottom-16 right-4 w-64 rounded-2xl p-4）
struct PostFeatureTipView: View {
    /// 当前是否在消息页（网页：消息页不显示）
    let onMessagesTab: Bool
    /// 「去看看」：切到消息页动态分段
    let onGo: () -> Void

    @State private var dismissed = false

    private static let storageKey = "ml_posts_tip_v1"

    var body: some View {
        let hiddenForever = UserDefaults.standard.string(forKey: Self.storageKey) != nil
        if !dismissed && !hiddenForever && !onMessagesTab {
            ZStack(alignment: .topTrailing) {
                VStack(alignment: .leading, spacing: 0) {
                    HStack(spacing: 8) {
                        ZStack {
                            Circle().fill(Color.twEmerald500.opacity(0.1)).frame(width: 32, height: 32)
                            Image(systemName: "sparkles")
                                .font(.system(size: 14))
                                .foregroundColor(.twEmerald600)
                        }
                        Text("消息增加了「动态」")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.appForeground)
                            .padding(.trailing, 20)
                    }
                    Text("发动态、配图，关注的人互相看得见，还能点赞评论。")
                        .font(.system(size: 12))
                        .lineSpacing(8)
                        .foregroundColor(.appMutedFg)
                        .padding(.top, 8)
                    HStack(spacing: 8) {
                        Button {
                            neverShow()
                            onGo()
                        } label: {
                            Text("去看看")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.appPrimaryFg)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 6)
                                .background(Color.appPrimary)
                                .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                        Button { neverShow() } label: {
                            Text("不再提示")
                                .font(.system(size: 12))
                                .foregroundColor(.appMutedFg)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 6)
                                .overlay(Capsule().stroke(Color.appBorder, lineWidth: 0.5))
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.top, 12)
                }
                .padding(16)

                Button { dismissed = true } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 10))
                        .foregroundColor(.appMutedFg)
                        .padding(6)
                }
                .buttonStyle(.plain)
                .padding(4)
            }
            .frame(width: 256)
            .background(Color.appCard)
            .cornerRadius(16)
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.appBorder, lineWidth: 0.5))
            .shadow(color: .black.opacity(0.15), radius: 12, y: 4)
        }
    }

    private func neverShow() {
        UserDefaults.standard.set("1", forKey: Self.storageKey)
        dismissed = true
    }
}
