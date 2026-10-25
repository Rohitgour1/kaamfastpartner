import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:kaamfast_partner/data/mock_data.dart';
import 'package:kaamfast_partner/data/service_approval.dart';
import 'package:kaamfast_partner/l10n/app_strings.dart';
import 'package:kaamfast_partner/services/partner_api.dart';
import 'package:kaamfast_partner/state/session_controller.dart';
import 'package:kaamfast_partner/theme/partner_theme.dart';
import 'package:provider/provider.dart';

class MyServicesScreen extends StatefulWidget {
  const MyServicesScreen({super.key});

  @override
  State<MyServicesScreen> createState() => _MyServicesScreenState();
}

class _MyServicesScreenState extends State<MyServicesScreen> with WidgetsBindingObserver {
  bool _loading = true;
  int? _busyModuleId;
  bool _adding = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _refresh());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _refresh();
  }

  Future<void> _refresh() async {
    await context.read<SessionController>().refreshKyc();
    if (mounted) setState(() => _loading = false);
  }

  void _toast(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _reapply(ServiceApproval service) async {
    setState(() => _busyModuleId = service.moduleId);
    try {
      await context.read<SessionController>().applyForServices([service.moduleId]);
      if (!mounted) return;
      _toast(context.tr('Re-applied. Upload any missing documents for review.'));
      context.push('/kyc');
    } catch (e) {
      if (mounted) _toast('$e');
    } finally {
      if (mounted) setState(() => _busyModuleId = null);
    }
  }

  Future<void> _addServices() async {
    final session = context.read<SessionController>();
    final api = context.read<PartnerApi>();
    final partnerType = (session.role ?? session.user?.role)?.id;
    final taken = session.serviceApprovals.map((s) => s.moduleId).toSet();

    setState(() => _adding = true);
    List<Map<String, dynamic>> modules;
    try {
      modules = (await api.onboardingServices()).where((module) {
        final id = int.tryParse('${module['id']}');
        final types = module['provider_types'];
        final list = types is List ? types.map((e) => '$e').toList() : const <String>[];
        return id != null && !taken.contains(id) && (partnerType == null || list.contains(partnerType));
      }).toList();
    } catch (e) {
      if (mounted) {
        setState(() => _adding = false);
        _toast('$e');
      }
      return;
    }
    if (!mounted) return;
    setState(() => _adding = false);

    if (modules.isEmpty) {
      _toast(context.tr('You have already added every available service.'));
      return;
    }

    final picked = await showModalBottomSheet<List<int>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _AddServiceSheet(modules: modules),
    );
    if (picked == null || picked.isEmpty || !mounted) return;

    setState(() => _adding = true);
    try {
      await session.applyForServices(picked);
      if (!mounted) return;
      _toast(context.tr('Service added. Upload required documents for review.'));
      context.push('/kyc');
    } catch (e) {
      if (mounted) _toast('$e');
    } finally {
      if (mounted) setState(() => _adding = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = context.watch<SessionController>();
    final services = session.serviceApprovals;
    final canOperate = session.canGoOnline;

    return Scaffold(
      appBar: AppBar(title: Text(context.tr('My services'))),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 120),
          children: [
            if (!canOperate) ...[
              _Banner(
                color: Colors.orange.shade50,
                border: Colors.orange.shade200,
                icon: Icons.info_outline,
                iconColor: Colors.orange.shade800,
                text: context.tr(
                  "Your account can't receive orders yet. Complete KYC or contact support.",
                ),
              ),
              const SizedBox(height: 12),
            ],
            Text(
              context.tr('Each service is approved separately by admin. You get orders only for active services.'),
              style: const TextStyle(color: PartnerColors.muted, fontSize: 13),
            ),
            const SizedBox(height: 14),
            if (_loading && services.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 40),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (services.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 32),
                child: Center(
                  child: Text(
                    context.tr('No services added yet.'),
                    style: const TextStyle(color: PartnerColors.muted),
                  ),
                ),
              )
            else
              for (final service in services)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _ServiceStatusCard(
                    service: service,
                    busy: _busyModuleId == service.moduleId,
                    onReapply: _busyModuleId == null ? () => _reapply(service) : null,
                  ),
                ),
            if (session.role == PartnerRole.service) ...[
              const SizedBox(height: 4),
              TextButton.icon(
                onPressed: () => context.push('/services'),
                icon: const Icon(Icons.tune, size: 18),
                label: Text(context.tr('Edit work types')),
              ),
            ],
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        child: FilledButton.icon(
          onPressed: _adding ? null : _addServices,
          icon: _adding
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : const Icon(Icons.add),
          label: Text(context.tr('Add service')),
        ),
      ),
    );
  }
}

