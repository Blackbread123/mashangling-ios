import Foundation

// MARK: - 基础工具

/// 站点基地址（与网页版同一后端、同一数据库）
enum SiteConfig {
    static let baseURL = "https://mashangling.kimi.site"

    /// 把后端返回的相对路径（/api/cover/1?v=2）或 dataURL / http URL 统一成可用 URL
    static func absoluteURL(_ path: String?) -> URL? {
        guard let path = path, !path.isEmpty else { return nil }
        if path.hasPrefix("data:") {
            // dataURL 不走网络，由专门的 DataImageView 处理
            return nil
        }
        if path.hasPrefix("http") { return URL(string: path) }
        return URL(string: baseURL + path)
    }

    static func isDataURL(_ s: String?) -> Bool { s?.hasPrefix("data:") == true }

    /// dataURL -> UIImage 用
    static func dataFromDataURL(_ s: String?) -> Data? {
        guard let s = s, let range = s.range(of: "base64,") else { return nil }
        let b64 = String(s[range.upperBound...])
        return Data(base64Encoded: b64)
    }
}

/// ISO8601 日期解析（后端 superjson 将 Date 序列化为 ISO 字符串）
enum DateFmt {
    static let iso: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()
    static let isoPlain: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f
    }()

    static func parse(_ s: String?) -> Date? {
        guard let s = s else { return nil }
        return iso.date(from: s) ?? isoPlain.date(from: s)
    }

    /// "M/d HH:mm"
    static func short(_ s: String?) -> String {
        guard let d = parse(s) else { return "" }
        let f = DateFormatter()
        f.locale = Locale(identifier: "zh_CN")
        f.dateFormat = "M/d HH:mm"
        return f.string(from: d)
    }

    /// "HH:mm"
    static func time(_ s: String?) -> String {
        guard let d = parse(s) else { return "" }
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        return f.string(from: d)
    }

    /// "yyyy-MM-dd HH:mm"
    static func full(_ s: String?) -> String {
        guard let d = parse(s) else { return "" }
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd HH:mm"
        return f.string(from: d)
    }

    /// "yyyy-M-d"
    static func day(_ s: String?) -> String {
        guard let d = parse(s) else { return "" }
        let f = DateFormatter()
        f.dateFormat = "yyyy-M-d"
        return f.string(from: d)
    }

    /// "M月d日 HH:mm"（对应网页 toLocaleString zh-CN 的月日时分）
    static func mddhm(_ d: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "zh_CN")
        f.dateFormat = "M月d日 HH:mm"
        return f.string(from: d)
    }
}

// MARK: - 等级 / 头衔体系（复刻 contracts/levels.ts）

enum Levels {
    static let maxLevel = 30
    static func needForLevel(_ n: Int) -> Int { 50 * n * n }
    static func levelFromPoints(_ p: Int) -> (level: Int, into: Int, need: Int) {
        var level = 1
        var rest = max(0, p)
        while level < maxLevel && rest >= needForLevel(level) {
            rest -= needForLevel(level)
            level += 1
        }
        return (level, rest, level >= maxLevel ? 0 : needForLevel(level))
    }
    static let bands = ["新手蛋农", "孵蛋学徒", "捡蛋好手", "产蛋大户", "金蛋掌柜", "传说鸡舍主"]
    static func band(of level: Int) -> String {
        bands[min(bands.count - 1, max(0, (level - 1) / 5))]
    }
    /// 头衔目录
    static let titles: [String: (label: String, icon: String, desc: String)] = [
        "eggking": ("鸡蛋王", "🐔", "无料达人周榜定榜第一名的证明"),
        "buyking": ("买股王", "📈", "心选橱窗周榜定榜第一名的证明（每周日 23:59 定榜，另奖 100 积分）"),
        "weeklyking": ("周榜冠军", "👑", "无料达人周榜定榜第一名的证明（每周日 23:59 定榜，另奖 100 积分）"),
        "seveneggs": ("七蛋王", "🥚", "农场集齐 7 颗鸡蛋的证明"),
    ]
}

/// 平台标识
enum PlatformLabel {
    static func of(_ platform: String?) -> String {
        switch platform {
        case "rouzao": return "柔造"
        case "yingtang": return "映糖"
        default: return "外部无料"
        }
    }
}

/// 标签分类标识
enum CategoryLabel {
    static func of(_ c: String?) -> String {
        switch c {
        case "work": return "作品"
        case "character": return "角色"
        case "merch": return "制品"
        default: return "其他"
        }
    }
}

// MARK: - 作者（嵌套在橱窗里）

struct Author: Codable, Identifiable {
    let id: Int
    let name: String?
    let avatar: String?
    let equippedTitle: String?
    let level: Int?
}

// MARK: - 标签

/// 标签分类文案（对应 TagPicker.tsx 的 CATEGORY_LABEL）
enum TagCategory {
    static let labels: [String: String] = [
        "work": "作品", "character": "角色", "merch": "制品", "other": "其他",
    ]
    static func label(_ category: String?) -> String {
        labels[category ?? "other"] ?? category ?? "其他"
    }
}

struct Tag: Codable, Identifiable, Hashable {
    let id: Int
    let name: String
    let category: String?
    var status: String?
    var showcaseCount: Int?
    var todayCount: Int?
}

