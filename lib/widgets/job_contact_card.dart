import 'package:flutter/material.dart';
import 'package:kaamfast_partner/data/mock_data.dart';
import 'package:kaamfast_partner/features/tasks/booking_chat_screen.dart';
import 'package:kaamfast_partner/l10n/app_strings.dart';
import 'package:kaamfast_partner/theme/partner_theme.dart';
import 'package:url_launcher/url_launcher.dart';

/// Shows contact name (no phone) with Call + in-app Chat actions.
class JobContactCard extends StatelessWidget {
  const JobContactCard({
    super.key,
    required this.task,
    this.compact = false,
  });

  final PartnerTask task;
  final bool compact;

  String get _role {
    if (task.status == 'in_progress' && (task.receiverName ?? '').trim().isNotEmpty) {
      return 'Receiver';
    }
    if ((task.senderName ?? '').trim().isNotEmpty || (task.senderPhone ?? '').trim().isNotEmpty) {
      return 'Sender';
    }
    return 'Customer';
  }

  String get _name {
    if (_role == 'Receiver') {
      final n = (task.receiverName ?? '').trim();
      if (n.isNotEmpty) return n;
    }
    if (_role == 'Sender') {
      final n = (task.senderName ?? '').trim();
      if (n.isNotEmpty) return n;
    }
    return (task.customerName ?? 'Customer').trim().isEmpty
        ? 'Customer'
        : task.customerName!.trim();
  }

  String _displayName(BuildContext context) => _name == 'Customer' ? context.tr('Customer') : _name;

  String? get _phone {
    if (_role == 'Receiver') {
      final p = (task.receiverPhone ?? '').trim();
      if (p.isNotEmpty) return p;
    }
    if (_role == 'Sender') {
      final p = (task.senderPhone ?? '').trim();
      if (p.isNotEmpty) return p;
    }
    final c = (task.customerPhone ?? '').trim();
    return c.isEmpty ? null : c;
  }

  Future<void> _call(BuildContext context) async {
    final raw = (_phone ?? '').replaceAll(RegExp(r'[^\d+]'), '');
    if (raw.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.tr('Phone number not available'))),
      );
      return;
    }
    var digits = raw.replaceAll(RegExp(r'\D'), '');
    if (digits.length == 10) digits = '91$digits';
    final uri = Uri.parse('tel:+$digits');
    if (!await launchUrl(uri)) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.tr('Could not open dialer'))),
        );
      }
    }
  }

  void _openChat(BuildContext context) {
    final id = task.bookingId;
    if (id == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.tr('Chat unavailable for this task'))),
      );
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => BookingChatScreen(
          bookingId: id,
          title: '${context.tr(_role)} · ${_displayName(context)}',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_name == 'Customer' &&
        (task.senderName ?? '').isEmpty &&
        (task.receiverName ?? '').isEmpty &&
        (task.customerName ?? '').isEmpty &&
        _phone == null) {
      return const SizedBox.shrink();
    }

    final header = Row(
      children: [
        CircleAvatar(
          radius: compact ? 18 : 22,
          backgroundColor: PartnerColors.primary.withValues(alpha: 0.12),
          child: Icon(Icons.person, color: PartnerColors.primary, size: compact ? 18 : 22),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                context.tr(_role),
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: PartnerColors.muted,
                  letterSpacing: 0.3,
                ),
              ),
              Text(
                _displayName(context),
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: compact ? 14 : 15,
                ),
              ),
            ],
          ),
        ),
      ],
    );

    final actions = Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () => _call(context),
            icon: const Icon(Icons.call_outlined, size: 18),
            label: Text(context.tr('Call')),
            style: OutlinedButton.styleFrom(
              foregroundColor: PartnerColors.primary,
              side: BorderSide(color: PartnerColors.primary.withValues(alpha: 0.35)),
              padding: const EdgeInsets.symmetric(vertical: 10),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: FilledButton.icon(
            onPressed: () => _openChat(context),
            icon: const Icon(Icons.chat_bubble_outline, size: 18),
            label: Text(context.tr('Chat')),
            style: FilledButton.styleFrom(
              backgroundColor: PartnerColors.primary,
              padding: const EdgeInsets.symmetric(vertical: 10),
            ),
          ),
        ),
      ],
    );

    if (compact) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          header,
          const SizedBox(height: 10),
          actions,
        ],
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: PartnerColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          header,
          const SizedBox(height: 12),
          actions,
        ],
      ),
    );
  }
}
