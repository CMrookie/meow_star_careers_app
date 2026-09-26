# meow_star_careers_app · 求职招聘移动端（Flutter）

对接 [meow-star-careers](https://github.com/CMrookie/meow-star-careers) 招聘求职系统服务端（Rust + actix-web + PostgreSQL）的全功能移动客户端：
**中文界面、求职者 / 招聘者双角色**。

> **相关仓库**：[服务端](https://github.com/CMrookie/meow-star-careers) ｜ [后台管理系统](https://github.com/CMrookie/meow-star-careers-admin)　（本地开发时后端仓库目录为 `../just-a-work`，默认 `http://127.0.0.1:8080`，`/swagger-ui/` 有交互式 API 文档）
> UI 遵循 **Material 3**（useMaterial3 + ColorScheme.fromSeed 派生语义色），底部导航用 NavigationBar。

### 视觉规范（`lib/ui/theme.dart` 统一提供设计令牌）

- **职位卡片**：`JobCardSurface`（`lib/ui/paged_list_view.dart`）是唯一的卡面实现，
  列表卡片、打开动画的飞行层、详情页头部**共用它**，所以打开动画首尾严丝合缝；
  右上角是一个**凹口**（`SmoothNotchClipper`，`lib/ui/widgets.dart`）：顶边平直 → 外凸圆角
  （`notchFillet`，与右缘侧同半径）拐下 → 一段竖直「墙」（位于胶囊左缘外 `notchGap` 处，
  距右缘 92px）→ 到**胶囊纵向中线**（y = 胶囊中心）才开始**贴合胶囊左侧**：转成
  **内凹弧**（圆心 = 胶囊左端圆帽圆心、半径 = 圆帽半径 + `notchGap`）绕过圆帽下半圈 →
  水平底线（`notchSlotDepth` = 胶囊底 + `notchGap`）→ 右缘侧外凸圆角收进卡面右缘。
  因为凹弧与胶囊同心等距，胶囊左侧与下方的留白完全一致（现各 8px），胶囊有充足容身位置；
  顶边止于距右缘 76px（= 墙 92px − 圆角 16px）；
  顶边在胶囊左端上方只留一条 8px 压条（= `notchPillTop` − `notchGap`）；
  卡面色按用工类型（全职蓝 / 兼职橙 / 项目紫 / 实习绿）+ 投诉降饱和生成
  （`jobAccentColor`），卡面与「查看」胶囊**各自有独立阴影**（卡面 = 同色投影，胶囊 = 深色近距）；
- **打开动画**：`lib/ui/jobs/job_open_transition.dart` 用 `PageRouteBuilder` 做「容器变换」——
  飞行层就是同一个 `JobCardSurface`，起点矩形取卡面实际位置、终点 = 详情页头部
  `(0, 0, 屏宽, 卡面高 + 状态栏高)`；`fill` 参数把槽口线性填平、胶囊同步缩小淡出，
  卡面放大到屏幕宽度并移动到页面顶端；详情页头部用同一个卡面（`notchFill: 1`）+ 相同的
  `topInset`，因此落点像素级重合，**打开无跳动**（`test/job_card_test.dart` 有专门回归用例）；
  详情页由动画带入 `initialJob` 先渲染再后台刷新，避免 loading 闪动；
- **容器**：白卡统一走- **容器**：白卡统一走 `AppCard` / `SectionCard` / `ListGroup`（24 圆角 + `softShadow` 柔和投影）；
- **标签**：`TagChip`（同色淡底胶囊，可带图标）、`GlassPill`（彩色卡面上的半透明白胶囊）；
- **控件**：输入框 16 圆角浅灰填充、按钮全圆角胶囊、对话框/弹层 24~28 圆角；
- 令牌常量：`radiusCard / radiusControl / radiusInner / radiusPill`、`softShadow`、`tintedShadow()`。

## 功能

- **账号**：手机号（11 位）+ 密码注册与登录（无需短信验证码），支持求职者 / 招聘者两种角色
  （招聘者注册时填写企业信息）、自动登录恢复、退出；
- **求职者**：职位搜索（关键词 / 城市 / 工作性质 / 薪资区间）与分页浏览、职位详情、
  收藏 / 取消收藏、投递（选简历 + 求职信）、我的投递（状态跟踪、撤回）、简历管理（公开/私密）；
- **招聘者**：发布 / 编辑 / 上下架 / 删除职位、投递收件箱（查看候选人联系方式、推进
  `待处理 → 已查看 → 面试中 → 已录用/不合适`）、公开简历检索与详情、我的企业；
- **私聊**：会话列表（未读数）、一对一聊天，WebSocket 实时收发（断线自动重连，
  离线自动回退 REST）；两端各自聊天气泡与更早历史加载；
- **视频面试**：招聘者对投递发起「即时 / 预约」线上面试，双方在投递详情 / 视频面试列表
  进入房间（flutter_webrtc P2P + STUN，信令与状态事件经现有 WS 转发；结束/取消同步对端）；
- **演示模式（开发）**：登录页「求职者演示账号 / 招聘者演示账号」一键进入，
  全部数据来自客户端内置内存仓库（不依赖后端）：6 个职位、简历、投递与状态、会话/消息
  均可真实交互（发消息会有演示账号自动回复）。

## 运行

依赖：Flutter SDK（本工程要求 Dart ≥3.13.2，推荐使用项目生成时的 3.47.x 工具链；
后端见 just-a-work 的启动说明）。

```bash
flutter pub get
# iOS 模拟器 / Android 模拟器 / macOS 桌面 任选
flutter run
```

启动后在 **登录页右上角「服务器」图标**（或 我的 → 设置 → 服务器地址）可修改后端地址，
默认 `http://127.0.0.1:8080`；模拟器访问宿主机注意：Android 模拟器用 `http://10.0.2.2:8080`。

后端未启动也能进入登录/注册界面；`测试连接` 按钮会请求 `{base}/healthz`。

平台备注（开发期已放开明文 http）：
- iOS：`Info.plist` 已设 `NSAllowsArbitraryLoads`；Android：已加 `INTERNET` + `usesCleartextTraffic`；
  macOS：已加 `network.client` 沙箱权限；
- Web 端如使用，需在 just-a-work 的 `.env` 配置
  `CORS_ALLOWED_ORIGINS=http://localhost:8080,...`（且 Web 端设置不持久化）。

## 验证

```bash
flutter analyze
flutter test        # 模型解析 / 请求构造(含 Bearer 与查询参数) / 登录页冒烟
```## 结构

```
lib/
  core/      配置(可换 base URL)、存储抽象(IO 文件/内存)、格式化、统一异常
  models/    与后端 JSON(camelCase) 对齐的数据模型
  services/  ApiClient、职位/简历/投递/企业/会话、WebSocket 实时通道
  state/     SessionController(登录态) + AppScope(InheritedNotifier)
  ui/        登录注册、双角色主框架、职位/收藏/投递/收件箱/简历/简历库/会话/聊天/我的/设置
test/        模型、服务(经 MockClient 校验请求体/鉴权头/参数)、界面冒烟
```

## 双端视频联调（开发）

1. 后端监听局域网：`just-a-work/.env` 设 `SERVER_HOST=0.0.0.0` 后重启，确认 `http://<Mac局域网IP>:8080/healthz` 可达；
2. 两台设备登录后把「服务器地址」改为 `http://<Mac局域网IP>:8080`；
3. 先在单台设备「我的 → 设置 → 摄像头 / 麦克风自检」验证本机采集与授权（再进双端，避免权限问题干扰联调）；
4. 招聘者对投递发起「即时面试」→ 求职者进入房间 → 互通后测试静音/关画面/切换摄像头/挂断结束。

- 同网段走内置 Google STUN 即可；跨公网/对称 NAT 需自建 TURN 并配置
  `lib/ui/interviews/interview_room_page.dart` 的 `iceServers`。
- 服务端 WS 联调探针见 `tool/ws_signal_probe.dart`、`tool/ws_state_probe.dart`。

## 约定与限制

- 职位薪资单位为「元/月」；展示为 `15K-25K` 区间。
- 投递列表接口按角色返回：求职者看到自己的，招聘者看到本企业的（同一 `GET /applications`）。
- 聊天消息历史按 `limit/before` 游标倒序分页；实时消息以「消息 id」在 UI 层去重。
- 应用名「职聘」，Android label / iOS DisplayName 已同步修改。

---

## 相关仓库

这是三端招聘平台的其中一端，另外两端：

- **服务端（Rust + actix-web + PostgreSQL）**：[GitHub](https://github.com/CMrookie/meow-star-careers) ｜ [Gitee](https://gitee.com/rookie_c/meow-star-careers)
- **后台管理系统（Vue3 + TypeScript）**：[GitHub](https://github.com/CMrookie/meow-star-careers-admin) ｜ [Gitee](https://gitee.com/rookie_c/meow-star-careers-admin)

> 三端共用一套接口契约与角色模型（seeker / recruiter / reviewer / admin），由 OpenAPI 定义。