// MARK: - 橱窗卡片（feed item，对应 assembleFeedItems 返回）

struct Showcase: Codable, Identifiable {
    let id: Int
    let title: String
    let platform: String?
    let coverImage: String?
    let pinned: Bool?
    let stockStatus: String?
    let quantity: Int?
    let remaining: Int?
    let pointCost: Int?
    let expiresAt: String?
    let isFullyClaimed: Bool?
    let createdAt: String?
    let author: Author?
    let tags: [Tag]?
    let likeCount: Int?
    let claimCount: Int?
    let codeCount: Int?
    let likedByMe: Bool?
    let claimedByMe: Bool?
    let addressSentByMe: Bool?
    let addressCount: Int?

    var authorName: String? { author?.name }

    var isExpired: Bool {
        guard let t = DateFmt.parse(expiresAt) else { return false }
        return t < Date()
    }

    /// 限时角标文本
    var expiresBadgeText: String? {
        guard let d = DateFmt.parse(expiresAt) else { return nil }
        if d < Date() { return "已失效" }
        let f = DateFormatter()
        f.dateFormat = "MM-dd HH:mm"
        return "限时 · \(f.string(from: d)) 失效"
    }
}

// MARK: - 橱窗详情（showcase.byId 返回）

struct ShowcaseDetailData: Codable {
    let id: Int
    let title: String
    let description: String?
    let platform: String?
    let rouzaoCode: String?
    let codeVisibility: String?
    let stockStatus: String?
    let coverImage: String?
    let viewCount: Int?
    let pinned: Bool?
    let createdAt: String?
    let isMine: Bool?
    let author: Author?
    let tags: [Tag]?
    let likeCount: Int?
    let claimCount: Int?
    let wantCount: Int?
    let soldoutCount: Int?
    let shareCount: Int?
    let likedByMe: Bool?
    let claimedByMe: Bool?
    let myClaimStatus: String?      // pending / approved / rejected
    let myClaimResolvedAt: String?
    let quantity: Int?
    let remaining: Int?
    let isFullyClaimed: Bool?
    let claimMode: String?          // request / instant / points
    let pointCost: Int?
    let shortCode: String?
    let addressSentByMe: Bool?
    let addressCount: Int?
    let myRequested: Bool?
    let addressEligible: Bool?
    let addressDeadline: String?
    let addressDeadlineExpired: Bool?
    let addressDeadlineText: String?
    let shippingFree: Bool?
    let expiresAt: String?
    let expired: Bool?
    let expiresAtText: String?
    let myGift: GiftRef?
    let related: [Showcase]?

    struct GiftRef: Codable {
        let id: Int
        let fromName: String
    }
}

// MARK: - 用户（auth.me 返回 users 全行，去掉 passwordHash）

struct User: Codable, Identifiable {
    let id: Int
    let unionId: String?
    let name: String?
    let email: String?
    let notifyEmail: String?
    let dmBlocked: Bool?
    let bio: String?
    let avatar: String?
    let role: String?
    let bannedAt: String?
    let superAdmin: Bool?
    let isBot: Bool?
    // 注意：服务端 homeModules 可能是数组也可能是字符串（字段类型不稳定），
    // App 内用不到它（主页模块走 settings.getHomeModules），这里不声明，避免解码失败。
    let siteTheme: String?
    let createdAt: String?
    let updatedAt: String?
    let lastSignInAt: String?

    var isAdmin: Bool { role == "admin" }
}

// MARK: - 个人主页（showcase.byUser 返回）

struct ProfileData: Codable {
    let author: ProfileAuthor?
    let items: [Showcase]?
    let totalLikes: Int?
    let totalClaims: Int?
    let cardFavCount: Int?

    struct ProfileAuthor: Codable {
        let id: Int
        let name: String?
        let avatar: String?
        let bio: String?
        let level: Int?
        let equippedTitle: String?
        let followerCount: Int?
        let dmBlocked: Bool?
        let isBot: Bool?
    }
}

// MARK: - Feed 响应

struct FeedResponse: Codable {
    let items: [Showcase]
    let nextCursor: Int?
}

/// request.received：我收到的「我想领」
struct RequestReceivedRow: Codable, Identifiable {
    let id: Int
    let contact: String?
    let createdAt: String?
    let showcaseId: Int?
    let showcaseTitle: String?
    let requesterName: String?
}

/// soldout.received：我收到的补货提醒
struct SoldoutReceivedRow: Codable, Identifiable {
    let id: Int
    let createdAt: String?
    let showcaseId: Int?
    let showcaseTitle: String?
    let markerName: String?
}

// MARK: - 心选橱窗

struct HeartSearchResult: Codable, Identifiable {
    let id: Int
    let title: String
    let coverImage: String?
    let shortCode: String?
    let authorName: String?
    let todayRank: Int?
}

struct HeartTrend: Codable {
    let showcaseId: Int
    let title: String
    let shortCode: String?
    let points: [TrendPoint]?

    struct TrendPoint: Codable {
        let day: String
        let rank: Int
    }
}

struct MarketResponse: Codable {
    let points: [MarketPoint]?
}

