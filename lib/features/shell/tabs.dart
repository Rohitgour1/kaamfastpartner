import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:kaamfast_partner/core/app_constants.dart';
import 'package:kaamfast_partner/data/mock_data.dart';
import 'package:kaamfast_partner/l10n/app_strings.dart';
import 'package:kaamfast_partner/l10n/language_sheet.dart';
import 'package:kaamfast_partner/l10n/locale_controller.dart';
import 'package:kaamfast_partner/services/overlay_permission_service.dart';
import 'package:kaamfast_partner/services/partner_api.dart';
import 'package:kaamfast_partner/services/razorpay_checkout.dart';
import 'package:kaamfast_partner/state/session_controller.dart';
import 'package:kaamfast_partner/theme/partner_theme.dart';
import 'package:kaamfast_partner/widgets/job_complete_helper.dart';
import 'package:kaamfast_partner/widgets/job_navigation.dart';
import 'package:kaamfast_partner/widgets/legal_links.dart';
import 'package:kaamfast_partner/widgets/task_card.dart';
import 'package:kaamfast_partner/features/wallet/payment_method_screen.dart';
import 'package:kaamfast_partner/features/wallet/wallet_transactions_screen.dart'
    as ka;
import 'package:kaamfast_partner/features/wallet/withdrawal_history_screen.dart'
    as kb;
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

class TasksTab extends StatelessWidget {
  const TasksTab({super.key});

