import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

import '../../core/app_config.dart';
import '../../models/models.dart';
import '../../services/realtime_chat.dart';
import '../../core/ice_config.dart';
import '../../state/session.dart';
import '../widgets.dart';

/// 视频面试房间：WebRTC P2P + 后端 WS 信令转发。
/// 角色约定：招聘者（interviewer）为 offerer；任一参与者进入后广播 joined，
/// offerer 见到对方 joined 后发起 offer；另一方收到 offer 回 answer；ICE 双向互发。
class InterviewRoomPage extends StatefulWidget {
  final String interviewId;
  final InterviewView initial;
  const InterviewRoomPage({super.key, required this.interviewId, required this.initial});

  @override
  State<InterviewRoomPage> createState() => _InterviewRoomPageState();
}

class _InterviewRoomPageState extends State<InterviewRoomPage> {
  final _localRenderer = RTCVideoRenderer();
  final _remoteRenderer = RTCVideoRenderer();
  StreamSubscription<RealtimeEvent>? _sub;

  RTCPeerConnection? _pc;
  MediaStream? _localStream;
  late InterviewView _view;
  bool _micOn = true;
  bool _videoOn = true;
  bool _peerPresent = false;
  bool _offerSent = false;
  bool _answerReceived = false;
  bool _answerSent = false;
  bool _remoteSet = false;
  final List<Map<String, dynamic>> _pendingIce = [];
  DateTime? _lastOfferAt;

  bool _busy = true;
  String? _fatal;

  SessionController get _session => AppScope.read(context);

  bool get _isHost => _session.user?.id == _view.interviewerId;

  @override
  void initState() {
    super.initState();
    _view = widget.initial;
    _localRenderer.initialize();
    _remoteRenderer.initialize();
    _sub = _session.realtime.stream.listen(_onEvent);
    _boot();
  }

  @override
  void dispose() {
    _sub?.cancel();
    _localRenderer.dispose();
    _remoteRenderer.dispose();
    _localStream?.getTracks().forEach((t) => t.stop());
    _localStream?.dispose();
    _pc?.close();
    _pc?.dispose();
    super.dispose();
  }

  Future<void> _boot() async {
    try {
      // 刷新最新状态；未到预约时间则不能进入
      final fresh = await _session.api.getInterview(widget.interviewId, _session.token!);
      if (!mounted) return;
      _view = fresh;
      if (!_view.canJoin && _view.status != 'in_progress') {
        setState(() => _fatal = '未到预约时间或面试不可进入');
        return;
      }
      debugPrint('[room] $widget.interviewId opened status=${_view.status} canJoin=${_view.canJoin}');
      if (_view.status == 'invited') {
        _view = await _session.api.startInterview(widget.interviewId, _session.token!);
        if (!mounted) return;
        setState(() {});
      }
      // 媒体超时/失败不阻塞，但先尝试取得本地流再建连接、广播，
      // 保证轨道先于 offer 加入（媒体 6 秒内未就绪则无本地画面继续加入）。
      await _startLocalMedia();
      debugPrint('[room] media step done, local=${_localStream != null}');
      await _ensurePeer();
      debugPrint('[room] peer created');
      if (mounted) setState(() => _busy = false);
      _schedulePresence();
      debugPrint('[room] presence scheduled');
    } catch (e) {
      debugPrint('[room] BOOT ERROR $e');
      if (!mounted) return;
      setState(() => _fatal = friendlyError(e));
    }
  }

  /// 尝试本地媒体：授权或采集失败/6 秒无响应时给出提示并继续（无本地媒体仍可加入房间）。
  Future<void> _startLocalMedia() async {
    try {
      final stream = await navigator.mediaDevices
          .getUserMedia({
            'audio': true,
            'video': {'facingMode': 'user', 'width': 320, 'height': 240, 'frameRate': 15},
          })
          .timeout(const Duration(seconds: 6));
      if (!mounted) return;
      _localStream = stream;
      _localRenderer.srcObject = stream;
      // 若连接已建立，把新轨道补上（后续媒体请求成功时生效）
      if (_pc != null) {
        for (final track in stream.getTracks()) {
          try {
            await _pc!.addTrack(track, stream);
          } catch (_) {}
        }
      }
      if (mounted) setState(() {});
    } catch (e) {
      debugPrint('[room] local media unavailable: $e');
      if (mounted) showToast(context, '本地音视频不可用（可仅收对方画面）：$e', error: true);
    }
  }

