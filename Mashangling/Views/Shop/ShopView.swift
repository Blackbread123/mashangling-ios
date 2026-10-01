import SwiftUI

// MARK: - 商店（对应网页 Shop.tsx：买好感 / 买果树 / 扩容卡片与母鸡位）
struct ShopView: View {
    @State private var data: ShopOverview? = nil
    @State private var friends: [FollowUser] = []
    @State private var loading = true
    @State private var busy = false
    @State private var selectedFriend: Int? = nil
    @State private var goodwillAmount = "1"

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 14) {
                if loading {
                    LoadingView()
                } else if let d = data {
                    // 余额
                    SectionCard {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("\(d.balance ?? 0)")
                                    .font(.system(size: 28, weight: .bold))
                                    .foregroundColor(.appForeground)
                                Text("可用积分（总 \(d.totalPoints ?? 0) · 已消耗 \(d.spent ?? 0)）")
                                    .font(.system(size: 10))
                                    .foregroundColor(.appMutedFg)
                            }
                            Spacer()
                        }
                    }

                    // 买好感
                    SectionCard {
                        VStack(alignment: .leading, spacing: 10) {
                            HStack(spacing: 6) {
                                Image(systemName: "heart.circle.fill")
                                    .font(.system(size: 13))
                                    .foregroundColor(.appRedFg)
                                Text("给好友买好感")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(.appForeground)
                                Text("\(d.goodwillCost ?? 1000) 积分 = 1 点好感")
                                    .font(.system(size: 10))
                                    .foregroundColor(.appMutedFg)
                            }
                            if friends.isEmpty {
                                Text("还没有互关好友")
                                    .font(.system(size: 11))
                                    .foregroundColor(.appMutedFg)
                            } else {
                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: 8) {
                                        ForEach(friends) { f in
                                            Button { selectedFriend = f.userId } label: {
                                                VStack(spacing: 4) {
                                                    AvatarView(path: f.avatar, name: f.name ?? "", size: 40)
                                                        .overlay(
                                                            Circle().stroke(Color.appPrimary,
                                                                            lineWidth: selectedFriend == f.userId ? 2 : 0)
                                                        )
                                                    Text(f.name ?? "")
                                                        .font(.system(size: 10))
                                                        .foregroundColor(selectedFriend == f.userId ? .appPrimary : .appMutedFg)
                                                        .lineLimit(1)
                                                        .frame(width: 56)
                                                }
                                            }
                                            .buttonStyle(.plain)
                                        }
                                    }
                                }
                                HStack(spacing: 8) {
                                    AppTextField(text: $goodwillAmount, placeholder: "好感点数", keyboard: .numberPad)
                                        .frame(width: 110)
                                    Button { Task { await buyGoodwill() } } label: {
                                        Text("购买")
                                            .font(.system(size: 13, weight: .medium))
                                            .foregroundColor(.appPrimaryFg)
                                            .padding(.horizontal, 20)
                                            .padding(.vertical, 9)
                                            .background(Color.appPrimary)
                                            .clipShape(Capsule())
                                    }
                                    .disabled(selectedFriend == nil || (Int(goodwillAmount) ?? 0) < 1 || busy)
                                    Spacer()
                                }
                            }
                        }
                    }

                    // 果树
                    if let trees = d.trees, !trees.isEmpty {
                        SectionCard {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("果树（果实周日 23:00 落地结算积分）")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(.appForeground)
                                ForEach(trees) { t in
                                    HStack(spacing: 10) {
                                        AppImage(path: "/farm/tree_\(t.key).png", contentMode: .fit)
                                            .frame(width: 36, height: 36)
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(t.name)
                                                .font(.system(size: 13, weight: .medium))
                                                .foregroundColor(.appForeground)
                                            Text("果实价值 \(t.fruitValue) 积分/个")
                                                .font(.system(size: 10))
                                                .foregroundColor(.appMutedFg)
                                        }
                                        Spacer()
                                        if t.owned {
                                            MiniBadge(text: "已拥有", fg: .appEmeraldFg, bg: .appEmeraldBg)
                                        } else if t.purchasable {
                                            Button { Task { await buyTree(t) } } label: {
                                                Text(t.cost == 0 ? "免费领取" : "\(t.cost) 积分")
                                                    .font(.system(size: 11, weight: .medium))
                                                    .foregroundColor(t.canAfford ? .appPrimaryFg : .appMutedFg)
                                                    .padding(.horizontal, 12)
                                                    .padding(.vertical, 6)
                                                    .background(t.canAfford ? Color.appPrimary : Color.appSecondary)
                                                    .clipShape(Capsule())
                                            }
                                            .disabled(busy || !t.canAfford)
                                        } else {
                                            MiniBadge(text: "未解锁", fg: .appMutedFg, bg: .appSecondary)
                                        }
                                    }
                                }
                            }
                        }
                    }

                    // 扩容位
                    if let items = d.items, !items.isEmpty {
                        SectionCard {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("扩容与解锁")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(.appForeground)
                                ForEach(items) { it in
                                    HStack {
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text("\(it.name)（\(it.count)/\(it.max)）")
                                                .font(.system(size: 13, weight: .medium))
                                                .foregroundColor(.appForeground)
                                            Text(it.desc)
                                                .font(.system(size: 10))
                                                .foregroundColor(.appMutedFg)
                                        }
                                        Spacer()
                                        if let cost = it.nextCost {
                                            Text("下一档 \(cost) 积分")
                                                .font(.system(size: 11))
                                                .foregroundColor(.appAmberFg)
                                        }
                                        NavigationLink(destination: CardStudioView()) {
                                            Text(it.editLabel ?? "去管理")
                                                .font(.system(size: 11))
                                                .foregroundColor(.appPrimary)
                                                .padding(.horizontal, 10)
                                                .padding(.vertical, 5)
                                                .overlay(Capsule().stroke(Color.appPrimary, lineWidth: 1))
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                            }
                        }
                    }
                } else {
                    EmptyStateView(icon: "bag", title: "商店加载失败")
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
        }
        .background(Color.appBackground)
        .navigationTitle("商店")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            data = try? await MashanglingAPI.shared.shop.overview()
            friends = (try? await MashanglingAPI.shared.follow.mutuals()) ?? []
            loading = false
        }
    }

    private func buyGoodwill() async {
        guard let fid = selectedFriend, let amount = Int(goodwillAmount), amount >= 1 else { return }
        busy = true
        defer { busy = false }
        do {
            let r = try await MashanglingAPI.shared.shop.buyGoodwill(friendId: fid, amount: amount)
            ToastCenter.shared.success("已送出 \(r.amount) 点好感（消耗 \(r.cost) 积分）")
            data = try? await MashanglingAPI.shared.shop.overview()
        } catch { ToastCenter.shared.error(error.localizedDescription) }
    }

    private func buyTree(_ t: ShopOverview.ShopTree) async {
        busy = true
        defer { busy = false }
        do {
            let r = try await MashanglingAPI.shared.farm.buyTree(treeIdx: t.idx)
            ToastCenter.shared.success("🌳 \(r.name) 种下了！")
            data = try? await MashanglingAPI.shared.shop.overview()
        } catch { ToastCenter.shared.error(error.localizedDescription) }
    }
}