  Future<void> _run(
    BuildContext context,
    Future<void> Function() action,
  ) async {
    try {
      await action();
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('$e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = context.watch<SessionController>();
    final tasks = session.tasks;

    return RefreshIndicator(
      onRefresh: session.refreshTasks,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
        children: [
          Text(
            context.tr('Tasks Workspace'),
            style: GoogleFonts.hankenGrotesk(
              fontSize: 22,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            context.tr('Accept, start, and complete your jobs here.'),
            style: const TextStyle(color: PartnerColors.muted),
          ),
          const SizedBox(height: 16),
          if (session.tasksBusy)
            const Padding(
              padding: EdgeInsets.only(top: 40),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (tasks.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 40),
              child: Center(
                child: Text(
                  context.tr('No tasks yet — go online to receive jobs'),
                  style: const TextStyle(color: PartnerColors.muted),
                ),
              ),
            )
          else
            ...tasks.map(
              (t) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: TaskCard(
                  task: t,
                  businessMode: session.role == PartnerRole.business,
                  onAccept: () => _run(context, () => session.acceptTask(t.id)),
                  onReject: () => _run(context, () => session.rejectTask(t.id)),
                  onStart: () => startPartnerJob(context, session, t),
                  onArrived: () => markPartnerArrived(context, session, t),
                  onComplete: () => completePartnerJob(context, session, t),
                  onUploadPhotos: () =>
                      uploadPartnerJobPhotos(context, session, t),
                  onNavigate: () => openJobRoute(context, t),
                  onAssignRider: () => _run(
                    context,
                    () => session.assignRider(t.id, 'Assigned rider'),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class EarningsTab extends StatefulWidget {
  const EarningsTab({super.key});

  @override
  State<EarningsTab> createState() => _EarningsTabState();
}

class _EarningsTabState extends State<EarningsTab> {
  bool _busy = false;
  bool _hasBank = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<SessionController>().refreshEarnings();
      _loadBank();
    });
  }

  Future<void> _loadBank() async {
    try {
      final raw = await context.read<PartnerApi>().bankAccount();
      final bank = raw['bank_account'];
      final map = bank is Map ? Map<String, dynamic>.from(bank) : null;
      if (!mounted) return;
      setState(() {
        _hasBank =
            (map?['account_number']?.toString().trim().isNotEmpty ?? false) &&
            ((map?['ifsc_code'] ?? map?['ifsc'])
                    ?.toString()
                    .trim()
                    .isNotEmpty ??
                false);
      });
    } catch (_) {}
  }

  Future<bool> _ensureBank() async {
    if (_hasBank) return true;
    final saved = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const PaymentMethodScreen()),
    );
    await _loadBank();
    if (!mounted) return false;
    if (saved == true && _hasBank) return true;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(context.tr('Save a payment method before withdrawing')),
      ),
    );
    return false;
  }

  Future<void> _addMoney() async {
    final amount = await _askAmount(
      context,
      title: context.tr('Add money'),
      confirmLabel: context.tr('Pay with Razorpay'),
    );
    if (amount == null || !mounted) return;
    setState(() => _busy = true);
    try {
      final session = context.read<SessionController>();
      final api = context.read<PartnerApi>();
      final order = await api.walletTopup(amount);
      final topupId = (order['id'] as num?)?.toInt();
      if (topupId == null) {
        throw Exception(AppStrings.tr('Could not start wallet top-up.'));
      }
      var key = order['razorpay_key']?.toString().trim() ?? '';
      if (key.isEmpty) {
        try {
          final config = await api.paymentConfig();
          key = config['key_id']?.toString().trim() ?? '';
        } catch (_) {}
      }
      if (key.isEmpty) {
        throw Exception(
          AppStrings.tr('Razorpay Key ID missing. Save it in Admin → Payments.'),
        );
      }
      final mock = order['mock'] == true;
      final paid = await RazorpayCheckout().open(
        key: key,
        orderId: mock ? '' : (order['gateway_order_id']?.toString() ?? ''),
        amountPaise:
            (order['amount_paise'] as num?)?.toInt() ?? (amount * 100).round(),
        description: AppStrings.tr('Partner wallet top-up'),
        contact: session.user?.mobile,
      );
      await api.confirmWalletTopup(topupId, paid);
      await session.refreshEarnings();
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(context.tr('Wallet credited'))));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _withdraw() async {
    if (!await _ensureBank() || !mounted) return;
    final amount = await _askAmount(
      context,
      title: context.tr('Withdraw'),
      confirmLabel: context.tr('Request withdrawal'),
    );
    if (amount == null || !mounted) return;
    final upi = await _askText(
      context,
      title: context.tr('UPI ID'),
      hint: 'name@ybl',
    );
    if (!mounted || upi == null || upi.trim().isEmpty) return;
    if (!RegExp(
      r'^[a-zA-Z0-9.\-_]{2,256}@[a-zA-Z]{2,64}$',
    ).hasMatch(upi.trim())) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.tr('Enter a valid UPI ID, like name@ybl')),
        ),
      );
      return;
    }
    setState(() => _busy = true);
    try {
      await context.read<PartnerApi>().walletWithdraw(
        amount: amount,
        upiId: upi.trim(),
      );
      await context.read<SessionController>().refreshEarnings();
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(
        SnackBar(content: Text(context.tr('Withdrawal requested'))),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = context.watch<SessionController>();
    final summary = session.earningsSummary;
    final balance = (summary?['wallet_balance'] as num?)?.toDouble() ?? 0;
    final today =
        (summary?['today_earnings'] as num?)?.toDouble() ??
        session.user?.todayEarnings ??
        0;
    final total = (summary?['total_earnings'] as num?)?.toDouble() ?? 0;
    final jobs = (summary?['completed_jobs'] as num?)?.toInt() ?? 0;
    final pending = (summary?['pending_settlements'] as num?)?.toInt() ?? 0;

    return RefreshIndicator(
      onRefresh: session.refreshEarnings,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
        children: [
          Text(
            'Earnings & Payouts',
            style: GoogleFonts.hankenGrotesk(
              fontSize: 22,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [PartnerColors.primaryDeep, PartnerColors.accent],
              ),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.tr('Available Balance for Payout'),
                  style: const TextStyle(color: Colors.white70),
                ),
                const SizedBox(height: 6),
                Text(
                  '₹${balance.toStringAsFixed(0)}',
                  style: GoogleFonts.hankenGrotesk(
                    color: Colors.white,
                    fontSize: 32,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  context.tr('{count} pending settlement(s)', {
                    'count': pending,
                  }),
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: FilledButton(
                        onPressed: _busy ? null : _addMoney,
                        style: FilledButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: PartnerColors.primary,
                        ),
                        child: Text(context.tr('Add money')),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _busy ? null : _withdraw,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white,
                          side: const BorderSide(color: Colors.white70),
                        ),
                        child: Text(context.tr('Withdraw')),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          ListTile(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: const BorderSide(color: PartnerColors.line),
            ),
            tileColor: Colors.white,
            leading: const Icon(Icons.account_balance_outlined),
            title: Text(context.tr('Payment method')),
            subtitle: Text(
              context.tr(
                _hasBank
                    ? 'Bank account saved'
                    : 'Add bank account for withdrawals',
              ),
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () async {
              final saved = await Navigator.push<bool>(
                context,
                MaterialPageRoute(builder: (_) => const PaymentMethodScreen()),
              );
              if (saved == true) await _loadBank();
            },
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const ka.WalletTransactionsScreen(),
                    ),
                  ),
                  icon: const Icon(Icons.receipt_long),
                  label: Text(context.tr('Transactions')),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const kb.WithdrawalHistoryScreen(),
                    ),
                  ),
                  icon: const Icon(Icons.history),
                  label: Text(context.tr('Withdrawals')),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _EarnRow(context.tr('Today'), '₹${today.toStringAsFixed(0)}'),
          _EarnRow(
            context.tr('Total earnings'),
            '₹${total.toStringAsFixed(0)}',
          ),
          _EarnRow(context.tr('Completed jobs'), '$jobs'),
        ],
      ),
    );
  }
}

