import 'package:flutter/material.dart';
import 'package:kaamfast_partner/data/mock_data.dart';
import 'package:kaamfast_partner/features/tasks/searching_delivery_screen.dart';
import 'package:kaamfast_partner/l10n/app_strings.dart';
import 'package:kaamfast_partner/state/session_controller.dart';
import 'package:kaamfast_partner/theme/partner_theme.dart';
import 'package:kaamfast_partner/widgets/customer_photos_strip.dart';
import 'package:kaamfast_partner/widgets/job_complete_helper.dart';
import 'package:kaamfast_partner/widgets/job_contact_card.dart';
import 'package:kaamfast_partner/widgets/job_navigation.dart';
import 'package:provider/provider.dart';

class TaskDetailScreen extends StatefulWidget {
  const TaskDetailScreen({super.key, required this.taskId});

  final String taskId;

  @override
  State<TaskDetailScreen> createState() => _TaskDetailScreenState();
}

class _TaskDetailScreenState extends State<TaskDetailScreen> {
  PartnerTask? _task;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final session = context.read<SessionController>();
    final cached = session.tasks.where((e) => e.id == widget.taskId).firstOrNull;
    setState(() {
      _task = cached;
      _loading = cached == null;
      _error = null;
    });
    try {
      final fresh = await session.loadTaskDetail(widget.taskId);
      if (!mounted) return;
      setState(() {
        _task = fresh ?? cached;
        _loading = false;
        if (_task == null) _error = 'Task not found';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = cached == null ? '$e' : null;
        _task ??= cached;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = context.watch<SessionController>();
    final task = session.tasks.where((e) => e.id == widget.taskId).firstOrNull ?? _task;

    return Scaffold(
      backgroundColor: PartnerColors.bg,
      appBar: AppBar(
        title: Text(task?.orderCode ?? context.tr('Task detail')),
        actions: [
          IconButton(onPressed: _load, icon: const Icon(Icons.refresh)),
        ],
      ),
      body: _loading && task == null
          ? const Center(child: CircularProgressIndicator())
          : _error != null && task == null
              ? Center(child: Text(context.tr(_error!)))
              : task == null
                  ? Center(child: Text(context.tr('Task not found')))
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: ListView(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
                        children: [
                          _HeaderCard(task: task),
                          const SizedBox(height: 12),
                          _AddressCard(task: task),
                          if (task.customerPhotoUrls.isNotEmpty) ...[
                            const SizedBox(height: 12),
                            Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: PartnerColors.line),
                              ),
                              child: CustomerPhotosStrip(
                                urls: task.customerPhotoUrls,
                                title: task.isDeliveryService ? 'Parcel photo from customer' : 'Customer photo',
                              ),
                            ),
                          ],
                          const SizedBox(height: 12),
                          JobContactCard(task: task),
                          if (task.legs.isNotEmpty) ...[
                            const SizedBox(height: 12),
                            _LegsCard(legs: task.legs),
                          ],
                          if (task.needsCompletePhotos) ...[
                            const SizedBox(height: 12),
                            _PhotosCard(
                              task: task,
                              onAdd: () async {
                                await uploadPartnerJobPhotos(context, session, task);
                                await _load();
                              },
                            ),
                          ],
                          const SizedBox(height: 16),
                          _DetailActions(
                            task: task,
                            session: session,
                            onChanged: _load,
                          ),
                        ],
                      ),
                    ),
    );
  }
}

class _HeaderCard extends StatelessWidget {
  const _HeaderCard({required this.task});
  final PartnerTask task;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
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
                child: Text(task.title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
              ),
              Text(
                '₹${task.estEarning.toStringAsFixed(2)}',
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: PartnerColors.primary),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            '${context.tr(task.category)} · ${context.tr(task.status)}',
            style: const TextStyle(color: PartnerColors.muted),
          ),
          if (task.legType != null) ...[
            const SizedBox(height: 4),
            Text(
              context.tr('Your leg: {leg}', {'leg': context.tr(task.legType!)}),
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ],
          if (task.notes != null && task.notes!.trim().isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              context.tr('Notes: {notes}', {'notes': task.notes}),
              style: const TextStyle(color: PartnerColors.muted),
            ),
          ],
        ],
      ),
    );
  }
}

class _AddressCard extends StatelessWidget {
  const _AddressCard({required this.task});
  final PartnerTask task;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: PartnerColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(context.tr('Locations'), style: const TextStyle(fontWeight: FontWeight.w800)),
          const SizedBox(height: 10),
          Text(context.tr('Pickup'), style: TextStyle(fontSize: 12, color: PartnerColors.muted, fontWeight: FontWeight.w600)),
          Text(task.pickup, style: const TextStyle(fontWeight: FontWeight.w600)),
          if (task.hasDrop) ...[
            const SizedBox(height: 10),
            Text(context.tr('Drop'), style: TextStyle(fontSize: 12, color: PartnerColors.muted, fontWeight: FontWeight.w600)),
            Text(task.drop, style: const TextStyle(fontWeight: FontWeight.w600)),
          ],
        ],
      ),
    );
  }
}

