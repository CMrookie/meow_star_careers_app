#!/usr/bin/env bash
# 在本机（不是服务器上）验证 TURN 是否真的能中继。
# 用法: ./verify.sh <公网IP或域名> <用户名> <密码>
# 依赖: 本机装了 docker（用 coturn 镜像自带的 turnutils_uclient，免安装）
set -euo pipefail
HOST="${1:?用法: ./verify.sh <公网IP或域名> <用户名> <密码>}"
USER="${2:?缺少用户名}"
PASS="${3:?缺少密码}"
IMG="coturn/coturn:4.6-alpine"

echo "== 1/2 UDP 3478（最常用）=="
docker run --rm "$IMG" turnutils_uclient -u "$USER" -w "$PASS" -p 3478 -n 3 "$HOST" \
  || { echo "❌ UDP 3478 失败：检查安全组是否放行 3478/udp、服务是否在跑"; exit 1; }

echo "== 2/2 TCP 3478（企业网封 UDP 时用 ?transport=tcp）=="
docker run --rm "$IMG" turnutils_uclient -t -u "$USER" -w "$PASS" -p 3478 -n 3 "$HOST" \
  || echo "⚠️ TCP 3478 失败：若你只用 UDP 可忽略；否则放行 3478/tcp"

cat <<'TIP'

判断标准：输出里应出现 relay 地址（形如 <公网IP>:49xxx）与 success。
若只看到 host/srflx、或报 401/438：多半是 user 配置或 external-ip 写错。
本地联调还可直接用 App：设置 → 视频通话中继 → 填入地址与凭据 → 进房间看是否连通。
TIP
