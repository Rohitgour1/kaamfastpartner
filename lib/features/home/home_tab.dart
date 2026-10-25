import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:kaamfast_partner/data/mock_data.dart';
import 'package:kaamfast_partner/data/partner_incentive.dart';
import 'package:kaamfast_partner/l10n/app_strings.dart';
import 'package:kaamfast_partner/state/session_controller.dart';
import 'package:kaamfast_partner/theme/partner_theme.dart';
import 'package:kaamfast_partner/widgets/job_complete_helper.dart';
import 'package:kaamfast_partner/widgets/job_navigation.dart';
import 'package:kaamfast_partner/widgets/online_toggle_helper.dart';
import 'package:kaamfast_partner/widgets/task_card.dart';
import 'package:provider/provider.dart';

class HomeTab extends StatelessWidget {
  const HomeTab({super.key});

  @override
  Widget build(BuildContext context) {
    final session = context.watch<SessionController>();
    final user = session.user;
    if (user == null) {
      return Center(child: Text(context.tr('No session')));
    }

    if (user.role == PartnerRole.business) {
      return _BusinessHome(user: user, tasks: session.tasks);
    }
    return _DeliveryHome(user: user, tasks: session.tasks);
  }
}

class _DeliveryHome extends StatelessWidget {
  const _DeliveryHome({required this.user, required this.tasks});

  final PartnerUser user;
  final List<PartnerTask> tasks;

  @override
  Widget build(BuildContext context) {
    final session = context.read<SessionController>();
    final pending = tasks.where((t) => t.status == 'pending').toList();
    final upcoming = tasks.where((t) => t.status != 'pending' && t.status != 'completed').toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
      children: [
        _GreetingHeader(user: user),
        const SizedBox(height: 14),
        _EarningsBanner(user: user),
        const SizedBox(height: 14),
        _AvailabilitySection(user: user),
        if (session.incentive != null) ...[
          const SizedBox(height: 14),
          _IncentiveBanner(
            incentive: session.incentive!,
            jobWord: user.role == PartnerRole.delivery ? 'deliveries' : 'jobs',
          ),
        ],
        const SizedBox(height: 18),
        Row(
          children: [
            Text(
              _requestsHeading(context, user),
              style: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 13, letterSpacing: 0.8),
            ),
            const Spacer(),
            Row(
              children: [
                const _LiveDot(),
                const SizedBox(width: 6),
                Text(
                  context.tr('Live'),
                  style: const TextStyle(color: PartnerColors.primary, fontWeight: FontWeight.w700, fontSize: 12),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 10),
        if (pending.isEmpty)
          _EmptyBox(message: context.tr('Keep an eye out for new service requests!'))
        else
          ...pending.map(
            (t) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: TaskCard(
                task: t,
                onAccept: () async {
                  try {
                    await session.acceptTask(t.id);
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
                    }
                  }
                },
                onReject: () async {
                  try {
                    await session.rejectTask(t.id);
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
                    }
                  }
                },
                onStart: () => startPartnerJob(context, session, t),
                onArrived: () => markPartnerArrived(context, session, t),
                onComplete: () => completePartnerJob(context, session, t),
                onUploadPhotos: () => uploadPartnerJobPhotos(context, session, t),
                onNavigate: () => openJobRoute(context, t),
              ),
            ),
          ),
        const SizedBox(height: 8),
        Text(
          context.tr('Upcoming jobs').toUpperCase(),
          style: GoogleFonts.inter(
            fontWeight: FontWeight.w800,
            fontSize: 12,
            letterSpacing: 0.8,
            color: PartnerColors.muted,
          ),
        ),
        const SizedBox(height: 10),
        if (upcoming.isEmpty)
          _EmptyBox(message: context.tr('No active jobs right now'))
        else
          ...upcoming.map(
            (t) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: TaskCard(
                task: t,
                onAccept: () async {
                  try {
                    await session.acceptTask(t.id);
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
                    }
                  }
                },
                onReject: () async {
                  try {
                    await session.rejectTask(t.id);
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
                    }
                  }
                },
                onStart: () => startPartnerJob(context, session, t),
                onArrived: () => markPartnerArrived(context, session, t),
                onComplete: () => completePartnerJob(context, session, t),
                onUploadPhotos: () => uploadPartnerJobPhotos(context, session, t),
                onNavigate: () => openJobRoute(context, t),
              ),
            ),
          ),
      ],
    );
  }
}