struct MarketPoint: Codable {
    let day: String
    let rank: Int
    let open: Int
    let close: Int
    let high: Int
    let low: Int
    let up: Bool
    let flat: Bool
    let isToday: Bool
}

struct HeartSupportRow: Codable, Identifiable {
    let id: Int
    let showcaseId: Int
    let direction: String
    let amount: Int
    let dayKey: String
    let settled: Bool
    let payout: Int?
    let createdAt: String?
    let title: String?
    let coverImage: String?
    let shortCode: String?
}

struct HeartRising: Codable, Identifiable {
    let id: Int
    let title: String
    let coverImage: String?
    let shortCode: String?
    let authorName: String?
    let rise: Int
}

/// 心选当日奖池（heart.poolAdmin，仅管理员）
struct HeartPoolAdmin: Codable {
    let dayKey: String?
    let todaySupport: Int?
    let carryIn: Int?
    let total: Int?
    let settled: Bool?
}

/// 举报终审结果
struct DecideResult: Codable {
    let ok: Bool?
    let banned: Bool?
}

struct HeartWeeklyTopUser: Codable, Identifiable {
    var id: Int { userId }
    let userId: Int
    let name: String?
    let avatar: String?
    let profit: Int
}

struct HeartRecentSupport: Codable, Identifiable {
    let id: Int
    let showcaseId: Int
    let userName: String?
    let isBot: Bool?
    let title: String?
    let direction: String?
    let createdAt: String?
}

struct HeartInfo: Codable {
    let inWindow: Bool
    let windowText: String
    let botNames: [String]?
}

// MARK: - 农场

struct FarmRate: Codable {
    let weeklyRate: Double?
    let dailyRate: Double?
}

struct FarmOverview: Codable {
    let visible: Bool
    let isOwner: Bool
    let hens: [String]?            // PNG dataURL 列表
    let eggCount: Int
    let eggCap: Int
    let eggSpent: Int?
    let available: Int?
    let weekKey: String?
    let trees: [FarmTree]?
    let nextTreeIdx: Int?
    let weeklyRate: Double?
    let dailyRate: Double?

    struct FarmTree: Codable, Identifiable {
        var id: Int { idx }
        let idx: Int
        let key: String
        let name: String
        let fruit: String
        let cost: Int
        let fruitValue: Int
        let owned: Bool
        let fruitCount: Int
        let purchasable: Bool
        let canAfford: Bool
    }
}

/// points.farm（鸡场部分）
struct PointsFarm: Codable {
    let visible: Bool
    let eggCount: Int
    let eggCap: Int
    let farmPublic: Bool
    let isOwner: Bool
    let available: Int?
    let totalPoints: Int?
    let eggSpent: Int?
    let nextCost: Int?
    let canBuy: Bool?
    let hens: [String]?
}

// MARK: - 积分

struct PointsMy: Codable {
    let points: Int
    let weekPoints: Int?
    let monthPoints: Int?
    let level: Int
    let into: Int
    let need: Int
    let band: String
    let maxLevel: Bool?
    let available: Int
    let eggCount: Int?
    let eggSpent: Int?
    let farmPublic: Bool?
    let titles: [TitleItem]?

    struct TitleItem: Codable, Identifiable {
        var id: String { key }
        let key: String
        let equipped: Bool
        let earnedAt: String?
    }
}

struct PointsTickerRow: Codable, Identifiable {
    var id: String { "\(name)-\(delta)-\(label)" }
    let name: String
    let delta: Int
    let label: String
}

struct PointLogRow: Codable, Identifiable {
    let id: Int
    let userId: Int
    let delta: Int
    let label: String
    let showcaseId: Int?
    let fromUserId: Int?
    let createdAt: String?
    let fromUserName: String?
    let kind: String?
}

struct PointsLeaderboard: Codable {
    let items: [PointsLeaderboardUser]?
}

struct PointsLeaderboardUser: Codable, Identifiable {
    var id: Int { userId }
    let userId: Int
    let name: String?
    let avatar: String?
    let points: Int?
    let weekPoints: Int?
    let lastWeekPoints: Int?
    let rise: Int?
    let level: Int?
    let equippedTitle: String?
}

// MARK: - 任务

struct TaskProgress: Codable {
    let daily: [TaskItem]?
    let weekly: [TaskItem]?
}

struct TaskItem: Codable, Identifiable {
    var id: String { key }
    let key: String
    let progress: Int
    let goal: Int
    let done: Bool
    let claimed: Bool
    let reward: Int

    /// 任务文案（复刻网页 TASK_META）
    var label: String {
        switch key {
        case "daily_login": return "登录网站"
        case "daily_browse5": return "浏览 5 个橱窗"
        case "daily_feedback5": return "给出 5 次反馈"
        case "daily_cardbrowse3": return "浏览 3 次卡片广场的卡片"
        case "daily_cardfeedback1": return "给出 1 次卡片反馈"
        case "weekly_publish1": return "发布 1 个橱窗"
        case "weekly_cardcomment1": return "评论 1 次卡片"
        case "weekly_share1": return "分享 1 次橱窗"
        case "daily_all": return "完成全部每日任务"
        case "weekly_all": return "完成全部每周任务"
        default: return key
        }
    }
}