// MARK: - 某领取人的寄件记录（对应网页 /shipping/user/:userId）
struct UserShipmentsView: View {
    let userId: Int

    @State private var data: UserShipmentsResponse? = nil
    @State private var loading = true

    var body: some View {
        Group {
            if loading {
                LoadingView()
            } else if let d = data {
                List(d.items ?? []) { item in
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            NavigationLink(destination: ShowcaseDetailView(showcaseId: item.showcaseId)) {
                                Text(item.showcaseTitle ?? "")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundColor(.appPrimary)
                                    .lineLimit(1)
                            }
                            Spacer()
                            Text(DateFmt.short(item.createdAt))
                                .font(.system(size: 10))
                                .foregroundColor(.appMutedFg)
                        }
                        Text("\(item.nickname ?? "")  \(item.phone ?? "")")
                            .font(.system(size: 12))
                            .foregroundColor(.appForeground)
                        Text(item.full ?? item.address ?? "")
                            .font(.system(size: 11))
                            .foregroundColor(.appMutedFg)
                        HStack(spacing: 8) {
                            if let no = item.trackingNo, !no.isEmpty {
                                Text("单号 \(no)")
                                    .font(.system(size: 10, design: .monospaced))
                                    .foregroundColor(.appMutedFg)
                            }
                            if let fee = item.fee {
                                Text("邮费 \(item.feeLabel ?? "\(fee)")")
                                    .font(.system(size: 10))
                                    .foregroundColor(.appMutedFg)
                            }
                            Spacer()
                        }
                    }
                    .padding(.vertical, 4)
                }
                .listStyle(.plain)
            } else {
                EmptyStateView(icon: "cube.box", title: "暂无寄件记录")
            }
        }
        .background(Color.appBackground)
        .navigationTitle(data?.claimer?.name ?? "TA 的寄件")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            data = try? await MashanglingAPI.shared.address.userShipments(userId: userId)
            loading = false
        }
    }
}