String _requestsHeading(BuildContext context, PartnerUser user) {
  if (user.role == PartnerRole.delivery) return context.tr('Delivery requests').toUpperCase();
  if (user.workTypes.length != 1) return context.tr('Service requests').toUpperCase();
  final type = user.workTypes.first.trim();
  final label = type.toLowerCase() == 'cleaner' ? 'Cleaning' : type;
  return context.tr('{type} requests', {'type': context.tr(label)}).toUpperCase();
}

class _BusinessHome extends StatelessWidget {
  const _BusinessHome({required this.user, required this.tasks});

  final PartnerUser user;
  final List<PartnerTask> tasks;

  @override
  Widget build(BuildContext context) {
    final session = context.read<SessionController>();

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
      children: [
        _GreetingHeader(user: user),
        const SizedBox(height: 14),
        _EarningsBanner(user: user),
        const SizedBox(height: 14),
        _AvailabilitySection(user: user),
        const SizedBox(height: 14),
        Row(
          children: [
            _StatChip(label: context.tr('Active'), value: '${user.activeJobsCount}'),
            const SizedBox(width: 8),
            _StatChip(label: context.tr('Available'), value: '${user.availableJobsCount}'),
            const SizedBox(width: 8),
            _StatChip(label: context.tr('Done today'), value: '${user.completedTodayCount}'),
          ],
        ),
        const SizedBox(height: 18),
        Text(
          context.tr('Laundry orders').toUpperCase(),
          style: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 13, letterSpacing: 0.8),
        ),
        const SizedBox(height: 10),
        ...tasks.map(
          (t) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: TaskCard(
              task: t,
              businessMode: true,
              onAccept: () async {
                try {
                  await session.acceptTask(t.id);
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
                  }
                }
              },
              onReject: () async {
                try {
                  await session.rejectTask(t.id);
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
                  }
                }
              },
              onStart: () async {
                try {
                  await session.startTask(t.id);
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
                  }
                }
              },
              onArrived: () => markPartnerArrived(context, session, t),
              onComplete: () => completePartnerJob(context, session, t),
              onUploadPhotos: () => uploadPartnerJobPhotos(context, session, t),
              onNavigate: () => openJobRoute(context, t),
              onAssignRider: () async {
                try {
                  await session.assignRider(t.id, 'Assigned rider');
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
                  }
                }
              },
            ),
          ),
        ),
      ],
    );
  }
}

class _GreetingHeader extends StatelessWidget {
  const _GreetingHeader({required this.user});
  final PartnerUser user;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        CircleAvatar(
          radius: 24,
          backgroundColor: PartnerColors.accentSoft,
          child: Text(
            user.name.isNotEmpty ? user.name[0] : 'P',
            style: const TextStyle(fontWeight: FontWeight.w800, color: PartnerColors.primary),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                context.tr(_timeGreeting),
                style: const TextStyle(color: PartnerColors.muted, fontSize: 13),
              ),
              Text(user.name, style: GoogleFonts.hankenGrotesk(fontSize: 20, fontWeight: FontWeight.w800)),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: user.isOnline ? PartnerColors.accentSoft : PartnerColors.chip,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            context.tr(user.isOnline ? 'Online' : 'Offline'),
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: user.isOnline ? PartnerColors.primary : PartnerColors.muted,
            ),
          ),
        ),
      ],
    );
  }

  String get _timeGreeting {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good Morning,';
    if (hour < 17) return 'Good Afternoon,';
    return 'Good Evening,';
  }
}

class _EarningsBanner extends StatelessWidget {
  const _EarningsBanner({required this.user});
  final PartnerUser user;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: PartnerColors.primaryDeep,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: PartnerColors.primaryDeep.withValues(alpha: 0.2),
            blurRadius: 25,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(context.tr("Today's Earnings"), style: const TextStyle(color: Colors.white70, fontSize: 12)),
                const SizedBox(height: 4),
                Text(
                  '₹${user.todayEarnings.toStringAsFixed(0)}',
                  style: GoogleFonts.hankenGrotesk(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w800),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              context.tr('{count} jobs', {'count': user.completedTodayCount}),
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}

class _AvailabilitySection extends StatelessWidget {
  const _AvailabilitySection({required this.user});

  final PartnerUser user;

  @override
  Widget build(BuildContext context) {
    final session = context.watch<SessionController>();
    if (!session.canGoOnline) {
      return _NoticeCard(
        icon: Icons.block,
        color: Colors.orange.shade800,
        text: context.tr("Your account can't receive orders yet. Complete KYC or contact support."),
        actionLabel: context.tr('Documents'),
        onAction: () => context.push('/kyc'),
      );
    }

    final services = session.serviceApprovals;
    final noneActive = services.isNotEmpty && session.approvedServices.isEmpty;
    return Column(
      children: [
        _OnlineCard(
          user: user,
          busy: session.availabilityBusy,
          onToggle: () async {
            try {
              await goOnlineWithOverlayPrompt(context, session);
            } catch (e) {
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
              }
            }
          },
        ),
        if (noneActive) ...[
          const SizedBox(height: 10),
          _NoticeCard(
            icon: Icons.hourglass_top,
            color: Colors.orange.shade800,
            text: context.tr("Your services are under review. You'll get orders after approval."),
            actionLabel: context.tr('My services'),
            onAction: () => context.push('/my-services'),
          ),
        ],
      ],
    );
  }
}

