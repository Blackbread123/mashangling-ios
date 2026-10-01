import SwiftUI

// MARK: - 消息中心（对应网页 Messages.tsx：站内信 + 私信）
struct MessagesView: View {
    @EnvironmentObject var authManager: AuthManager
    @State private var tab = 0
    @State private var typeFilter = "all"
    @State private var messages: [MessageRow] = []
    @State private var conversations: [Conversation] = []
    @State private var loading = false
    @State private var showLogin = false

    private let types: [(String, String)] = [
        ("all", "全部"), ("like", "点赞"), ("want", "想要"), ("claimed", "领到"),
        ("restock", "补货"), ("repost", "返图"), ("soldout", "没有了"),
        ("claim_received", "领取申请"), ("claim_approved", "申请结果"),
        ("dm", "私信"), ("follow", "关注"), ("address", "地址"),
        ("gift", "礼物"), ("heart", "心选"),
    ]

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // 顶部切换
                HStack(spacing: 0) {
                    tabButton(0, title: "通知")
                    tabButton(1, title: "私信")
                }
                .padding(3)
                .background(Color.appSecondary)
                .cornerRadius(12)
                .padding(.horizontal, 16)
                .padding(.top, 10)

                if !authManager.isAuthenticated {
                    EmptyStateView(icon: "envelope", title: "登录后查看消息")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if tab == 0 {
                    notificationList
                } else {
                    conversationList
                }
            }
            .background(Color.appBackground)
            .navigationTitle("消息")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if tab == 0, authManager.isAuthenticated {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("全部已读") { Task { await markAll() } }
                            .font(.system(size: 12))
                            .foregroundColor(.appMutedFg)
                    }
                }
            }
            .task { await load() }
        }
    }

    private func tabButton(_ idx: Int, title: String) -> some View {
        Button { tab = idx } label: {
            Text(title)
                .font(.system(size: 14, weight: tab == idx ? .semibold : .regular))
                .foregroundColor(tab == idx ? .appForeground : .appMutedFg)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(tab == idx ? Color.appCard : Color.clear)
                .cornerRadius(10)
        }
        .buttonStyle(.plain)
    }

    // MARK: 通知列表
    private var notificationList: some View {
        VStack(spacing: 0) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(types, id: \.0) { t in
                        PillButton(title: t.1, selected: typeFilter == t.0) {
                            typeFilter = t.0
                            Task { await loadMessages() }
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
            }

            if loading && messages.isEmpty {
                LoadingView()
                Spacer()
            } else if messages.isEmpty {
                EmptyStateView(icon: "tray", title: "暂无通知")
                Spacer()
            } else {
                List(messages) { m in
                    messageRow(m)
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                        .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                }
                .listStyle(.plain)
                .refreshable { await loadMessages() }
            }
        }
    }

    private func messageRow(_ m: MessageRow) -> some View {
        Button {
            Task { await open(m) }
        } label: {
            HStack(alignment: .top, spacing: 10) {
                Circle()
                    .fill(m.read ? Color.clear : Color.appPrimary)
                    .frame(width: 8, height: 8)
                    .padding(.top, 6)
                VStack(alignment: .leading, spacing: 3) {
                    HStack {
                        Text(m.title)
                            .font(.system(size: 13, weight: m.read ? .regular : .semibold))
                            .foregroundColor(.appForeground)
                            .lineLimit(1)
                        Spacer()
                        Text(DateFmt.short(m.createdAt))
                            .font(.system(size: 10))
                            .foregroundColor(.appMutedFg)
                    }
                    if let c = m.content, !c.isEmpty {
                        Text(c)
                            .font(.system(size: 12))
                            .foregroundColor(.appMutedFg)
                            .lineLimit(2)
                    }
                }
            }
            .padding(12)
            .background(Color.appCard)
            .cornerRadius(4)
            .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color.appBorder, lineWidth: 0.5))
        }
        .buttonStyle(.plain)
    }

    // MARK: 会话列表
    private var conversationList: some View {
        Group {
            if loading && conversations.isEmpty {
                LoadingView()
                Spacer()
            } else if conversations.isEmpty {
                EmptyStateView(icon: "bubble.left.and.bubble.right", title: "暂无私信", subtitle: "去别人主页点「私信」开始聊天")
                Spacer()
            } else {
                List(conversations) { c in
                    NavigationLink(destination: DmThreadView(peerId: c.peerId, peerName: c.peerName ?? "")) {
                        HStack(spacing: 10) {
                            AvatarView(path: c.peerAvatar, name: c.peerName ?? "", size: 42)
                            VStack(alignment: .leading, spacing: 3) {
                                HStack {
                                    Text(c.peerName ?? "")
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundColor(.appForeground)
                                    Spacer()
                                    Text(DateFmt.short(c.lastAt))
                                        .font(.system(size: 10))
                                        .foregroundColor(.appMutedFg)
                                }
                                HStack {
                                    Text((c.fromMe == true ? "我：" : "") + (c.lastContent ?? ""))
                                        .font(.system(size: 12))
                                        .foregroundColor(.appMutedFg)
                                        .lineLimit(1)
                                    Spacer()
                                    if let n = c.unread, n > 0 {
                                        Text("\(n)")
                                            .font(.system(size: 10, weight: .bold))
                                            .foregroundColor(.white)
                                            .padding(.horizontal, 6)
                                            .padding(.vertical, 2)
                                            .background(Color.appDestructive)
                                            .clipShape(Capsule())
                                    }
                                }
                            }
                        }
                    }
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
                }
                .listStyle(.plain)
                .refreshable { await loadConversations() }
            }
        }
    }

    // MARK: 数据
    private func load() async {
        guard authManager.isAuthenticated else { return }
        loading = true
        async let m: () = loadMessages()
        async let c: () = loadConversations()
        _ = await (m, c)
        loading = false
    }

    private func loadMessages() async {
        guard authManager.isAuthenticated else { return }
        messages = (try? await MashanglingAPI.shared.message.list(type: typeFilter)) ?? []
    }

    private func loadConversations() async {
        guard authManager.isAuthenticated else { return }
        conversations = (try? await MashanglingAPI.shared.dm.conversations()) ?? []
    }

    private func open(_ m: MessageRow) async {
        if !m.read {
            try? await MashanglingAPI.shared.message.markRead(id: m.id)
            await loadMessages()
        }
    }

    private func markAll() async {
        try? await MashanglingAPI.shared.message.markAllRead()
        await loadMessages()
        ToastCenter.shared.success("已全部标记为已读")
    }
}