  Future<RTCPeerConnection> _ensurePeer() async {
    var pc = _pc;
    if (pc != null) return pc;
    // 大陆可直连的公共 STUN（原 Google STUN 墙内不可达）；如配置了自建 TURN 会自动带上
    final cfg = AppScope.read(context).config;
    pc = await createPeerConnection({
      'iceServers': buildIceServers(
        turnUrl: cfg.turnUrl,
        turnUser: cfg.turnUser,
        turnCred: cfg.turnCred,
      ),
    });
    _pc = pc;

    pc.onIceCandidate = (RTCIceCandidate candidate) {
      _session.realtime.sendSignal(widget.interviewId, {
        'kind': 'ice',
        'candidate': candidate.candidate,
        'sdpMid': candidate.sdpMid,
        'sdpMLineIndex': candidate.sdpMLineIndex,
      });
    };
    pc.onTrack = (RTCTrackEvent event) {
      if (event.streams.isNotEmpty) {
        _remoteRenderer.srcObject = event.streams.first;
      }
      if (mounted) setState(() => _peerPresent = true);
    };
    pc.onConnectionState = (state) {
      if (!mounted) return;
      if (state == RTCPeerConnectionState.RTCPeerConnectionStateDisconnected ||
          state == RTCPeerConnectionState.RTCPeerConnectionStateFailed) {
        showToast(context, '连接不稳定，请检查网络', error: true);
      }
    };

    final stream = _localStream;
    if (stream != null) {
      for (final track in stream.getTracks()) {
        await pc.addTrack(track, stream);
      }
    }
    return pc;
  }

  /// 持续广播“我在房间”，直到 SDP 协商开始（host 发出 offer / guest 发出 answer）。
  /// 不能以“见过对方 joined”为停止条件——否则先见到对方的一侧会静默，形成死锁。
  void _schedulePresence() {
    Future<void>.delayed(const Duration(milliseconds: 600), () {
      if (!mounted) return;
      final done = _isHost ? _answerReceived : _answerSent;
      if (done) return;
      _session.realtime.sendSignal(widget.interviewId, {'kind': 'joined'});
      _schedulePresence();
    });
  }

  void _onEvent(RealtimeEvent event) {
    if (!event.isInterviewSignal) {
      // 对方结束/取消面试 -> 通知本地
      if (event.isInterviewUpdated &&
          event.interview != null &&
          event.interview!.id == widget.interviewId) {
        _applyRemoteState(event.interview!);
      }
      return;
    }
    if (event.interviewId != widget.interviewId) return;
    final payload = event.payload ?? const {};
    final kind = payload['kind'] as String?;
    if (!mounted) return;
    debugPrint('[room] got ${event.type} interview=${event.interviewId} from=${event.fromId} kind=$kind');
    switch (kind) {
      case 'joined':
        if (!_peerPresent) setState(() => _peerPresent = true);
        if (_isHost && !_answerReceived) {
          final last = _lastOfferAt;
          final ok = last == null || DateTime.now().difference(last).inMilliseconds > 2000;
          if (ok && !_offerSent) _sendOffer();
        }
        break;
      case 'offer':
        _handleOffer(payload);
        break;
      case 'answer':
        _handleAnswer(payload);
        break;
      case 'ice':
        _addIce(payload);
        break;
    }
  }

  Future<void> _sendOffer() async {
    _offerSent = true;
    _lastOfferAt = DateTime.now();
    try {
      final pc = await _ensurePeer();
      final offer = await pc.createOffer();
      await pc.setLocalDescription(offer);
      final ok = _session.realtime.sendSignal(widget.interviewId, {
        'kind': 'offer',
        'sdp': offer.sdp,
      });
      debugPrint('[room] offer sent ok=$ok');
    } catch (e) {
      debugPrint('[room] send offer error $e');
      _offerSent = false;
    }
  }

  Future<void> _handleOffer(Map<String, dynamic> payload) async {
    try {
      final pc = await _ensurePeer();
      final sdp = payload['sdp'] as String?;
      if (sdp == null) return;
      await pc.setRemoteDescription(RTCSessionDescription(sdp, 'offer'));
      _remoteSet = true;
      // 补发早到的 ICE
      for (final c in _pendingIce) {
        try {
          await pc.addCandidate(_candidateOf(c));
        } catch (_) {}
      }
      _pendingIce.clear();
      final answer = await pc.createAnswer();
      await pc.setLocalDescription(answer);
      final ok = _session.realtime.sendSignal(widget.interviewId, {
        'kind': 'answer',
        'sdp': answer.sdp,
      });
      _answerSent = true;
      debugPrint('[room] answer sent ok=$ok');
    } catch (e) {
      debugPrint('[room] handle offer error $e');
    }
  }

  Future<void> _handleAnswer(Map<String, dynamic> payload) async {
    try {
      final pc = await _ensurePeer();
      final sdp = payload['sdp'] as String?;
      if (sdp == null) return;
      await pc.setRemoteDescription(RTCSessionDescription(sdp, 'answer'));
      _answerReceived = true;
      debugPrint('[room] answer received');
    } catch (e) {
      debugPrint('[room] handle answer error $e');
    }
  }

