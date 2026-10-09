import SwiftUI

// MARK: - 积分商城（对应网页 Shop.tsx：买好感 / 扩容位 / 农场果树）
struct ShopView: View {
    @EnvironmentObject var authManager: AuthManager
    @State private var data: ShopOverview? = nil
    @State private var loading = true
    @State private var showGift = false
    @State private var showLogin = false

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 0) {
                // 标题行（mb-6：amber-100 圆 + 购物袋 + h1）
                HStack(spacing: 8) {
                    ZStack {
                        Circle().fill(Color.fixAmber100)
                        Image(systemName: "bag")
                            .font(.system(size: 20))
                            .foregroundColor(.fixAmber600)
                    }
                    .frame(width: 36, height: 36)
                    Text("积分商城")
                        .font(.system(size: 24, weight: .bold))
                        .tracking(-0.6)
                        .foregroundColor(.appForeground)
                }
                .padding(.bottom, 24)

                // 余额卡片（rounded-2xl=5 + border-amber-200；盐系已去渐变=透明底）
                HStack(spacing: 12) {
                    Image(systemName: "centsign.circle")
                        .font(.system(size: 28))
                        .foregroundColor(.fixAmber500)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("当前可用积分")
                            .font(.system(size: 12))
                            .foregroundColor(.fixAmber700)
                        Text(data.map { "\($0.balance ?? 0)" } ?? "…")
                            .font(.system(size: 24, weight: .bold))
                            .monospacedDigit()
                            .foregroundColor(.fixAmber900)
                    }
                    Spacer(minLength: 0)
                    if let d = data {
                        Text("累计 \(d.totalPoints ?? 0)\n已花 \(d.spent ?? 0)")
                            .font(.system(size: 12))
                            .lineSpacing(6)
                            .multilineTextAlignment(.trailing)
                            .foregroundColor(.fixAmber700.opacity(0.8))
                    }
                }
                .padding(.horizontal, 20).padding(.vertical, 16)
                .overlay(RoundedRectangle(cornerRadius: 5).stroke(Color.fixAmber200, lineWidth: 1))
                .padding(.bottom, 24)

                if loading {
                    Text("加载中…")
                        .font(.system(size: 14))
                        .foregroundColor(.appMutedFg)
                        .frame(maxWidth: .infinity)
                        .multilineTextAlignment(.center)
                        .padding(.vertical, 80)
                } else if let d = data {
                    VStack(spacing: 16) {
                        goodwillCard(d)
                        ForEach(d.items ?? []) { item in
                            shopItemCard(d, item)
                        }
                        treesCard(d)
                    }
                } else {
                    EmptyStateView(icon: "bag", title: "商店加载失败")
                        .frame(maxWidth: .infinity)
                }

                // 底部说明（mt-6 居中 muted）
                Text("购买后可在「我的主页」对应位置查看与编辑：卡片/母鸡在「个性化」页，鸡蛋与果树在农场")
                    .font(.system(size: 12))
                    .foregroundColor(.appMutedFg)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 24)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 24)
        }
        .background(Color.appBackground)
        .navigationTitle("积分商城")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showLogin) { LoginView() }
        .sheet(isPresented: $showGift) {
            GoodwillGiftSheet(balance: data?.balance ?? 0,
                              cost: data?.goodwillCost ?? 1000) {
                Task { data = try? await MashanglingAPI.shared.shop.overview() }
            }
        }
        .task {
            data = try? await MashanglingAPI.shared.shop.overview()
            loading = false
        }
        .refreshable {
            data = try? await MashanglingAPI.shared.shop.overview()
        }
    }

    // MARK: 好感度兑换卡（对应网页 HeartHandshake 卡）
    private func goodwillCard(_ d: ShopOverview) -> some View {
        let cost = d.goodwillCost ?? 1000
        let balance = d.balance ?? 0
        return HStack(spacing: 16) {
            ZStack {
                RoundedRectangle(cornerRadius: 4).fill(Color.appBrand100)
                Image(systemName: "heart.fill")
                    .font(.system(size: 24))
                    .foregroundColor(.appBrand600)
            }
            .frame(width: 48, height: 48)
            VStack(alignment: .leading, spacing: 0) {
                Text("好友好感度")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.appForeground)
                Text("兑换后送给指定互关好友，好感度记在你们的友谊上（双方主页可见），可用于上传好友徽章")
                    .font(.system(size: 12))
                    .lineSpacing(7)
                    .foregroundColor(.appMutedFg)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 2)
                (Text("\(cost) 积分 = 1 点好感度")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(balance >= cost ? .fixAmber600 : .appMutedFg)
                 + Text(balance >= cost ? "" : "（还差 \(cost - balance)）")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.appMutedFg))
                    .padding(.top, 4)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            Button {
                guard authManager.isAuthenticated else { showLogin = true; return }
                showGift = true
            } label: {
                HStack(spacing: 4) {
                    Text("兑换并赠送")
                    Image(systemName: "arrow.right").font(.system(size: 16))
                }
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.appPrimaryFg)
                .padding(.horizontal, 16).padding(.vertical, 8)
                .background(Color.appPrimary)
                .clipShape(Capsule())
            }
            .buttonStyle(.plain)
        }
        .padding(20)
        .background(Color.appCard)
        .cornerRadius(5)
        .overlay(RoundedRectangle(cornerRadius: 5).stroke(Color.appBorder, lineWidth: 1))
    }

    // MARK: 扩容位卡（theme=卡片主题 / hen=母鸡 / egg=鸡蛋）
    private func shopItemCard(_ d: ShopOverview, _ item: ShopOverview.ShopItem) -> some View {
        let balance = d.balance ?? 0
        let full = item.nextCost == nil
        let afford = !full && balance >= (item.nextCost ?? 0)
        let iconName = item.key == "theme" ? "paintpalette" : item.key == "hen" ? "photo" : "oval"
        let iconBg: Color = item.key == "theme" ? .fixViolet100 : item.key == "hen" ? .fixOrange100 : .fixYellow100
        let iconFg: Color = item.key == "theme" ? .fixViolet600 : item.key == "hen" ? .fixOrange600 : .fixYellow600
        return HStack(spacing: 16) {
            ZStack {
                RoundedRectangle(cornerRadius: 4).fill(iconBg)
                Image(systemName: iconName)
                    .font(.system(size: 24))
                    .foregroundColor(iconFg)
            }
            .frame(width: 48, height: 48)
            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .lastTextBaseline, spacing: 8) {
                    Text(item.name)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.appForeground)
                    Text("已有 \(item.count)/\(item.max)")
                        .font(.system(size: 12))
                        .foregroundColor(.appMutedFg)
                }
                Text(item.desc)
                    .font(.system(size: 12))
                    .lineSpacing(7)
                    .foregroundColor(.appMutedFg)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 2)
                Group {
                    if full {
                        Text("已达上限")
                            .foregroundColor(.appMutedFg)
                    } else if item.nextCost == 0 {
                        Text(item.count == 0 ? "第一件免费" : "有已购空位 · 补建免费")
                            .foregroundColor(.fixEmerald600)
                    } else {
                        (Text("下一件 \(item.nextCost ?? 0) 积分")
                            .foregroundColor(afford ? .fixAmber600 : .appMutedFg)
                         + Text(afford ? "" : "（还差 \((item.nextCost ?? 0) - balance)）")
                            .foregroundColor(.appMutedFg))
                    }
                }
                .font(.system(size: 12, weight: .medium))
                .padding(.top, 4)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            // 跳转目标：theme→卡片工作室，hen→个性化页母鸡管理（网页：卡片/母鸡都在「个性化」页），egg→我的主页
            NavigationLink(destination: itemDestination(item.key)) {
                HStack(spacing: 4) {
                    Text(item.editLabel ?? "去管理")
                    Image(systemName: "arrow.right").font(.system(size: 16))
                }
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.appPrimaryFg)
                .padding(.horizontal, 16).padding(.vertical, 8)
                .background(Color.appPrimary)
                .clipShape(Capsule())
            }
            .buttonStyle(.plain)
        }
        .padding(20)
        .background(Color.appCard)
        .cornerRadius(5)
        .overlay(RoundedRectangle(cornerRadius: 5).stroke(Color.appBorder, lineWidth: 1))
    }

    @ViewBuilder
    private func itemDestination(_ key: String) -> some View {
        switch key {
        case "theme": CardStudioView()
        case "hen":   CardStudioView()
        default:      ProfileView(userId: authManager.currentUser?.id ?? 0)
        }
    }

    // MARK: 农场果树（对应网页绿色渐变卡，盐系去渐变后=透明底 + border-green-200）
    private func treesCard(_ d: ShopOverview) -> some View {
        let balance = d.balance ?? 0
        let trees = d.trees ?? []
        return VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 8) {
                ZStack {
                    RoundedRectangle(cornerRadius: 3).fill(Color.fixGreen100)
                    Image(systemName: "leaf")
                        .font(.system(size: 16))
                        .foregroundColor(.fixGreen600)
                }
                .frame(width: 32, height: 32)
                Text("农场果树")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.appForeground)
                Text("唯一限购 · 按顺序解锁 · 第一种免费")
                    .font(.system(size: 12))
                    .foregroundColor(.appMutedFg)
            }
            .padding(.bottom, 12)

            LazyVGrid(columns: [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)], spacing: 8) {
                ForEach(trees) { t in
                    VStack(spacing: 0) {
                        AppImage(path: "/farm/tree_\(t.key).png", contentMode: .fit)
                            .frame(width: 56, height: 56)
                        Text(t.name)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.appForeground)
                            .padding(.top, 4)
                        Text("\(t.fruit) \(t.fruitValue) 积分/个")
                            .font(.system(size: 12))
                            .foregroundColor(.appMutedFg)
                        if t.owned {
                            Text("已种下")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.fixGreen600)
                                .padding(.top, 6)
                        } else if t.purchasable {
                            Button { Task { await buyTree(t) } } label: {
                                Text(t.cost == 0 ? "免费领取" : (t.canAfford ? "\(t.cost) 积分" : "还差 \(t.cost - balance)"))
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 12).padding(.vertical, 4)
                                    .background(Color.fixGreen600)
                                    .clipShape(Capsule())
                                    .opacity(t.canAfford ? 1 : 0.5)
                            }
                            .buttonStyle(.plain)
                            .disabled(!t.canAfford)
                            .padding(.top, 6)
                        } else {
                            Text("\(t.cost) 积分 · 待解锁")
                                .font(.system(size: 12))
                                .foregroundColor(.appMutedFg)
                                .padding(.top, 6)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(12)
                    .background(t.owned || t.purchasable ? Color.white.opacity(0.7) : Color.white.opacity(0.4))
                    .cornerRadius(4)
                    .overlay(
                        RoundedRectangle(cornerRadius: 4)
                            .stroke(t.owned ? Color.fixGreen300 : t.purchasable ? Color.fixAmber300 : Color.appBorder,
                                    style: StrokeStyle(lineWidth: 1, dash: t.owned || t.purchasable ? [] : [6]))
                    )
                }
            }

            // 收益算法简述
            HStack(alignment: .top, spacing: 8) {
                Image(systemName: "info.circle")
                    .font(.system(size: 14))
                    .foregroundColor(.fixGreen600)
                    .padding(.top, 2)
                Text("收益算法：每天 23:00 结算，利息 =（1 + 生产者系数×数量）×（1 + 产物系数×数量）开 7 次方根 × 当时可用积分，连滚 7 天恰等于原周收益。生产者指母鸡和果树，产物指鸡蛋和果实，越靠后的果树系数越高。果实每天自动长出 1 个，周日结算时落地换成积分；鸡蛋持有上限 = 母鸡数 × 5。")
                    .font(.system(size: 12))
                    .lineSpacing(7)
                    .foregroundColor(.appMutedFg)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.white.opacity(0.6))
            .cornerRadius(4)
            .padding(.top, 12)
        }
        .padding(20)
        .cornerRadius(5)
        .overlay(RoundedRectangle(cornerRadius: 5).stroke(Color.fixGreen200, lineWidth: 1))
    }

    private func buyTree(_ t: ShopOverview.ShopTree) async {
        do {
            let r = try await MashanglingAPI.shared.farm.buyTree(treeIdx: t.idx)
            ToastCenter.shared.success(r.cost > 0 ? "已种下「\(r.name)」（花费 \(r.cost) 积分）" : "已免费领取「\(r.name)」")
            data = try? await MashanglingAPI.shared.shop.overview()
        } catch { ToastCenter.shared.error(error.localizedDescription) }
    }
}

