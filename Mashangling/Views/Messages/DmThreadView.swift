import SwiftUI

// MARK: - 私信会话页（对应网页 DmThread.tsx）
struct DmThreadView: View {
    let peerId: Int
    var peerName: String = ""

    @EnvironmentObject var authManager: AuthManager
    @State private var thread: DMThreadResponse? = nil
    @State private var input = ""
    @State private var replyTo: DMItem? = nil
    @State private var friendship: FriendshipInfo? = nil
    @State private var sending = false
    @State private var timer: Timer? = nil

    var body: some View {
        VStack(spacing: 0) {
            // 好感度条（互关好友）
            if let f = friendship, f.mutual {
                HStack(spacing: 8) {
                    Image(systemName: "heart.circle.fill")
                        .font(.system(size: 12))
                        .foregroundColor(.appRedFg)
                    Text("好感 Lv.\(f.level ?? 0)")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.appForeground)
                    if let total = f.total {
                        Text("累计 \(total)")
                            .font(.system(size: 10))
                            .foregroundColor(.appMutedFg)
                    }
                    Spacer()
                    if let badges = f.badges, !badges.isEmpty {
                        HStack(spacing: 4) {
                            ForEach(badges.prefix(3)) { b in
                                AppImage(path: b.image)
                                    .frame(width: 22, height: 22)
                                    .cornerRadius(5)
                            }
                        }
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 7)
                .background(Color.appSecondary.opacity(0.4))
            }

            // 消息列表
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(thread?.items ?? []) { item in
                            bubble(item)
                                .id(item.id)
                        }
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                }
                .scrollDismissesKeyboard(.interactively)
                .onChange(of: thread?.items.count) { _ in
                    if let last = thread?.items.last {
                        withAnimation { proxy.scrollTo(last.id, anchor: .bottom) }
                    }
                }
                .onAppear {
                    if let last = thread?.items.last {
                        proxy.scrollTo(last.id, anchor: .bottom)
                    }
                }
            }

