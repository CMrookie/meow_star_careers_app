import 'package:flutter/material.dart';

import '../core/format.dart';
import '../models/models.dart';
import '../state/session.dart';
import 'theme.dart';
import 'widgets.dart';

Color complaintStatusColor(String s) {
  switch (s) {
    case 'pending':
      return warmOrange;
    case 'approved':
      return accentGreen;
    case 'rejected':
      return const Color(0xFFE5484D);
    default:
      return textHint;
  }
}

/// 投诉记录 / 企业投诉 / 管理员审核（服务端按角色返回对应数据）
class ComplaintsPage extends StatefulWidget {
  const ComplaintsPage({super.key});

  @override
  State<ComplaintsPage> createState() => _ComplaintsPageState();
}

class _ComplaintsPageState extends State<ComplaintsPage> {
  List<ComplaintView>? _items;
  Object? _error;

  bool get _isAdmin => (AppScope.of(context).user?.role ?? '') == 'admin';

  String get _title {
    final u = AppScope.of(context).user;
    if (_isAdmin) return '投诉审核';
    if (u?.isRecruiter ?? false) return '企业投诉记录';
    return '我的投诉';
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final session = AppScope.read(context);
    setState(() {
      _items = null;
      _error = null;
    });
    try {
      final list = await session.api.complaints(session.token!);
      if (!mounted) return;
      setState(() => _items = list);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e);
    }
  }

  Future<void> _review(ComplaintView c, bool approved) async {
    final noteCtrl = TextEditingController();
    String? note;
    if (!approved) {
      note = await showModalBottomSheet<String>(
        context: context,
        backgroundColor: Colors.white,
        isScrollControlled: true,
        builder: (ctx) => SafeArea(
          child: Padding(
            padding: EdgeInsets.only(
              left: 20, right: 20, top: 16,
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
            ),
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('驳回原因', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
              const SizedBox(height: 10),
              TextField(controller: noteCtrl, maxLines: 3, maxLength: 500,
                  decoration: const InputDecoration(hintText: '请说明驳回原因（选填）')),
              const SizedBox(height: 8),
              FilledButton(
                onPressed: () => Navigator.pop(ctx, noteCtrl.text.trim()),
                child: const Text('确认驳回'),
              ),
            ]),
          ),
        ),
      );
      if (note == null) return; // 取消
    }
    if (!mounted) return;
    final session = AppScope.of(context);
    try {
      await runAction(context, () async {
        await session.api.reviewComplaint(c.id, approved: approved, note: note, token: session.token!);
      });
      if (!mounted) return;
      showToast(context, approved ? '已通过，投诉次数已生效' : '已驳回');
      _load();
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final items = _items;
    return Scaffold(
      backgroundColor: bgPage,
      appBar: AppBar(title: Text(_title)),
      body: _error != null && items == null
          ? ErrorView(error: _error!, onRetry: _load)
          : items == null
              ? const Center(child: CircularProgressIndicator(strokeWidth: 2.5))
              : items.isEmpty
                  ? const EmptyView(icon: Icons.rate_review_outlined, title: '暂无投诉记录')
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: ListView.separated(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        itemCount: items.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 14),
                        itemBuilder: (context, i) => _tile(items[i]),
                      ),
                    ),
    );
  }

  Widget _tile(ComplaintView c) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12),
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(
              child: Text(c.companyName,
                  maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
            ),
            TagChip(c.statusLabel, color: complaintStatusColor(c.status), filled: true),
          ]),
          if (_isAdmin) ...[
            const SizedBox(height: 4),
            Text('投诉人：${c.complainantName}',
                style: const TextStyle(fontSize: 12, color: textSub)),
          ],
          const SizedBox(height: 8),
          Text(c.evidence, maxLines: 4, overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 13, color: textSub, height: 1.5)),
          if (c.reviewNote != null && c.reviewNote!.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text('审核备注：${c.reviewNote}', style: TextStyle(fontSize: 12, color: complaintStatusColor(c.status))),
          ],
          const SizedBox(height: 8),
          Row(children: [
            Text('提交于 ${relativeTime(c.createdAt)}',
                style: const TextStyle(fontSize: 11, color: Color(0xFFB8BCC4))),
            const Spacer(),
            if (_isAdmin && c.pending) ...[
              OutlinedButton(
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(0, 34),
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  foregroundColor: const Color(0xFFE5484D),
                  side: const BorderSide(color: Color(0xFFE5484D)),
                ),
                onPressed: () => _review(c, false),
                child: const Text('驳回', style: TextStyle(fontSize: 13)),
              ),
              const SizedBox(width: 8),
              FilledButton(
                style: FilledButton.styleFrom(minimumSize: const Size(0, 34)),
                onPressed: () => _review(c, true),
                child: const Text('通过并生效', style: TextStyle(fontSize: 13)),
              ),
            ],
          ]),
        ]),
      ),
    );
  }
}
