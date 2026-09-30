# 自建 TURN（coturn）—— 解决「对称 NAT 下 P2P 打不通」

App 里视频面试走 WebRTC P2P。**同网段、多数家用宽带**靠 STUN 就能直连；
但**双方都在对称型 NAT 后面**（企业网、部分 4G、严格防火墙）时，P2P 必然失败，
必须经 **TURN 中继**转发媒体流。这份文档是「把 TURN 服务真正跑起来」的可执行步骤。

> 只想先验证功能、不想买服务器：App 设置页有「**填入公开测试服**」按钮（Open Relay Project），
> 但那是**第三方共享免费服务**，稳定性无保证、媒体流经第三方中转，**不要用于正式环境**。

---

## 0. 先算清成本（很重要，中继会消耗服务器带宽）

| 项 | 说明 |
|---|---|
| 机器 | 1 核 1G 足够（coturn 本身很轻），关键是**公网带宽** |
| 带宽 | 每路中继通话约 **1–2 Mbps**（720p）上下行各算一次；2 人同时用 ≈ 4–8 Mbps |
| 计费 | 按固定带宽买比按流量划算；阿里云按流量计费时中继跑满会明显烧钱 |
| 结论 | 小规模自用：2–5 Mbps 固定带宽即可；用 `total-quota` / `user-quota` 限制被滥用 |

---

## 1. 阿里云 ECS 上部署（Docker，3 步）

### 1) 安全组放行端口

| 协议 | 端口 | 用途 |
|---|---|---|
| UDP | **3478** | TURN/STUN 主端口 |
| TCP | **3478** | UDP 被封时的兜底（`?transport=tcp`） |
| UDP | **49152-65535** | **中继端口段**（漏了这条会出现「能收集候选但连不通」） |
| TCP | 5349 | 仅启用 TLS 时需要 |

### 2) 起服务

```bash
# 把 deploy/turn 传到服务器（或直接在服务器上 clone 仓库）
cd deploy/turn

# ⚠️ 改三处：realm / user / external-ip
vi turnserver.conf

docker compose up -d
docker compose logs -f      # 看到 "Relay address" / "listener" 日志即正常
```

> 没装 Docker？裸机也很快：
> `apt install coturn` → 把 `turnserver.conf` 放到 `/etc/turnserver.conf` →
> 编辑 `/etc/default/coturn` 去掉 `TURNSERVER_ENABLED` 前的 `#` → `systemctl enable --now coturn`

### 3) 填进 App

**我的 → 设置 → 视频通话中继（TURN）**：

```
TURN 地址：turn:<公网IP>:3478?transport=udp,turn:<公网IP>:3478?transport=tcp
用户名：   meowapp            # 与 turnserver.conf 的 user= 前段一致
密码：     你在配置里设的强密码
```

改完**下次进房间即生效，不用重新打包**。

---

## 2. 验证（从你的笔记本跑，不是服务器）

```bash
./verify.sh <公网IP> meowapp <密码>
```

预期输出里出现 **relay 地址**（形如 `<公网IP>:49xxx`）和 `success`。

也可以用仓库里的探针（无需安装任何东西，纯 Python 标准库）：

```bash
python3 tool/turn_probe.py turn <公网IP> 3478 meowapp <密码> udp
python3 tool/turn_probe.py turn <公网IP> 3478 meowapp <密码> tcp   # 企业网封 UDP 时
```

输出里出现 `✅ relay=<公网IP>:49xxx` 才算成功；`❌ Allocate 被拒（code=401）` = 账号密码不匹配，
`code=400` = 这个地址根本不是 TURN（只有 STUN）服务。

也可用 App 验证：配好 TURN 后进房间，日志里应出现 `local candidate: relay`
（房间日志会打印候选类型统计），能互通即说明中继生效。

浏览器方式（需要能访问 github.io）：
<https://webrtc.github.io/samples/src/content/peerconnection/trickle-ice/>

---

## 3. 排错清单（按出现频率排序）

| 现象 | 原因 | 处理 |
|---|---|---|
| 配了 TURN 仍连不通 | `external-ip` 写成了内网地址 | 阿里云 ECS 网卡是内网 IP，必须写 `external-ip=<公网IP>`；弹性公网 IP/NAT 场景写 `external-ip=<公网IP>/<内网IP>` |
| 只能看到 host/srflx，没有 relay | 安全组/防火墙没放行 3478 | 放行 **UDP 3478**；`docker compose logs` 看到 binding 才算起来 |
| 能收集到 relay，但通话连不上 | 没放行中继端口段 | 放行 **UDP 49152-65535**（或把 `min-port/max-port` 收窄到一段再放行） |
| 企业网/机场网络失败 | UDP 被运营商封 | 用 `?transport=tcp`（安全组放行 3478/tcp；有域名+证书就上 `turns:<域名>:5349`） |
| 401 Unauthorized | 用户名/密码不匹配 | 客户端填的 `用户名/密码` 必须与 `user=用户名:密码` 完全一致；改完 `docker compose restart` |
| 用一会儿就被刷爆带宽 | 被陌生人当免费代理 | 保留 `denied-peer-ip` 内网段限制，并把 `total-quota`/`user-quota` 调小、换强密码 |

---

## 4. 安全与进阶

- **静态凭据足够自用**：`lt-cred-mech` + `user=` 一组账号密码即可；
  进阶可换 `use-auth-secret` + 后端签发**临时凭据**（REST API 方式，凭据带过期时间），
  这样即使凭据泄漏也只影响很短时间——需要后端配合，当前项目未实现。
- **不要直接暴露到公网当公共 STUN/TURN**：本配置已禁 `no-loopback-peers`、禁内网网段中继、
  带配额；但仍建议只给自己 App 用（强密码 + 定期更换）。
- **TLS**：有域名与证书时打开 `cert/pkey` 与 5349，客户端用 `turns:`，可穿过更严格的网络策略。