            // 回复预览条
            if let r = replyTo {
                HStack(spacing: 8) {
                    Rectangle().fill(Color.appPrimary).frame(width: 3)
                    Text("回复：\(r.content)")
                        .font(.system(size: 11))
                        .foregroundColor(.appMutedFg)
                        .lineLimit(1)
                    Spacer()
                    Button { replyTo = nil } label: {
                        Image(systemName: "xmark").font(.system(size: 10)).foregroundColor(.appMutedFg)
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 6)
                .background(Color.appSecondary.opacity(0.5))
            }

            // 输入区
            HStack(spacing: 8) {
                TextField(thread?.peer.dmBlocked == true ? "对方已关闭私信" : "发私信…", text: $input)
                    .font(.system(size: 14))
                    .padding(.horizontal, 12)
                    .frame(height: 40)
                    .background(Color.appCard)
                    .overlay(RoundedRectangle(cornerRadius: 20).stroke(Color.appInput, lineWidth: 1))
                    .cornerRadius(20)
                    .disabled(thread?.peer.dmBlocked == true)
                    .onSubmit { Task { await send() } }
                Button { Task { await send() } } label: {
                    Image(systemName: "paperplane.fill")
                        .font(.system(size: 14))
                        .foregroundColor(.appPrimaryFg)
                        .frame(width: 40, height: 40)
                        .background(Color.appPrimary)
                        .clipShape(Circle())
                }
                .disabled(input.trimmingCharacters(in: .whitespaces).isEmpty || sending || thread?.peer.dmBlocked == true)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(Color.appBackground)
        }
        .background(Color.appBackground)
        .navigationTitle(thread?.peer.name ?? peerName)
        .navigationBarTitleDisplayMode(.inline)
        // 会话页隐藏自定义底栏：输入框获得完整底部空间，不再被底栏盖住
        .onAppear { TabBarVisibility.shared.hidden = true }
        .onDisappear {
            TabBarVisibility.shared.hidden = false
            timer?.invalidate()
            timer = nil
        }
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                NavigationLink(destination: ProfileView(userId: peerId)) {
                    Image(systemName: "person.circle")
                        .foregroundColor(.appForeground)
                }
            }
        }
        .task {
            await load()
            timer?.invalidate()
            timer = Timer.scheduledTimer(withTimeInterval: 10, repeats: true) { _ in
                Task { await load(silent: true) }
            }
        }
    }

    // MARK: 气泡
    private func bubble(_ item: DMItem) -> some View {
        let isMe = item.fromUserId == authManager.currentUser?.id
        return HStack(alignment: .bottom, spacing: 6) {
            if isMe { Spacer(minLength: 40) } else {
                AvatarView(path: thread?.peer.avatar, name: thread?.peer.name ?? "", size: 30)
            }
            VStack(alignment: isMe ? .trailing : .leading, spacing: 3) {
                if let rt = item.replyTo {
                    Text(rt.content)
                        .font(.system(size: 10))
                        .foregroundColor(.appMutedFg)
                        .lineLimit(1)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.appSecondary.opacity(0.6))
                        .cornerRadius(6)
                }
                // 附件快照
                attachmentView(item)
                if !item.content.isEmpty {
                    Text(item.content)
                        .font(.system(size: 14))
                        .foregroundColor(isMe ? .appPrimaryFg : .appForeground)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(isMe ? Color.appPrimary : Color.appCard)
                        .cornerRadius(14)
                        .overlay(
                            RoundedRectangle(cornerRadius: 14)
                                .stroke(isMe ? Color.clear : Color.appBorder, lineWidth: 0.5)
                        )
                        .contextMenu {
                            Button { replyTo = item } label: {
                                Label("回复", systemImage: "arrowshape.turn.up.left")
                            }
                            Button {
                                UIPasteboard.general.string = item.content
                            } label: {
                                Label("复制", systemImage: "doc.on.doc")
                            }
                        }
                }
                Text(DateFmt.time(item.createdAt))
                    .font(.system(size: 9))
                    .foregroundColor(.appMutedFg)
            }
            if !isMe { Spacer(minLength: 40) }
        }
    }

    // MARK: 附件（橱窗 / 卡片 / 名片 / 礼物）
    @ViewBuilder
    private func attachmentView(_ item: DMItem) -> some View {
        let isMe = item.fromUserId == authManager.currentUser?.id
        if let s = item.showcase {
            NavigationLink(destination: ShowcaseDetailView(showcaseId: s.id)) {
                HStack(spacing: 8) {
                    AppImage(path: s.coverImage)
                        .frame(width: 44, height: 44)
                        .cornerRadius(8)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("分享了一个橱窗").font(.system(size: 10)).foregroundColor(.appMutedFg)
                        Text(s.title).font(.system(size: 12, weight: .medium)).foregroundColor(.appForeground).lineLimit(1)
                    }
                    Spacer()
                    Image(systemName: "chevron.right").font(.system(size: 10)).foregroundColor(.appMutedFg)
                }
                .padding(8)
                .frame(maxWidth: 240)
                .background(Color.appCard)
                .cornerRadius(4)
                .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color.appBorder, lineWidth: 0.5))
            }
            .buttonStyle(.plain)
        }
        if let c = item.cardPost {
            HStack(spacing: 8) {
                if let cfg = c.config {
                    CardThemeThumbnailView(config: cfg)
                        .frame(width: 40, height: 54)
                        .cornerRadius(6)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text("分享了一套卡片").font(.system(size: 10)).foregroundColor(.appMutedFg)
                    Text(c.removed == true ? "（已撤下）\(c.title)" : c.title)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.appForeground)
                        .lineLimit(1)
                }
                Spacer()
            }
            .padding(8)
            .frame(maxWidth: 240)
            .background(Color.appCard)
            .cornerRadius(4)
            .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color.appBorder, lineWidth: 0.5))
        }
        if let p = item.profileUser {
            NavigationLink(destination: ProfileView(userId: p.id)) {
                HStack(spacing: 8) {
                    AvatarView(path: p.avatar, name: p.name, size: 34)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("分享了名片").font(.system(size: 10)).foregroundColor(.appMutedFg)
                        Text(p.name).font(.system(size: 12, weight: .medium)).foregroundColor(.appForeground)
                    }
                    Spacer()
                }
                .padding(8)
                .frame(maxWidth: 240)
                .background(Color.appCard)
                .cornerRadius(4)
                .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color.appBorder, lineWidth: 0.5))
            }
            .buttonStyle(.plain)
        }
        if let g = item.gift, !g.claimed, !isMe {
            Button {
                Task { await claimGift(g.id) }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "gift.fill")
                        .font(.system(size: 18))
                        .foregroundColor(.appRedFg)
                    Text("收到一个礼物，点击领取")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.appForeground)
                }
                .padding(10)
                .background(Color.appAmberBg)
                .cornerRadius(10)
            }
            .buttonStyle(.plain)
        } else if let g = item.gift {
            HStack(spacing: 8) {
                Image(systemName: "gift")
                    .font(.system(size: 16))
                    .foregroundColor(.appAmberFg)
                Text(g.claimed ? "礼物已领取" : "送出了一份礼物")
                    .font(.system(size: 12))
                    .foregroundColor(.appMutedFg)
            }
            .padding(8)
        }
    }

    // MARK: 数据
    private func load(silent: Bool = false) async {
        do {
            thread = try await MashanglingAPI.shared.dm.thread(peerId: peerId)
            try? await MashanglingAPI.shared.dm.markDmRead(peerId: peerId)
        } catch {
            if !silent { ToastCenter.shared.error(error.localizedDescription) }
        }
        friendship = try? await MashanglingAPI.shared.gift.friendshipInfo(peerId: peerId)
    }

    private func send() async {
        let text = input.trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty else { return }
        sending = true
        defer { sending = false }
        do {
            _ = try await MashanglingAPI.shared.dm.send(
                toUserId: peerId, content: text,
                requireMutual: false, replyToId: replyTo?.id)
            input = ""
            replyTo = nil
            await load(silent: true)
        } catch {
            ToastCenter.shared.error(error.localizedDescription)
        }
    }

    private func claimGift(_ giftId: Int) async {
        do {
            _ = try await MashanglingAPI.shared.gift.claim(giftId: giftId)
            ToastCenter.shared.success("礼物已领取，无料码可在橱窗详情查看")
            await load(silent: true)
        } catch { ToastCenter.shared.error(error.localizedDescription) }
    }
}