class _ServiceStatusCard extends StatelessWidget {
  const _ServiceStatusCard({required this.service, required this.busy, this.onReapply});

  final ServiceApproval service;
  final bool busy;
  final VoidCallback? onReapply;

  @override
  Widget build(BuildContext context) {
    final (Color color, IconData icon, String label, String detail) = switch (service.status) {
      'approved' => (
          Colors.green.shade700,
          Icons.check_circle,
          context.tr('Active'),
          context.tr('Receiving orders'),
        ),
      'rejected' => (
          PartnerColors.danger,
          Icons.cancel,
          context.tr('Not approved'),
          service.reason ?? context.tr('Admin did not approve this service.'),
        ),
      'suspended' => (
          Colors.grey.shade700,
          Icons.pause_circle,
          context.tr('Paused'),
          context.tr('Paused by admin'),
        ),
      _ => (
          Colors.orange.shade800,
          Icons.hourglass_top,
          context.tr('Under review'),
          context.tr("You'll get orders after approval"),
        ),
    };

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: PartnerColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  context.tr(service.module),
                  style: GoogleFonts.hankenGrotesk(fontWeight: FontWeight.w800, fontSize: 16),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(icon, size: 14, color: color),
                    const SizedBox(width: 4),
                    Text(
                      label,
                      style: TextStyle(color: color, fontWeight: FontWeight.w800, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(detail, style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.w600)),
          if (service.isRejected) ...[
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: busy ? null : onReapply,
              icon: busy
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.refresh, size: 18),
              label: Text(context.tr('Re-apply')),
            ),
          ],
        ],
      ),
    );
  }
}

class _AddServiceSheet extends StatefulWidget {
  const _AddServiceSheet({required this.modules});

  final List<Map<String, dynamic>> modules;

  @override
  State<_AddServiceSheet> createState() => _AddServiceSheetState();
}

class _AddServiceSheetState extends State<_AddServiceSheet> {
  final _picked = <int>{};

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              context.tr('Add service'),
              style: GoogleFonts.hankenGrotesk(fontWeight: FontWeight.w800, fontSize: 18),
            ),
            const SizedBox(height: 4),
            Text(
              context.tr('Your active services keep receiving orders while new ones are reviewed.'),
              style: const TextStyle(color: PartnerColors.muted, fontSize: 12),
            ),
            const SizedBox(height: 10),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: [
                  for (final module in widget.modules)
                    Builder(builder: (context) {
                      final id = int.parse('${module['id']}');
                      final name = module['name']?.toString() ?? module['slug']?.toString() ?? '';
                      final description = module['short_description']?.toString() ?? '';
                      return CheckboxListTile(
                        contentPadding: EdgeInsets.zero,
                        value: _picked.contains(id),
                        onChanged: (on) => setState(() => on == true ? _picked.add(id) : _picked.remove(id)),
                        title: Text(context.tr(name), style: const TextStyle(fontWeight: FontWeight.w700)),
                        subtitle: description.isEmpty ? null : Text(context.tr(description)),
                      );
                    }),
                ],
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _picked.isEmpty ? null : () => Navigator.of(context).pop(_picked.toList()),
                child: Text(
                  _picked.length > 1
                      ? context.tr('Apply for {count} services', {'count': _picked.length})
                      : context.tr('Apply for service'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Banner extends StatelessWidget {
  const _Banner({
    required this.color,
    required this.border,
    required this.icon,
    required this.iconColor,
    required this.text,
  });

  final Color color;
  final Color border;
  final IconData icon;
  final Color iconColor;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: iconColor, size: 20),
          const SizedBox(width: 10),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 13, height: 1.35))),
        ],
      ),
    );
  }
}
