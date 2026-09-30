import 'package:flutter/material.dart';

import '../models/models.dart';

/// 用人单位投诉等级（展示层）。
///
/// **定级规则的单一来源在服务端**：
/// - `/jobs` 系列直接下发 `complaintLevel` / `complaintBasis` / `complaintRatePercent`
///   （数字只写在后端 SQL 的 `complaint_rule_*` 函数里，见后端 0018 迁移）；
/// - 本文件里的 [assessComplaints] / [complaintLevelThresholds] /
///   [complaintRateThresholds] 只服务两件事：**演示模式**（demo_store 充当后端）
///   与**老后端/离线兜底**（响应缺字段时）。真实数据一律用服务端下发的等级，
///   统一入口见 [assessmentForJob]。
/// 口径说明：投诉是「经管理员审核通过」的有效投诉（需已实际沟通、证据 ≥20 字）。
enum ComplaintLevel { excellent, minor, alert, warning, severe }

/// 服务端下发的等级名 -> 枚举（未知/缺失返回 null）
ComplaintLevel? levelFromWire(String? wire) =>
    wire == null ? null : ComplaintLevel.values.asNameMap()[wire];

/// 服务端下发的口径 -> 枚举（未知/缺失返回 null）
ComplaintBasis? basisFromWire(String? wire) => switch (wire) {
      'rate' => ComplaintBasis.rate,
      'count' => ComplaintBasis.count,
      _ => null,
    };

/// 等级阈值（含下界）：0 / 1 / 3 / 6 / 10
const List<int> complaintLevelThresholds = <int>[0, 1, 3, 6, 10];

/// 「已看过规则提示」的本地键：按**服务端下发的规则版本**区分，
/// 后端调整口径（version 变化）后会自动重新提示一次。
String complaintRuleSeenKeyFor(String version) => 'complaintRuleSeen:$version';

/// 定级口径
enum ComplaintBasis {
  /// 按公司规模折算的每百人投诉率（规模已知且 ≥ [minStaffSizeForRate]）
  rate,

  /// 投诉次数（规模未知，或规模过小导致率不稳定）
  count,
}

/// 用率定级所需的最小规模：低于这个人数，"1 起投诉"就能把率抬到 2%，
/// 统计波动过大，容易冤枉小公司，所以退回次数口径。
const int minStaffSizeForRate = 50;

/// 每百人投诉率（%）的上界阈值：0 → 轻微 ≤0.5% → 预警 ≤1.5% → 警告 ≤3% → 严重 >3%
const List<double> complaintRateThresholds = <double>[0.5, 1.5, 3.0];

/// 一次定级的结果：等级 + 用了哪种口径 + 参与计算的原始数据
class ComplaintAssessment {
  final ComplaintLevel level;
  final ComplaintBasis basis;
  final int complaints;
  final int? staffSize;

  /// 服务端下发的每百人投诉率（%）；为空时按次数/规模本地推算（演示模式）
  final double? rateFromServer;

  const ComplaintAssessment({
    required this.level,
    required this.basis,
    required this.complaints,
    this.staffSize,
    this.rateFromServer,
  });

  /// 每百人投诉率（%）：**优先用服务端下发的值**；按次数口径时为 null
  double? get ratePercent {
    if (basis != ComplaintBasis.rate) return null;
    if (rateFromServer != null) return rateFromServer;
    return staffSize != null && staffSize! > 0 ? complaints / staffSize! * 100 : null;
  }

  /// 卡面/详情用的短语
  String get badge => complaints <= 0
      ? '无投诉 · 优秀'
      : ratePercent != null
          ? '投诉率 ${ratePercent!.toStringAsFixed(1)}% · ${level.label}'
          : '投诉 $complaints 次 · ${level.label}';

  /// 口径说明（点开细节时展示）
  String get basisNote => switch (basis) {
        ComplaintBasis.rate =>
          '按 $staffSize 人规模折算：每百人 ${ratePercent!.toStringAsFixed(2)} 起有效投诉'
              ,
        ComplaintBasis.count => staffSize == null
            ? '该单位未申报规模，按投诉次数定级'
            : '规模 $staffSize 人（不足 $minStaffSizeForRate 人），小样本波动大，按投诉次数定级',
      };
}

/// 定级（推荐入口）：有规模就按规模折算的投诉率，否则退回投诉次数。
ComplaintAssessment assessComplaints({required int complaints, int? staffSize}) {
  if (complaints <= 0) {
    return ComplaintAssessment(
      level: ComplaintLevel.excellent,
      basis: staffSize != null && staffSize >= minStaffSizeForRate
          ? ComplaintBasis.rate
          : ComplaintBasis.count,
      complaints: complaints < 0 ? 0 : complaints,
      staffSize: staffSize,
    );
  }
  if (staffSize != null && staffSize >= minStaffSizeForRate) {
    final rate = complaints / staffSize * 100;
    final level = rate <= complaintRateThresholds[0]
        ? ComplaintLevel.minor
        : rate <= complaintRateThresholds[1]
            ? ComplaintLevel.alert
            : rate <= complaintRateThresholds[2]
                ? ComplaintLevel.warning
                : ComplaintLevel.severe;
    return ComplaintAssessment(
        level: level, basis: ComplaintBasis.rate, complaints: complaints, staffSize: staffSize);
  }
  return ComplaintAssessment(
      level: complaintLevelOf(complaints),
      basis: ComplaintBasis.count,
      complaints: complaints,
      staffSize: staffSize);
}

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

  /// 卡面/底部提示用的短语（次数口径；有规模时请用 [ComplaintAssessment.badge]）
  String badge(int complaints) =>
      this == ComplaintLevel.excellent ? '无投诉 · 优秀' : '投诉 $complaints 次 · $label';
}