  RTCIceCandidate _candidateOf(Map<String, dynamic> payload) => RTCIceCandidate(
        payload['candidate'] as String? ?? '',
        payload['sdpMid'] as String?,
        (payload['sdpMLineIndex'] as num?)?.toInt() ?? 0,
      );

  Future<void> _addIce(Map<String, dynamic> payload) async {
    try {
      if (!_remoteSet) {
        _pendingIce.add(payload);
        return;
      }
      final pc = await _ensurePeer();
      await pc.addCandidate(_candidateOf(payload));
    } catch (_) {}
  }

  void _applyRemoteState(InterviewView iv) {
    debugPrint('[room] remote state -> ${iv.status}');
    setState(() => _view = iv);
    if (iv.status == 'finished' || iv.status == 'cancelled') {
      showToast(context, iv.status == 'finished' ? '面试已结束' : '面试已取消');
      Future<void>.delayed(const Duration(milliseconds: 700), () {
        if (mounted) Navigator.of(context).pop();
      });
    }
  }

  Future<void> _toggleMic() async {
    setState(() => _micOn = !_micOn);
    _localStream?.getAudioTracks().forEach((t) => t.enabled = _micOn);
  }

  Future<void> _toggleCamera() async {
    setState(() => _videoOn = !_videoOn);
    _localStream?.getVideoTracks().forEach((t) => t.enabled = _videoOn);
  }

  Future<void> _switchCamera() async {
    try {
      final tracks = _localStream?.getVideoTracks();
      if (tracks != null && tracks.isNotEmpty) {
        await Helper.switchCamera(tracks.first);
      }
    } catch (_) {}
  }

  Future<void> _hangUp() async {
    // 仅招聘者（interviewer，发起方）的挂断视为“结束整场面试”；
    // 求职者离开只退出房间，避免测试中误终场。
    if (_isHost && (_view.status == 'in_progress' || _view.status == 'invited')) {
      try {
        await _session.api.finishInterview(widget.interviewId, _session.token!);
      } catch (_) {}
    }
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121417),
      appBar: AppBar(
        backgroundColor: const Color(0xFF121417),
        foregroundColor: Colors.white,
        title: Column(children: [
          Text(_view.jobTitle, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          Text(
            '${interviewStatusLabel(_view.status)} · 对方：${_view.peerNameOf(_session.user?.id ?? '')}',
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w400),
          ),
        ]),
      ),
      body: _fatal != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.videocam_off_outlined, color: Colors.white54, size: 48),
                  const SizedBox(height: 12),
                  Text(_fatal!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.white70, fontSize: 14)),
                  const SizedBox(height: 18),
                  FilledButton(
                    style: FilledButton.styleFrom(minimumSize: const Size(160, 44)),
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('返回'),
                  ),
                ]),
              ),
            )
          : Stack(
              children: [
                // 远端（主画面）
                Positioned.fill(
                  child: _peerPresent
                      ? RTCVideoView(_remoteRenderer, objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover)
                      : const Center(
                          child: Column(mainAxisSize: MainAxisSize.min, children: [
                            Icon(Icons.video_call_outlined, color: Colors.white38, size: 64),
                            SizedBox(height: 10),
                            Text('等待对方加入…', style: TextStyle(color: Colors.white60, fontSize: 13)),
                          ]),
                        ),
                ),
                // 本地（小窗）
                Positioned(
                  right: 12,
                  top: 12,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: SizedBox(
                      width: 104,
                      height: 140,
                      child: RTCVideoView(_localRenderer, mirror: true, objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover),
                    ),
                  ),
                ),
                if (_busy)
                  const Positioned.fill(
                    child: Center(child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5)),
                  ),
                // 控制条
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 18),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _roundBtn(
                            icon: _micOn ? Icons.mic : Icons.mic_off,
                            active: _micOn,
                            onTap: _toggleMic,
                          ),
                          const SizedBox(width: 22),
                          _roundBtn(
                            icon: _videoOn ? Icons.videocam : Icons.videocam_off,
                            active: _videoOn,
                            onTap: _toggleCamera,
                          ),
                          const SizedBox(width: 22),
                          _roundBtn(
                            icon: Icons.cameraswitch_outlined,
                            active: true,
                            onTap: _switchCamera,
                          ),
                          const SizedBox(width: 22),
                          _roundBtn(
                            icon: Icons.call_end,
                            active: false,
                            color: const Color(0xFFE5484D),
                            onTap: _hangUp,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _roundBtn({
    required IconData icon,
    required bool active,
    required VoidCallback onTap,
    Color? color,
  }) {
    final bg = active ? Colors.white24 : (color ?? const Color(0xCC3A3F45));
    final fg = color == null ? Colors.white : Colors.white;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 52,
        height: 52,
        decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
        child: Icon(icon, color: fg, size: 24),
      ),
    );
  }
}
