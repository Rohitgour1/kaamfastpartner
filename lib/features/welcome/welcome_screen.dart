import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:kaamfast_partner/l10n/app_strings.dart';
import 'package:kaamfast_partner/l10n/language_sheet.dart';
import 'package:kaamfast_partner/theme/partner_theme.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: PartnerColors.bg,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  AspectRatio(
                    aspectRatio: 1.05,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        Container(
                          decoration: const BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [Color(0xFFD8F0B8), Color(0xFFE4F6C8), PartnerColors.bg],
                            ),
                          ),
                        ),
                        Positioned(
                          top: 18,
                          left: 18,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.9),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.verified, size: 16, color: PartnerColors.primary),
                                const SizedBox(width: 6),
                                Text(
                                  context.tr('Join 50,000+ Partners'),
                                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const Positioned(
                          top: 12,
                          right: 10,
                          child: LanguageButton(),
                        ),
                        Positioned(
                          left: 20,
                          right: 20,
                          bottom: 28,
                          child: Text.rich(
                            TextSpan(
                              style: GoogleFonts.hankenGrotesk(
                                fontSize: 34,
                                fontWeight: FontWeight.w800,
                                height: 1.15,
                                color: PartnerColors.ink,
                              ),
                              children: [
                                TextSpan(text: context.tr('Earn More.\nWork Better.\n')),
                                TextSpan(
                                  text: context.tr('Grow with Kaam Fast.'),
                                  style: const TextStyle(color: PartnerColors.primary),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                    child: Column(
                      children: const [
                        _Benefit(
                          icon: Icons.badge_outlined,
                          iconBg: Color(0xFFE4F6C8),
                          iconColor: Color(0xFF3D8B24),
                          title: 'Build your profile',
                          body: 'Showcase reviews and photos to win trust instantly.',
                        ),
                        _Benefit(
                          icon: Icons.groups_outlined,
                          iconBg: Color(0xFFC8E88A),
                          iconColor: Color(0xFF2F6B1C),
                          title: 'Get more customers',
                          body: 'Access a wider network of clients needing your skills daily.',
                        ),
                        _Benefit(
                          icon: Icons.account_balance_wallet_outlined,
                          iconBg: Color(0xFFE4F6C8),
                          iconColor: PartnerColors.primary,
                          title: 'Get paid securely',
                          body: 'Guaranteed direct bank transfers with zero hidden fees.',
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.92),
                border: const Border(top: BorderSide(color: PartnerColors.line)),
                boxShadow: [
                  BoxShadow(
                    color: PartnerColors.primaryDeep.withValues(alpha: 0.08),
                    blurRadius: 20,
                    offset: const Offset(0, -4),
                  ),
                ],
              ),
              child: Column(
                children: [
                  FilledButton(
                    onPressed: () => context.push('/role'),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(context.tr('Become a Partner')),
                        const SizedBox(width: 8),
                        const Icon(Icons.arrow_forward, size: 20),
                      ],
                    ),
                  ),
                  TextButton(
                    onPressed: () => context.push('/login'),
                    child: Text(
                      context.tr('Already a Partner? Login'),
                      style: const TextStyle(color: PartnerColors.primary, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Benefit extends StatelessWidget {
  const _Benefit({
    required this.icon,
    required this.iconBg,
    required this.iconColor,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final Color iconBg;
  final Color iconColor;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(backgroundColor: iconBg, child: Icon(icon, color: iconColor)),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(context.tr(title), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                const SizedBox(height: 2),
                Text(context.tr(body), style: const TextStyle(color: PartnerColors.muted, fontSize: 13)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
