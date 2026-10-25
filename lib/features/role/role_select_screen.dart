import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:kaamfast_partner/data/mock_data.dart';
import 'package:kaamfast_partner/l10n/app_strings.dart';
import 'package:kaamfast_partner/l10n/language_sheet.dart';
import 'package:kaamfast_partner/state/session_controller.dart';
import 'package:kaamfast_partner/theme/partner_theme.dart';
import 'package:provider/provider.dart';

class RoleSelectScreen extends StatefulWidget {
  const RoleSelectScreen({super.key});

  @override
  State<RoleSelectScreen> createState() => _RoleSelectScreenState();
}

class _RoleSelectScreenState extends State<RoleSelectScreen> {
  PartnerRole _selected = PartnerRole.delivery;

  @override
  void initState() {
    super.initState();
    final session = context.read<SessionController>();
    _selected = session.role ?? session.user?.role ?? PartnerRole.delivery;
  }

  Future<void> _continue() async {
    final session = context.read<SessionController>();

    // Role is fixed after login. This screen is only for first-time signup.
    if (session.loggedIn) {
      if (context.canPop()) {
        context.pop();
      } else {
        context.go(session.isKycApproved ? '/home' : '/kyc');
      }
      return;
    }

    session.selectRole(_selected);
    if (_selected == PartnerRole.service) {
      context.push('/services');
      return;
    }
    context.push('/login');
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
        actions: const [LanguageButton()],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                context.tr('How do you want to work with Kaam Fast?'),
                style: GoogleFonts.hankenGrotesk(fontSize: 24, fontWeight: FontWeight.w800, height: 1.2),
              ),
              const SizedBox(height: 8),
              Text(
                context.tr('Select the role that best fits your skills, tools, and business setup.'),
                style: const TextStyle(color: PartnerColors.muted, fontSize: 14),
              ),
              const SizedBox(height: 20),
              Expanded(
                child: ListView(
                  children: [
                    for (final role in PartnerRole.values) ...[
                      _RoleCard(
                        role: role,
                        selected: _selected == role,
                        onTap: () => setState(() => _selected = role),
                      ),
                      const SizedBox(height: 12),
                    ],
                  ],
                ),
              ),
              FilledButton(
                onPressed: _continue,
                child: Text(context.tr('Continue as {role}', {'role': context.tr(_selected.title)})),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RoleCard extends StatelessWidget {
  const _RoleCard({required this.role, required this.selected, required this.onTap});

  final PartnerRole role;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? PartnerColors.primaryDeep : PartnerColors.chip,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: selected ? PartnerColors.accent : Colors.transparent,
              width: selected ? 2 : 1,
            ),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: PartnerColors.primaryDeep.withValues(alpha: 0.18),
                      blurRadius: 30,
                      offset: const Offset(0, 8),
                    ),
                  ]
                : null,
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: selected ? Colors.white.withValues(alpha: 0.2) : role.accent.withValues(alpha: 0.12),
                child: Icon(role.icon, color: selected ? Colors.white : role.accent),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.tr(role.title),
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                        color: selected ? Colors.white : PartnerColors.ink,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      context.tr(role.description),
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
