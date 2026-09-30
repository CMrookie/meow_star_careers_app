#!/usr/bin/env python3
"""TURN/STUN 连通性探针（开发自检工具，无第三方依赖）。

验证两件事：
1. STUN：向服务器发 Binding Request，能否拿回公网映射地址（srflx）；
2. TURN：用长期凭据（username/realm/password）发 Allocate Request，
   能否分配到 relay 地址 —— 这才代表「对称 NAT 下能靠中继打通」。

地址与凭据与 App 内保持一致（lib/core/ice_config.dart 的 publicTestTurnUrls /
defaultStunServers），所以这里的结论直接适用于 App。

用法:
  python3 tool/turn_probe.py stun                 # 只测 STUN
  python3 tool/turn_probe.py turn                 # 测 TURN（默认公开测试服）
  python3 tool/turn_probe.py turn <host> <port> <user> <pass> [udp|tcp]
"""
import hashlib
import hmac
import os
import socket
import struct
import sys

MAGIC = 0x2112A442
BIND_REQUEST, BIND_SUCCESS = 0x0001, 0x0101
ALLOCATE_REQUEST, ALLOCATE_SUCCESS, ALLOCATE_ERROR = 0x0003, 0x0103, 0x0113
ATTR_MAPPED, ATTR_USERNAME, ATTR_MESSAGE_INTEGRITY = 0x0001, 0x0006, 0x0008
ATTR_ERROR_CODE, ATTR_REALM, ATTR_NONCE = 0x0009, 0x0014, 0x0015
ATTR_XOR_RELAYED, ATTR_REQ_TRANSPORT = 0x0016, 0x0019
ATTR_XOR_MAPPED = 0x0020

# 与 lib/core/ice_config.dart 保持一致
STUN_SERVERS = [("stun.miwifi.com", 3478), ("stun.chat.bilibili.com", 3478), ("stun.hitv.com", 3478)]
PUBLIC_TURN = [
    ("openrelay.metered.ca", 80, "udp"),
    ("openrelay.metered.ca", 443, "udp"),
    ("openrelay.metered.ca", 443, "tcp"),
]
PUBLIC_USER, PUBLIC_PASS = "openrelayproject", "openrelayproject"


def _txid():
    return os.urandom(12)


def _attr(t, v):
    pad = (4 - len(v) % 4) % 4
    return struct.pack(">HH", t, len(v)) + v + b"\x00" * pad


def _msg(mtype, txid, attrs=b"", length=None):
    body = attrs
    return struct.pack(">HHI", mtype, len(body) if length is None else length, MAGIC) + txid + body


def _parse(data):
    mtype, mlen, _ = struct.unpack(">HHI", data[:8])
    out, i = {}, 20
    while i + 4 <= 20 + mlen and i + 4 <= len(data):
        t, l = struct.unpack(">HH", data[i:i + 4])
        out.setdefault(t, []).append(data[i + 4:i + 4 + l])
        i += 4 + l + ((4 - l % 4) % 4)
    return mtype, out


def _addr(value):
    if len(value) < 8:
        return None
    fam = value[1]
    port = struct.unpack(">H", value[2:4])[0] ^ (MAGIC >> 16)
    raw = value[4:8] if fam == 0x01 else value[4:20]
    key = struct.pack(">I", MAGIC) if fam == 0x01 else struct.pack(">I", MAGIC) + _tx_global
    ip = bytes(a ^ b for a, b in zip(raw, key))
    return f"{socket.inet_ntoa(ip)}:{port}"


_tx_global = b""


def _send(host, port, payload, proto, timeout=4.0):
    fam = socket.AF_INET
    if proto == "tcp":
        # STUN over TCP：每条消息前有 2 字节长度前缀（RFC 5389 §7.2.2）
        s = socket.socket(fam, socket.SOCK_STREAM)
        s.settimeout(timeout)
        s.connect((host, port))
        s.sendall(struct.pack(">H", len(payload)) + payload)
        head = b""
        while len(head) < 2:
            chunk = s.recv(2 - len(head))
            if not chunk:
                raise ConnectionError("连接被关闭")
            head += chunk
        need = struct.unpack(">H", head)[0]
        body = b""
        while len(body) < need:
            chunk = s.recv(need - len(body))
            if not chunk:
                raise ConnectionError("消息不完整")
            body += chunk
        return body
    s = socket.socket(fam, socket.SOCK_DGRAM)
    s.settimeout(timeout)
    s.sendto(payload, (host, port))
    return s.recvfrom(2048)[0]