struct CheckinStatus: Codable {
    let checkedToday: Bool
    let streak: Int
}

struct CheckinResult: Codable {
    let ok: Bool
    let already: Bool?
    let streak: Int?
    let reward: Int?
}

struct TaskClaimResult: Codable {
    let ok: Bool
    let already: Bool?
    let reward: Int?
}

// MARK: - 消息（站内信 message.list）

struct MessageRow: Codable, Identifiable {
    let id: Int
    let type: String
    let title: String
    let content: String?
    let image: String?
    let link: String?
    let read: Bool
    let createdAt: String?
    let fromUserId: Int?
    let showcaseId: Int?
    let fromUserName: String?
}

struct UnreadCount: Codable { let count: Int }

// MARK: - 私信（dm.*）

struct Conversation: Codable, Identifiable {
    var id: Int { peerId }
    let peerId: Int
    let peerName: String?
    let peerAvatar: String?
    let lastContent: String?
    let fromMe: Bool?
    let lastAt: String?
    let unread: Int?
}

struct DMThreadResponse: Codable {
    let peer: Peer
    let items: [DMItem]

    struct Peer: Codable {
        let id: Int
        let name: String?
        let avatar: String?
        let dmBlocked: Bool?
    }
}

struct DMItem: Codable, Identifiable {
    let id: Int
    let fromUserId: Int
    let toUserId: Int
    let content: String
    let showcaseId: Int?
    let cardPostId: Int?
    let profileUserId: Int?
    let giftId: Int?
    let replyToId: Int?
    let createdAt: String?
    // 快照附件
    let showcase: DMShowcaseSnap?
    let cardPost: DMCardSnap?
    let profileUser: DMProfileSnap?
    let gift: DMGiftSnap?
    let replyTo: DMReplySnap?

    struct DMShowcaseSnap: Codable {
        let id: Int
        let title: String
        let coverImage: String?
    }
    struct DMCardSnap: Codable {
        let id: Int
        let title: String
        let config: CardConfig?
        let removed: Bool?
    }
    struct DMProfileSnap: Codable {
        let id: Int
        let name: String
        let avatar: String?
        let bio: String?
    }
    struct DMGiftSnap: Codable {
        let id: Int
        let claimed: Bool
    }
    struct DMReplySnap: Codable {
        let id: Int
        let content: String
        let fromUserId: Int?
    }
}

// MARK: - 关注 / 好友

struct FollowStatus: Codable {
    let following: Bool
    let special: Bool
    let followerCount: Int?
}

struct FollowToggleResult: Codable {
    let following: Bool
    let special: Bool?
}

struct FollowUser: Codable, Identifiable {
    var id: Int { userId }
    let userId: Int
    let name: String?
    let avatar: String?
    let bio: String?
    let special: Bool?
    let followedAt: String?
    let mutual: Bool?
    let level: Int?
    let equippedTitle: String?
    let followerCount: Int?
}

struct MutualsResponse: Codable { let items: [FollowUser]? }
struct FriendsResponse: Codable { let items: [FollowUser]? }
/// follow.followers / follow.followingOf：带总数的列表
struct FollowListResponse: Codable {
    let count: Int
    let items: [FollowUser]?
}
struct MutualWithResponse: Codable {
    let count: Int
    let items: [FollowUser]?
}
struct SearchUsersResponse: Codable { let items: [FollowUser]? }

// MARK: - 礼物 / 好友好感

struct FriendshipInfo: Codable {
    let mutual: Bool
    let total: Int?
    let balance: Int?
    let level: Int?
    let levelStart: Int?
    let nextNeed: Int?
    let badges: [Badge]?
    let nextBadgeCost: Int?

    struct Badge: Codable, Identifiable {
        let id: Int
        let image: String
        let uploaderId: Int?
        let cost: Int?
        let isPublic: Bool?
        let createdAt: String?
    }
}

struct PublicBadge: Codable, Identifiable {
    let id: Int
    let image: String
    let friendId: Int?
    let friendName: String?
    let uploadedByMe: Bool?
    let level: Int?
}

struct GiftRecords: Codable {
    let sent: [GiftRow]?
    let received: [GiftRow]?

    struct GiftRow: Codable, Identifiable {
        let id: Int
        let showcaseId: Int
        let showcaseTitle: String?
        let coverImage: String?
        let removed: Bool?
        let expiresAt: String?
        let claimed: Bool
        let claimedAt: String?
        let createdAt: String?
        let peer: Peer?

        struct Peer: Codable {
            let id: Int?
            let name: String?
            let avatar: String?
        }
    }
}

// MARK: - 商店（shop.overview）

struct ShopOverview: Codable {
    let balance: Int?                 // 可用积分
    let totalPoints: Int?
    let spent: Int?
    let goodwillCost: Int?            // 1 点好感的积分价格
    let trees: [ShopTree]?
    let items: [ShopItem]?

    struct ShopTree: Codable, Identifiable {
        var id: Int { idx }
        let idx: Int
        let key: String
        let name: String
        let fruit: String
        let cost: Int
        let fruitValue: Int
        let owned: Bool
        let purchasable: Bool
        let canAfford: Bool
    }

