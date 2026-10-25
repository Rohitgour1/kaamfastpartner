import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';
import 'package:go_router/go_router.dart';
import 'package:kaamfast_partner/app_router.dart';
import 'package:kaamfast_partner/core/api_client.dart';
import 'package:kaamfast_partner/features/tasks/searching_delivery_screen.dart';
import 'package:kaamfast_partner/l10n/app_strings.dart';
import 'package:kaamfast_partner/l10n/locale_controller.dart';
import 'package:kaamfast_partner/services/job_alert.dart';
import 'package:kaamfast_partner/services/live_sync.dart';
import 'package:kaamfast_partner/services/overlay_permission_service.dart';
import 'package:kaamfast_partner/services/partner_api.dart';
import 'package:kaamfast_partner/services/push_service.dart';
import 'package:kaamfast_partner/state/session_controller.dart';
import 'package:kaamfast_partner/theme/partner_theme.dart';
import 'package:provider/provider.dart';

export 'package:kaamfast_partner/overlay_main.dart' show overlayMain;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AppStrings.loadSaved();
  await PushService.init();
  runApp(const KaamFastPartnerApp());
}

class KaamFastPartnerApp extends StatefulWidget {
  const KaamFastPartnerApp({super.key});

  @override
  State<KaamFastPartnerApp> createState() => _KaamFastPartnerAppState();
}

class _KaamFastPartnerAppState extends State<KaamFastPartnerApp> {
  late final TokenStorage _tokens = TokenStorage();
  late final ApiClient _apiClient = ApiClient(_tokens);
  late final PartnerApi _partnerApi = PartnerApi(_apiClient, _tokens);
  late final LiveSync _live = LiveSync();
  final LocaleController _locale = LocaleController();
  late final SessionController _session = SessionController(
    _partnerApi,
    _tokens,
    _live,
  );
  final _messenger = GlobalKey<ScaffoldMessengerState>();
  final _rootNav = GlobalKey<NavigatorState>();
  late final GoRouter _router = createPartnerRouter(
    _session,
    navigatorKey: _rootNav,
  );
  int _lastPushTick = 0;
  int _lastJobAlertTick = 0;
  int _lastServiceTick = 0;
  String? _lastServiceKey;
  DateTime? _lastServiceAt;
  int? _openedSearchingFor;

  @override
  void initState() {
    super.initState();
    if (!kIsWeb && Platform.isAndroid) {
      FlutterOverlayWindow.overlayListener.listen((event) {
        if (event is Map && event['action']?.toString() == 'open_app') {
          JobAlert.openAppIfPossible();
        }
      });
    }
    _live.addListener(_onLive);
  }

  void _onServiceEvent() {
    final event = _live.lastServiceEvent;
    final type = event['type'] ?? '';
    final key = '$type:${event['service_module_id']}';
    final now = DateTime.now();
    if (key == _lastServiceKey &&
        _lastServiceAt != null &&
        now.difference(_lastServiceAt!) < const Duration(seconds: 10)) {
      return;
    }
    _lastServiceKey = key;
    _lastServiceAt = now;
    if (_session.loggedIn) unawaited(_session.refreshKyc());

    final module = event['module'];
    final service = AppStrings.tr(
      module == null || module.isEmpty ? 'Service' : module,
    );
    final reason = event['reason'] ?? '';
    final message = switch (type) {
      'service.approved' => AppStrings.tr(
        "{service} approved — you'll now receive orders",
        {'service': service},
      ),
      'service.rejected' =>
        reason.isEmpty
            ? AppStrings.tr('{service} not approved', {'service': service})
            : AppStrings.tr('{service} not approved: {reason}', {
                'service': service,
                'reason': reason,
              }),
      _ => AppStrings.tr('{service} status updated', {'service': service}),
    };
    _messenger.currentState?.showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 6),
        action: SnackBarAction(
          label: AppStrings.tr(
            type == 'service.rejected' ? 'Re-apply' : 'View',
          ),
          onPressed: () => _router.push('/my-services'),
        ),
      ),
    );
  }

  void _onLive() {
    if (_live.serviceTick != _lastServiceTick) {
      _lastServiceTick = _live.serviceTick;
      _onServiceEvent();
      _lastPushTick = _live.pushTick;
      return;
    }
    if (_live.jobAlertTick != _lastJobAlertTick) {
      _lastJobAlertTick = _live.jobAlertTick;
      if (_session.loggedIn) {
        _session.refreshTasks();
      }
    }
    if (_live.pushTick == _lastPushTick) return;
    _lastPushTick = _live.pushTick;

    final type = _live.lastData['type'] ?? _live.lastJobType;
    final bookingId = int.tryParse(_live.lastData['booking_id'] ?? '');
    final isSearching =
        type == 'booking.searching_delivery' ||
        (_live.lastTitle ?? '').toLowerCase().contains(
          'searching for delivery',
        );

    if (isSearching && bookingId != null) {
      _openSearching(bookingId, _live.lastData['offer_phase']);
      return;
    }

    final title = _live.lastTitle;
    final body = _live.lastBody;
    if (title == null && body == null) return;
    _messenger.currentState?.showSnackBar(
      SnackBar(
        content: Text(
          [
            title,
            body,
          ].whereType<String>().where((e) => e.isNotEmpty).join(' · '),
        ),
      ),
    );
  }

  void _openSearching(int bookingId, String? phase) {
    if (_openedSearchingFor == bookingId) return;
    _openedSearchingFor = bookingId;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final nav = _rootNav.currentState;
      if (nav == null) return;
      nav
          .push(
            MaterialPageRoute<void>(
              builder: (_) =>
                  SearchingDeliveryScreen(bookingId: bookingId, phase: phase),
            ),
          )
          .whenComplete(() {
            if (_openedSearchingFor == bookingId) {
              _openedSearchingFor = null;
            }
          });
    });
  }

  @override
  void dispose() {
    _live.removeListener(_onLive);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider.value(value: _partnerApi),
        Provider.value(value: OverlayPermissionService.instance),
        ChangeNotifierProvider.value(value: _live),
        ChangeNotifierProvider.value(value: _session),
        ChangeNotifierProvider.value(value: _locale),
      ],
      child: Consumer<LocaleController>(
        builder: (context, locale, _) => MaterialApp.router(
          title: 'Kaam Fast Partner',
          debugShowCheckedModeBanner: false,
          theme: PartnerTheme.light(),
          locale: locale.locale,
          supportedLocales: [
            for (final code in AppStrings.supported) Locale(code),
          ],
          localizationsDelegates: GlobalMaterialLocalizations.delegates,
          routerConfig: _router,
          scaffoldMessengerKey: _messenger,
        ),
      ),
    );
  }
}