/// 定级依据（规则页与首次提示共用）
const List<String> complaintLevelReasons = <String>[
  '分母是公司规模：同样的「10 起投诉」，2000 人公司是 0.5%，60 人公司是 16.7%，'
      '性质完全不同。所以等级按**每百人投诉率**折算，而不是绝对次数 —— 规模大的公司不再被次数冤枉。',
  '只统计经平台审核通过的投诉：投诉必须已与该单位实际沟通过、证据不少于 20 字并通过管理员审核，'
      '所以每一条都是有效投诉，不掺无效噪声。',
  '小样本退回次数：规模不足 50 人时，「1 起投诉」就能把率抬到 2% 以上，统计波动太大、'
      '容易冤枉小公司，因此这一档改用投诉次数定级（0 / 1–2 / 3–5 / 6–9 / ≥10），并在卡片上标明口径。',
  '率阈值 0.5% / 1.5% / 3%：每百人 3 起经审核的有效投诉已属明显异常（现实劳动争议与投诉率通常是'
      '个位数千分位量级），作为「严重」线；0.5% 与 1.5% 作为「轻微 / 预警」的梯度。',
  '规模数据来自企业申报（公司资料里的员工数），可能与实际有偏差；正式环境应接入工商 / 平台核验，'
      '并将申报值与核验值同时展示。',
  '后续校准：当平台数据量足够时，改用投诉率分布的分位数（例如 P90 以上记为「严重」）重新定标。'
      '规则带版本号（当前 v2），口径调整后会重新向用户提示。',
];

/// 统一入口：**优先采用服务端下发的等级 / 口径 / 率**（单一来源），
/// 只在缺字段时（演示数据 / 老后端）退回本地口径计算。
ComplaintAssessment resolveAssessment({
  required int complaints,
  int? staffSize,
  String? level,
  String? basis,
  double? ratePercent,
}) {
  final wireLevel = levelFromWire(level);
  if (wireLevel == null) {
    return assessComplaints(complaints: complaints, staffSize: staffSize);
  }
  return ComplaintAssessment(
    level: wireLevel,
    basis: basisFromWire(basis) ??
        (ratePercent != null ? ComplaintBasis.rate : ComplaintBasis.count),
    complaints: complaints,
    staffSize: staffSize,
    rateFromServer: ratePercent,
  );
}

/// 职位视图 -> 定级结果：卡面徽标、配色、文案统一走这里，避免各处重复计算
ComplaintAssessment assessmentForJob(JobView job) => resolveAssessment(
      complaints: job.complaintCount,
      staffSize: job.companyStaffSize,
      level: job.complaintLevel,
      basis: job.complaintBasis,
      ratePercent: job.complaintRatePercent,
    );

/// 职位排序键（与后端 ORDER BY 同一套键）：优先用服务端下发的等级 / 口径 / 率
(int, int, double, int) jobSortKeyForJob(JobView job) {
  final a = assessmentForJob(job);
  return (
    a.level.index,
    a.basis == ComplaintBasis.rate ? 0 : 1,
    a.ratePercent ?? a.complaints.toDouble(),
    -job.createdAt.millisecondsSinceEpoch,
  );
}

/// 离线 / 演示模式下的兜底规则（与后端 v2 同值；真实数据以服务端下发为准）
const ComplaintRuleSet complaintRuleFallback = ComplaintRuleSet(
  version: 'v2',
  levels: ['excellent', 'minor', 'alert', 'warning', 'severe'],
  minStaffSizeForRate: minStaffSizeForRate,
  rateThresholds: complaintRateThresholds,
  countThresholds: complaintLevelThresholds,
);

/// 职位列表排序用的比较键：先按投诉等级（优秀 → 严重），
/// 同级内按投诉次数由少到多，最后按发布时间由新到旧。
/// 返回可比较的整数元组式键（保证排序稳定、可读）。
(int, int, double, int) jobSortKey(int complaints, int? staffSize, DateTime createdAt) {
  final a = assessComplaints(complaints: complaints, staffSize: staffSize);
  return (
    a.level.index,
    a.basis == ComplaintBasis.rate ? 0 : 1, // 同等级内：有规模折算的排前面（数据更可信）
    a.ratePercent ?? a.complaints.toDouble(),
    -createdAt.millisecondsSinceEpoch,
  );
}