// MARK: - 好感度兑换弹窗（对应网页 Shop.tsx 的 gift Dialog）
struct GoodwillGiftSheet: View {
    let balance: Int
    let cost: Int
    var onDone: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var friends: [FollowUser] = []
    @State private var loading = true
    @State private var friendId: Int? = nil
    @State private var amountText = "1"
    @State private var busy = false

    private var giftN: Int { max(1, min(50, Int(amountText) ?? 1)) }
    private var giftTotal: Int { giftN * cost }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 16) {
                Text("\(cost) 积分 = 1 点好感度，送给互关好友后双方主页可见")
                    .font(.system(size: 12))
                    .lineSpacing(7)
                    .foregroundColor(.appMutedFg)

                Text("送给哪位好友")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.appMutedFg)

                if loading {
                    LoadingView().frame(maxWidth: .infinity)
                } else if friends.isEmpty {
                    Text("还没有互相关注的好友，先去互关一位吧")
                        .font(.system(size: 12))
                        .foregroundColor(.appMutedFg)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .overlay(RoundedRectangle(cornerRadius: 3).stroke(Color.appBorder, style: StrokeStyle(lineWidth: 1, dash: [6])))
                } else {
                    ScrollView {
                        VStack(spacing: 4) {
                            ForEach(friends) { f in
                                Button { friendId = f.userId } label: {
                                    HStack(spacing: 8) {
                                        AvatarView(path: f.avatar, name: f.name ?? "", size: 24)
                                        Text(f.name ?? "")
                                            .font(.system(size: 14))
                                            .foregroundColor(.appForeground)
                                            .lineLimit(1)
                                        Spacer(minLength: 0)
                                    }
                                    .padding(.horizontal, 12).padding(.vertical, 8)
                                    .background(friendId == f.userId ? Color.appBrand50.opacity(0.6) : Color.clear)
                                    .cornerRadius(3)
                                    .overlay(RoundedRectangle(cornerRadius: 3)
                                        .stroke(friendId == f.userId ? Color.appBrand400 : Color.appBorder, lineWidth: 1))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    .frame(maxHeight: 176)
                }

                HStack(spacing: 8) {
                    Text("送多少点")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.appMutedFg)
                    AppTextField(text: $amountText, placeholder: "1", keyboard: .numberPad)
                        .frame(width: 80)
                        .onChange(of: amountText) { v in
                            let digits = String(v.filter { $0.isNumber }.prefix(2))
                            if digits != v { amountText = digits }
                        }
                    (Text("点（最多 50 点）= ")
                     + Text("\(giftTotal) 积分").fontWeight(.bold).foregroundColor(.fixAmber600))
                        .font(.system(size: 12))
                        .foregroundColor(.appMutedFg)
                    Spacer(minLength: 0)
                }

                Button { Task { await submit() } } label: {
                    Text(busy ? "兑换中…"
                         : giftTotal > balance ? "积分不足（还差 \(giftTotal - balance)）"
                         : "确认兑换并赠送（\(giftTotal) 积分）")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.appPrimaryFg)
                        .frame(maxWidth: .infinity)
                        .frame(height: 36)
                        .background(Color.appPrimary)
                        .clipShape(Capsule())
                        .opacity(friendId == nil || giftTotal > balance ? 0.6 : 1)
                }
                .buttonStyle(.plain)
                .disabled(busy || friendId == nil || giftTotal > balance)
                Spacer()
            }
            .padding(20)
            .background(Color.appBackground)
            .navigationTitle("兑换好感度送给好友")
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
            friends = (try? await MashanglingAPI.shared.follow.mutuals()) ?? []
            loading = false
        }
    }

    private func submit() async {
        guard let fid = friendId else { return }
        busy = true
        defer { busy = false }
        do {
            let r = try await MashanglingAPI.shared.shop.buyGoodwill(friendId: fid, amount: giftN)
            ToastCenter.shared.success("已送出 \(r.amount) 点好感度（花费 \(r.cost) 积分）")
            dismiss()
            onDone()
        } catch { ToastCenter.shared.error(error.localizedDescription) }
    }
}

