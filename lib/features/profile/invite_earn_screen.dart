import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:kaamfast_partner/core/app_constants.dart';
import 'package:kaamfast_partner/l10n/app_strings.dart';
import 'package:kaamfast_partner/state/session_controller.dart';
import 'package:kaamfast_partner/theme/partner_theme.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

class InviteEarnScreen extends StatefulWidget {
  const InviteEarnScreen({super.key});

  @override
  State<InviteEarnScreen> createState() => _InviteEarnScreenState();
}

class _InviteEarnScreenState extends State<InviteEarnScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  Map<String, dynamic>? _summary;
  Map<String, dynamic>? _tree;
  List<Map<String, dynamic>> _list = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  String get _code {
    final fromApi = _summary?['referral_code']?.toString().trim();
    if (fromApi != null && fromApi.isNotEmpty) return fromApi;
    return context.read<SessionController>().user?.referralCode?.trim() ?? '';
  }

  String get _inviteText {
    return context.tr(
      'Join Kaam Fast as a partner using my referral code {code} and start earning. '
      'Download the Kaam Fast Partner app.',
      {'code': _code},
    );
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final api = context.read<SessionController>().api;
      final summary = await api.referralSummary();
      Map<String, dynamic>? tree;
      var list = <Map<String, dynamic>>[];
      try {
        tree = await api.referralTree();
      } catch (_) {}
      try {
        list = await api.referralList();
      } catch (_) {}
      if (!mounted) return;
      setState(() {
        _summary = summary;
        _tree = tree;
        _list = list;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = '$e';
        _loading = false;
      });
    }
  }

  Future<void> _copyCode() async {
    if (_code.isEmpty) return;
    await Clipboard.setData(ClipboardData(text: _code));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(context.tr('Referral code copied'))),
    );
  }

  Future<void> _shareWhatsApp() async {
    if (_code.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.tr('Referral code is not ready yet'))),
      );
      return;
    }
    final text = Uri.encodeComponent(_inviteText);
    for (final uri in [
      Uri.parse('whatsapp://send?text=$text'),
      Uri.parse('https://wa.me/?text=$text'),
    ]) {
      try {
        if (await launchUrl(uri, mode: LaunchMode.externalApplication)) return;
      } catch (_) {}
    }
    await _copyCode();
  }

  @override
  Widget build(BuildContext context) {
    final invited = _summary?['direct_referrals'] ?? 0;
    final network = _summary?['total_network'] ?? _list.length;
    final levels = _summary?['levels'] is List ? List.from(_summary!['levels'] as List) : const [];

    return Scaffold(
      appBar: AppBar(
        title: Text(context.tr('Invite & Earn')),
        bottom: TabBar(
          controller: _tabs,
          labelColor: PartnerColors.primary,
          unselectedLabelColor: PartnerColors.muted,
          indicatorColor: PartnerColors.accent,
          tabs: [
            Tab(text: context.tr('Details')),
            Tab(text: context.tr('Referral tree')),
          ],
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabs,
              children: [
                RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
                    children: [
                      if (_error != null)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Text(_error!, style: const TextStyle(color: PartnerColors.danger)),
                        ),
                      Container(
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: PartnerColors.primary,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              context.tr('Invite partners, grow your network'),
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                                fontSize: 18,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              context.tr('Share your code. When they join as partners, they appear in your referral tree.'),
                              style: const TextStyle(color: Colors.white70, height: 1.35),
                            ),
                            const SizedBox(height: 16),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          context.tr('YOUR CODE'),
                                          style: const TextStyle(
                                            color: Colors.white70,
                                            fontSize: 11,
                                            fontWeight: FontWeight.w700,
                                            letterSpacing: 0.8,
                                          ),
                                        ),
                                        Text(
                                          _code.isEmpty ? '—' : _code,
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 26,
                                            fontWeight: FontWeight.w800,
                                            letterSpacing: 2,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  IconButton(
                                    onPressed: _copyCode,
                                    icon: const Icon(Icons.copy_rounded, color: Colors.white),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          Expanded(
                            child: FilledButton.icon(
                              onPressed: _shareWhatsApp,
                              icon: const Icon(Icons.chat_rounded, size: 18),
                              label: Text(context.tr('Invite via WhatsApp')),
                            ),
                          ),
                          const SizedBox(width: 10),
                          OutlinedButton(
                            onPressed: _copyCode,
                            child: Text(context.tr('Copy')),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(child: _stat(context.tr('Direct invites'), '$invited')),
                          const SizedBox(width: 10),
                          Expanded(child: _stat(context.tr('Network'), '$network')),
                        ],
                      ),
                      if (levels.isNotEmpty) ...[
                        const SizedBox(height: 18),
                        Text(
                          context.tr('How referral levels work'),
                          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                        ),
                        const SizedBox(height: 8),
                        for (final raw in levels)
                          if (raw is Map)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(color: PartnerColors.line),
                                  color: Colors.white,
                                ),
                                child: Row(
                                  children: [
                                    CircleAvatar(
                                      backgroundColor: PartnerColors.accentSoft,
                                      foregroundColor: PartnerColors.primary,
                                      child: Text(
                                        '${raw['level'] ?? ''}',
                                        style: const TextStyle(fontWeight: FontWeight.w800),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Text(
                                        raw['name'] != null
                                            ? context.tr(raw['name'].toString())
                                            : context.tr('Level {level}', {'level': raw['level']}),
                                        style: const TextStyle(fontWeight: FontWeight.w700),
                                      ),
                                    ),
                                    Text(
                                      '${raw['percentage'] ?? 0}%',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w800,
                                        color: PartnerColors.primary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                      ],
                      const SizedBox(height: 8),
                      Text(
                        context.tr('App: {name}', {'name': AppConstants.appName}),
                        style: const TextStyle(fontSize: 12, color: PartnerColors.muted),
                      ),
                    ],
                  ),
                ),
                RefreshIndicator(
                  onRefresh: _load,
                  child: _treeBody(),
                ),
              ],
            ),
    );
  }

  Widget _treeBody() {
    final children = (_tree?['children'] is List)
        ? List<Map<String, dynamic>>.from(
            (_tree!['children'] as List).whereType<Map>().map((e) => Map<String, dynamic>.from(e)),
          )
        : <Map<String, dynamic>>[];

    if (children.isEmpty && _list.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(24),
        children: [
          const SizedBox(height: 48),
          const Icon(Icons.account_tree_outlined, size: 48, color: PartnerColors.muted),
          const SizedBox(height: 12),
          Text(
            context.tr('No referrals yet'),
            textAlign: TextAlign.center,
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
          ),
          const SizedBox(height: 6),
          Text(
            context.tr('Share your code. Partners who join with it will show up here as a tree.'),
            textAlign: TextAlign.center,
            style: const TextStyle(color: PartnerColors.muted),
          ),
        ],
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
      children: [
        if (_tree != null)
          _TreeNodeCard(
            name: _tree!['name']?.toString() ?? context.tr('You'),
            subtitle: '${context.tr('You')} · ${_tree!['referral_code'] ?? _code}',
            depth: 0,
            isRoot: true,
          ),
        if (children.isNotEmpty)
          ...children.map((node) => _ReferralBranch(node: node, depth: 1))
        else
          ..._list.map((row) {
            final level = (row['level'] is num) ? (row['level'] as num).toInt() : 1;
            return Padding(
              padding: EdgeInsets.only(left: (level.clamp(1, 6) - 1) * 16.0, bottom: 8),
              child: _TreeNodeCard(
                name: row['name']?.toString() ?? context.tr('Partner'),
                subtitle:
                    'L$level · ${row['referral_code'] ?? '—'} · ${row['phone'] ?? ''}',
                depth: level,
              ),
            );
          }),
      ],
    );
  }

  Widget _stat(String label, String value) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: PartnerColors.accentSoft,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: PartnerColors.muted, fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 20,
              color: PartnerColors.primary,
            ),
          ),
        ],
      ),
    );
  }
}