class _NoticeCard extends StatelessWidget {
  const _NoticeCard({
    required this.icon,
    required this.color,
    required this.text,
    required this.actionLabel,
    required this.onAction,
  });

  final IconData icon;
  final Color color;
  final String text;
  final String actionLabel;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color),
          const SizedBox(width: 10),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 13, height: 1.35))),
          TextButton(onPressed: onAction, child: Text(actionLabel)),
        ],
      ),
    );
  }
}

class _OnlineCard extends StatelessWidget {
  const _OnlineCard({required this.user, required this.onToggle, this.busy = false});
  final PartnerUser user;
  final VoidCallback onToggle;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: PartnerColors.line),
      ),
      child: Row(
        children: [
          Icon(
            user.isOnline ? Icons.wifi_tethering : Icons.wifi_off,
            color: user.isOnline ? PartnerColors.success : PartnerColors.muted,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(context.tr('Available for Work'), style: const TextStyle(fontWeight: FontWeight.w700)),
                Text(
                  context.tr(busy
                      ? 'Updating…'
                      : (user.isOnline ? 'Currently accepting orders' : 'You are offline')),
                  style: const TextStyle(fontSize: 12, color: PartnerColors.muted),
                ),
              ],
            ),
          ),
          if (busy)
            const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2))
          else
            Switch.adaptive(
              value: user.isOnline,
              activeThumbColor: Colors.white,
              activeTrackColor: PartnerColors.primary,
              onChanged: (_) => onToggle(),
            ),
        ],
      ),
    );
  }
}

class _IncentiveBanner extends StatelessWidget {
  const _IncentiveBanner({required this.incentive, required this.jobWord});

  final PartnerIncentive incentive;
  final String jobWord;

  @override
  Widget build(BuildContext context) {
    final bonus = '₹${incentive.bonusAmount.toStringAsFixed(0)}';
    final earned = incentive.earned;
    final remaining = incentive.remainingJobs;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: earned ? PartnerColors.accentSoft : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: PartnerColors.line),
      ),
      child: Row(
        children: [
          Icon(
            earned ? Icons.verified_rounded : Icons.emoji_events_outlined,
            color: earned ? PartnerColors.success : PartnerColors.accent,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.tr(earned ? 'Daily bonus earned!' : 'Daily Incentive Active!'),
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                Text(
                  earned
                      ? context.tr('{bonus} has been added to your wallet.', {'bonus': bonus})
                      : context.tr(
                          jobWord == 'deliveries'
                              ? 'Complete {count} more deliveries today to earn {bonus} extra bonus.'
                              : 'Complete {count} more jobs today to earn {bonus} extra bonus.',
                          {'count': remaining, 'bonus': bonus},
                        ),
                  style: const TextStyle(fontSize: 11, color: PartnerColors.muted),
                ),
                if (!earned) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: incentive.progress,
                            minHeight: 6,
                            backgroundColor: PartnerColors.chip,
                            color: PartnerColors.accent,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${incentive.completedJobs}/${incentive.targetJobs}',
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: PartnerColors.line),
        ),
        child: Column(
          children: [
            Text(value, style: GoogleFonts.hankenGrotesk(fontWeight: FontWeight.w800, fontSize: 18, color: PartnerColors.primary)),
            Text(label, style: const TextStyle(fontSize: 11, color: PartnerColors.muted)),
          ],
        ),
      ),
    );
  }
}

class _EmptyBox extends StatelessWidget {
  const _EmptyBox({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: PartnerColors.line),
      ),
      child: Column(
        children: [
          CircleAvatar(
            backgroundColor: PartnerColors.chip,
            child: const Icon(Icons.inbox_outlined, color: PartnerColors.muted),
          ),
          const SizedBox(height: 10),
          Text(message, textAlign: TextAlign.center, style: const TextStyle(color: PartnerColors.muted)),
        ],
      ),
    );
  }
}

class _LiveDot extends StatelessWidget {
  const _LiveDot();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 8,
      height: 8,
      decoration: const BoxDecoration(color: PartnerColors.primary, shape: BoxShape.circle),
    );
  }
}
