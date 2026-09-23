// 展示用格式化工具：薪资 / 时间 / 常用字段。

/// 月薪区间文案。salary 为元/月，输出「15K-25K·13薪」风格（无数据时返回空）。
String salaryText(int? min, int? max) {
  if (min == null && max == null) return '薪资面议';
  String k(int? v) {
    if (v == null || v <= 0) return '';
    if (v % 1000 == 0) return '${v ~/ 1000}K';
    return '${(v / 1000).toStringAsFixed(1)}K';
  }

  final lo = k(min);
  final hi = k(max);
  if (lo.isEmpty && hi.isEmpty) return '薪资面议';
  if (lo.isEmpty) return '$hi 以下';
  if (hi.isEmpty) return '$lo 以上';
  if (lo == hi) return lo;
  return '$lo-$hi';
}

/// 相对时间：x 分钟前 / x 小时前 / 昨天 / 日期
String relativeTime(DateTime time) {
  final local = time.toLocal();
  final now = DateTime.now();
  final diff = now.difference(local);
  if (diff.inMinutes < 1) return '刚刚';
  if (diff.inMinutes < 60) return '${diff.inMinutes} 分钟前';
  if (diff.inHours < 24 && local.day == now.day) return '${diff.inHours} 小时前';
  if (diff.inHours < 48 && now.difference(DateTime(now.year, now.month, now.day)).inHours >= 0) {
    return '昨天';
  }
  if (local.year == now.year) {
    return '${local.month}月${local.day}日';
  }
  return '${local.year}-${local.month}-${local.day}';
}

/// 完整时间文案
String fullTime(DateTime t) {
  final l = t.toLocal();
  String two(int v) => v.toString().padLeft(2, '0');
  return '${l.year}-${two(l.month)}-${two(l.day)} ${two(l.hour)}:${two(l.minute)}';
}

/// 千分位金额/数值显示
String numberWithUnit(int? v) => v == null ? '-' : '$v';
