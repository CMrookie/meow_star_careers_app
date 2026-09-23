import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

import '../state/session.dart';
import 'theme.dart';

/// 开发自检页：不依赖后端/对端，验证本机摄像头与麦克风采集。
class CameraCheckPage extends StatefulWidget {
  const CameraCheckPage({super.key});

  @override
  State<CameraCheckPage> createState() => _CameraCheckPageState();
}

class _CameraCheckPageState extends State<CameraCheckPage> {
  final _renderer = RTCVideoRenderer();
  MediaStream? _stream;
  bool _micOn = true;
  bool _videoOn = true;
  bool _starting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _renderer.initialize();
    _start();
  }

  @override
  void dispose() {
    _renderer.dispose();
    _stream?.getTracks().forEach((t) => t.stop());
    _stream?.dispose();
    super.dispose();
  }

  Future<void> _start() async {
    setState(() {
      _starting = true;
      _error = null;
    });
    try {
      final stream = await navigator.mediaDevices.getUserMedia({
        'audio': true,
        'video': {'facingMode': 'user'},
      });
      _stream = stream;
      _renderer.srcObject = stream;
    } catch (e) {
      _error = friendlyErrorText(e);
    } finally {
      if (mounted) setState(() => _starting = false);
    }
  }

  String friendlyErrorText(Object e) {
    final s = '$e';
    if (s.toLowerCase().contains('permission') || s.toLowerCase().contains('denied')) {
      return '未获得摄像头/麦克风权限，请在系统设置中允许后重试';
    }
    return '采集失败：$s';
  }

  @override
  Widget build(BuildContext context) {
    final session = AppScope.of(context);
    return Scaffold(
      backgroundColor: bgPage,
      appBar: AppBar(title: const Text('摄像头自检')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            height: 300,
            decoration: BoxDecoration(
              color: const Color(0xFF121417),
              borderRadius: BorderRadius.circular(radiusCard),
            ),
            clipBehavior: Clip.antiAlias,
            child: _error != null
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Text(_error!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.white70)),
                    ),
                  )
                : _starting
                    ? const Center(
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                      )
                    : _stream == null
                        ? const Center(
                            child: Text('点击“重新开始”打开摄像头',
                                style: TextStyle(color: Colors.white54)),
                          )
                        : RTCVideoView(_renderer,
                            mirror: true,
                            objectFit:
                                RTCVideoViewObjectFit.RTCVideoViewObjectFitCover),
          ),
          const SizedBox(height: 14),
          Text('用途：在双端视频前，先在单台设备确认本机摄像头/麦克风可用并已授权。',
              style: const TextStyle(fontSize: 12, color: textHint)),
          if (session.isDemo)
            const Padding(
              padding: EdgeInsets.only(top: 6),
              child: Text('当前为演示模式（无对端）；此页只验证本机采集。',
                  style: TextStyle(fontSize: 12, color: warmOrange)),
            ),
          const SizedBox(height: 14),
          Row(children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _stream == null ? null : _start,
                icon: const Icon(Icons.refresh, size: 18),
                label: const Text('重新开始'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: FilledButton.tonalIcon(
                onPressed: () async {
                  if (_stream == null) return;
                  setState(() => _micOn = !_micOn);
                  _stream?.getAudioTracks().forEach((t) => t.enabled = _micOn);
                },
                icon: Icon(_micOn ? Icons.mic : Icons.mic_off, size: 18),
                label: Text(_micOn ? '静音麦克风' : '开启麦克风'),
              ),
            ),
          ]),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () async {
                  if (_stream == null) return;
                  setState(() => _videoOn = !_videoOn);
                  _stream?.getVideoTracks().forEach((t) => t.enabled = _videoOn);
                },
                icon: Icon(_videoOn ? Icons.videocam : Icons.videocam_off, size: 18),
                label: Text(_videoOn ? '关闭画面' : '打开画面'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () async {
                  final tracks = _stream?.getVideoTracks();
                  if (tracks == null || tracks.isEmpty) return;
                  try {
                    await Helper.switchCamera(tracks.first);
                  } catch (_) {}
                },
                icon: const Icon(Icons.cameraswitch_outlined, size: 18),
                label: const Text('切换摄像头'),
              ),
            ),
          ]),
        ],
      ),
    );
  }
}