class _LegsCard extends StatelessWidget {
  const _LegsCard({required this.legs});
  final List<Map<String, dynamic>> legs;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: PartnerColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(context.tr('Laundry flow'), style: const TextStyle(fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          ...legs.map((leg) {
            final type = leg['leg_type']?.toString() ?? leg['label']?.toString() ?? 'Leg';
            final status = leg['status']?.toString() ?? '';
            final partner = leg['partner'] is Map
                ? (leg['partner'] as Map)['name']?.toString()
                : leg['partner_name']?.toString();
            return ListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              title: Text(context.tr(type), style: const TextStyle(fontWeight: FontWeight.w700)),
              subtitle: Text(partner ?? context.tr('Waiting for partner')),
              trailing: Text(context.tr(status), style: const TextStyle(color: PartnerColors.muted, fontSize: 12)),
            );
          }),
        ],
      ),
    );
  }
}

class _PhotosCard extends StatelessWidget {
  const _PhotosCard({required this.task, required this.onAdd});
  final PartnerTask task;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
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
                child: Text(context.tr('Completed photos'), style: const TextStyle(fontWeight: FontWeight.w800)),
              ),
              TextButton.icon(
                onPressed: onAdd,
                icon: const Icon(Icons.add_a_photo_outlined, size: 18),
                label: Text(context.tr(task.photoUrls.isEmpty ? 'Add photos' : 'Add more')),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (task.photoUrls.isEmpty)
            Text(
              context.tr('Upload clear photos of completed laundry before marking complete.'),
              style: const TextStyle(color: PartnerColors.muted),
            )
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final url in task.photoUrls)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Image.network(
                      url,
                      width: 96,
                      height: 96,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => Container(
                        width: 96,
                        height: 96,
                        color: PartnerColors.chip,
                        child: const Icon(Icons.broken_image_outlined),
                      ),
                    ),
                  ),
              ],
            ),
        ],
      ),
    );
  }
}

class _DetailActions extends StatelessWidget {
  const _DetailActions({
    required this.task,
    required this.session,
    required this.onChanged,
  });

  final PartnerTask task;
  final SessionController session;
  final Future<void> Function() onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
                          if (task.canNavigate)
                            SizedBox(
                              width: double.infinity,
                              child: OutlinedButton.icon(
                                onPressed: () => openJobRoute(context, task),
                                icon: const Icon(Icons.navigation_outlined),
                                label: Text(context.tr('Show route')),
                              ),
                            ),
                          if (task.needsCompletePhotos &&
                              task.legs.any((l) =>
                                  l['leg_type']?.toString() == 'laundry' &&
                                  l['status']?.toString() == 'completed') &&
                              task.legs.any((l) =>
                                  l['leg_type']?.toString() == 'drop' &&
                                  (l['status']?.toString() == 'pending' ||
                                      l['partner'] == null)) &&
                              task.bookingId != null) ...[
                            const SizedBox(height: 8),
                            SizedBox(
                              width: double.infinity,
                              child: FilledButton.icon(
                                onPressed: () {
                                  Navigator.of(context).push(
                                    MaterialPageRoute<void>(
                                      builder: (_) => SearchingDeliveryScreen(
                                        bookingId: task.bookingId!,
                                      ),
                                    ),
                                  );
                                },
                                icon: const Icon(Icons.radar),
                                label: Text(context.tr('View delivery search')),
                              ),
                            ),
                          ],
                          if (task.status == 'pending') ...[
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () async {
                    await session.rejectTask(task.id);
                    if (context.mounted) Navigator.pop(context);
                  },
                  child: Text(context.tr('Reject')),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: FilledButton(
                  onPressed: () async {
                    await session.acceptTask(task.id);
                    await onChanged();
                  },
                  child: Text(context.tr('Accept')),
                ),
              ),
            ],
          ),
        ],
        if (task.waitingForPickup) ...[
          const SizedBox(height: 8),
          Text(
            context.tr('Waiting for clothes'),
            textAlign: TextAlign.center,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ] else if (task.status == 'accepted' || task.status == 'arrived') ...[
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () async {
                if (task.isPickupLeg && !task.arrivedAtStop) {
                  await markPartnerArrived(context, session, task);
                } else if (task.status == 'accepted' && task.isDeliveryService) {
                  await markPartnerArrived(context, session, task);
                } else {
                  await startPartnerJob(context, session, task);
                }
                await onChanged();
              },
              child: Text(
                context.tr(task.isPickupLeg
                    ? (task.arrivedAtStop
                        ? 'Pickup clothes photo + OTP'
                        : 'Arrived at pickup')
                    : (task.status == 'accepted' && task.isDeliveryService
                        ? 'Arrived at pickup'
                        : (task.isDeliveryService
                            ? 'Pick goods & start'
                            : (task.isOnSiteService ? 'Start service' : 'Start task')))),
              ),
            ),
          ),
        ],
        if (!task.waitingForPickup && task.status == 'in_progress') ...[
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () async {
                await completePartnerJob(context, session, task);
                await onChanged();
              },
              style: FilledButton.styleFrom(backgroundColor: PartnerColors.success),
              child: Text(context.tr(task.isPickupLeg ? 'Drop clothes at laundry' : 'Complete')),
            ),
          ),
        ],
      ],
    );
  }
}
