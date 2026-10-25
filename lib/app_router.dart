import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:kaamfast_partner/features/auth/login_screen.dart';
import 'package:kaamfast_partner/features/role/role_select_screen.dart';
import 'package:kaamfast_partner/features/role/service_select_screen.dart';
import 'package:kaamfast_partner/features/services/my_services_screen.dart';
import 'package:kaamfast_partner/features/shell/main_shell.dart';
import 'package:kaamfast_partner/features/splash/splash_screen.dart';
import 'package:kaamfast_partner/features/welcome/welcome_screen.dart';
import 'package:kaamfast_partner/features/notifications/notifications_screen.dart';
import 'package:kaamfast_partner/features/kyc/kyc_documents_screen.dart';
import 'package:kaamfast_partner/features/profile/edit_partner_profile_screen.dart';
import 'package:kaamfast_partner/features/profile/invite_earn_screen.dart';
import 'package:kaamfast_partner/features/tasks/task_detail_screen.dart';
import 'package:kaamfast_partner/state/session_controller.dart';

GoRouter createPartnerRouter(SessionController session, {GlobalKey<NavigatorState>? navigatorKey}) {
  return GoRouter(
    navigatorKey: navigatorKey,
    initialLocation: '/splash',
    refreshListenable: session,
    redirect: (context, state) {
      final loc = state.matchedLocation;

      // Stay on splash until session bootstrap finishes — prevents
      // splash ↔ home loops when notifyListeners fires mid-bootstrap.
      if (!session.bootstrapped) {
        return loc == '/splash' ? null : '/splash';
      }

      final loggedIn = session.loggedIn;
      // Role is chosen once before login. Logged-in partners cannot switch it.
      final authEntry = {'/splash', '/welcome', '/login'};
      final kycAllowed = {'/kyc', '/profile/edit', '/services', '/my-services'};

      if (!loggedIn) {
        if (loc == '/home' || loc.startsWith('/home') || loc.startsWith('/tasks')) {
          return '/welcome';
        }
        if (loc == '/kyc' ||
            loc == '/profile/edit' ||
            loc == '/notifications' ||
            loc == '/my-services') {
          return '/welcome';
        }
        if (loc == '/splash') return '/welcome';
        return null;
      }

      // Logged in: leave splash / welcome / login.
      if (authEntry.contains(loc)) {
        return session.isKycApproved ? '/home' : '/kyc';
      }

      if (loc == '/role') {
        return session.isKycApproved ? '/home' : '/kyc';
      }

      // Until KYC is approved, only documents / profile / role setup screens.
      if (session.needsKycGate && !kycAllowed.contains(loc)) {
        return '/kyc';
      }

      return null;
    },
    routes: [
      GoRoute(path: '/splash', builder: (_, _) => const SplashScreen()),
      GoRoute(path: '/welcome', builder: (_, _) => const WelcomeScreen()),
      GoRoute(path: '/role', builder: (_, _) => const RoleSelectScreen()),
      GoRoute(
        path: '/services',
        builder: (_, _) => const ServiceSelectScreen(),
      ),
      GoRoute(path: '/my-services', builder: (_, _) => const MyServicesScreen()),
      GoRoute(path: '/login', builder: (_, _) => const LoginScreen()),
      GoRoute(path: '/home', builder: (_, _) => const MainShell()),
      GoRoute(
        path: '/tasks/:id',
        builder: (_, state) => TaskDetailScreen(taskId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/notifications',
        builder: (_, _) => const PartnerNotificationsScreen(),
      ),
      GoRoute(path: '/kyc', builder: (_, _) => const KycDocumentsScreen()),
      GoRoute(path: '/profile/edit', builder: (_, _) => const EditPartnerProfileScreen()),
      GoRoute(path: '/invite', builder: (_, _) => const InviteEarnScreen()),
    ],
  );
}