class _ReferralBranch extends StatelessWidget {
  const _ReferralBranch({required this.node, required this.depth});

  final Map<String, dynamic> node;
  final int depth;

  @override
  Widget build(BuildContext context) {
    final kids = node['children'] is List
        ? List<Map<String, dynamic>>.from(
            (node['children'] as List).whereType<Map>().map((e) => Map<String, dynamic>.from(e)),
          )
        : <Map<String, dynamic>>[];
    final level = node['level'] ?? depth;

    return Padding(
      padding: EdgeInsets.only(left: (depth.clamp(1, 6) - 1) * 14.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _TreeNodeCard(
            name: node['name']?.toString() ?? context.tr('Partner'),
            subtitle:
                'L$level · ${node['referral_code'] ?? '—'} · ${node['phone'] ?? ''}',
            depth: depth,
          ),
          ...kids.map((child) => _ReferralBranch(node: child, depth: depth + 1)),
        ],
      ),
    );
  }
}

class _TreeNodeCard extends StatelessWidget {
  const _TreeNodeCard({
    required this.name,
    required this.subtitle,
    required this.depth,
    this.isRoot = false,
  });

  final String name;
  final String subtitle;
  final int depth;
  final bool isRoot;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: isRoot ? PartnerColors.primary : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: isRoot ? PartnerColors.primary : PartnerColors.line),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: isRoot ? PartnerColors.accent : PartnerColors.accentSoft,
            foregroundColor: PartnerColors.primary,
            child: Text(
              name.isNotEmpty ? name.characters.first.toUpperCase() : 'P',
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    color: isRoot ? Colors.white : PartnerColors.ink,
                  ),
                ),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 12,
                    color: isRoot ? Colors.white70 : PartnerColors.muted,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
