import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:kaamfast_partner/data/mock_data.dart';
import 'package:kaamfast_partner/features/home/home_tab.dart';
import 'package:kaamfast_partner/features/shell/tabs.dart';
import 'package:kaamfast_partner/l10n/app_strings.dart';
import 'package:kaamfast_partner/state/session_controller.dart';
import 'package:kaamfast_partner/theme/partner_theme.dart';
import 'package:provider/provider.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final session = context.watch<SessionController>();
    final titles = [
      context.tr(switch (session.role) {
        PartnerRole.delivery => 'Delivery Hub',
        PartnerRole.business => 'Business Hub',
        PartnerRole.service => 'Services Hub',
        null => 'Home',
      }),
      context.tr('Tasks Workspace'),
      context.tr('Earnings & Payouts'),
      context.tr('Partner Profile'),
    ];

    final pages = const [HomeTab(), TasksTab(), EarningsTab(), ProfileTab()];

    return Scaffold(
      backgroundColor: PartnerColors.bg,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      titles[_index],
                      style: GoogleFonts.hankenGrotesk(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => context.push('/notifications'),
                    icon: const Icon(
                      Icons.notifications_none_rounded,
                      color: PartnerColors.primary,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(child: pages[_index]),
          ],
        ),
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          border: const Border(top: BorderSide(color: PartnerColors.line)),
          boxShadow: [
            BoxShadow(
              color: PartnerColors.primaryDeep.withValues(alpha: 0.08),
              blurRadius: 20,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: NavigationBar(
          height: 68,
          backgroundColor: Colors.white,
          indicatorColor: PartnerColors.accentSoft,
          selectedIndex: _index,
          onDestinationSelected: (i) => setState(() => _index = i),
          labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
          destinations: [
            NavigationDestination(
              icon: const Icon(Icons.dashboard_outlined),
              selectedIcon: const Icon(Icons.dashboard),
              label: context.tr('Home'),
            ),
            NavigationDestination(
              icon: const Icon(Icons.inventory_2_outlined),
              selectedIcon: const Icon(Icons.inventory_2),
              label: context.tr('Tasks'),
            ),
            NavigationDestination(
              icon: const Icon(Icons.payments_outlined),
              selectedIcon: const Icon(Icons.payments),
              label: context.tr('Earnings'),
            ),
            NavigationDestination(
              icon: const Icon(Icons.account_circle_outlined),
              selectedIcon: const Icon(Icons.account_circle),
              label: context.tr('Profile'),
            ),
          ],
        ),
      ),
    );
  }
}
