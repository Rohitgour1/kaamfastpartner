import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:kaamfast_partner/data/work_types.dart';
import 'package:kaamfast_partner/l10n/app_strings.dart';
import 'package:kaamfast_partner/state/session_controller.dart';
import 'package:kaamfast_partner/theme/partner_theme.dart';
import 'package:provider/provider.dart';

class ServiceSelectScreen extends StatefulWidget {
  const ServiceSelectScreen({super.key});

  @override
  State<ServiceSelectScreen> createState() => _ServiceSelectScreenState();
}

class _ServiceSelectScreenState extends State<ServiceSelectScreen> {
  final _selected = <String>{};
  final _initialSelected = <String>{};
  bool _loading = true;
  bool _saving = false;
  String? _error;
  List<PartnerWorkType> _options = PartnerWorkType.fallbackForServicePartner();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final session = context.read<SessionController>();
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      if (session.loggedIn) {
        await session.hydrateSelectedWorkTypes();
      }
      final options = await session.loadWorkTypes();
      if (!mounted) return;
      final selectedIds = session.selectedWorkTypes.map((e) => e.id).toSet();
      // Also match by slug/title if ids drifted between fallback/API.
      for (final option in options) {
        final matched = session.selectedWorkTypes.any(
          (picked) =>
              picked.id == option.id ||
              picked.slug == option.slug ||
              picked.title.toLowerCase() == option.title.toLowerCase(),
        );
        if (matched) selectedIds.add(option.id);
      }
      setState(() {
        _options = options;
        _selected
          ..clear()
          ..addAll(selectedIds);
        _initialSelected
          ..clear()
          ..addAll(selectedIds);
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _options = PartnerWorkType.fallbackForServicePartner();
        _selected
          ..clear()
          ..addAll(session.selectedWorkTypes.map((e) => e.id));
        _initialSelected
          ..clear()
          ..addAll(_selected);
        _loading = false;
        _error = '$e';
      });
    }
  }

  Future<void> _continue() async {
    if (_selected.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.tr('Select at least one service you can provide'))),
      );
      return;
    }
    final picked = _options.where((e) => _selected.contains(e.id)).toList();
    final added = _selected.difference(_initialSelected);
    final session = context.read<SessionController>();
    session.selectWorkTypes(picked);

    if (!session.loggedIn) {
      context.push('/login');
      return;
    }

    setState(() => _saving = true);
    try {
      final needsReview = await session.submitSelectedServices(
        forceReview: added.isNotEmpty,
      );
      if (!mounted) return;
      if (needsReview || added.isNotEmpty || !session.isKycApproved) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              added.isEmpty
                  ? context.tr('Upload required documents for review.')
                  : context.tr('New service added. Upload documents for review.'),
            ),
          ),
        );
        context.go('/kyc');
        return;
      }
      if (context.canPop()) {
        context.pop();
      } else {
        context.go('/home');
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        title: Text(context.tr('Kaam Fast Partner')),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                context.tr('What work do you want to take?'),
                style: GoogleFonts.hankenGrotesk(fontSize: 24, fontWeight: FontWeight.w800, height: 1.2),
              ),
              const SizedBox(height: 8),
              Text(
                context.tr('Choose helper, cleaner, labour or any service you can provide. You can pick more than one.'),
                style: const TextStyle(color: PartnerColors.muted, fontSize: 14),
              ),
              if (_error != null) ...[
                const SizedBox(height: 8),
                Text(
                  context.tr('Showing default services. {error}', {'error': _error}),
                  style: const TextStyle(fontSize: 12, color: PartnerColors.muted),
                ),
              ],
              if (!_loading && _selected.isNotEmpty) ...[
                const SizedBox(height: 10),
                Text(
                  context.tr('{count} selected', {'count': _selected.length}),
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    color: PartnerColors.primary,
                  ),
                ),
              ],
              const SizedBox(height: 16),
              Expanded(
                child: _loading
                    ? const Center(child: CircularProgressIndicator())
                    : ListView.separated(
                        itemCount: _options.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 10),
                        itemBuilder: (context, index) {
                          final item = _options[index];
                          final selected = _selected.contains(item.id);
                          return _ServiceCard(
                            item: item,
                            selected: selected,
                            onTap: _saving
                                ? null
                                : () {
                                    setState(() {
                                      if (selected) {
                                        _selected.remove(item.id);
                                      } else {
                                        _selected.add(item.id);
                                      }
                                    });
                                  },
                          );
                        },
                      ),
              ),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: (_loading || _saving) ? null : _continue,
                child: Text(
                  _saving
                      ? context.tr('Saving…')
                      : _selected.isEmpty
                          ? context.tr('Select a service')
                          : _selected.length == 1
                              ? context.tr('Continue with 1 service')
                              : context.tr('Continue with {count} services', {'count': _selected.length}),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ServiceCard extends StatelessWidget {
  const _ServiceCard({required this.item, required this.selected, required this.onTap});

  final PartnerWorkType item;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? PartnerColors.primaryDeep : Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: selected ? PartnerColors.accent : PartnerColors.line,
              width: selected ? 2 : 1,
            ),
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: selected ? Colors.white.withValues(alpha: 0.18) : PartnerColors.accentSoft,
                child: Icon(item.icon, color: selected ? Colors.white : PartnerColors.primary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.tr(item.title),
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                        color: selected ? Colors.white : PartnerColors.ink,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      item.description.isNotEmpty
                          ? context.tr(item.description)
                          : context.tr(
                              item.isModule
                                  ? 'Receive jobs for {name}.'
                                  : 'Get {name} jobs from Kaam Fast customers.',
                              {'name': context.tr(item.title)},
                            ),
                      style: TextStyle(
                        fontSize: 12,
                        height: 1.35,
                        color: selected ? Colors.white.withValues(alpha: 0.8) : PartnerColors.muted,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                selected ? Icons.check_circle : Icons.circle_outlined,
                color: selected ? PartnerColors.accent : PartnerColors.muted,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