def stun_test(host, port, proto="udp", timeout=4.0):
    global _tx_global
    tx = _txid()
    _tx_global = tx
    try:
        data = _send(host, port, _msg(BIND_REQUEST, tx), proto, timeout)
        mtype, attrs = _parse(data)
        if mtype != BIND_SUCCESS:
            return False, f"非 Binding 响应（0x{mtype:04x}）"
        if ATTR_XOR_MAPPED in attrs:
            return True, f"映射地址 {_addr(attrs[ATTR_XOR_MAPPED][0])}"
        if ATTR_MAPPED in attrs:
            v = attrs[ATTR_MAPPED][0]
            return True, f"映射地址 {socket.inet_ntoa(v[4:8])}:{struct.unpack('>H', v[2:4])[0]}"
        return True, "有响应（未见映射属性）"
    except Exception as e:  # noqa: BLE001
        return False, f"{type(e).__name__}: {e}"


def turn_alloc(host, port, user, pwd, proto="udp", timeout=5.0):
    """发 Allocate：先拿 401 的 realm/nonce，再带凭据与 MESSAGE-INTEGRITY 重发。"""
    global _tx_global
    req_transport = _attr(ATTR_REQ_TRANSPORT, struct.pack(">BBBB", 17, 0, 0, 0))
    tx = _txid()
    _tx_global = tx
    try:
        data = _send(host, port, _msg(ALLOCATE_REQUEST, tx, req_transport), proto, timeout)
        mtype, attrs = _parse(data)
        if mtype == ALLOCATE_SUCCESS:
            relay = attrs.get(ATTR_XOR_RELAYED, [None])[0]
            return True, f"直接分配成功，relay={_addr(relay) if relay else '?'}"
        if mtype != ALLOCATE_ERROR or ATTR_REALM not in attrs or ATTR_NONCE not in attrs:
            code = ""
            if ATTR_ERROR_CODE in attrs and len(attrs[ATTR_ERROR_CODE][0]) >= 4:
                v = attrs[ATTR_ERROR_CODE][0]
                code = f" code={v[2]}{v[3]:02d}"
            return False, f"未拿到 realm/nonce（0x{mtype:04x}{code}）"
        realm = attrs[ATTR_REALM][0]
        nonce = attrs[ATTR_NONCE][0]
        # 长期凭据：key = MD5(user:realm:password)
        key = hashlib.md5(user.encode() + b":" + realm + b":" + pwd.encode()).digest()
        attrs2 = (req_transport
                  + _attr(ATTR_USERNAME, user.encode())
                  + _attr(ATTR_REALM, realm)
                  + _attr(ATTR_NONCE, nonce))
        # MESSAGE-INTEGRITY：长度字段要包含该属性本身
        head = struct.pack(">HHI", ALLOCATE_REQUEST, len(attrs2) + 24, MAGIC) + _txid()
        _tx_global = head[8:20]
        digest = hmac.new(key, head + attrs2, hashlib.sha1).digest()
        payload = head + attrs2 + _attr(ATTR_MESSAGE_INTEGRITY, digest)
        data = _send(host, port, payload, proto, timeout)
        mtype, attrs = _parse(data)
        if mtype == ALLOCATE_SUCCESS:
            relay = attrs.get(ATTR_XOR_RELAYED, [None])[0]
            return True, f"relay={_addr(relay) if relay else '（未见 XOR-RELAYED-ADDRESS）'}"
        detail = ""
        if ATTR_ERROR_CODE in attrs and len(attrs[ATTR_ERROR_CODE][0]) >= 4:
            v = attrs[ATTR_ERROR_CODE][0]
            detail = f" code={v[2]}{v[3]:02d}"
        return False, f"Allocate 被拒（0x{mtype:04x}{detail}）"
    except Exception as e:  # noqa: BLE001
        return False, f"{type(e).__name__}: {e}"


def main():
    mode = sys.argv[1] if len(sys.argv) > 1 else "all"
    if mode == "stun" or mode == "all":
        print("== STUN Binding（验证公共 STUN 可用性）==")
        for h, p in STUN_SERVERS:
            ok, info = stun_test(h, p)
            print(f"  {'✅' if ok else '❌'} stun:{h}:{p}  {info}")
    if mode in ("turn", "all"):
        args = sys.argv[2:]
        targets = ([(args[0], int(args[1]), args[4] if len(args) > 4 else "udp", args[2], args[3])]
                   if len(args) >= 4 else [(h, p, proto, PUBLIC_USER, PUBLIC_PASS) for h, p, proto in PUBLIC_TURN])
        print("== TURN Allocate（拿到 relay 才算真正可用）==")
        for h, p, proto, user, pwd in targets:
            ok, info = turn_alloc(h, p, user, pwd, proto)
            print(f"  {'✅' if ok else '❌'} turn:{h}:{p}?transport={proto}  {info}")


if __name__ == "__main__":
    main()