Future<double?> _askAmount(
  BuildContext context, {
  required String title,
  required String confirmLabel,
}) {
  return showModalBottomSheet<double>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) => _PromptSheet(
      title: title,
      hint: context.tr('Amount (₹)'),
      confirmLabel: confirmLabel,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      parse: (text) => double.tryParse(text.trim()),
    ),
  );
}

Future<String?> _askText(
  BuildContext context, {
  required String title,
  required String hint,
}) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) => _PromptSheet(
      title: title,
      hint: hint,
      confirmLabel: context.tr('Continue'),
      parse: (text) => text.trim(),
    ),
  );
}

class _PromptSheet<T> extends StatefulWidget {
  const _PromptSheet({
    required this.title,
    required this.hint,
    required this.confirmLabel,
    required this.parse,
    this.keyboardType,
  });

  final String title;
  final String hint;
  final String confirmLabel;
  final TextInputType? keyboardType;
  final T? Function(String text) parse;

  @override
  State<_PromptSheet<T>> createState() => _PromptSheetState<T>();
}

class _PromptSheetState<T> extends State<_PromptSheet<T>> {
  final _field = TextEditingController();

  @override
  void dispose() {
    _field.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        8,
        20,
        20 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            widget.title,
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _field,
            keyboardType: widget.keyboardType,
            decoration: InputDecoration(labelText: widget.hint),
            autofocus: true,
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: () {
              final value = widget.parse(_field.text);
              if (value == null) return;
              if (value is double && value < 1) return;
              Navigator.pop(context, value);
            },
            child: Text(widget.confirmLabel),
          ),
        ],
      ),
    );
  }
}

class _EarnRow extends StatelessWidget {
  const _EarnRow(this.label, this.value);
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: PartnerColors.line),
      ),
      child: Row(
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
          const Spacer(),
          Text(
            value,
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              color: PartnerColors.primary,
            ),
          ),
        ],
      ),
    );
  }
}

class ProfileTab extends StatelessWidget {
  const ProfileTab({super.key});

