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
            // 跳转目标：theme→卡片工作室，hen→农场，egg→我的主页（对应网页 editPath / /u/:id）
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
        case "hen":   FarmView(userId: authManager.currentUser?.id ?? 0)
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
