# 码上领 iOS

「码上领」（mashangling.kimi.site）的官方 iOS 客户端，与网页版共用同一后端与数据库。

## 功能

- 首页：橱窗信息流（推荐 / 最新 / 猜你喜欢、日周月总榜、平台筛选）、全站积分播报、快捷入口模块
- 广场：卡片广场（热门 / 最新、卡片详情、点赞 / 想要 / 收藏 / 评论 / 转发、作者热度榜）
- 发布：发布 / 编辑橱窗（封面、标签、限量、申请审批 / 即领 / 积分解锁、限时、包邮等）
- 消息：站内信通知（按类型筛选、一键已读）+ 私信会话（回复、礼物、附件快照、好感度）
- 我的：个人主页（积分等级、农场、卡片作品、好友徽章、粉丝 / 关注 / 好友）
- 橱窗详情：点赞、我领到了、我想要、没有了、清单、领取申请 / 积分解锁、返图、
  发送地址、礼物分享、生成分享卡片、举报、无料码查看
- 心选橱窗：积分看涨 / 买空、模拟大盘 K 线、买股王周榜、我的支持
- 农场：母鸡 / 鸡蛋 / 果树、利息利率、买蛋买树、对外展示开关
- 积分：签到、任务中心、头衔佩戴、达人榜、积分流水
- 快递：快递后台（寄件看板、填单号、邮费审批、导出 Excel / 菜鸟模板）、我的快递（补邮凭证）
- 个性化：卡片主题设计、卡片码导入、自定义母鸡、对外展示开关
- 设置：资料、头像、界面主题（跟随账号）、通知邮箱、私信开关、收货 / 寄件地址、绑定邮箱
- 管理后台：站点统计、增长趋势、举报处理、标签管理、权限管理

## 构建

工程文件不入库，由 [XcodeGen](https://github.com/yonaskolb/XcodeGen) 生成：

```bash
brew install xcodegen
xcodegen generate
open Mashangling.xcodeproj
```

要求：Xcode 15+，iOS 16.0+。CI（GitHub Actions · macos-15）会在每次 push 时自动编译验证，
并打出未签名的 `Mashangling.ipa` 发布到仓库 [Releases](../../releases)（tag 形如 `build-N`）。

## 安装到 iPhone（自签 ipa）

CI 产物是**未签名** ipa，直接装不上真机，需要先用你的 Apple ID 重签名。任选一种：

### 方法一：Sideloadly（Windows / macOS，最简单）

1. 电脑安装 [Sideloadly](https://sideloadly.io) 和 iTunes（非 Microsoft Store 版）。
2. iPhone 用数据线连电脑，解锁并点「信任此电脑」。
3. 把 Releases 里下载的 `Mashangling.ipa` 拖进 Sideloadly。
4. 填入你的 Apple ID 邮箱，点 Start；按提示输入密码（开了双重认证会弹验证码）。
5. 装完后在 iPhone 上进入
   「设置 → 通用 → VPN与设备管理 → 你的 Apple ID → 信任」。
6. 免费证书 7 天到期，到期后重新执行第 3～5 步即可（数据保留）。

### 方法二：AltStore / SideStore（装好后可在手机上续签）

1. 按 [AltStore 官网](https://altstore.io) 指引在电脑装 AltServer，给手机装 AltStore。
2. 把 `Mashangling.ipa` 传到手机（iCloud 云盘 / AirDrop / 微信文件均可）。
3. 在 AltStore 的「My Apps」页点左上角 `+`，选择这个 ipa 安装。
4. 免费证书同样是 7 天，但只要 AltStore 与电脑在同一 Wi-Fi，它会自动续签。

### 方法三：自己有 Apple 开发者账号（付费 $99/年）

直接在本仓库执行 `xcodegen generate` 后用 Xcode 打开，
在 Signing & Capabilities 里选自己的 Team，连真机 Run 即可。
付费证书签名一次管 1 年，且无需 7 天续签。

### 常见问题

- **「不受信任的开发者」**：去「设置 → 通用 → VPN与设备管理」里信任你的证书。
- **Sideloadly 报「maximum number of apps」**：免费 Apple ID 同时只能侧载 3 个 App，
  先删掉一个不用的，或等 7 天名额释放。
- **App 打开闪退/无法验证**：证书过期了，重新签名安装即可。

## 技术栈

SwiftUI（iOS 16+），tRPC over HTTPS（`/api/trpc/*`，Cookie 会话），
无第三方依赖。