  @override
  Widget build(BuildContext context) {
    final session = context.watch<SessionController>();
    final user = session.user;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
      children: [
        Text(
          context.tr('Partner Profile'),
          style: GoogleFonts.hankenGrotesk(
            fontSize: 22,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: PartnerColors.line),
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 30,
                backgroundColor: PartnerColors.accentSoft,
                backgroundImage:
                    (user?.avatarUrl != null && user!.avatarUrl!.isNotEmpty)
                    ? NetworkImage(user.avatarUrl!)
                    : null,
                child: (user?.avatarUrl != null && user!.avatarUrl!.isNotEmpty)
                    ? null
                    : Text(
                        (user?.name ?? 'P').characters.first.toUpperCase(),
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                          color: PartnerColors.primary,
                        ),
                      ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      user?.name ?? context.tr('Partner'),
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 18,
                      ),
                    ),
                    if ((user?.email ?? '').isNotEmpty)
                      Text(
                        user!.email!,
                        style: const TextStyle(
                          color: PartnerColors.muted,
                          fontSize: 13,
                        ),
                      ),
                    Text(
                      context.tr(user?.role.title ?? ''),
                      style: const TextStyle(color: PartnerColors.muted),
                    ),
                    if (session.selectedWorkTypes.isNotEmpty)
                      Text(
                        session.selectedWorkTypes
                            .map((e) => context.tr(e.title))
                            .join(' · '),
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: PartnerColors.primary,
                        ),
                      ),
                    Text(
                      context.tr('Status: {status} · KYC: {kyc}', {
                        'status': context.tr(user?.status ?? '—'),
                        'kyc': context.tr(user?.kycStatus ?? '—'),
                      }),
                      style: const TextStyle(
                        fontSize: 12,
                        color: PartnerColors.muted,
                      ),
                    ),
                    Text(
                      context.tr(
                        user?.canOperate == true ||
                                user?.kycStatus?.toLowerCase() == 'approved'
                            ? 'Eligible to go online'
                            : 'Complete KYC to go online',
                      ),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color:
                            user?.canOperate == true ||
                                user?.kycStatus?.toLowerCase() == 'approved'
                            ? Colors.green.shade700
                            : Colors.orange.shade800,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _Tile(
          Icons.edit_outlined,
          context.tr('Edit profile'),
          context.tr('Update your name, email and photo'),
          onTap: () => context.push('/profile/edit'),
        ),
        const _OverlayPermissionTile(),
        _Tile(
          Icons.badge_outlined,
          context.tr('Documents'),
          context.tr(
            user?.canOperate == true ||
                    user?.kycStatus?.toLowerCase() == 'approved'
                ? 'View your submitted KYC documents'
                : 'Upload / update documents for KYC approval',
          ),
          onTap: () => context.push('/kyc'),
        ),
        _Tile(
          Icons.card_giftcard_outlined,
          context.tr('Invite & earn'),
          (user?.referralCode ?? '').isNotEmpty
              ? context.tr('Code {code} · View details & tree', {
                  'code': user!.referralCode,
                })
              : context.tr('Share your referral code'),
          onTap: () => context.push('/invite'),
        ),
        _Tile(
          Icons.support_agent,
          context.tr('Kaam Fast Partner Support'),
          context.tr('WhatsApp, call or email support'),
          onTap: () => _openSupport(context),
        ),
        _Tile(
          Icons.description_outlined,
          context.tr('Terms & Conditions'),
          context.tr('Rules for using Kaam Fast Partner'),
          onTap: () => openLegalUrl(context, AppConstants.termsUrl),
        ),
        _Tile(
          Icons.privacy_tip_outlined,
          context.tr('Privacy Policy'),
          context.tr('How we use and protect your data'),
          onTap: () => openLegalUrl(context, AppConstants.privacyPolicyUrl),
        ),
        _Tile(
          Icons.miscellaneous_services_outlined,
          context.tr('My services'),
          session.serviceApprovals.isEmpty
              ? (session.selectedWorkTypes.isEmpty
                    ? context.tr('Choose helper, cleaner, labour and more.')
                    : session.selectedWorkTypes
                          .map((e) => context.tr(e.title))
                          .join(', '))
              : context.tr('{active} active · {total} total', {
                  'active': session.approvedServices.length,
                  'total': session.serviceApprovals.length,
                }),
          onTap: () => context.push('/my-services'),
        ),
        _Tile(
          Icons.translate,
          context.tr('Language'),
          context.tr('Choose language'),
          trailingText: languageLabel(
            context.watch<LocaleController>().languageCode,
          ),
          onTap: () => showLanguagePicker(context),
        ),
        const SizedBox(height: 8),
        ListTile(
          leading: const Icon(Icons.logout, color: Colors.red),
          title: Text(
            context.tr('Logout'),
            style: const TextStyle(
              color: Colors.red,
              fontWeight: FontWeight.w700,
            ),
          ),
          onTap: () async {
            await session.logout();
            if (context.mounted) context.go('/welcome');
          },
        ),
      ],
    );
  }

  Future<void> _openSupport(BuildContext context) async {
    final choice = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                title: Text(
                  context.tr('Partner Support'),
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                subtitle: Text(
                  context.tr('We usually reply within a few hours.'),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.chat, color: PartnerColors.primary),
                title: const Text('WhatsApp'),
                onTap: () => Navigator.pop(context, 'whatsapp'),
              ),
              ListTile(
                leading: const Icon(
                  Icons.call_outlined,
                  color: PartnerColors.primary,
                ),
                title: Text(context.tr('Call support')),
                onTap: () => Navigator.pop(context, 'call'),
              ),
              ListTile(
                leading: const Icon(
                  Icons.email_outlined,
                  color: PartnerColors.primary,
                ),
                title: Text(context.tr('Email')),
                onTap: () => Navigator.pop(context, 'email'),
              ),
            ],
          ),
        );
      },
    );
    if (choice == null || !context.mounted) return;

    final session = context.read<SessionController>();
    Map<String, dynamic> config = {};
    try {
      config = await session.api.supportConfig();
    } catch (_) {}

    String digits(String? raw) => (raw ?? '').replaceAll(RegExp(r'\D'), '');

    var whatsapp = digits('${config['whatsapp'] ?? ''}');
    var callPhone = digits(
      '${config['support_phone_digits'] ?? config['support_phone'] ?? ''}',
    );
    var email = '${config['support_email'] ?? ''}'.trim();

    if (whatsapp.isEmpty || RegExp(r'^0+$').hasMatch(whatsapp)) {
      whatsapp = digits(AppConstants.supportWhatsApp);
    }
    if (callPhone.isEmpty || RegExp(r'^0+$').hasMatch(callPhone)) {
      callPhone = digits(AppConstants.supportPhone);
    }
    if (email.isEmpty) {
      email = AppConstants.supportEmail;
    }
    if (whatsapp.length == 10) whatsapp = '91$whatsapp';
    if (callPhone.length == 10) callPhone = '91$callPhone';

    final uri = switch (choice) {
      'whatsapp' =>
        whatsapp.isEmpty
            ? null
            : Uri.parse(
                'https://wa.me/$whatsapp?text=${Uri.encodeComponent('Hi Kaam Fast Partner Support')}',
              ),
      'call' => callPhone.isEmpty ? null : Uri.parse('tel:+$callPhone'),
      'email' =>
        email.isEmpty
            ? null
            : Uri(
                scheme: 'mailto',
                path: email,
                query: 'subject=Partner Support',
              ),
      _ => null,
    };
    if (uri == null) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.tr('Support contact is not configured yet.')),
          ),
        );
      }
      return;
    }
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.tr('Could not open support app'))),
      );
    }
  }
}