    struct ShopItem: Codable, Identifiable {
        var id: String { key }
        let key: String               // theme / hen / egg
        let name: String
        let desc: String
        let count: Int
        let max: Int
        let nextCost: Int?
        let editPath: String?
        let editLabel: String?
    }
}

// MARK: - 设置（settings.get）

struct SettingsData: Codable {
    let name: String?
    let avatar: String?
    let email: String?
    let notifyEmail: String?
    let bio: String?
    let dmBlocked: Bool?
    let hasPublishedShowcase: Bool?
}

struct HomeModulesData: Codable { let homeModules: String? }
struct SiteThemeData: Codable { let siteTheme: String? }

// MARK: - 地址（address.get）

struct AddressData: Codable {
    let nickname: String?
    let address: String?
    let phone: String?
    let entries: [AddressEntry]?
    let senderAddress: String?
    let alipayAccount: String?
    let yundaLoginName: String?
    let ztoLoginName: String?
    let cainiaoNick: String?
    let cainiaoUserType: String?

    struct AddressEntry: Codable, Identifiable, Hashable {
        var id: String { "\(nickname)-\(phone)-\(address)" }
        let nickname: String
        let address: String
        let phone: String
    }
}

// MARK: - 领取申请（claim.received）

struct ClaimRow: Codable, Identifiable {
    let id: Int
    let showcaseId: Int?
    let showcaseTitle: String?
    let applicantId: Int?
    let applicantName: String?
    let note: String?
    let credentialImage: String?
    let status: String?
    let createdAt: String?
    let resolvedAt: String?
}

// MARK: - 补码（code.list）

struct CodeRow: Codable, Identifiable {
    let id: Int
    let showcaseId: Int?
    let code: String
    let createdAt: String?
}

// MARK: - 返图（repost.list / repost.mine）

struct RepostRow: Codable, Identifiable {
    let id: Int
    let showcaseId: Int?
    let userId: Int?
    let image: String
    let comment: String?
    let createdAt: String?
    let userName: String?
    let userAvatar: String?
}

// MARK: - 清单 / 浏览历史

struct BookmarkIds: Codable { let ids: [Int] }
struct RequestedFlag: Codable { let requested: Bool }
struct MarkedFlag: Codable { let marked: Bool }

struct BrowseHistoryRow: Codable, Identifiable {
    var id: Int { showcaseId }
    let showcaseId: Int
    let lastAt: String?
    let title: String?
    let coverImage: String?
    let authorName: String?
    let authorId: Int?
}

// MARK: - 通用响应

struct OkResponse: Codable { let ok: Bool? }
struct SuccessResponse: Codable { let success: Bool? }

// MARK: - 统计看板（stats.dashboard / stats.trend）

struct StatsDashboardData: Codable {
    let followers: StatsPeriodCounts
    let views: StatsMetric
    let likes: StatsMetric
    let wants: StatsMetric
    let claimed: StatsMetric
    let reposts: StatsMetric
    let shares: StatsMetric
    let showcasePoints: StatsPeriodCounts
    let showcasePointTop: [StatsTopItem]?
    let followerTop: [StatsTopItem]?
    let cards: StatsCards

    struct StatsPeriodCounts: Codable {
        let week: Int
        let month: Int
        let year: Int
        let total: Int

        func value(for period: String) -> Int {
            switch period {
            case "month": return month
            case "year": return year
            default: return week
            }
        }
    }

    struct StatsTopItem: Codable, Identifiable {
        var id: Int { showcaseId }
        let showcaseId: Int
        let title: String
        let count: Int
    }

    struct StatsPeriodTops: Codable {
        let week: [StatsTopItem]?
        let month: [StatsTopItem]?
        let year: [StatsTopItem]?

        func items(for period: String) -> [StatsTopItem] {
            switch period {
            case "month": return month ?? []
            case "year": return year ?? []
            default: return week ?? []
            }
        }
    }

    struct StatsMetric: Codable {
        let counts: StatsPeriodCounts
        let top: StatsPeriodTops
    }

    struct StatsCardTopItem: Codable, Identifiable {
        var id: Int { postId }
        let postId: Int
        let title: String
        let count: Int
    }

    struct StatsCardPeriodTops: Codable {
        let week: [StatsCardTopItem]?
        let month: [StatsCardTopItem]?
        let year: [StatsCardTopItem]?

        func items(for period: String) -> [StatsCardTopItem] {
            switch period {
            case "month": return month ?? []
            case "year": return year ?? []
            default: return week ?? []
            }
        }
    }

    struct StatsCardMetric: Codable {
        let counts: StatsPeriodCounts
        let top: StatsCardPeriodTops
    }

    struct StatsCards: Codable {
        let views: StatsCardMetric
        let likes: StatsCardMetric
        let wants: StatsCardMetric
        let comments: StatsCardMetric
        let shares: StatsCardMetric
        let favorites: StatsCardMetric
    }
}

struct StatsTrend: Codable {
    let labels: [String]?
    let series: Series?

