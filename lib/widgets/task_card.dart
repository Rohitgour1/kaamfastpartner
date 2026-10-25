import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:kaamfast_partner/data/mock_data.dart';
import 'package:kaamfast_partner/features/tasks/task_detail_screen.dart';
import 'package:kaamfast_partner/l10n/app_strings.dart';
import 'package:kaamfast_partner/theme/partner_theme.dart';
import 'package:kaamfast_partner/widgets/customer_photos_strip.dart';
import 'package:kaamfast_partner/widgets/job_contact_card.dart';

class TaskCard extends StatelessWidget {
  const TaskCard({
    super.key,
    required this.task,
    this.businessMode = false,
    this.onTap,
    this.onAccept,
    this.onReject,
    this.onStart,
    this.onArrived,
    this.onComplete,
    this.onAssignRider,
    this.onUploadPhotos,
    this.onNavigate,
  });

  final PartnerTask task;
  final bool businessMode;
  final VoidCallback? onTap;
  final VoidCallback? onAccept;
  final VoidCallback? onReject;
  final VoidCallback? onStart;
  final VoidCallback? onArrived;
  final VoidCallback? onComplete;
  final VoidCallback? onAssignRider;
  final VoidCallback? onUploadPhotos;
  final VoidCallback? onNavigate;

