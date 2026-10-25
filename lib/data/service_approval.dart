class ServiceApproval {
  const ServiceApproval({
    required this.moduleId,
    required this.module,
    this.moduleSlug,
    required this.status,
    this.reason,
  });

  final int moduleId;
  final String module;
  final String? moduleSlug;
  final String status;
  final String? reason;

  bool get isApproved => status == 'approved';
  bool get isPending => status == 'pending';
  bool get isRejected => status == 'rejected';
  bool get isSuspended => status == 'suspended';

  static List<ServiceApproval> listFrom(Object? raw) {
    if (raw is! List) return const [];
    final out = <ServiceApproval>[];
    for (final row in raw) {
      if (row is! Map) continue;
      final id = int.tryParse('${row['service_module_id']}');
      if (id == null) continue;
      final reason = row['status_reason']?.toString();
      out.add(ServiceApproval(
        moduleId: id,
        module: row['module']?.toString() ?? row['module_slug']?.toString() ?? 'Service',
        moduleSlug: row['module_slug']?.toString(),
        status: (row['status']?.toString() ?? 'pending').toLowerCase(),
        reason: reason == null || reason.trim().isEmpty ? null : reason.trim(),
      ));
    }
    return out;
  }
}