    struct Series: Codable {
        let followers: [Int]?
        let views: [Int]?
        let likes: [Int]?
        let wants: [Int]?
        let claimed: [Int]?
        let reposts: [Int]?
        let shares: [Int]?
        let showcasePoints: [Int]?
        let cardLikes: [Int]?
        let cardWants: [Int]?
        let cardComments: [Int]?
        let cardShares: [Int]?
        let cardFavorites: [Int]?
    }
}


// MARK: - 卡片主题配置（分享卡片画布）

struct CardConfig: Codable, Equatable {
    var palette: String = "orange"
    var gradient: Bool = false
    var stickers: [CardSticker] = []

    struct CardSticker: Codable, Equatable, Identifiable {
        var id: String { url.hashValue.description + "-\(x)-\(y)" }
        var url: String           // PNG dataURL
        var x: Double             // 0~1 相对画布宽
        var y: Double             // 0~1 相对画布高
        var scale: Double         // 相对画布宽度
    }
}

/// 卡片主题（card.mine 列表项）
struct CardThemeItem: Codable, Identifiable {
    let id: Int
    let name: String
    let config: CardConfig
    let code: String
    let source: String?           // self / imported
    let createdAt: String?
}

struct CardMineResponse: Codable {
    let themes: [CardThemeItem]
    let defaultThemeId: Int?
    let count: Int
    let maxThemes: Int
    let slots: Int
    let nextCost: Int?
    let availablePoints: Int
}

struct CardThemeOfResponse: Codable {
    let theme: CardThemeRef?

    struct CardThemeRef: Codable {
        let id: Int
        let name: String
        let config: CardConfig
    }
}

struct CardPreviewResponse: Codable {
    let name: String
    let config: CardConfig
}

struct CardHensResponse: Codable {
    let hens: [HenItem]
    let count: Int
    let maxHens: Int
    let slots: Int
    let nextCost: Int?
    let availablePoints: Int

    struct HenItem: Codable, Identifiable {
        let id: Int
        let image: String
        let createdAt: String?
    }
}

/// 个人主页的卡片作品（card.forUser）
struct UserCardsResponse: Codable {
    let visible: Bool
    let cardsPublic: Bool?
    let items: [UserCardItem]?

    struct UserCardItem: Codable, Identifiable {
        let id: Int
        let title: String
        let config: CardConfig
        let createdAt: String?
    }
}

// MARK: - 卡片广场

struct CardFeedResponse: Codable {
    let items: [CardPostItem]
    let nextCursor: Int?
}

struct CardPostItem: Codable, Identifiable {
    let id: Int
    let title: String
    let config: CardConfig
    let createdAt: String?
    let isMine: Bool?
    let author: CardAuthor?
    let tags: [CardTag]?
    let viewCount: Int?
    var likeCount: Int?
    let wantCount: Int?
    var commentCount: Int?
    let shareCount: Int?
    let favoriteCount: Int?
    var likedByMe: Bool?
    let wantedByMe: Bool?
    let favoritedByMe: Bool?

    struct CardAuthor: Codable {
        let id: Int
        let name: String?
        let avatar: String?
        let level: Int?
        let equippedTitle: String?
    }

    struct CardTag: Codable, Identifiable {
        let id: Int
        let name: String
    }
}

/// 卡片浏览历史条目（cardPlaza.browseHistory）
struct CardBrowseHistoryItem: Codable, Identifiable {
    var id: Int { postId }
    let postId: Int
    let lastAt: String?
    let title: String?
    let config: CardConfig?
    let removed: Bool?
    let authorName: String?
}

struct CardCommentRow: Codable, Identifiable {
    let id: Int
    let content: String
    let createdAt: String?
    let userId: Int?
    let name: String?
    let avatar: String?
}

struct CardLeaderboardResponse: Codable {
    let items: [CardLeaderboardUser]?

    struct CardLeaderboardUser: Codable, Identifiable {
        var id: Int { userId }
        let rank: Int
        let userId: Int
        let name: String?
        let avatar: String?
        let heat: Int
    }
}

struct MyCommentsResponse: Codable {
    let items: [MyCommentRow]?

    struct MyCommentRow: Codable, Identifiable {
        let id: Int
        let content: String
        let createdAt: String?
        let postId: Int
        let postTitle: String?
        let postStatus: String?
    }
}

/// 清单里收藏的卡片（bookmark.list.cards）
struct FavoriteCardRow: Codable, Identifiable {
    var id: Int { postId }
    let postId: Int
    let title: String
    let config: CardConfig
    let removed: Bool?
    let favoritedAt: String?
    let authorName: String?
    let authorId: Int?
}

struct BookmarkListResponse: Codable {
    let items: [BookmarkedShowcase]?
    let cards: [FavoriteCardRow]?
}

struct BookmarkedShowcase: Codable, Identifiable {
    let id: Int
    let title: String
    let platform: String?
    let coverImage: String?
    let pinned: Bool?
    let stockStatus: String?
    let quantity: Int?
    let remaining: Int?
    let pointCost: Int?
    let expiresAt: String?
    let isFullyClaimed: Bool?
    let createdAt: String?
    let author: Author?
    let tags: [Tag]?
    let likeCount: Int?
    let claimCount: Int?
    let codeCount: Int?
    let likedByMe: Bool?
    let claimedByMe: Bool?
    let addressSentByMe: Bool?
    let addressCount: Int?
    let bookmarkedAt: String?