// MARK: - 邮费审批详情（对应网页 /shipping/approval/:id）
struct ApprovalDetailSheet: View {
    let approvalId: Int
    var onDone: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var detail: ApprovalDetail? = nil
    @State private var reason = ""
    @State private var busy = false

    var body: some View {
        NavigationStack {
            Group {
                if let d = detail {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 12) {
                            SectionCard {
                                VStack(alignment: .leading, spacing: 6) {
                                    Text(d.showcaseTitle ?? "")
                                        .font(.system(size: 15, weight: .semibold))
                                        .foregroundColor(.appForeground)
                                    Text("领取人：\(d.claimerName ?? "")")
                                        .font(.system(size: 12))
                                        .foregroundColor(.appMutedFg)
                                    Text("邮费：\(d.fee ?? 0) 积分 · 类型：\(d.kind == "proof" ? "补邮凭证" : "免邮申请")")
                                        .font(.system(size: 12))
                                        .foregroundColor(.appMutedFg)
                                    if let addr = d.addressFull {
                                        Text("地址：\(addr)")
                                            .font(.system(size: 11))
                                            .foregroundColor(.appMutedFg)
                                    }
                                    if let no = d.trackingNo, !no.isEmpty {
                                        Text("单号：\(no)")
                                            .font(.system(size: 11))
                                            .foregroundColor(.appMutedFg)
                                    }
                                }
                            }
                            if let proof = d.proofImage, !proof.isEmpty {
                                VStack(alignment: .leading, spacing: 6) {
                                    Text("付款凭证")
                                        .font(.system(size: 13, weight: .semibold))
                                        .foregroundColor(.appForeground)
                                    AppImage(path: proof)
                                        .aspectRatio(contentMode: .fit)
                                        .frame(maxWidth: .infinity)
                                        .cornerRadius(10)
                                }
                            }
                            if d.isOwner == true && (d.status == "submitted" || d.status == "pending") {
                                TextField("驳回理由（驳回时必填）…", text: $reason)
                                    .font(.system(size: 13))
                                    .padding(10)
                                    .background(Color.appInput)
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                                HStack(spacing: 10) {
                                    Button { Task { await review("approve") } } label: {
                                        Text("通过")
                                            .font(.system(size: 13, weight: .medium))
                                            .foregroundColor(.appPrimaryFg)
                                            .frame(maxWidth: .infinity)
                                            .padding(.vertical, 10)
                                            .background(Color.appPrimary)
                                            .clipShape(Capsule())
                                    }
                                    .disabled(busy)
                                    Button { Task { await review("reject") } } label: {
                                        Text("驳回")
                                            .font(.system(size: 13))
                                            .foregroundColor(.appDestructive)
                                            .frame(maxWidth: .infinity)
                                            .padding(.vertical, 10)
                                            .overlay(Capsule().stroke(Color.appDestructive.opacity(0.5), lineWidth: 1))
                                    }
                                    .disabled(busy || (reason.trimmingCharacters(in: .whitespaces).isEmpty))
                                }
                            } else {
                                MiniBadge(text: d.status ?? "", fg: .appMutedFg, bg: .appSecondary)
                            }
                        }
                        .padding(16)
                    }
                } else {
                    LoadingView()
                }
            }
            .background(Color.appBackground)
            .navigationTitle("审批详情")
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
            detail = try? await MashanglingAPI.shared.address.approvalDetail(id: approvalId)
        }
    }

    private func review(_ action: String) async {
        busy = true
        defer { busy = false }
        do {
            _ = try await MashanglingAPI.shared.address.reviewApproval(
                approvalId: approvalId, action: action,
                reason: reason.trimmingCharacters(in: .whitespaces))
            ToastCenter.shared.success(action == "approve" ? "已通过" : "已驳回")
            dismiss()
            onDone()
        } catch { ToastCenter.shared.error(error.localizedDescription) }
    }
}
