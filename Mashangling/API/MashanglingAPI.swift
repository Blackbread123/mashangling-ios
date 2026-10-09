import Foundation

// MARK: - 码上领 API 服务（按 tRPC 路由分组，与网页版共用同一后端与数据库）
actor MashanglingAPI {

    static let shared = MashanglingAPI()
    private let client = APIClient.shared

    // MARK: - 认证（auth.*）
    struct AuthService {
        let client: APIClient

        func me() async throws -> User {
            try await client.get("auth.me")
        }

        func logout() async throws -> Bool {
            let _: SuccessResponse = try await client.post("auth.logout")
            await APIClient.shared.setToken(nil)
            return true
        }

        /// 注销账号（App Store 上架要求；需后端提供 user.deleteAccount，参数为登录密码）
        func deleteAccount(password: String) async throws -> Bool {
            let r: OkResponse = try await client.post("user.deleteAccount", input: ["password": password])
            return r.ok ?? false
        }

        /// 封禁状态（2026-10-08）：封禁中返回 BanInfo，正常返回 nil
        func banInfo() async throws -> BanInfo? {
            try await client.getOptional("auth.banInfo")
        }
    }

    // MARK: - 邮箱认证（emailAuth.*）
    struct EmailAuthService {
        let client: APIClient

        /// 邮箱+密码登录（成功后服务端 Set-Cookie 下发 kimi_sid，URLSession 自动存储）
        func login(email: String, password: String) async throws -> Bool {
            let r: OkResponse = try await client.post("emailAuth.login", input: [
                "email": email, "password": password,
            ])
            return r.ok ?? false
        }

        /// 邮箱注册
        func register(email: String, password: String, name: String) async throws -> Bool {
            let r: OkResponse = try await client.post("emailAuth.register", input: [
                "email": email, "password": password, "name": name,
            ])
            return r.ok ?? false
        }
    }

    // MARK: - 橱窗（showcase.*）
    struct ShowcaseService {
        let client: APIClient

        /// 橱窗 feed 流
        func feed(sort: String = "hot", window: String = "week", tagId: Int? = nil,
                  includeTagIds: [Int]? = nil, excludeTagIds: [Int]? = nil, q: String? = nil,
                  platform: String? = nil, shuffle: Int? = nil,
                  cursor: Int = 0, limit: Int = 24) async throws -> FeedResponse {
            var input: [String: Any] = [
                "sort": sort, "window": window, "cursor": cursor, "limit": limit,
            ]
            if let tagId = tagId { input["tagId"] = tagId }
            if let includeTagIds = includeTagIds, !includeTagIds.isEmpty { input["includeTagIds"] = includeTagIds }
            if let excludeTagIds = excludeTagIds, !excludeTagIds.isEmpty { input["excludeTagIds"] = excludeTagIds }
            if let q = q, !q.isEmpty { input["q"] = q }
            if let platform = platform { input["platform"] = platform }
            if let shuffle = shuffle { input["shuffle"] = shuffle }
            return try await client.get("showcase.feed", input: input)
        }

        /// 橱窗详情（自动浏览量+1）
        func byId(id: Int) async throws -> ShowcaseDetailData {
            try await client.get("showcase.byId", input: ["id": id])
        }

        /// 某用户的橱窗列表（个人主页）
        func byUser(userId: Int) async throws -> ProfileData {
            try await client.get("showcase.byUser", input: ["userId": userId])
        }

        /// 发布橱窗（coverImage 为压缩后的 dataURL）
        func create(title: String, platform: String, rouzaoCode: String, codeVisibility: String,
                    description: String, coverImage: String, tagIds: [Int], stockStatus: String,
                    quantity: Int?, claimMode: String, pointCost: Int?,
                    addressDeadline: String?, expiresAt: String?, shippingFree: Bool) async throws -> Int {
            var input: [String: Any] = [
                "title": title, "platform": platform, "rouzaoCode": rouzaoCode,
                "codeVisibility": codeVisibility, "description": description,
                "coverImage": coverImage, "tagIds": tagIds, "stockStatus": stockStatus,
                "claimMode": claimMode, "shippingFree": shippingFree,
            ]
            input["quantity"] = quantity as Any? ?? NSNull()
            input["pointCost"] = pointCost as Any? ?? NSNull()
            input["addressDeadline"] = addressDeadline as Any? ?? NSNull()
            input["expiresAt"] = expiresAt as Any? ?? NSNull()
            struct Created: Codable { let id: Int }
            let r: Created = try await client.post("showcase.create", input: input)
            return r.id
        }

        /// 编辑橱窗
        func update(id: Int, title: String, platform: String, rouzaoCode: String, codeVisibility: String,
                    description: String, coverImage: String, tagIds: [Int], stockStatus: String,
                    quantity: Int?, claimMode: String, pointCost: Int?,
                    addressDeadline: String?, expiresAt: String?, shippingFree: Bool,
                    pinned: Bool = false) async throws -> Bool {
            var input: [String: Any] = [
                "id": id, "title": title, "platform": platform, "rouzaoCode": rouzaoCode,
                "codeVisibility": codeVisibility, "description": description,
                "coverImage": coverImage, "tagIds": tagIds, "stockStatus": stockStatus,
                "claimMode": claimMode, "shippingFree": shippingFree, "pinned": pinned,
            ]
            input["quantity"] = quantity as Any? ?? NSNull()
            input["pointCost"] = pointCost as Any? ?? NSNull()
            input["addressDeadline"] = addressDeadline as Any? ?? NSNull()
            input["expiresAt"] = expiresAt as Any? ?? NSNull()
            let r: OkResponse = try await client.post("showcase.update", input: input)
            return r.ok ?? false
        }

        /// 删除橱窗
        func remove(id: Int) async throws -> Bool {
            let r: OkResponse = try await client.post("showcase.remove", input: ["id": id])
            return r.ok ?? false
        }

        /// 我的浏览历史（feed item 列表，最近 50 个去重）
        func browseHistory() async throws -> [Showcase] {
            try await client.get("showcase.browseHistory")
        }
    }

    // MARK: - 标签（tag.*）
    struct TagService {
        let client: APIClient

        func search(q: String = "", limit: Int = 50) async throws -> [Tag] {
            try await client.get("tag.search", input: ["q": q, "limit": limit])
        }

        func create(name: String, category: String) async throws -> Tag {
            try await client.post("tag.create", input: ["name": name, "category": category])
        }

        func byId(id: Int) async throws -> TagDetail {
            try await client.get("tag.byId", input: ["id": id])
        }

        /// 今日趋势标签（前 5）
        func trendingToday() async throws -> [Tag] {
            try await client.get("tag.trendingToday")
        }
    }

    // MARK: - 标签管理（tagAdmin.*，管理员）
    struct TagAdminService {
        let client: APIClient

        func list() async throws -> [AdminTagRow] {
            try await client.get("tagAdmin.adminList")
        }

        func update(id: Int, name: String, category: String) async throws -> Bool {
            let r: OkResponse = try await client.post("tagAdmin.adminUpdate", input: [
                "id": id, "name": name, "category": category,
            ])
            return r.ok ?? false
        }

        func setStatus(id: Int, status: String) async throws -> Bool {
            let r: OkResponse = try await client.post("tagAdmin.adminSetStatus", input: [
                "id": id, "status": status,
            ])
            return r.ok ?? false
        }
    }

    // MARK: - 举报（report.*）
    struct ReportService {
        let client: APIClient

        func create(targetType: String, targetId: Int, reason: String) async throws -> Bool {
            let r: OkResponse = try await client.post("report.create", input: [
                "targetType": targetType, "targetId": targetId, "reason": reason,
            ])
            return r.ok ?? false
        }

        func list() async throws -> [ReportRow] {
            try await client.get("report.list")
        }

        /// 提交处理意见并上报主管理员
        func escalate(id: Int, opinion: String) async throws -> Bool {
            let r: OkResponse = try await client.post("report.escalate", input: [
                "id": id, "opinion": opinion,
            ])
            return r.ok ?? false
        }

        /// 主管理员终审：removeTarget 下架目标 / dismiss 驳回举报
        func decide(id: Int, action: String) async throws -> DecideResult {
            try await client.post("report.decide", input: [
                "id": id, "action": action,
            ])
        }

        /// BAN 类举报终审：删除内容并封禁作者；banDays=nil 表示永久封禁（显式传 null）
        func decideWithBan(id: Int, banDays: Int?) async throws -> DecideResult {
            try await client.post("report.decide", input: [
                "id": id, "action": "removeTarget",
                "banDays": banDays.map { $0 as Any } ?? NSNull(),
            ])
        }
    }

    // MARK: - 互动（interaction.*）
    struct InteractionService {
        let client: APIClient

        /// 点赞/取消点赞 → 返回最新状态
        func toggleLike(showcaseId: Int) async throws -> Bool {
            let r: LikeResult = try await client.post("interaction.toggleLike", input: ["showcaseId": showcaseId])
            return r.liked ?? false
        }

        /// 「我领到了」/取消
        func toggleClaim(showcaseId: Int) async throws -> Bool {
            let r: ClaimResult = try await client.post("interaction.toggleClaim", input: ["showcaseId": showcaseId])
            return r.claimed ?? false
        }

        struct LikeResult: Codable { let liked: Bool? }
        struct ClaimResult: Codable { let claimed: Bool? }
    }

    // MARK: - 清单/收藏（bookmark.*）
    struct BookmarkService {
        let client: APIClient

        func toggle(showcaseId: Int) async throws -> Bool {
            let r: ToggleResult = try await client.post("bookmark.toggle", input: ["showcaseId": showcaseId])
            return r.bookmarked ?? false
        }

        func mineFor(showcaseIds: [Int]) async throws -> [Int] {
            let r: BookmarkIds = try await client.get("bookmark.mineFor", input: ["showcaseIds": showcaseIds])
            return r.ids
        }

        func list() async throws -> BookmarkListResponse {
            try await client.get("bookmark.list")
        }

        struct ToggleResult: Codable { let bookmarked: Bool? }
    }

    // MARK: - 「我想要」（request.*）
    struct RequestService {
        let client: APIClient

        func create(showcaseId: Int) async throws -> Bool {
            let r: OkResponse = try await client.post("request.create", input: ["showcaseId": showcaseId])
            return r.ok ?? false
        }

        /// 我是否已对该橱窗点过「我想要」
        func mineFor(showcaseId: Int) async throws -> Bool {
            let r: RequestedFlag = try await client.get("request.mineFor", input: ["showcaseId": showcaseId])
            return r.requested
        }

        /// 我收到的「我想要」（仅发布者本人）
        func received() async throws -> [RequestReceivedRow] {
            try await client.get("request.received")
        }
    }

    // MARK: - 「没有了」反馈（soldout.*）
    struct SoldoutService {
        let client: APIClient

        struct MarkResult: Codable { let ok: Bool?; let mailed: Bool? }

        /// 标记「没有了」→ 返回是否给发布人发了邮件（对应网页 toast 两种文案）
        func mark(showcaseId: Int) async throws -> MarkResult {
            try await client.post("soldout.mark", input: ["showcaseId": showcaseId])
        }

        func mineFor(showcaseId: Int) async throws -> Bool {
            let r: MarkedFlag = try await client.get("soldout.mineFor", input: ["showcaseId": showcaseId])
            return r.marked
        }

        /// 我收到的「没有了」补货提醒（仅本人）
        func received() async throws -> [SoldoutReceivedRow] {
            try await client.get("soldout.received")
        }
    }

    // MARK: - 返图（repost.*）
    struct RepostService {
        let client: APIClient

        func list(showcaseId: Int) async throws -> [RepostRow] {
            try await client.get("repost.list", input: ["showcaseId": showcaseId])
        }

        func mine() async throws -> MyRepostsResponse {
            try await client.get("repost.mine")
        }

        func create(showcaseId: Int, image: String, comment: String) async throws -> Bool {
            let r: OkResponse = try await client.post("repost.create", input: [
                "showcaseId": showcaseId, "image": image, "comment": comment,
            ])
            return r.ok ?? false
        }

        func remove(id: Int) async throws -> Bool {
            let r: OkResponse = try await client.post("repost.remove", input: ["id": id])
            return r.ok ?? false
        }
    }

    // MARK: - 领取申请（claim.*）
    struct ClaimService {
        let client: APIClient

        /// 申请领取 / 凭证解锁 / 积分解锁 / 限量即领（统一入口）
        func create(showcaseId: Int, note: String = "", credentialImage: String? = nil) async throws -> Bool {
            var input: [String: Any] = ["showcaseId": showcaseId, "note": note]
            if let credentialImage = credentialImage { input["credentialImage"] = credentialImage }
            let r: OkResponse = try await client.post("claim.create", input: input)
            return r.ok ?? false
        }

        /// 我收到的领取申请（发布者）
        func received() async throws -> [ClaimRow] {
            try await client.get("claim.received")
        }

        /// 审批
        func resolve(id: Int, action: String) async throws -> Bool {
            let r: OkResponse = try await client.post("claim.resolve", input: [
                "id": id, "action": action,
            ])
            return r.ok ?? false
        }
    }

    // MARK: - 补码（code.*）
    struct CodeService {
        let client: APIClient

        struct CodeList: Codable {
            let locked: Bool
            let count: Int
            let items: [CodeRow]
        }

        func list(showcaseId: Int) async throws -> CodeList {
            try await client.get("code.list", input: ["showcaseId": showcaseId])
        }

        /// 补码 → 返回通知到的人数
        func add(showcaseId: Int, code: String) async throws -> Int {
            struct R: Codable { let ok: Bool?; let notified: Int? }
            let r: R = try await client.post("code.add", input: [
                "showcaseId": showcaseId, "code": code,
            ])
            return r.notified ?? 0
        }

        func remove(id: Int) async throws -> Bool {
            let r: OkResponse = try await client.post("code.remove", input: ["id": id])
            return r.ok ?? false
        }
    }

    // MARK: - 分享打点（share.*）
    struct ShareService {
        let client: APIClient

        func mark(showcaseId: Int, channel: String) async throws {
            let _: OkResponse = try await client.post("share.mark", input: [
                "showcaseId": showcaseId, "channel": channel,
            ])
        }
    }

    // MARK: - 设置（settings.*）
    struct SettingsService {
        let client: APIClient

        func get() async throws -> SettingsData {
            try await client.get("settings.get")
        }

        func updateName(_ name: String) async throws -> Bool {
            let r: OkResponse = try await client.post("settings.updateName", input: ["name": name])
            return r.ok ?? false
        }

        func updateAvatar(_ avatarDataURL: String) async throws -> Bool {
            let r: OkResponse = try await client.post("settings.updateAvatar", input: ["avatar": avatarDataURL])
            return r.ok ?? false
        }

        func updateBio(_ bio: String) async throws -> Bool {
            let r: OkResponse = try await client.post("settings.updateBio", input: ["bio": bio])
            return r.ok ?? false
        }

        func updateNotifyEmail(_ email: String) async throws -> Bool {
            let r: OkResponse = try await client.post("settings.updateNotifyEmail", input: ["notifyEmail": email])
            return r.ok ?? false
        }

        func updateDmBlocked(_ blocked: Bool) async throws -> Bool {
            let r: OkResponse = try await client.post("settings.updateDmBlocked", input: ["blocked": blocked])
            return r.ok ?? false
        }

        func getHomeModules() async throws -> HomeModulesData {
            try await client.get("settings.getHomeModules")
        }

        func updateHomeModules(_ json: String) async throws -> Bool {
            let r: OkResponse = try await client.post("settings.updateHomeModules", input: ["homeModules": json])
            return r.ok ?? false
        }

        /// 绑定/换绑邮箱（需当前密码）
        func bindEmail(email: String, password: String) async throws -> Bool {
            let r: OkResponse = try await client.post("settings.bindEmail", input: [
                "email": email, "password": password,
            ])
            return r.ok ?? false
        }

        func getSiteTheme() async throws -> SiteThemeData {
            try await client.get("settings.getSiteTheme")
        }

        func updateSiteTheme(_ theme: String) async throws -> Bool {
            let r: OkResponse = try await client.post("settings.updateSiteTheme", input: ["siteTheme": theme])
            return r.ok ?? false
        }
    }

    // MARK: - 关注（follow.*）
    struct FollowService {
        let client: APIClient

        func toggle(userId: Int) async throws -> FollowToggleResult {
            try await client.post("follow.toggle", input: ["userId": userId])
        }

        func setSpecial(userId: Int, special: Bool) async throws -> Bool {
            let r: OkResponse = try await client.post("follow.setSpecial", input: [
                "userId": userId, "special": special,
            ])
            return r.ok ?? false
        }

        func status(userId: Int) async throws -> FollowStatus {
            try await client.get("follow.status", input: ["userId": userId])
        }

        /// 我关注的人
        func list() async throws -> [FollowUser] {
            struct R: Codable { let items: [FollowUser]? }
            let r: R = try await client.get("follow.list")
            return r.items ?? []
        }

        /// 某用户关注的人（带总数）
        func followingOf(userId: Int) async throws -> FollowListResponse {
            try await client.get("follow.followingOf", input: ["userId": userId])
        }

        /// 某用户的粉丝（带总数）
        func followers(userId: Int) async throws -> FollowListResponse {
            try await client.get("follow.followers", input: ["userId": userId])
        }

        /// 我的互关好友（无参数，当前登录用户）
        func mutuals() async throws -> [FollowUser] {
            let r: MutualsResponse = try await client.get("follow.mutuals")
            return r.items ?? []
        }

        /// 某用户的好友（互关）
        func friends(userId: Int) async throws -> [FollowUser] {
            let r: FriendsResponse = try await client.get("follow.friends", input: ["userId": userId])
            return r.items ?? []
        }

        /// 与某用户的共同好友
        func mutualWith(userId: Int) async throws -> MutualWithResponse {
            try await client.get("follow.mutualWith", input: ["userId": userId])
        }

        /// 搜索用户（发起私信用）
        func searchUsers(q: String, limit: Int = 8) async throws -> [FollowUser] {
            let r: SearchUsersResponse = try await client.get("follow.searchUsers", input: ["q": q, "limit": limit])
            return r.items ?? []
        }
    }

    // MARK: - 站内信（message.*）
    struct MessageService {
        let client: APIClient

        /// 通知列表（type: all/like/want/claimed/restock/repost/soldout/claim_approved/claim_rejected/claim_received/dm/follow/address/gift/heart）
        func list(type: String = "all") async throws -> [MessageRow] {
            try await client.get("message.list", input: ["type": type])
        }

        func unreadCount() async throws -> Int {
            let r: UnreadCount = try await client.get("message.unreadCount", cacheable: false)
            return r.count
        }

        func markRead(id: Int) async throws {
            let _: OkResponse = try await client.post("message.markRead", input: ["id": id])
        }

        func markAllRead() async throws {
            let _: OkResponse = try await client.post("message.markAllRead")
        }
    }

    // MARK: - 私信（dm.*）
    struct DMService {
        let client: APIClient

        /// 会话列表
        func conversations() async throws -> [Conversation] {
            struct R: Codable { let items: [Conversation]? }
            let r: R = try await client.get("dm.conversations")
            return r.items ?? []
        }

        /// 与某人的私信记录
        func thread(peerId: Int) async throws -> DMThreadResponse {
            try await client.get("dm.thread", input: ["peerId": peerId])
        }

        /// 发送私信（requireMutual=仅互关好友场景）
        func send(toUserId: Int, content: String, requireMutual: Bool = false, replyToId: Int? = nil) async throws -> Bool {
            var input: [String: Any] = [
                "toUserId": toUserId, "content": content, "requireMutual": requireMutual,
            ]
            if let replyToId = replyToId { input["replyToId"] = replyToId }
            let r: OkResponse = try await client.post("dm.send", input: input)
            return r.ok ?? false
        }

        /// 分享橱窗给好友
        func shareShowcase(toUserId: Int, showcaseId: Int) async throws -> Bool {
            let r: OkResponse = try await client.post("dm.shareShowcase", input: [
                "toUserId": toUserId, "showcaseId": showcaseId,
            ])
            return r.ok ?? false
        }

        /// 分享名片给好友
        func shareProfile(toUserId: Int, profileUserId: Int) async throws -> Bool {
            let r: OkResponse = try await client.post("dm.shareProfile", input: [
                "toUserId": toUserId, "profileUserId": profileUserId,
            ])
            return r.ok ?? false
        }

        /// 标记某会话已读
        func markDmRead(peerId: Int) async throws {
            let _: OkResponse = try await client.post("message.markDmRead", input: ["peerId": peerId])
        }
    }

    // MARK: - 积分（points.*）
    struct PointsService {
        let client: APIClient

        /// 全站积分播报（最近 5 分钟）
        func ticker() async throws -> [PointsTickerRow] {
            try await client.get("points.ticker")
        }

        /// 我的积分总览
        func my() async throws -> PointsMy {
            try await client.get("points.my")
        }

        /// 积分流水（最近 200 条）
        func records() async throws -> [PointLogRow] {
            try await client.get("points.records")
        }

        /// 达人榜（week / month）
        func leaderboard(period: String = "week", limit: Int = 10) async throws -> [PointsLeaderboardUser] {
            let r: PointsLeaderboard = try await client.get("points.leaderboard", input: [
                "period": period, "limit": limit,
            ])
            return r.items ?? []
        }

        /// 上升最快（周环比）
        func rising(limit: Int = 5) async throws -> [PointsLeaderboardUser] {
            let r: PointsLeaderboard = try await client.get("points.rising", input: ["limit": limit])
            return r.items ?? []
        }

        /// 鸡场信息
        func farm(userId: Int) async throws -> PointsFarm {
            try await client.get("points.farm", input: ["userId": userId])
        }

        /// 买鸡蛋
        func buyEgg() async throws -> (eggCount: Int, spent: Int) {
            struct R: Codable { let eggCount: Int; let spent: Int }
            let r: R = try await client.post("points.buyEgg")
            return (r.eggCount, r.spent)
        }

        /// 佩戴/卸下头衔（nil=卸下）
        func equipTitle(_ titleKey: String?) async throws -> Bool {
            let r: OkResponse = try await client.post("points.equipTitle", input: [
                "titleKey": titleKey as Any? ?? NSNull(),
            ])
            return r.ok ?? false
        }

        /// 农场对外展示开关
        func toggleFarm() async throws -> Bool {
            struct R: Codable { let farmPublic: Bool }
            let r: R = try await client.post("points.toggleFarm")
            return r.farmPublic
        }
    }

    // MARK: - 任务（task.*）
    struct TaskService {
        let client: APIClient

        func mine() async throws -> TaskProgress {
            try await client.get("task.mine")
        }

        func claim(taskKey: String) async throws -> TaskClaimResult {
            try await client.post("task.claim", input: ["taskKey": taskKey])
        }

        func checkinStatus() async throws -> CheckinStatus {
            try await client.get("task.checkinStatus")
        }

        func checkin() async throws -> CheckinResult {
            try await client.post("task.checkin")
        }
    }

    // MARK: - 商店（shop.*）
    struct ShopService {
        let client: APIClient

        func overview() async throws -> ShopOverview {
            try await client.get("shop.overview")
        }

        /// 给互关好友买好感（1000 积分 = 1 点好感）→ 返回 (amount, cost)
        func buyGoodwill(friendId: Int, amount: Int) async throws -> (amount: Int, cost: Int) {
            struct R: Codable { let ok: Bool?; let cost: Int; let amount: Int }
            let r: R = try await client.post("shop.buyGoodwill", input: [
                "friendId": friendId, "amount": amount,
            ])
            return (r.amount, r.cost)
        }
    }

    // MARK: - 心选橱窗（heart.*）
    struct HeartService {
        let client: APIClient

        /// 搜索（橱窗名/发布人模糊，或 M 编码精确）
        func search(q: String) async throws -> [HeartSearchResult] {
            try await client.get("heart.search", input: ["q": q])
        }

        /// 排名趋势（近 7 天）
        func trend(showcaseId: Int) async throws -> HeartTrend {
            try await client.get("heart.trend", input: ["showcaseId": showcaseId])
        }

        /// 模拟大盘 K 线
        func market(showcaseId: Int) async throws -> MarketResponse {
            try await client.get("heart.market", input: ["showcaseId": showcaseId])
        }

        /// 支持/买空（9:00-22:00）
        func support(showcaseId: Int, amount: Int, direction: String) async throws -> Bool {
            let r: OkResponse = try await client.post("heart.support", input: [
                "showcaseId": showcaseId, "amount": amount, "direction": direction,
            ])
            return r.ok ?? false
        }

        /// 我支持的橱窗
        func mine() async throws -> [HeartSupportRow] {
            try await client.get("heart.mine")
        }

        /// 近期上升橱窗（前 3）
        func rising() async throws -> [HeartRising] {
            try await client.get("heart.rising")
        }

        /// 买股王周榜（前 5）
        func weeklyTop() async throws -> [HeartWeeklyTopUser] {
            try await client.get("heart.weeklyTop")
        }

        /// 当日奖池（仅管理员）
        func poolAdmin() async throws -> HeartPoolAdmin {
            try await client.get("heart.poolAdmin")
        }

        /// 最近 3 条支持横幅
        func recentSupports() async throws -> [HeartRecentSupport] {
            try await client.get("heart.recentSupports")
        }

        /// 支持时段信息
        func info() async throws -> HeartInfo {
            try await client.get("heart.info")
        }
    }

    // MARK: - 农场（farm.*）
    struct FarmService {
        let client: APIClient

        func overview(userId: Int) async throws -> FarmOverview {
            try await client.get("farm.overview", input: ["userId": userId])
        }

        func myRate() async throws -> FarmRate {
            try await client.get("farm.myRate")
        }

        /// 购买/领取果树 → 返回 (name, cost)（用于提示）
        func buyTree(treeIdx: Int) async throws -> (name: String, cost: Int) {
            struct R: Codable { let treeIdx: Int; let name: String; let cost: Int }
            let r: R = try await client.post("farm.buyTree", input: ["treeIdx": treeIdx])
            return (r.name, r.cost)
        }

        /// 利息结算历史（最近 12 周）
        func history() async throws -> [FarmInterestRow] {
            try await client.get("farm.history")
        }
    }

    // MARK: - 礼物 / 好友好感（gift.*）
    struct GiftService {
        let client: APIClient

        /// 以礼物分享给互关好友 → 返回好感等级
        func share(showcaseId: Int, toUserId: Int) async throws -> Int {
            struct R: Codable { let ok: Bool?; let goodwill: Int?; let level: Int? }
            let r: R = try await client.post("gift.share", input: [
                "showcaseId": showcaseId, "toUserId": toUserId,
            ])
            return r.level ?? 0
        }

        /// 领取礼物
        func claim(giftId: Int) async throws -> Bool {
            let r: OkResponse = try await client.post("gift.claim", input: ["giftId": giftId])
            return r.ok ?? false
        }

        /// 与某好友的好感信息
        func friendshipInfo(peerId: Int) async throws -> FriendshipInfo {
            try await client.get("gift.friendshipInfo", input: ["peerId": peerId])
        }

        /// 某用户主页展示的好友徽章
        func publicBadges(userId: Int) async throws -> [PublicBadge] {
            try await client.get("gift.publicBadges", input: ["userId": userId])
        }

        func updateBadge(badgeId: Int, image: String) async throws -> Bool {
            let r: OkResponse = try await client.post("gift.updateBadge", input: [
                "badgeId": badgeId, "image": image,
            ])
            return r.ok ?? false
        }

        func setBadgePublic(badgeId: Int, isPublic: Bool) async throws -> Bool {
            let r: OkResponse = try await client.post("gift.setBadgePublic", input: [
                "badgeId": badgeId, "isPublic": isPublic,
            ])
            return r.ok ?? false
        }

        /// 上传好友徽章（PNG dataURL）→ 返回消耗的好感
        func uploadBadge(peerId: Int, image: String) async throws -> Int {
            struct R: Codable { let ok: Bool?; let cost: Int }
            let r: R = try await client.post("gift.uploadBadge", input: [
                "peerId": peerId, "image": image,
            ])
            return r.cost
        }

        /// 礼物记录（送出/收到）
        func records() async throws -> GiftRecords {
            try await client.get("gift.records")
        }
    }

    // MARK: - 统计看板（stats.*）
    struct StatsService {
        let client: APIClient

        func pageView() async {
            let _: OkResponse? = try? await client.post("stats.pageView")
        }

        func dashboard() async throws -> StatsDashboardData {
            try await client.get("stats.dashboard")
        }

        /// trend(period: week/month/year)
        func trend(period: String) async throws -> StatsTrend {
            try await client.get("stats.trend", input: ["period": period])
        }
    }

    // MARK: - 卡片主题（card.*）
    struct CardService {
        let client: APIClient

        func mine() async throws -> CardMineResponse {
            try await client.get("card.mine")
        }

        /// 返回 (id, code, cost)
        func create(name: String, config: CardConfig) async throws -> (id: Int, code: String, cost: Int) {
            struct R: Codable { let id: Int; let code: String?; let cost: Int? }
            let r: R = try await client.post("card.create", input: [
                "name": name, "config": config.toDict(),
            ])
            return (r.id, r.code ?? "", r.cost ?? 0)
        }

        func update(id: Int, name: String, config: CardConfig) async throws -> Bool {
            let r: OkResponse = try await client.post("card.update", input: [
                "id": id, "name": name, "config": config.toDict(),
            ])
            return r.ok ?? false
        }

        func remove(id: Int) async throws -> Bool {
            let r: OkResponse = try await client.post("card.remove", input: ["id": id])
            return r.ok ?? false
        }

        func setDefault(themeId: Int?) async throws -> Bool {
            let r: OkResponse = try await client.post("card.setDefault", input: [
                "themeId": themeId as Any? ?? NSNull(),
            ])
            return r.ok ?? false
        }

        /// 通过卡片码导入，返回 (name, cost)
        func importByCode(code: String) async throws -> (name: String, cost: Int) {
            struct R: Codable { let name: String?; let cost: Int? }
            let r: R = try await client.post("card.importByCode", input: ["code": code])
            return (r.name ?? "", r.cost ?? 0)
        }

        /// 预览卡片码对应的主题
        func previewByCode(code: String) async throws -> CardPreviewResponse {
            try await client.get("card.previewByCode", input: ["code": code])
        }

        /// 某用户在广场的在架卡片（个人主页展示）
        func forUser(userId: Int) async throws -> UserCardsResponse {
            try await client.get("card.forUser", input: ["userId": userId])
        }

        /// 某用户的默认分享卡片主题
        func themeOf(userId: Int) async throws -> CardThemeOfResponse {
            try await client.get("card.themeOf", input: ["userId": userId])
        }

        /// 切换卡片对外展示
        func togglePublic() async throws -> Bool {
            struct R: Codable { let cardsPublic: Bool }
            let r: R = try await client.post("card.togglePublic")
            return r.cardsPublic
        }

        /// 我的自定义母鸡
        func hens() async throws -> CardHensResponse {
            try await client.get("card.hens")
        }

        /// 上传母鸡，返回消耗积分
        func uploadHen(image: String) async throws -> Int {
            struct R: Codable { let spent: Int? }
            let r: R = try await client.post("card.uploadHen", input: ["image": image])
            return r.spent ?? 0
        }

        func updateHen(id: Int, image: String) async throws -> Bool {
            let r: OkResponse = try await client.post("card.updateHen", input: ["id": id, "image": image])
            return r.ok ?? false
        }

        func removeHen(id: Int) async throws -> Bool {
            let r: OkResponse = try await client.post("card.removeHen", input: ["id": id])
            return r.ok ?? false
        }
    }

    // MARK: - 卡片广场（cardPlaza.*）
    struct CardPlazaService {
        let client: APIClient

        func feed(sort: String = "hot", window: String = "week",
                  includeTagIds: [Int]? = nil, excludeTagIds: [Int]? = nil,
                  shuffle: Int? = nil, cursor: Int = 0, limit: Int = 24) async throws -> CardFeedResponse {
            var input: [String: Any] = [
                "sort": sort, "window": window, "cursor": cursor, "limit": limit,
            ]
            if let includeTagIds = includeTagIds, !includeTagIds.isEmpty { input["includeTagIds"] = includeTagIds }
            if let excludeTagIds = excludeTagIds, !excludeTagIds.isEmpty { input["excludeTagIds"] = excludeTagIds }
            if let shuffle = shuffle { input["shuffle"] = shuffle }
            return try await client.get("cardPlaza.feed", input: input)
        }

        /// 发布我的卡片到广场
        func publish(themeId: Int, title: String, tagIds: [Int]) async throws -> Int {
            struct R: Codable { let id: Int }
            let r: R = try await client.post("cardPlaza.publish", input: [
                "themeId": themeId, "title": title, "tagIds": tagIds,
            ])
            return r.id
        }

        func remove(postId: Int) async throws -> Bool {
            let r: OkResponse = try await client.post("cardPlaza.remove", input: ["postId": postId])
            return r.ok ?? false
        }

        func toggleLike(postId: Int) async throws -> Bool {
            struct R: Codable { let liked: Bool? }
            let r: R = try await client.post("cardPlaza.toggleLike", input: ["postId": postId])
            return r.liked ?? false
        }

        /// 返回 already：是否之前已标记过
        func want(postId: Int) async throws -> Bool {
            struct R: Codable { let already: Bool? }
            let r: R = try await client.post("cardPlaza.want", input: ["postId": postId])
            return r.already ?? false
        }

        func toggleFavorite(postId: Int) async throws -> Bool {
            struct R: Codable { let favorited: Bool? }
            let r: R = try await client.post("cardPlaza.toggleFavorite", input: ["postId": postId])
            return r.favorited ?? false
        }

        func comment(postId: Int, content: String) async throws -> Bool {
            let r: OkResponse = try await client.post("cardPlaza.comment", input: [
                "postId": postId, "content": content,
            ])
            return r.ok ?? false
        }

        func deleteComment(commentId: Int) async throws -> Bool {
            let r: OkResponse = try await client.post("cardPlaza.deleteComment", input: ["commentId": commentId])
            return r.ok ?? false
        }

        func byId(id: Int) async throws -> CardPostItem {
            try await client.get("cardPlaza.byId", input: ["id": id])
        }

        func comments(postId: Int) async throws -> [CardCommentRow] {
            try await client.get("cardPlaza.comments", input: ["postId": postId])
        }

        /// 转发给互关好友（私信）
        func shareToFriend(postId: Int, toUserId: Int) async throws -> Bool {
            let r: OkResponse = try await client.post("cardPlaza.shareToFriend", input: [
                "postId": postId, "toUserId": toUserId,
            ])
            return r.ok ?? false
        }

        func search(q: String, limit: Int = 12) async throws -> CardSearchResponse {
            try await client.get("cardPlaza.search", input: ["q": q, "limit": limit])
        }

        /// 我的卡片浏览历史
        func browseHistory() async throws -> [CardBrowseHistoryItem] {
            struct R: Codable { let items: [CardBrowseHistoryItem]? }
            let r: R = try await client.get("cardPlaza.browseHistory")
            return r.items ?? []
        }

        /// 我的评论
        func myComments() async throws -> MyCommentsResponse {
            try await client.get("cardPlaza.myComments")
        }

        /// 卡片作者热度榜（week/month/all）
        func leaderboard(window: String = "week") async throws -> CardLeaderboardResponse {
            try await client.get("cardPlaza.leaderboard", input: ["window": window])
        }
    }

    // MARK: - 地址与快递（address.*）
    struct AddressService {
        let client: APIClient

        /// 我的地址（多地址 + 寄件地址 + 支付宝 + 快递绑定信息）
        func get() async throws -> AddressData {
            try await client.get("address.get")
        }

        /// 保存收货地址（最多 4 个）+ 可选寄件地址
        func save(entries: [AddressData.AddressEntry], senderAddress: String? = nil) async throws -> Bool {
            var input: [String: Any] = [
                "entries": entries.map { ["nickname": $0.nickname, "address": $0.address, "phone": $0.phone] },
            ]
            if let senderAddress = senderAddress { input["senderAddress"] = senderAddress }
            let r: OkResponse = try await client.post("address.save", input: input)
            return r.ok ?? false
        }

        func saveAlipay(_ alipayAccount: String) async throws -> Bool {
            let r: OkResponse = try await client.post("address.saveAlipay", input: ["alipayAccount": alipayAccount])
            return r.ok ?? false
        }

        /// 同步寄件地址（onlyIfEmpty：已有寄件地址时不覆盖；失败静默）
        func saveSenderQuietly(_ senderAddress: String, onlyIfEmpty: Bool = true) async {
            let _: OkResponse? = try? await client.post("address.saveSender", input: [
                "senderAddress": senderAddress, "onlyIfEmpty": onlyIfEmpty,
            ])
        }

        /// 领取外部无料后发送地址给发布者
        func send(showcaseId: Int, addressIndex: Int) async throws -> Bool {
            let r: OkResponse = try await client.post("address.send", input: [
                "showcaseId": showcaseId, "addressIndex": addressIndex,
            ])
            return r.ok ?? false
        }

        /// 某橱窗收到的地址（仅发布者）
        func received(showcaseId: Int) async throws -> ReceivedAddresses {
            try await client.get("address.received", input: ["showcaseId": showcaseId])
        }

        /// 快递后台看板
        func shippingBoard() async throws -> ShippingBoard {
            try await client.get("address.shippingBoard")
        }

        /// 导航角标
        func navBadges() async throws -> NavBadges {
            try await client.get("address.navBadges", cacheable: false)
        }

        /// 我的快递（领取人视角）
        func myShipments() async throws -> MyShipmentsResponse {
            try await client.get("address.myShipments")
        }

        /// 填单号寄件
        func ship(shareId: Int, trackingNo: String) async throws -> Bool {
            let r: OkResponse = try await client.post("address.ship", input: [
                "shareId": shareId, "trackingNo": trackingNo,
            ])
            return r.ok ?? false
        }

        /// 取消预下单/订单
        func cancelShip(shareId: Int) async throws -> Bool {
            let r: OkResponse = try await client.post("address.cancelShip", input: ["shareId": shareId])
            return r.ok ?? false
        }

        /// 邮费审批列表（发布者）
        func approvals() async throws -> ApprovalsResponse {
            try await client.get("address.approvals")
        }

        func approvalDetail(id: Int) async throws -> ApprovalDetail {
            try await client.get("address.approvalDetail", input: ["id": id])
        }

        /// 领取人上传补邮凭证
        func uploadProof(approvalId: Int, image: String) async throws -> Bool {
            let r: OkResponse = try await client.post("address.uploadProof", input: [
                "approvalId": approvalId, "image": image,
            ])
            return r.ok ?? false
        }

        /// 发布人审批补邮凭证
        func reviewApproval(approvalId: Int, action: String, reason: String = "") async throws -> ReviewResult {
            try await client.post("address.reviewApproval", input: [
                "approvalId": approvalId, "action": action, "reason": reason,
            ])
        }

        /// 标记已外部寄件（可选单号/邮费/凭证）
        func markExternalShipped(shareId: Int, trackingNo: String = "", fee: Int? = nil, feeProof: String? = nil) async throws -> Bool {
            var input: [String: Any] = ["shareId": shareId, "trackingNo": trackingNo]
            if let fee = fee { input["fee"] = fee }
            if let feeProof = feeProof { input["feeProof"] = feeProof }
            let r: OkResponse = try await client.post("address.markExternalShipped", input: input)
            return r.ok ?? false
        }

        /// 标记邮费已付清
        func markShippingPaid(shareId: Int) async throws -> Bool {
            let r: OkResponse = try await client.post("address.markShippingPaid", input: ["shareId": shareId])
            return r.ok ?? false
        }

        /// 隐藏/恢复某条寄件记录
        func setShareHidden(shareId: Int, hidden: Bool) async throws -> Bool {
            let r: OkResponse = try await client.post("address.setShareHidden", input: [
                "shareId": shareId, "hidden": hidden,
            ])
            return r.ok ?? false
        }

        /// 恢复某橱窗下所有隐藏记录
        func unhideShowcaseShares(showcaseId: Int) async throws -> Bool {
            let r: OkResponse = try await client.post("address.unhideShowcaseShares", input: ["showcaseId": showcaseId])
            return r.ok ?? false
        }

        /// 删除寄件记录（返回橱窗是否一并被删除）
        func deleteShare(shareId: Int) async throws -> DeleteShareResult {
            try await client.post("address.deleteShare", input: ["shareId": shareId])
        }

        /// 某领取人在我橱窗下的全部寄件记录
        func userShipments(userId: Int) async throws -> UserShipmentsResponse {
            try await client.get("address.userShipments", input: ["userId": userId])
        }

        /// 预下单（zto/yunda/cainiao）
        func preorderShip(shareId: Int, channel: String, itemName: String = "周边无料", weight: String = "1", cpCode: String = "", testMode: Bool = false) async throws -> ShipOrderResult {
            try await client.post("address.preorderShip", input: [
                "shareId": shareId, "channel": channel, "itemName": itemName,
                "weight": weight, "cpCode": cpCode, "testMode": testMode,
            ])
        }

        /// 韵达自动下单
        func autoShip(shareId: Int, itemName: String = "周边无料", weight: String = "1", testMode: Bool = false) async throws -> ShipOrderResult {
            try await client.post("address.autoShip", input: [
                "shareId": shareId, "itemName": itemName, "weight": weight, "testMode": testMode,
            ])
        }

        /// 中通自动下单
        func autoShipZto(shareId: Int, itemName: String = "周边无料", weight: String = "1", testMode: Bool = false) async throws -> ShipOrderResult {
            try await client.post("address.autoShipZto", input: [
                "shareId": shareId, "itemName": itemName, "weight": weight, "testMode": testMode,
            ])
        }

        /// 菜鸟自动下单
        func autoShipCainiao(shareId: Int, itemName: String = "周边无料", weight: String = "1", cpCode: String = "", testMode: Bool = false) async throws -> ShipOrderResult {
            try await client.post("address.autoShipCainiao", input: [
                "shareId": shareId, "itemName": itemName, "weight": weight, "cpCode": cpCode, "testMode": testMode,
            ])
        }

        func saveSender(_ senderAddress: String, onlyIfEmpty: Bool = false) async throws -> Bool {
            let r: OkResponse = try await client.post("address.saveSender", input: [
                "senderAddress": senderAddress, "onlyIfEmpty": onlyIfEmpty,
            ])
            return r.ok ?? false
        }

        // MARK: 快递账号绑定
        func bindYunda(token: String) async throws -> BindResult {
            try await client.post("address.bindYunda", input: ["token": token])
        }
        func unbindYunda() async throws -> Bool {
            let r: OkResponse = try await client.post("address.unbindYunda")
            return r.ok ?? false
        }
        func yundaStatus() async throws -> ExpressStatus {
            try await client.get("address.yundaStatus")
        }
        func bindZto(token: String) async throws -> BindResult {
            try await client.post("address.bindZto", input: ["token": token])
        }
        func unbindZto() async throws -> Bool {
            let r: OkResponse = try await client.post("address.unbindZto")
            return r.ok ?? false
        }
        func ztoStatus() async throws -> ExpressStatus {
            try await client.get("address.ztoStatus")
        }
        func bindCainiao(cookie: String) async throws -> BindResult {
            try await client.post("address.bindCainiao", input: ["cookie": cookie])
        }
        func unbindCainiao() async throws -> Bool {
            let r: OkResponse = try await client.post("address.unbindCainiao")
            return r.ok ?? false
        }
        func cainiaoStatus() async throws -> ExpressStatus {
            try await client.get("address.cainiaoStatus")
        }

        /// 导出寄件需求 Excel（返回 base64 + 文件名）
        func exportExcel(showcaseId: Int = 0, status: String = "all") async throws -> ExportResult {
            try await client.post("address.exportExcel", input: [
                "showcaseId": showcaseId, "status": status,
            ])
        }

        /// 导出菜鸟批量寄件模板
        func exportCainiao(showcaseId: Int = 0, userId: Int = 0, status: String = "todo") async throws -> ExportResult {
            try await client.post("address.exportCainiao", input: [
                "showcaseId": showcaseId, "userId": userId, "status": status,
            ])
        }
    }

    // MARK: - 动态（post.*，2026-10-08 网页版新功能）
    struct PostService {
        let client: APIClient

        /// 动态流：自己 + 关注的人，按时间倒序
        func feed(cursor: Int = 0, limit: Int = 10) async throws -> PostFeedResponse {
            var input: [String: Any] = ["limit": limit]
            if cursor > 0 { input["cursor"] = cursor }
            return try await client.get("post.feed", input: input, cacheable: false)
        }

        /// 某人的动态（个人主页）：未关注返回 restricted
        func byUser(userId: Int, cursor: Int = 0, limit: Int = 10) async throws -> PostFeedResponse {
            var input: [String: Any] = ["userId": userId, "limit": limit]
            if cursor > 0 { input["cursor"] = cursor }
            return try await client.get("post.byUser", input: input, cacheable: false)
        }

        /// 动态数量（个人主页入口卡）
        func countByUser(userId: Int) async throws -> PostCountResponse {
            try await client.get("post.countByUser", input: ["userId": userId])
        }

        /// 发动态：文字 + 最多 9 张配图（dataURL）
        func create(content: String, images: [String]) async throws -> Int {
            let r: PostCreateResult = try await client.post("post.create", input: [
                "content": content, "images": images,
            ])
            return r.id ?? 0
        }

        func delete(id: Int) async throws -> Bool {
            let r: OkResponse = try await client.post("post.delete", input: ["id": id])
            return r.ok ?? false
        }

        /// 置顶/取消置顶（每人至多一条）
        func togglePin(id: Int) async throws -> Bool {
            let r: PostPinResult = try await client.post("post.togglePin", input: ["id": id])
            return r.pinned ?? false
        }

        func toggleLike(postId: Int) async throws -> Bool {
            let r: PostLikeResult = try await client.post("post.toggleLike", input: ["postId": postId])
            return r.liked ?? false
        }

        func comments(postId: Int, limit: Int = 50) async throws -> [PostComment] {
            try await client.get("post.comments", input: ["postId": postId, "limit": limit], cacheable: false)
        }

        func addComment(postId: Int, content: String, replyToCommentId: Int? = nil) async throws -> Bool {
            var input: [String: Any] = ["postId": postId, "content": content]
            if let rid = replyToCommentId { input["replyToCommentId"] = rid }
            let r: PostCreateResult = try await client.post("post.addComment", input: input)
            return (r.id ?? 0) > 0
        }

        func deleteComment(id: Int) async throws -> Bool {
            let r: OkResponse = try await client.post("post.deleteComment", input: ["id": id])
            return r.ok ?? false
        }
    }

    // MARK: - 管理后台（admin.*）
    struct AdminService {
        let client: APIClient

        func stats() async throws -> AdminStats {
            try await client.get("admin.stats")
        }

        func growthTrend(period: String = "week") async throws -> AdminGrowthTrend {
            try await client.get("admin.growthTrend", input: ["period": period])
        }

        /// 手动触发心选结算
        func settleHeart() async throws -> Bool {
            let r: OkResponse = try await client.post("admin.settleHeart")
            return r.ok ?? false
        }

        /// 最近注册用户（仅主管理员）
        func recentUsers() async throws -> [AdminUser] {
            try await client.get("admin.recentUsers")
        }

        /// 按 ID 搜索用户（仅主管理员）
        func searchUserById(userId: Int) async throws -> AdminUser? {
            struct R: Codable { let user: AdminUser? }
            let r: R = try await client.get("admin.searchUserById", input: ["userId": userId])
            return r.user
        }

        /// 授予/收回管理员（仅主管理员）
        func setRole(userId: Int, admin: Bool) async throws -> Bool {
            let r: OkResponse = try await client.post("admin.setRole", input: [
                "userId": userId, "admin": admin,
            ])
            return r.ok ?? false
        }

        /// 数据库备份列表（2026-10-08，仅主管理员）
        func backupList() async throws -> BackupListResponse {
            try await client.get("admin.backupList")
        }

        /// 立即手动备份（仅主管理员）
        func backupNow() async throws -> BackupNowResult {
            try await client.post("admin.backupNow")
        }

        // MARK: 动态管理（2026-10-09，仅主管理员）

        /// 待审阅动态数（入口角标用）
        func postPendingCount() async throws -> Int {
            struct R: Codable { let count: Int? }
            let r: R = try await client.get("admin.postPendingCount", cacheable: false)
            return r.count ?? 0
        }

        /// 动态管理列表：view = pending / favorites / all，cursor 分页
        func postList(view: String, cursor: Int? = nil, limit: Int = 20) async throws -> AdminPostListResponse {
            var input: [String: Any] = ["view": view, "limit": limit]
            if let c = cursor { input["cursor"] = c }
            return try await client.get("admin.postList", input: input, cacheable: false)
        }

        /// 标记/取消标记（reviewed / favorited），幂等
        func postMark(id: Int, mark: String, on: Bool) async throws -> Bool {
            let r: OkResponse = try await client.post("admin.postMark", input: [
                "id": id, "mark": mark, "on": on,
            ])
            return r.ok ?? false
        }

        /// 软删除动态（status → deleted）
        func postDelete(id: Int) async throws -> Bool {
            let r: OkResponse = try await client.post("admin.postDelete", input: ["id": id])
            return r.ok ?? false
        }
    }

    // MARK: - 服务实例
    var auth:        AuthService        { AuthService(client: client) }
    var emailAuth:   EmailAuthService   { EmailAuthService(client: client) }
    var showcase:    ShowcaseService    { ShowcaseService(client: client) }
    var tag:         TagService         { TagService(client: client) }
    var tagAdmin:    TagAdminService    { TagAdminService(client: client) }
    var report:      ReportService      { ReportService(client: client) }
    var interaction: InteractionService { InteractionService(client: client) }
    var bookmark:    BookmarkService    { BookmarkService(client: client) }
    var request:     RequestService     { RequestService(client: client) }
    var soldout:     SoldoutService     { SoldoutService(client: client) }
    var repost:      RepostService      { RepostService(client: client) }
    var claim:       ClaimService       { ClaimService(client: client) }
    var code:        CodeService        { CodeService(client: client) }
    var share:       ShareService       { ShareService(client: client) }
    var settings:    SettingsService    { SettingsService(client: client) }
    var follow:      FollowService      { FollowService(client: client) }
    var message:     MessageService     { MessageService(client: client) }
    var dm:          DMService          { DMService(client: client) }
    var points:      PointsService      { PointsService(client: client) }
    var task:        TaskService        { TaskService(client: client) }
    var shop:        ShopService        { ShopService(client: client) }
    var heart:       HeartService       { HeartService(client: client) }
    var farm:        FarmService        { FarmService(client: client) }
    var gift:        GiftService        { GiftService(client: client) }
    var stats:       StatsService       { StatsService(client: client) }
    var post:        PostService        { PostService(client: client) }
    var card:        CardService        { CardService(client: client) }
    var cardPlaza:   CardPlazaService   { CardPlazaService(client: client) }
    var address:     AddressService     { AddressService(client: client) }
    var admin:       AdminService       { AdminService(client: client) }
}

// MARK: - CardConfig 编码辅助
extension CardConfig {
    func toDict() -> [String: Any] {
        var d: [String: Any] = [
            "palette": palette,
            "gradient": gradient,
        ]
        d["stickers"] = stickers.map { ["url": $0.url, "x": $0.x, "y": $0.y, "scale": $0.scale] }
        return d
    }
}