    /// 转成通用橱窗卡片模型
    var asShowcase: Showcase {
        Showcase(id: id, title: title, platform: platform, coverImage: coverImage,
                 pinned: pinned, stockStatus: stockStatus, quantity: quantity,
                 remaining: remaining, pointCost: pointCost, expiresAt: expiresAt,
                 isFullyClaimed: isFullyClaimed, createdAt: createdAt, author: author,
                 tags: tags, likeCount: likeCount, claimCount: claimCount,
                 codeCount: codeCount, likedByMe: likedByMe, claimedByMe: claimedByMe,
                 addressSentByMe: addressSentByMe, addressCount: addressCount)
    }
}

// MARK: - 快递后台（address.*）

struct NavBadges: Codable {
    let pendingFeeCount: Int?
    let approvalCount: Int?
}

/// 快递看板条目
struct ShipItem: Codable, Identifiable {
    let id: Int
    let userId: Int
    let nickname: String
    let address: String
    let phone: String
    let full: String?
    let trackingNo: String?
    let yundaOrderId: String?
    let ztoOrderId: String?
    let freightActual: String?
    let shippingPaid: Bool?
    let shipState: String?         // "" / preorder / ordered / external / cancelled
    let createdAt: String?
    let fee: Int?
    let feeLabel: String?
    let pickupCode: String?
    let cainiaoCpName: String?
    let pickupAt: String?
    let preChannel: String?
    let preorderAt: String?
    let preorderRemainMs: Int?
    let preorderApproved: Bool?
    let autoShipAt: Int?           // 毫秒时间戳
    let shipStatus: String?
    let shipCheckedAt: String?

    /// 状态文案（复刻网页 shipStatusOf）
    var stateText: String {
        if shipState == "cancelled" { return "已取消" }
        if shipState == "external" { return "已外部寄件" }
        if shipState == "preorder" { return "预下单" }
        if shipState == "ordered" || trackingNo != nil || (yundaOrderId?.isEmpty == false) || (ztoOrderId?.isEmpty == false) { return "已下单" }
        return "未下单"
    }
}

struct ShipGroup: Codable, Identifiable {
    var id: Int { showcaseId }
    let showcaseId: Int
    let title: String
    let shippingFree: Bool?
    let removed: Bool?
    let items: [ShipItem]
    let hiddenCount: Int?
    let subtotal: Int?
    let unpaidSubtotal: Int?
}

struct ShippingBoard: Codable {
    let groups: [ShipGroup]
    let senderAddress: String?
    let grandTotal: Int?
    let grandUnpaid: Int?
    let rule: String?
    let yundaBound: Bool?
    let ztoBound: Bool?
    let cainiaoBound: Bool?
    let alipayAccount: String?
    let pendingApprovalCount: Int?
}

/// 收到的地址（address.received）
struct ReceivedAddresses: Codable {
    let showcaseTitle: String?
    let items: [ReceivedAddress]?

    struct ReceivedAddress: Codable, Identifiable {
        let id: Int
        let nickname: String
        let address: String
        let phone: String
        let full: String?
        let createdAt: String?
    }
}

/// 我的快递（address.myShipments）
struct MyShipmentsResponse: Codable {
    let groups: [MyShipGroup]?
    let pendingFees: [PendingFee]?

    struct MyShipGroup: Codable, Identifiable {
        var id: Int { showcaseId }
        let showcaseId: Int
        let title: String
        let removed: Bool?
        let items: [MyShipment]?
    }

    struct MyShipment: Codable, Identifiable {
        let id: Int
        let trackingNo: String
        let shipState: String?
        let shippingPaid: Bool?
        let isYunda: Bool?
        let showcaseRemoved: Bool?
        let createdAt: String?
        let approvalStatus: String?
        let approvalFee: Int?
    }

    struct PendingFee: Codable, Identifiable {
        var id: Int { approvalId }
        let approvalId: Int
        let showcaseId: Int
        let title: String
        let fee: Int?
        let alipayAccount: String?
        let status: String
        let reason: String?
        let removed: Bool?
        let deadlineAt: Int?
        let remainMs: Int?
        let autoShipAt: Int?
    }
}

/// 邮费审批列表（address.approvals）
struct ApprovalsResponse: Codable {
    let groups: [ApprovalGroup]?
    let pendingCount: Int?

    struct ApprovalGroup: Codable, Identifiable {
        var id: Int { showcaseId }
        let showcaseId: Int
        let title: String
        let items: [ApprovalItem]?
    }

    struct ApprovalItem: Codable, Identifiable {
        let id: Int
        let shareId: Int
        let claimerName: String?
        let kind: String?            // free / proof
        let status: String?          // auto_approved/pending/submitted/approved/rejected/modify/cancelled
        let fee: Int?
        let hasProof: Bool?
        let reason: String?
        let createdAt: String?
        let submittedAt: String?
        let reviewedAt: String?
    }
}

