import 'package:flutter/material.dart';

/// 用人单位投诉等级。
///
/// 次数口径：该单位在平台上**经管理员审核通过**的累计投诉次数
/// （平台既有规则：投诉需与该单位实际沟通过、证据 ≥ 20 字、并经平台审核，
///  因此每一条计入的投诉都是"有效投诉"，不是随手点一下）。
enum ComplaintLevel { excellent, minor, alert, warning, severe }

/// 等级阈值（含下界）：0 / 1 / 3 / 6 / 10
const List<int> complaintLevelThresholds = <int>[0, 1, 3, 6, 10];

/// 规则版本：写入本地设置，版本变化时重新向用户提示
const String complaintRuleSeenKey = 'complaintRuleSeenV1';

/// 投诉次数 → 等级
ComplaintLevel complaintLevelOf(int complaints) {
  if (complaints <= 0) return ComplaintLevel.excellent;
  if (complaints <= 2) return ComplaintLevel.minor;
  if (complaints <= 5) return ComplaintLevel.alert;
  if (complaints <= 9) return ComplaintLevel.warning;
  return ComplaintLevel.severe;
}

extension ComplaintLevelX on ComplaintLevel {
  /// 等级名
  String get label => switch (this) {
        ComplaintLevel.excellent => '优秀',
        ComplaintLevel.minor => '轻微',
        ComplaintLevel.alert => '预警',
        ComplaintLevel.warning => '警告',
        ComplaintLevel.severe => '严重',
      };

  /// 直觉色：绿（无投诉）→ 蓝（中性提示）→ 橙黄（留意）→ 橙红（警告）→ 红（严重）
  Color get color => switch (this) {
        ComplaintLevel.excellent => const Color(0xFF07C160),
        ComplaintLevel.minor => const Color(0xFF3E8EF7),
        ComplaintLevel.alert => const Color(0xFFFFA726),
        ComplaintLevel.warning => const Color(0xFFFF6A3D),
        ComplaintLevel.severe => const Color(0xFFE5484D),
      };

  IconData get icon => switch (this) {
        ComplaintLevel.excellent => Icons.verified_outlined,
        ComplaintLevel.minor => Icons.info_outline,
        ComplaintLevel.alert => Icons.visibility_outlined,
        ComplaintLevel.warning => Icons.warning_amber_rounded,
        ComplaintLevel.severe => Icons.dangerous_outlined,
      };

  /// 次数区间文案
  String get range => switch (this) {
        ComplaintLevel.excellent => '0 次',
        ComplaintLevel.minor => '1 – 2 次',
        ComplaintLevel.alert => '3 – 5 次',
        ComplaintLevel.warning => '6 – 9 次',
        ComplaintLevel.severe => '10 次及以上',
      };

  /// 一句话含义
  String get meaning => switch (this) {
        ComplaintLevel.excellent => '没有经审核的有效投诉，可以放心投递。',
        ComplaintLevel.minor => '个别求职者的一次性摩擦，尚未构成模式，正常留意即可。',
        ComplaintLevel.alert => '同一问题开始重复出现，投递前建议先核实岗位与用工情况。',
        ComplaintLevel.warning => '已属持续/系统性问题，建议先与在职员工或前员工了解后再决定。',
        ComplaintLevel.severe => '广泛不满，强烈建议规避；平台也会在职位卡上以红色标出。',
      };

  /// 卡面主色的降饱和系数（等级越高，卡片越"暗"）
  double get dimFactor => switch (this) {
        ComplaintLevel.excellent => 0,
        ComplaintLevel.minor => 0.10,
        ComplaintLevel.alert => 0.20,
        ComplaintLevel.warning => 0.28,
        ComplaintLevel.severe => 0.35,
      };

  /// 卡面主色（色系）：用色系表达优劣 —— 绿=优秀、蓝=轻微、琥珀=预警、橙红=警告、红=严重
  Color get surface => switch (this) {
        ComplaintLevel.excellent => const Color(0xFF12B76A), // 绿系
        ComplaintLevel.minor => const Color(0xFF3E7BFA), // 蓝系
        ComplaintLevel.alert => const Color(0xFFF59E0B), // 琥珀/橙黄系
        ComplaintLevel.warning => const Color(0xFFEA580C), // 橙红系
        ComplaintLevel.severe => const Color(0xFFD92D20), // 红系
      };

  /// 色系的深色端（卡面渐变用）
  Color get surfaceDeep => switch (this) {
        ComplaintLevel.excellent => const Color(0xFF0B8F52),
        ComplaintLevel.minor => const Color(0xFF2A5BD7),
        ComplaintLevel.alert => const Color(0xFFC97A06),
        ComplaintLevel.warning => const Color(0xFFBE4409),
        ComplaintLevel.severe => const Color(0xFFB01F17),
      };

  /// 卡面/底部提示用的短语
  String badge(int complaints) =>
      this == ComplaintLevel.excellent ? '无投诉 · 优秀' : '投诉 $complaints 次 · $label';
}

/// 定级依据（规则页与首次提示共用）
const List<String> complaintLevelReasons = <String>[
  '只统计经平台审核通过的投诉：投诉必须已与该单位实际沟通过、证据不少于 20 字并通过管理员审核，'
      '所以每一条都是有效投诉，不掺无效噪声。',
  '1–2 次记为「轻微」：一次性摩擦（试用期分歧、离职结算等）在任何规模的单位都可能出现，'
      '样本太少无法构成模式，只做中性提示。',
  '3 次起记为「预警」：沿用「重复三次才构成模式」的经验法则，≥3 条独立投诉说明问题在反复发生。',
  '6 次起记为「警告」：进入持续 / 系统性问题区间，投递前应主动核实。',
  '10 次及以上记为「严重」：两位数的有效投诉意味着广泛不满；该档位也与平台既有产品决策一致'
      '（旧版职位卡配色把 10 次作为「最暗」档）。',
  '局限与校准：当前按「累计投诉次数」定级，未按招聘规模归一；平台数据量足够后会改用分布分位数'
      '（例如 P90 以上记为「严重」）重新校准。规则带版本号，调整后会重新向用户提示。',
];

/// 职位列表排序用的比较键：先按投诉等级（优秀 → 严重），
/// 同级内按投诉次数由少到多，最后按发布时间由新到旧。
/// 返回可比较的整数元组式键（保证排序稳定、可读）。
(int, int, int) jobSortKey(int complaints, DateTime createdAt) => (
      complaintLevelOf(complaints).index,
      complaints,
      -createdAt.millisecondsSinceEpoch, // 时间越新键越小 → 越靠前
    );