class _OverlayPermissionTile extends StatefulWidget {
  const _OverlayPermissionTile();

  @override
  State<_OverlayPermissionTile> createState() => _OverlayPermissionTileState();
}

class _OverlayPermissionTileState extends State<_OverlayPermissionTile>
    with WidgetsBindingObserver {
  bool _granted = false;
  bool _pref = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refresh();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _onReturnedFromSettings();
    }
  }

  Future<void> _onReturnedFromSettings() async {
    await _refresh();
    if (!mounted) return;
    final overlay = OverlayPermissionService.instance;
    if (_granted) {
      await overlay.setPreferenceEnabled(true);
    }
    final session = context.read<SessionController>();
    if (session.user != null) {
      await overlay.syncWithOnlineState(
        isOnline: session.user!.isOnline,
        partnerName: session.user!.name,
      );
    }
    await _refresh();
  }

  Future<void> _refresh() async {
    final overlay = OverlayPermissionService.instance;
    final granted = await overlay.isPermissionGranted();
    final pref = await overlay.isPreferenceEnabled();
    if (!mounted) return;
    setState(() {
      _granted = granted;
      _pref = pref;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!OverlayPermissionService.instance.isAndroid) {
      return const SizedBox.shrink();
    }
    return _Tile(
      Icons.picture_in_picture_alt_outlined,
      context.tr('Display over other apps'),
      context.tr(
        _granted && _pref
            ? 'Enabled — ONLINE bubble can show'
            : 'Tap to open Android settings and allow',
      ),
      onTap: () async {
        await OverlayPermissionService.instance.openOverlaySettings();
      },
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile(
    this.icon,
    this.title,
    this.subtitle, {
    this.onTap,
    this.trailingText,
  });
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;
  final String? trailingText;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: PartnerColors.line),
      ),
      child: ListTile(
        onTap: onTap,
        leading: Icon(icon, color: PartnerColors.primary),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
        subtitle: Text(
          subtitle,
          style: const TextStyle(fontSize: 12, color: PartnerColors.muted),
        ),
        trailing: trailingText == null
            ? const Icon(Icons.chevron_right)
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    trailingText!,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      color: PartnerColors.primary,
                    ),
                  ),
                  const Icon(Icons.chevron_right),
                ],
              ),
      ),
    );
  }
}
