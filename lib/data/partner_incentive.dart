/// Daily incentive from `GET /partner/dashboard` → `incentive`.
class PartnerIncentive {
  const PartnerIncentive({
    required this.targetJobs,
    required this.bonusAmount,
    required this.completedJobs,
    required this.earned,
  });

  static PartnerIncentive? fromJson(dynamic raw) {
    if (raw is! Map) return null;
    final target = (raw['target_jobs'] as num?)?.toInt() ?? 0;
    final bonus = (raw['bonus_amount'] as num?)?.toDouble() ?? 0;
    if (target <= 0 || bonus <= 0) return null;
    return PartnerIncentive(
      targetJobs: target,
      bonusAmount: bonus,
      completedJobs: (raw['completed_jobs'] as num?)?.toInt() ?? 0,
      earned: raw['earned'] == true,
    );
  }

  final int targetJobs;
  final double bonusAmount;
  final int completedJobs;
  final bool earned;

  int get remainingJobs => (targetJobs - completedJobs).clamp(0, targetJobs);
  double get progress => (completedJobs / targetJobs).clamp(0, 1).toDouble();
}