/// 审批详情（address.approvalDetail）
struct ApprovalDetail: Codable {
    let id: Int
    let isOwner: Bool?
    let kind: String?
    let status: String?
    let fee: Int?
    let alipayAccount: String?
    let proofImage: String?
    let reason: String?
    let showcaseTitle: String?
    let showcaseId: Int?
    let claimerName: String?
    let addressFull: String?
    let shareId: Int?
    let shipState: String?
    let trackingNo: String?
    let createdAt: String?
    let submittedAt: String?
    let reviewedAt: String?
    let deadlineAt: Int?
    let remainMs: Int?
}

/// 某领取人的寄件记录（address.userShipments）
struct UserShipmentsResponse: Codable {
    let claimer: Claimer?
    let items: [UserShipItem]?

    struct Claimer: Codable {
        let id: Int
        let name: String?
        let avatar: String?
    }
}

/// 某领取人寄件条目（含橱窗信息）
struct UserShipItem: Codable, Identifiable {
    let id: Int
    let showcaseId: Int
    let showcaseTitle: String?
    let shippingFree: Bool?
    let nickname: String?
    let address: String?
    let phone: String?
    let full: String?
    let trackingNo: String?
    let yundaOrderId: String?
    let ztoOrderId: String?
    let freightActual: String?
    let shippingPaid: Bool?
    let shipState: String?
    let fee: Int?
    let feeLabel: String?
    let cainiaoCpName: String?
    let pickupCode: String?
    let pickupAt: String?
    let shipStatus: String?
    let createdAt: String?
}

/// 快递下单结果
struct ShipOrderResult: Codable {
    let ok: Bool?
    let orderId: String?
    let mailNo: String?
    let freight: String?
    let needProof: Bool?
    let cpName: String?
    let fee: String?
    let pickupCode: String?
    let pickupAt: String?
    let testMode: Bool?
}

struct BindResult: Codable {
    let ok: Bool?
    let loginName: String?
    let nick: String?
}

struct ExpressStatus: Codable {
    let bound: Bool?
    let valid: Bool?
    let loginName: String?
    let nick: String?
    let reason: String?
}

/// 导出 Excel 结果（base64 内容 + 文件名 + 条数）
struct ExportResult: Codable {
    let base64: String
    let filename: String
    let count: Int?
}

/// 删除寄件记录结果
struct DeleteShareResult: Codable {
    let ok: Bool?
    let showcaseDeleted: Bool?
}

/// 审批结果
struct ReviewResult: Codable {
    let ok: Bool?
    let status: String?
}

// MARK: - 管理后台

struct AdminStats: Codable {
    let totalUsers: Int?
    let todayUsers: Int?
    let totalShowcases: Int?
    let todayShowcases: Int?
    let totalPageViews: Int?
    let todayPageViews: Int?
}

struct AdminGrowthTrend: Codable {
    let labels: [String]?
    let newUsers: [Int]?
    let newShowcases: [Int]?
    let heartPool: [Int]?
    let pageViews: [Int]?
}

struct AdminUser: Codable, Identifiable {
    let id: Int
    let name: String?
    let email: String?
    let avatar: String?
    let role: String?
    let superAdmin: Bool?
    let createdAt: String?
}

struct ReportRow: Codable, Identifiable {
    let id: Int
    let targetType: String
    let targetId: Int
    let reason: String
    let status: String
    let assigneeId: Int?
    let opinion: String?
    let opinionBy: Int?
    let createdAt: String?
    let reporterName: String?
    let targetExcerpt: String?
    let targetAuthorName: String?
    let assigneeName: String?
    let opinionByName: String?
    let isSuper: Bool?
}

struct AdminTagRow: Codable, Identifiable {
    let id: Int
    let name: String
    let category: String
    let status: String
    let createdAt: String?
    let createdById: Int?
    let createdByName: String?
    let showcaseCount: Int?
}

// MARK: - 农场利息历史（farm.history）

struct FarmInterestRow: Codable, Identifiable {
    let id: Int
    let userId: Int?
    let weekKey: String?
    let principal: Int?
    let interest: Int?
    let fruitIncome: Int?
    let prodFactor: String?
    let goodsFactor: String?
    let createdAt: String?
}

// MARK: - 我发布的返图（repost.mine）

struct MyRepostsResponse: Codable {
    let items: [MyRepostRow]?

    struct MyRepostRow: Codable, Identifiable {
        let id: Int
        let image: String
        let comment: String?
        let createdAt: String?
        let showcaseId: Int?
        let showcaseTitle: String?
        let showcaseStatus: String?
    }
}

// MARK: - 标签详情（tag.byId）

struct TagDetail: Codable {
    let id: Int
    let name: String
    let category: String?
    let status: String?
    let showcaseCount: Int?
    let weekNew: Int?
}

// MARK: - 卡片搜索（cardPlaza.search）

struct CardSearchResponse: Codable {
    let posts: [CardSearchResult]?
    let codeMatch: CardCodeMatch?
}

struct CardSearchResult: Codable, Identifiable {
    let id: Int
    let title: String?
    let config: CardConfig?
    let viewCount: Int?
    let likeCount: Int?
    let createdAt: String?
    let author: CardSearchAuthor?
    let isMine: Bool?
}

struct CardSearchAuthor: Codable {
    let id: Int
    let name: String?
}

struct CardCodeMatch: Codable {
    let name: String
    let code: String
    let config: CardConfig?
    let ownerName: String?
    let ownerId: Int
}