  void _openDetail(BuildContext context) {
    if (onTap != null) {
      onTap!();
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => TaskDetailScreen(taskId: task.id),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: () => _openDetail(context),
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: PartnerColors.line),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: PartnerColors.accentSoft,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        task.orderCode,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: PartnerColors.primary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(task.time, style: const TextStyle(fontSize: 12, color: PartnerColors.muted)),
                    const Spacer(),
                    Text(
                      context.tr(task.category),
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: PartnerColors.accent,
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Icon(Icons.chevron_right, size: 18, color: PartnerColors.muted),
                  ],
                ),
                if ((task.handoffOtp ?? '').isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF4E5),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.orange.shade200),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          context.tr('Give this OTP to the delivery partner'),
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          task.handoffOtp!.split('').join(' '),
                          style: GoogleFonts.hankenGrotesk(
                            fontSize: 28,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 4,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(task.title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                          if (task.legType != null) ...[
                            const SizedBox(height: 2),
                            Text(
                              context.tr(_legLabel(task.legType!)),
                              style: const TextStyle(fontSize: 12, color: PartnerColors.muted, fontWeight: FontWeight.w600),
                            ),
                          ],
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              const Icon(Icons.location_on, size: 15, color: PartnerColors.primary),
                              const SizedBox(width: 2),
                              Flexible(
                                child: Text(
                                  task.distance.isEmpty ? context.tr('Tap for details') : task.distance,
                                  style: const TextStyle(fontSize: 12, color: PartnerColors.muted),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(context.tr('Fare'), style: const TextStyle(fontSize: 11, color: PartnerColors.muted)),
                        Text(
                          '₹${task.estEarning.toStringAsFixed(2)}',
                          style: GoogleFonts.hankenGrotesk(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: PartnerColors.primary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Divider(height: 1, color: PartnerColors.line),
                ),
                _Leg(
                  dot: PartnerColors.accent,
                  label: context.tr(task.isOnSiteService
                      ? 'Customer'
                      : task.isDropLeg
                          ? 'From laundry'
                          : 'Pickup'),
                  value: task.pickup,
                ),
                if (task.hasDrop && !task.isOnSiteService) ...[
                  const SizedBox(height: 8),
                  _Leg(dot: PartnerColors.danger, label: context.tr('Drop'), value: task.drop),
                ],
                if (task.customerPhotoUrls.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  CustomerPhotosStrip(
                    urls: task.customerPhotoUrls,
                    title: task.isDeliveryService ? 'Parcel photo' : 'Customer photo',
                  ),
                ],
                if (task.needsCompletePhotos && (task.photoUrls.isNotEmpty || task.status == 'in_progress')) ...[
                  const SizedBox(height: 12),
                  GestureDetector(
                    onTap: () {},
                    behavior: HitTestBehavior.opaque,
                    child: _PhotoStrip(
                      urls: task.photoUrls,
                      onAddMore: onUploadPhotos,
                    ),
                  ),
                ],
                const SizedBox(height: 14),
                if (task.assignedRider != null)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    margin: const EdgeInsets.only(bottom: 10),
                    decoration: BoxDecoration(
                      color: PartnerColors.chip,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.two_wheeler, size: 16, color: PartnerColors.primary),
                        const SizedBox(width: 6),
                        Text(
                          context.tr('Assigned: {name}', {'name': task.assignedRider}),
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                        ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(6)),
                          child: Text(
                            context.tr('In Transit'),
                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800),
                          ),
                        ),
                      ],
                    ),
                  ),
                GestureDetector(
                  onTap: () {},
                  behavior: HitTestBehavior.opaque,
                  child: _ActionButtons(
                    task: task,
                    businessMode: businessMode,
                    onAccept: onAccept,
                    onReject: onReject,
                    onStart: onStart,
                    onArrived: onArrived,
                    onComplete: onComplete,
                    onAssignRider: onAssignRider,
                    onUploadPhotos: onUploadPhotos,
                    onNavigate: onNavigate,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _legLabel(String type) => switch (type) {
        'pickup' => 'Pickup delivery',
        'laundry' => 'Laundry service',
        'drop' => 'Return delivery',
        _ => type,
      };
}

class _PhotoStrip extends StatelessWidget {
  const _PhotoStrip({required this.urls, this.onAddMore});

  final List<String> urls;
  final VoidCallback? onAddMore;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.tr('Completed photos'),
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: PartnerColors.muted),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 72,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              ...urls.map(
                (url) => Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: GestureDetector(
                    onTap: () => _preview(context, url),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Image.network(
                        url,
                        width: 72,
                        height: 72,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => Container(
                          width: 72,
                          height: 72,
                          color: PartnerColors.chip,
                          child: const Icon(Icons.broken_image_outlined, color: PartnerColors.muted),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              Material(
                color: PartnerColors.accentSoft,
                borderRadius: BorderRadius.circular(10),
                child: InkWell(
                  onTap: onAddMore,
                  borderRadius: BorderRadius.circular(10),
                  child: SizedBox(
                    width: 72,
                    height: 72,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.add_a_photo_outlined, color: PartnerColors.primary, size: 22),
                        const SizedBox(height: 4),
                        Text(
                          context.tr(urls.isEmpty ? 'Add photo' : 'Add more'),
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: PartnerColors.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _preview(BuildContext context, String url) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        insetPadding: const EdgeInsets.all(16),
        child: InteractiveViewer(
          child: Image.network(url, fit: BoxFit.contain),
        ),
      ),
    );
  }
}

class _ActionButtons extends StatelessWidget {
  const _ActionButtons({
    required this.task,
    required this.businessMode,
    this.onAccept,
    this.onReject,
    this.onStart,
    this.onArrived,
    this.onComplete,
    this.onAssignRider,
    this.onUploadPhotos,
    this.onNavigate,
  });

  final PartnerTask task;
  final bool businessMode;
  final VoidCallback? onAccept;
  final VoidCallback? onReject;
  final VoidCallback? onStart;
  final VoidCallback? onArrived;
  final VoidCallback? onComplete;
  final VoidCallback? onAssignRider;
  final VoidCallback? onUploadPhotos;
  final VoidCallback? onNavigate;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        if (task.status == 'pending') ...[
          SizedBox(
            width: 44,
            height: 40,
            child: OutlinedButton(
              onPressed: onReject,
              style: OutlinedButton.styleFrom(
                padding: EdgeInsets.zero,
                side: const BorderSide(color: PartnerColors.dangerSoft),
                foregroundColor: PartnerColors.danger,
              ),
              child: const Icon(Icons.close, size: 18),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: FilledButton(
              onPressed: onAccept,
              style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(40)),
              child: Text(context.tr('Accept Task'), style: const TextStyle(fontSize: 13)),
            ),
          ),
              ] else if (task.status == 'accepted' || task.status == 'arrived') ...[
                if (businessMode)
                  Expanded(
                    child: FilledButton(
                      onPressed: onAssignRider,
                      style: FilledButton.styleFrom(
                        backgroundColor: PartnerColors.primary.withValues(alpha: 0.1),
                        foregroundColor: PartnerColors.primary,
                        minimumSize: const Size.fromHeight(40),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.person_add_alt_1, size: 18),
                          const SizedBox(width: 6),
                          Text(context.tr('Assign Rider'), style: const TextStyle(fontSize: 13)),
                        ],
                      ),
                    ),
                  )
                else if (task.waitingForPickup)
                  Expanded(
                    child: Text(
                      context.tr('Waiting for clothes'),
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: PartnerColors.muted, fontWeight: FontWeight.w600),
                    ),
                  )
                else if (task.isPickupLeg)
                  Expanded(child: _PickupActions(task: task, onNavigate: onNavigate, onArrived: onArrived, onStart: onStart))
                else
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if ((task.senderName ?? '').isNotEmpty ||
                            (task.receiverName ?? '').isNotEmpty ||
                            (task.customerName ?? '').isNotEmpty) ...[
                          JobContactCard(task: task, compact: true),
                          const SizedBox(height: 8),
                        ],
                        if (task.canNavigate) ...[
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton.icon(
                              onPressed: onNavigate,
                              icon: const Icon(Icons.navigation_outlined, size: 18),
                              label: Text(
                                context.tr(task.status == 'accepted' && task.isDeliveryService
                                    ? 'Navigate to pickup'
                                    : (task.isOnSiteService ? 'Navigate to customer' : 'Navigate / show route')),
                                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                              ),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: PartnerColors.primary,
                                side: const BorderSide(color: PartnerColors.primary),
                                minimumSize: const Size.fromHeight(40),
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                        ],
                        if (task.status == 'accepted' && task.isDeliveryService)
                          SizedBox(
                            width: double.infinity,
                            child: FilledButton(
                              onPressed: onArrived,
                              style: FilledButton.styleFrom(
                                backgroundColor: PartnerColors.primary,
                                minimumSize: const Size.fromHeight(40),
                              ),
                              child: Text(context.tr('Arrived at pickup'), style: const TextStyle(fontSize: 13)),
                            ),
                          )
                        else
                          SizedBox(
                            width: double.infinity,
                            child: FilledButton(
                              onPressed: onStart,
                              style: FilledButton.styleFrom(
                                backgroundColor: PartnerColors.accent,
                                minimumSize: const Size.fromHeight(40),
                              ),
                              child: Text(
                                context.tr(task.isDeliveryService
                                    ? 'Pick goods & start'
                                    : (task.isOnSiteService ? 'Start service' : 'Start task')),
                                style: const TextStyle(fontSize: 13),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
              ] else if (task.status == 'in_progress') ...[
                if (task.waitingForPickup)
                  Expanded(
                    child: Text(
                      context.tr('Waiting for clothes'),
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: PartnerColors.muted, fontWeight: FontWeight.w600),
                    ),
                  )
                else if (task.isPickupLeg)
                  Expanded(
                    child: SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: onComplete,
                        style: FilledButton.styleFrom(
                          backgroundColor: PartnerColors.success,
                          minimumSize: const Size.fromHeight(40),
                        ),
                        child: Text(context.tr('Drop clothes at laundry'), style: const TextStyle(fontSize: 13)),
                      ),
                    ),
                  )
                else
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (task.canNavigate) ...[
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton.icon(
                              onPressed: onNavigate,
                              icon: const Icon(Icons.navigation_outlined, size: 18),
                              label: Text(
                                context.tr(task.isOnSiteService ? 'Navigate to customer' : 'Show route'),
                                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                              ),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: PartnerColors.primary,
                                side: const BorderSide(color: PartnerColors.primary),
                                minimumSize: const Size.fromHeight(40),
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                        ],
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton(
                            onPressed: onComplete,
                            style: FilledButton.styleFrom(
                              backgroundColor: PartnerColors.success,
                              minimumSize: const Size.fromHeight(40),
                            ),
                            child: Text(
                              context.tr(_completeLabel(task)),
                              style: const TextStyle(fontSize: 13),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
              ] else ...[
          Expanded(
            child: Text(
              context.tr('Completed & Payout Credited'),
              textAlign: TextAlign.center,
              style: const TextStyle(color: PartnerColors.success, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ],
    );
  }

  String _completeLabel(PartnerTask task) {
    if (task.needsCompletePhotos) {
      return task.photoCount > 0 ? 'Mark laundry complete' : 'Upload photos & complete';
    }
    if (task.isPickupLeg) return 'Drop clothes at laundry';
    if (task.isDropLeg) {
      return task.isCash ? 'Collect cash & complete' : 'Verify OTP & complete drop';
    }
    if (task.isOnSiteService) return 'Verify OTP & end service';
    return 'Enter Customer OTP & Complete';
  }
}

class _PickupActions extends StatelessWidget {
  const _PickupActions({
    required this.task,
    this.onNavigate,
    this.onArrived,
    this.onStart,
  });

  final PartnerTask task;
  final VoidCallback? onNavigate;
  final VoidCallback? onArrived;
  final VoidCallback? onStart;

  @override
  Widget build(BuildContext context) {
    final collect = task.arrivedAtStop;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (task.canNavigate) ...[
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: onNavigate,
              icon: const Icon(Icons.navigation_outlined, size: 18),
              label: Text(
                context.tr(collect ? 'Navigate to laundry' : 'Navigate to pickup'),
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: PartnerColors.primary,
                side: const BorderSide(color: PartnerColors.primary),
                minimumSize: const Size.fromHeight(40),
              ),
            ),
          ),
          const SizedBox(height: 8),
        ],
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: collect ? onStart : onArrived,
            style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(40)),
            child: Text(
              context.tr(collect ? 'Pickup clothes photo + OTP' : 'Arrived at pickup'),
              style: const TextStyle(fontSize: 13),
            ),
          ),
        ),
      ],
    );
  }
}

class _Leg extends StatelessWidget {
  const _Leg({required this.dot, required this.label, required this.value});
  final Color dot;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 10,
          height: 10,
          margin: const EdgeInsets.only(top: 4),
          decoration: BoxDecoration(color: dot, shape: BoxShape.circle),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(fontSize: 11, color: PartnerColors.muted, fontWeight: FontWeight.w600)),
              Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ],
    );
  }
}