// MARK: - 某领取人的寄件记录（逐行复刻网页 UserShipments.tsx，/shipping/user/:userId）
struct UserShipmentsView: View {
    let userId: Int

    struct ExportFileItem: Identifiable {
        let id = UUID()
        let url: URL
    }

    @Environment(\.dismiss) private var dismiss
    @State private var data: UserShipmentsResponse? = nil
    @State private var loading = true
    @State private var statusFilter: ShipStatusKey = .all
    @State private var busy = false
    @State private var exportItem: ExportFileItem? = nil

    private var items: [UserShipItem] { data?.items ?? [] }
    private var filtered: [UserShipItem] {
        statusFilter == .all ? items : items.filter {
            shipStatusKeyOf(shipState: $0.shipState, trackingNo: $0.trackingNo,
                            yundaOrderId: $0.yundaOrderId, ztoOrderId: $0.ztoOrderId) == statusFilter
        }
    }
    private var statusCounts: [ShipStatusKey: Int] {
        var acc: [ShipStatusKey: Int] = [.all: 0, .pending: 0, .preorder: 0, .ordered: 0, .external: 0, .cancelled: 0]
        for a in items {
            acc[shipStatusKeyOf(shipState: a.shipState, trackingNo: a.trackingNo,
                                yundaOrderId: a.yundaOrderId, ztoOrderId: a.ztoOrderId), default: 0] += 1
            acc[.all, default: 0] += 1
        }
        return acc
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 0) {
                Button { dismiss() } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 14))
                        Text("返回快递后台")
                            .font(.system(size: 14))
                    }
                    .foregroundColor(.appMutedFg)
                }
                .buttonStyle(.plain)

                if loading {
                    VStack(spacing: 12) {
                        RoundedRectangle(cornerRadius: 5).fill(Color.appSecondary).frame(height: 64)
                        RoundedRectangle(cornerRadius: 5).fill(Color.appSecondary).frame(height: 112)
                        RoundedRectangle(cornerRadius: 5).fill(Color.appSecondary).frame(height: 112)
                    }
                    .padding(.top, 24)
                } else if data == nil || items.isEmpty {
                    VStack(spacing: 0) {
                        Image(systemName: "shippingbox")
                            .font(.system(size: 32))
                            .foregroundColor(.appMutedFg)
                        Text("该用户在你的橱窗下没有寄件记录")
                            .font(.system(size: 14))
                            .foregroundColor(.appMutedFg)
                            .padding(.top, 12)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 64)
                    .overlay(RoundedRectangle(cornerRadius: 5).stroke(Color.appBorder, style: StrokeStyle(lineWidth: 0.5, dash: [4, 3])))
                    .padding(.top, 24)
                } else {
                    claimerCard.padding(.top, 16)
                    filterRow.padding(.top, 16)
                    if filtered.isEmpty {
                        Text("该状态下暂无记录")
                            .font(.system(size: 14))
                            .foregroundColor(.appMutedFg)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 48)
                            .overlay(RoundedRectangle(cornerRadius: 5).stroke(Color.appBorder, style: StrokeStyle(lineWidth: 0.5, dash: [4, 3])))
                            .padding(.top, 16)
                    } else {
                        VStack(spacing: 12) {
                            ForEach(filtered) { a in itemCard(a) }
                        }
                        .padding(.top, 16)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 24)
            .padding(.bottom, 24)
        }
        .background(Color.appBackground)
        .navigationTitle(data?.claimer?.name ?? "TA 的寄件")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            data = try? await MashanglingAPI.shared.address.userShipments(userId: userId)
            loading = false
        }
        .sheet(item: $exportItem) { item in ShareSheet(items: [item.url]) }
    }

    // MARK: 领取人信息卡 + 导出
    private var claimerCard: some View {
        HStack(spacing: 12) {
            if let avatar = data?.claimer?.avatar, !avatar.isEmpty {
                AppImage(path: avatar)
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 44, height: 44)
                    .clipShape(Circle())
                    .overlay(Circle().stroke(Color.appBorder, lineWidth: 0.5))
            } else {
                ZStack {
                    Circle().fill(Color.appSecondary).frame(width: 44, height: 44)
                    Text((data?.claimer?.name ?? "用").prefix(1))
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.appMutedFg)
                }
            }
            VStack(alignment: .leading, spacing: 2) {
                (Text(data?.claimer?.name ?? "用户 #\(userId)")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.appForeground)
                 + Text("  ID \(userId)")
                    .font(.system(size: 12))
                    .foregroundColor(.appMutedFg))
                    .lineLimit(1)
                Text("共 \(items.count) 条寄件记录 · 只看这个人在你橱窗下的记录")
                    .font(.system(size: 12))
                    .foregroundColor(.appMutedFg)
            }
            Spacer(minLength: 0)
            Button { Task { await exportCainiao() } } label: {
                HStack(spacing: 4) {
                    Image(systemName: "arrow.down")
                        .font(.system(size: 12))
                    Text("导出\(statusFilter == .all ? "全部" : statusFilter.label)")
                        .font(.system(size: 12))
                }
                .foregroundColor(.fixEmerald700)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .overlay(Capsule().stroke(Color.fixEmerald300, lineWidth: 0.5))
            }
            .buttonStyle(.plain)
            .disabled(busy)
        }
        .padding(16)
        .background(Color.appCard)
        .overlay(RoundedRectangle(cornerRadius: 5).stroke(Color.appBorder, lineWidth: 0.5))
        .cornerRadius(5)
    }

    // MARK: 状态筛选
    private var filterRow: some View {
        FlowLayout(spacing: 6, vSpacing: 6) {
            ForEach(ShipStatusKey.allCases) { f in
                Button { statusFilter = f } label: {
                    HStack(spacing: 4) {
                        Text(f.label)
                        if (statusCounts[f] ?? 0) > 0 {
                            Text("\(statusCounts[f] ?? 0)").opacity(0.7)
                        }
                    }
                    .font(.system(size: 12, weight: statusFilter == f ? .medium : .regular))
                    .foregroundColor(statusFilter == f ? Color.appPrimaryFg : Color.appSecondaryFg)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(statusFilter == f ? Color.appPrimary : Color.appSecondary)
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: 寄件记录卡
    private func itemCard(_ a: UserShipItem) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top, spacing: 8) {
                VStack(alignment: .leading, spacing: 4) {
                    NavigationLink(destination: ShowcaseDetailView(showcaseId: a.showcaseId)) {
                        Text(a.showcaseTitle ?? "")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.appPrimary)
                            .lineLimit(1)
                    }
                    .buttonStyle(.plain)
                    Text(a.full ?? a.address ?? "")
                        .font(.system(size: 12))
                        .foregroundColor(.appForeground.opacity(0.9))
                        .lineSpacing(8)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                Button {
                    UIPasteboard.general.string = a.full ?? a.address ?? ""
                    ToastCenter.shared.success("地址已复制")
                } label: {
                    Image(systemName: "doc.on.doc")
                        .font(.system(size: 12))
                        .foregroundColor(.appMutedFg)
                        .padding(4)
                }
                .buttonStyle(.plain)
            }
            FlowLayout(spacing: 8, vSpacing: 6) {
                if a.shipState == "cancelled" {
                    shipBadgeView("已取消", bg: .appBrand100, fg: .appBrand600, ring: .appBrand200)
                }
                if a.shipState == "external" {
                    shipBadgeView("已外部寄件", bg: .fixViolet100, fg: .fixViolet700, ring: .fixViolet300)
                }
                if a.shipState == "preorder" {
                    shipBadgeView("预下单", bg: .fixSky50, fg: .fixSky700, ring: .fixSky300)
                }
                if shipStatusKeyOf(shipState: a.shipState, trackingNo: a.trackingNo,
                                   yundaOrderId: a.yundaOrderId, ztoOrderId: a.ztoOrderId) == .pending {
                    shipBadgeView("未下单", bg: .appSecondary, fg: .appMutedFg, semibold: false)
                }
                if let no = a.trackingNo, !no.isEmpty {
                    HStack(spacing: 4) {
                        Image(systemName: "box.truck")
                            .font(.system(size: 10))
                        Text("\((a.ztoOrderId?.isEmpty == false) ? "中通" : (a.cainiaoCpName?.isEmpty == false ? a.cainiaoCpName! : "韵达")) \(no)")
                            .font(.system(size: 11, design: .monospaced))
                    }
                    .foregroundColor(.appForeground)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Color.appSecondary)
                    .clipShape(Capsule())
                }
                if let st = a.shipStatus, !st.isEmpty {
                    shipStatusBadge(st)
                }
                if (a.trackingNo?.isEmpty ?? true) && ((a.yundaOrderId?.isEmpty == false) || (a.ztoOrderId?.isEmpty == false)) && a.shipState == "ordered" {
                    shipBadgeView("已下单·待揽收", bg: .fixSky50, fg: .fixSky700, mono: true, semibold: false)
                }
                if let code = a.pickupCode, !code.isEmpty {
                    Text("取货码 \(code)")
                        .font(.system(size: 11, weight: .semibold, design: .monospaced))
                        .foregroundColor(.fixViolet700)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(Color.fixViolet100)
                        .overlay(Capsule().stroke(Color.fixViolet300, lineWidth: 0.5))
                        .clipShape(Capsule())
                }
                if a.shippingPaid == true {
                    shipBadgeView("已付款", bg: .fixEmerald100, fg: .fixEmerald700)
                } else if let fee = a.fee {
                    Text("预估邮费 ¥\(fee)")
                        .font(.system(size: 11))
                        .foregroundColor(.appMutedFg)
                }
                Spacer(minLength: 0)
                Text(DateFmt.zhDate(a.createdAt))
                    .font(.system(size: 11))
                    .foregroundColor(.appMutedFg)
            }
            .padding(.top, 8)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color.appCard)
        .overlay(RoundedRectangle(cornerRadius: 5).stroke(Color.appBorder, lineWidth: 0.5))
        .cornerRadius(5)
    }

    // MARK: 导出菜鸟模板
    private func exportCainiao() async {
        busy = true
        defer { busy = false }
        do {
            let r = try await MashanglingAPI.shared.address.exportCainiao(
                showcaseId: 0, userId: userId,
                status: statusFilter == .all ? "all" : statusFilter.rawValue)
            guard let data = Data(base64Encoded: r.base64) else {
                ToastCenter.shared.error("表格数据解析失败"); return
            }
            let url = FileManager.default.temporaryDirectory.appendingPathComponent(r.filename)
            try data.write(to: url)
            exportItem = ExportFileItem(url: url)
            ToastCenter.shared.success("已导出 \(r.count ?? 0) 条记录（菜鸟批量寄件模板格式）")
        } catch { ToastCenter.shared.error(error.localizedDescription) }
    }
}
