# CineChill Mobile (iOS)

基于 **CineChill 移动端 API 接口文档 v1.0.0.43** 开发的原生 iOS 客户端，采用 **SwiftUI + 兼容式玻璃质感** 设计语言。

## 运行环境

- **Xcode 16** 或更高
- **iOS 17+**（真机或模拟器）
- 一个可访问的 CineChill 服务端（`http://<服务器IP>:5256`）

## 打开与运行

1. 解压后双击 `CineChill.xcodeproj` 用 Xcode 打开。
2. 选择签名 Team（Signing & Capabilities → 自动签名），Bundle ID 默认 `com.cinechill.mobile`，可自行修改。
3. 选择模拟器或真机，⌘R 运行。
4. 首次启动 → 输入服务器地址（如 `192.168.1.10:5256`）→ 用户名/密码登录。

> 工程已在 `Info.plist` 开启 `NSAllowsArbitraryLoads`，以便连接本地 HTTP 服务。

## 玻璃质感实现

| 位置 | 实现 |
|---|---|
| 底部标签栏 | 原生 `TabView` + `.tabItem` / `.tag` |
| 卡片 / 药丸 / 圆形头像 | `GlassCard`、`GlassPill`、`appGlassCircle()`，基于 `Material` 和 shape overlay |
| 按钮 | `AppGlassButtonStyle` / `GlassPrimaryButton` |
| 搜索 | `.searchable` + `.searchScopes` |
| 导航栏 / 工具栏 | 系统导航与工具栏样式 |

## 架构

```
CineChill/
├─ App/            应用入口
├─ Core/
│  ├─ Networking/  APIClient（Cookie 会话）、JSONValue（容错解码）、APIError
│  ├─ Config/      ServerConfig（地址解析）
│  └─ Session/     SessionStore（服务器→登录→主界面 状态机）
├─ Design/         Theme、玻璃质感组件、RemoteImage
├─ Models/         MediaItem、Dashboard/RSS/Task/Notify 领域模型
├─ Services/       各模块接口封装（Auth/Server/Discover/Subscription/Task/Notify）
└─ Features/       Auth / Root / Dashboard / Discover / Subscriptions / Tasks / Notify / Settings
```

**设计要点**：接口文档中绝大多数 GET 未在 OpenAPI 声明返回结构，因此网络层默认解码为 `JSONValue`（动态成员访问 + 容错取值），领域模型再对多种字段命名（TMDB / 豆瓣 / Emby）做best-effort 解析，避免因字段不一致崩溃。

## 已实现模块 ↔ 接口映射（全量覆盖 27 分组 / 305 接口）

底部 5 个标签：**首页 · 发现 · 订阅 · 任务 · 更多**。"更多"页聚合其余全部模块。

| 模块 | 入口 | 主要接口 |
|---|---|---|
| **登录 / 服务器** | 启动流程 | `login`/`logout`/`user_info`/`change_auth`/`server/restart` |
| **首页仪表盘** | 首页 | `dashboard_stats`/`dashboard_device_metrics`/`today_picks` |
| **发现** | 发现 | tmdb/douban 各热门榜、`search`、`detail/{id}`、海报代理 |
| **订阅 / RSS** | 订阅 | `subscriptions/rss_sources` CRUD + sync |
| **任务** | 任务 | `tasks`/`run_saved_task`/`stop_task`/`toggle_task`/`system_logs` |
| **设置 / 通知** | 更多›账户 | 账号密码、通知（Telegram/微信）渠道与测试 |
| **Emby 用户 / 任务** | 更多›媒体库 | `emby/users` CRUD、`emby_tasks` 运行/停止 |
| **媒体整理 / 整理历史 / STRM** | 更多›媒体库 | `media_organize/*`、`organize-history/*`、`strm/*` |
| **MoviePilot / RSS 原生 / 资源转发 / 手动转移 / 海报套件** | 更多›资源与转发 | `moviepilot/*`、`rss/*`、`forward/*`、`transfer/*`、套件模板字体 |
| **115 上传 / 清理 / 302 配置** | 更多›115 网盘 | `drive115_upload/*`、`drive115_cleanup/*`、`config_302/*` |
| **Docker / 系统健康 / AI 剧集识别 / 飞牛签到 / Webhook / 检查更新** | 更多›系统与运维 | `docker/*`、`system_health/*`、`ai-episode-resolver/*`、`fnos_sign/*`、`webhook/*`、`upgrade/*` |

> 每个分组都有对应的 `Service`（`Services/`）封装其接口，UI 覆盖各模块的核心读操作与主要动作（增删改 / 运行 / 停止 / 测试等）。少数极少用的高级参数接口已在 Service 层就绪，可按需在视图中补充按钮。

## 网络层用法示例

```swift
let json = try await APIClient.shared.request(.get, "/api/some/endpoint")
let name = json["items"][0].firstString("name")
// 构造请求体：
try await APIClient.shared.request(.post, "/api/x", body: JSONValue.obj(["id": id, "enabled": true]))
```
