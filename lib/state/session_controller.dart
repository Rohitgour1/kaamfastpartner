import 'dart:async';

import 'package:flutter/material.dart';
import 'package:kaamfast_partner/core/api_client.dart';
import 'package:kaamfast_partner/data/mock_data.dart';
import 'package:kaamfast_partner/data/partner_incentive.dart';
import 'package:kaamfast_partner/data/service_approval.dart';
import 'package:kaamfast_partner/l10n/app_strings.dart';
import 'package:kaamfast_partner/data/work_types.dart';
import 'package:kaamfast_partner/services/job_alert.dart';
import 'package:kaamfast_partner/services/live_sync.dart';
import 'package:kaamfast_partner/services/overlay_permission_service.dart';
import 'package:kaamfast_partner/services/partner_api.dart';
import 'package:kaamfast_partner/services/partner_location_tracker.dart';
import 'package:kaamfast_partner/services/push_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SessionController extends ChangeNotifier {
  SessionController(this.api, this.tokens, this.live);

  final PartnerApi api;
  final TokenStorage tokens;
  final LiveSync live;
  final OverlayPermissionService overlay = OverlayPermissionService.instance;
  late final PartnerLocationTracker location = PartnerLocationTracker(api);

  PartnerRole? role;
  PartnerUser? user;
  String? phone;
  String? debugOtp;
  bool loggedIn = false;
  bool bootstrapped = false;
  bool availabilityBusy = false;
  bool tasksBusy = false;
  String? lastError;
  List<PartnerWorkType> selectedWorkTypes = [];

  /// Per-service admin approval; orders only arrive for approved rows.
  List<ServiceApproval> serviceApprovals = [];

  List<ServiceApproval> get approvedServices =>
      serviceApprovals.where((s) => s.isApproved).toList();

  List<PartnerTask> tasks = [];
  Map<String, dynamic>? earningsSummary;

  /// Admin-configured daily incentive with today's progress. Null when none is running.
  PartnerIncentive? incentive;
  Timer? _poll;
  int _lastLiveTick = -1;

  Future<void> bootstrap() async {
    try {
      final token = await tokens.read().timeout(const Duration(seconds: 8));
      if (token == null || token.isEmpty) {
        return;
      }

      // Restore last known phone before network calls (dashboard may omit it).
      phone = await tokens.readPhone().timeout(const Duration(seconds: 5));

      final me = await api.me().timeout(const Duration(seconds: 20));
      applyPartner(me);
      loggedIn = true;
    } on TimeoutException {
      // Keep the saved token so the next open can retry. Do not sit on splash.
      loggedIn = false;
    } catch (_) {
      try {
        await tokens.clear().timeout(const Duration(seconds: 5));
      } catch (_) {}
      loggedIn = false;
      user = null;
    } finally {
      // Leave splash as soon as auth is known. Location, overlay and FCM
      // must not block the first screen — those calls can hang forever.
      bootstrapped = true;
      notifyListeners();
    }

    if (loggedIn) {
      unawaited(_hydrateAfterLogin());
    }
  }

  void selectRole(PartnerRole value) {
    role = value;
    if (value != PartnerRole.service) {
      selectedWorkTypes = [];
      unawaited(_persistSelectedWorkTypes());
    }
    if (user != null) {
      user = user!.copyWith(
        role: value,
        workTypes: selectedWorkTypes.map((e) => e.title).toList(),
      );
    }
    notifyListeners();
  }

  void selectWorkTypes(List<PartnerWorkType> types) {
    selectedWorkTypes = List.of(types);
    if (user != null) {
      user = user!.copyWith(workTypes: types.map((e) => e.title).toList());
    }
    unawaited(_persistSelectedWorkTypes());
    notifyListeners();
  }

  static const _workTypesPrefKey = 'partner_selected_work_type_ids';

  Future<void> _persistSelectedWorkTypes() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(
        _workTypesPrefKey,
        selectedWorkTypes.map((e) => e.id).toList(),
      );
    } catch (_) {}
  }

  Future<Set<String>> _readPersistedWorkTypeIds() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return {...?prefs.getStringList(_workTypesPrefKey)};
    } catch (_) {
      return {};
    }
  }

  Future<List<PartnerWorkType>> loadWorkTypes() async {
    final modules = await api.onboardingServices();
    return PartnerWorkType.fromModules(
      modules,
      partnerType: role?.id ?? 'service',
    );
  }

  void setPhone(String value) {
    phone = value;
    notifyListeners();
  }

  void applyPartner(Map<String, dynamic> json) {
    final previous = user;
    var mapped = api.userFromPartnerJson(json, preferredRole: role);

    // Never drop known phone/email/avatar from a partial payload.
    final fallbackMobile = _digitsOnly(
      mapped.mobile.isNotEmpty
          ? mapped.mobile
          : (previous?.mobile ?? phone ?? ''),
    );
    if (fallbackMobile.isNotEmpty && mapped.mobile != fallbackMobile) {
      mapped = mapped.copyWith(mobile: fallbackMobile);
    }
    if ((mapped.email == null || mapped.email!.isEmpty) &&
        (previous?.email ?? '').isNotEmpty) {
      mapped = mapped.copyWith(email: previous!.email);
    }
    if ((mapped.avatarUrl == null || mapped.avatarUrl!.isEmpty) &&
        (previous?.avatarUrl ?? '').isNotEmpty) {
      mapped = mapped.copyWith(avatarUrl: previous!.avatarUrl);
    }
    if ((mapped.referralCode == null || mapped.referralCode!.isEmpty) &&
        (previous?.referralCode ?? '').isNotEmpty) {
      mapped = mapped.copyWith(referralCode: previous!.referralCode);
    }

    user = mapped;
    // Keep the account role from the server. Do not let a stale local pick win.
    if (_serverPartnerType(json) != null) {
      role = user!.role;
    } else {
      role ??= user!.role;
    }
    if (fallbackMobile.isNotEmpty) {
      phone = fallbackMobile;
      unawaited(tokens.writePhone(fallbackMobile));
    }
    if (selectedWorkTypes.isNotEmpty) {
      user = user!.copyWith(
        workTypes: selectedWorkTypes.map((e) => e.title).toList(),
      );
    }
  }

  String _digitsOnly(String value) => value.replaceAll(RegExp(r'\D'), '');

  String? _serverPartnerType(Map<String, dynamic> json) {
    String? read(Map source) {
      final type = source['partner_type']?.toString();
      if (type == null || type.isEmpty) return null;
      return type;
    }

    final direct = read(json);
    if (direct != null) return direct;
    final data = json['data'];
    if (data is Map) {
      final nested = read(data);
      if (nested != null) return nested;
    }
    final partner = json['partner'];
    if (partner is Map) return read(partner);
    return null;
  }

  Future<Map<String, dynamic>> sendOtp(String phoneDigits) async {
    lastError = null;
    final res = await api.sendOtp(phoneDigits);
    phone = _digitsOnly(phoneDigits);
    await tokens.writePhone(phone!);
    debugOtp = res['debug_otp']?.toString();
    notifyListeners();
    return res;
  }

  Future<void> verifyOtp(String otp, {String? name, String? email, String? referralCode}) async {
    lastError = null;
    final phoneDigits = _digitsOnly(phone ?? '');
    if (phoneDigits.isEmpty) {
      throw ApiException('Phone missing');
    }
    final res = await api.verifyOtp(phoneDigits, otp, name: name, email: email, referralCode: referralCode);
    final partner = res['partner'];
    final alreadyHasRole = partner is Map &&
        _serverPartnerType(Map<String, dynamic>.from(partner)) != null;
    if (partner is Map) {
      applyPartner(Map<String, dynamic>.from(partner));
    }
    // Login phone is authoritative if API payload omits it.
    if ((user?.mobile ?? '').isEmpty) {
      user = user?.copyWith(mobile: phoneDigits);
    }
    phone = phoneDigits;
    await tokens.writePhone(phoneDigits);
    loggedIn = true;
    // Existing accounts already have a role. Re-submitting onboarding here
    // used to overwrite partner_type on every login.
    if (!alreadyHasRole) {
      await ensureOnboardingSubmitted();
    }
    notifyListeners();
    unawaited(_hydrateAfterLogin());
  }

  /// Dashboard, tasks, push and GPS. Never awaited by splash or the online toggle.
  Future<void> _hydrateAfterLogin() async {
    try {
      await _refreshDashboardQuiet().timeout(const Duration(seconds: 20));
    } catch (_) {}
    try {
      await refreshKyc(notify: false).timeout(const Duration(seconds: 20));
    } catch (_) {}
    if (!loggedIn) return;
    if (isKycApproved) {
      try {
        await refreshTasks().timeout(const Duration(seconds: 25));
      } catch (_) {}
      unawaited(_startRealtime());
      unawaited(_syncPresence());
    }
    notifyListeners();
  }

  Future<void> _syncPresence() async {
    final current = user;
    if (current == null) return;
    try {
      await overlay
          .syncWithOnlineState(
            isOnline: current.isOnline,
            partnerName: current.name,
          )
          .timeout(const Duration(seconds: 8));
    } catch (_) {}
    try {
      if (current.isOnline) {
        await location.start().timeout(const Duration(seconds: 15));
      } else {
        await location.stop().timeout(const Duration(seconds: 5));
      }
    } catch (_) {}
  }

  Future<void> refreshProfile() async {
    lastError = null;
    phone ??= await tokens.readPhone();
    try {
      final me = await api.me();
      applyPartner(me);
    } catch (_) {
      // Fallback: profile endpoint (same resource, different route).
      final profile = await api.profile();
      applyPartner(profile);
    }
    if ((user?.mobile ?? '').isEmpty && (phone ?? '').isNotEmpty) {
      user = user?.copyWith(mobile: phone);
    }
    notifyListeners();
  }

  Future<void> updateProfile({required String name, required String email}) async {
    lastError = null;
    final json = await api.updateProfile(name: name, email: email);
    applyPartner(json);
    notifyListeners();
  }

  Future<void> updateAvatar(String filePath) async {
    lastError = null;
    final json = await api.uploadAvatar(filePath);
    applyPartner(json);
    notifyListeners();
  }

  Future<void> ensureOnboardingSubmitted() async {
    if (user == null) return;
    final partnerType = (role ?? user!.role).id;
    var ids = <int>[];

    if (role == PartnerRole.service && selectedWorkTypes.isNotEmpty) {
      ids = selectedWorkTypes
          .map((e) => e.moduleId)
          .whereType<int>()
          .toSet()
          .toList();
      if (ids.isEmpty) {
        try {
          final options = await loadWorkTypes();
          ids = options
              .where(
                (option) => selectedWorkTypes.any(
                  (picked) =>
                      picked.id == option.id || picked.slug == option.slug,
                ),
              )
              .map((e) => e.moduleId)
              .whereType<int>()
              .toSet()
              .toList();
        } catch (_) {}
      }
    }

    if (ids.isEmpty && role != PartnerRole.service) {
      try {
        final modules = await api.onboardingServices();
        for (final module in modules) {
          final types = module['provider_types'];
          final list = types is List ? types.map((e) => '$e').toList() : const <String>[];
          if (!list.contains(partnerType)) continue;
          final id = module['id'] is int
              ? module['id'] as int
              : int.tryParse('${module['id']}');
          if (id != null) ids.add(id);
        }
      } catch (_) {}
    }

    if (ids.isEmpty) return;

    try {
      await api.submitOnboarding(
        partnerType: partnerType,
        serviceModuleIds: ids.toSet().toList(),
        name: (user!.name.isEmpty || user!.name == 'Partner')
            ? (role ?? user!.role).title
            : user!.name,
        meta: {
          if (selectedWorkTypes.isNotEmpty) ...{
            'skills': selectedWorkTypes.map((e) => e.slug).toList(),
            'work_types': selectedWorkTypes.map((e) => e.title).toList(),
          },
        },
      );
      await refreshKyc();
    } catch (_) {
      // Login should still succeed if onboarding submit is delayed.
    }
  }

  /// Adds or re-applies for services. Approved services stay live on the server.
  Future<void> applyForServices(List<int> moduleIds) async {
    if (user == null || moduleIds.isEmpty) return;
    final partnerType = (role ?? user!.role).id;
    await api.submitOnboarding(
      partnerType: partnerType,
      serviceModuleIds: moduleIds.toSet().toList(),
      name: user!.name.isEmpty ? (role ?? user!.role).title : user!.name,
    );
    await refreshKyc();
  }

  /// Submits selected services. Returns true when the partner should open KYC/review.
  Future<bool> submitSelectedServices({bool forceReview = false}) async {
    await ensureOnboardingSubmitted();
    await refreshKyc();
    return forceReview || !isKycApproved;
  }

  Future<void> _refreshDashboardQuiet() async {
    try {
      final dash = await api.dashboard();
      final partner = dash['partner'];
      if (partner is Map) {
        final mapped = api.userFromPartnerJson(
          Map<String, dynamic>.from(partner),
          preferredRole: role,
        );
        if (_serverPartnerType(Map<String, dynamic>.from(partner)) != null) {
          role = mapped.role;
        }
        final stats = dash['stats'];
        incentive = PartnerIncentive.fromJson(dash['incentive']);
        // Keep phone/email/avatar if dashboard payload omits them.
        user = mapped.copyWith(
          mobile: mapped.mobile.isNotEmpty ? mapped.mobile : user?.mobile,
          email: (mapped.email != null && mapped.email!.isNotEmpty)
              ? mapped.email
              : user?.email,
          avatarUrl: (mapped.avatarUrl != null && mapped.avatarUrl!.isNotEmpty)
              ? mapped.avatarUrl
              : user?.avatarUrl,
          referralCode: (mapped.referralCode != null && mapped.referralCode!.isNotEmpty)
              ? mapped.referralCode
              : user?.referralCode,
          todayEarnings: stats is Map
              ? ((stats['today_earnings'] as num?)?.toDouble() ??
                    mapped.todayEarnings)
              : mapped.todayEarnings,
          completedTodayCount: stats is Map
              ? ((stats['completed_today'] as num?)?.toInt() ??
                    mapped.completedTodayCount)
              : mapped.completedTodayCount,
          activeJobsCount: stats is Map
              ? ((stats['active_jobs'] as num?)?.toInt() ??
                    mapped.activeJobsCount)
              : mapped.activeJobsCount,
          workTypes: selectedWorkTypes.map((e) => e.title).toList(),
        );
      }
    } catch (_) {
      // keep current user snapshot
    }
  }

  Future<void> refreshKyc({bool notify = true}) async {
    if (!loggedIn) return;
    try {
      final status = await api.onboardingStatus();
      if (user != null) {
        final kyc = status['kyc_status']?.toString() ?? user!.kycStatus;
        final approved = kyc?.toLowerCase() == 'approved';
        user = user!.copyWith(
          canOperate: status['can_operate'] == true,
          status: status['status']?.toString() ?? user!.status,
          kycStatus: kyc,
          isOnline: approved ? user!.isOnline : false,
        );
      }
      serviceApprovals = ServiceApproval.listFrom(status['service_approvals']);
      await hydrateSelectedWorkTypes(status: status, notify: false);
      if (notify) notifyListeners();
    } catch (_) {}
  }

  /// Restore selected services from onboarding status / approvals.
  Future<void> hydrateSelectedWorkTypes({
    Map<String, dynamic>? status,
    bool notify = true,
  }) async {
    if (!loggedIn) return;
    try {
      final data = status ?? Map<String, dynamic>.from(await api.onboardingStatus());
      final partnerType =
          data['partner_type']?.toString() ?? role?.id ?? user?.role.id ?? 'service';
      if (role == null) {
        role = switch (partnerType) {
          'business' => PartnerRole.business,
          'service' => PartnerRole.service,
          _ => PartnerRole.delivery,
        };
      }

      final modules = await api.onboardingServices();
      final options = PartnerWorkType.fromModules(
        modules,
        partnerType: partnerType,
      );

      final skillSlugs = <String>{
        for (final raw in (data['selected_skills'] is List
            ? data['selected_skills'] as List
            : const []))
          '${raw}'.toLowerCase(),
      };
      final workTitles = <String>{
        for (final raw in (data['selected_work_types'] is List
            ? data['selected_work_types'] as List
            : const []))
          '${raw}'.toLowerCase(),
      };
      final moduleIds = <int>{
        for (final raw in (data['selected_module_ids'] is List
            ? data['selected_module_ids'] as List
            : const []))
          if (raw is int)
            raw
          else if (int.tryParse('$raw') != null)
            int.parse('$raw'),
      };
      if (moduleIds.isEmpty && data['service_approvals'] is List) {
        for (final row in data['service_approvals'] as List) {
          if (row is! Map) continue;
          final id = row['service_module_id'];
          if (id is int) {
            moduleIds.add(id);
          } else {
            final parsed = int.tryParse('$id');
            if (parsed != null) moduleIds.add(parsed);
          }
        }
      }

      final picked = <PartnerWorkType>[];
      for (final option in options) {
        final bySkill = skillSlugs.contains(option.slug.toLowerCase()) ||
            skillSlugs.contains(option.id.toLowerCase());
        final byTitle = workTitles.contains(option.title.toLowerCase());
        final byModule = option.moduleId != null &&
            moduleIds.contains(option.moduleId) &&
            skillSlugs.isEmpty &&
            workTitles.isEmpty;
        if (bySkill || byTitle || byModule) {
          picked.add(option);
        }
      }

      // Module-only (e.g. laundry/cleaning) when skills empty.
      if (picked.isEmpty && moduleIds.isNotEmpty) {
        for (final option in options) {
          if (option.moduleId != null && moduleIds.contains(option.moduleId)) {
            // For helper module without skill meta, don't select all helper rows.
            if (option.moduleSlug == 'helper') continue;
            picked.add(option);
          }
        }
      }

      if (picked.isEmpty) {
        final persisted = await _readPersistedWorkTypeIds();
        if (persisted.isNotEmpty) {
          for (final option in options) {
            if (persisted.contains(option.id)) picked.add(option);
          }
        }
      }

      if (picked.isNotEmpty) {
        selectedWorkTypes = picked;
        if (user != null) {
          user = user!.copyWith(
            workTypes: picked.map((e) => e.title).toList(),
          );
        }
        unawaited(_persistSelectedWorkTypes());
      }
      if (notify) notifyListeners();
    } catch (_) {}
  }

  Future<void> unlockAfterKycApproval() async {
    if (!loggedIn || !isKycApproved) return;
    unawaited(_hydrateAfterLogin());
  }

  int? _livePartnerId;

  Future<void> _startRealtime() async {
    live.removeListener(_onLive);
    live.addListener(_onLive);
    final id = user?.id;
    if (id != null && _livePartnerId != id) {
      _livePartnerId = id;
      await live.startPartner(id);
    }
    try {
      final token = await PushService.token().timeout(const Duration(seconds: 8));
      if (token != null && token.isNotEmpty) {
        await api.registerDeviceToken(token).timeout(const Duration(seconds: 12));
      }
    } catch (_) {}
    _poll?.cancel();
    _poll = Timer.periodic(const Duration(seconds: 8), (_) {
      if (loggedIn && user?.isOnline == true) {
        refreshTasks();
      }
    });
  }

  void _onLive() {
    if (!loggedIn) return;
    if (_lastLiveTick == live.tick) return;
    _lastLiveTick = live.tick;
    if (!tasksBusy) refreshTasks();
    refreshEarnings();
  }

  Future<void> _stopRealtime() async {
    live.removeListener(_onLive);
    _poll?.cancel();
    _poll = null;
    _livePartnerId = null;
    await live.stop();
  }

  Future<void> refreshTasks() async {
    if (!loggedIn) return;
    tasksBusy = true;
    notifyListeners();
    try {
      final partnerId = user?.id;
      final available = await api.listBookings(scope: 'available', partnerId: partnerId);
      final mine = await api.listBookings(scope: 'mine', partnerId: partnerId);
      final byId = <String, PartnerTask>{};
      for (final t in [...available, ...mine]) {
        byId[t.id] = t;
      }
      tasks = byId.values.toList();
      final onTrip = tasks.any((t) =>
          t.status == 'accepted' ||
          t.status == 'arrived' ||
          t.status == 'in_progress');
      location.setOnTrip(onTrip);
      if (onTrip && user?.isOnline == true) {
        unawaited(location.pingNow());
      }
      if (user != null) {
        user = user!.copyWith(
          activeJobsCount: tasks
              .where((t) =>
                  t.status == 'accepted' ||
                  t.status == 'arrived' ||
                  t.status == 'in_progress')
              .length,
          availableJobsCount: tasks.where((t) => t.status == 'pending').length,
          workTypes: selectedWorkTypes.map((e) => e.title).toList(),
        );
      }
    } catch (e) {
      lastError = '$e';
    } finally {
      tasksBusy = false;
      notifyListeners();
    }
    unawaited(_refreshTodayStats());
  }

  /// Updates today's numbers and incentive progress without touching the rest of the profile.
  Future<void> _refreshTodayStats() async {
    try {
      final dash = await api.dashboard();
      final stats = dash['stats'];
      incentive = PartnerIncentive.fromJson(dash['incentive']);
      if (user != null && stats is Map) {
        user = user!.copyWith(
          todayEarnings: (stats['today_earnings'] as num?)?.toDouble() ?? user!.todayEarnings,
          completedTodayCount: (stats['completed_today'] as num?)?.toInt() ?? user!.completedTodayCount,
        );
      }
      notifyListeners();
    } catch (_) {}
  }

  Future<void> refreshEarnings() async {
    try {
      earningsSummary = await api.earnings();
      notifyListeners();
    } catch (e) {
      lastError = '$e';
      notifyListeners();
    }
  }

  /// Home / jobs are locked until admin approves all KYC documents.
  bool get isKycApproved {
    if (user == null) return false;
    if (user!.canOperate) return true;
    return user!.kycStatus?.toLowerCase() == 'approved';
  }

  bool get needsKycGate => loggedIn && !isKycApproved;

  bool get canGoOnline {
    if (user == null) return false;
    if (user!.canOperate) return true;
    final kyc = user!.kycStatus?.toLowerCase();
    final status = user!.status?.toLowerCase();
    if (kyc != 'approved') return false;
    return status != 'rejected' && status != 'suspended' && status != 'blocked';
  }

  /// Online / offline — Laravel `is_online` + Firebase RTDB presence (if configured).
  Future<void> setOnline(bool online) async {
    if (user == null || availabilityBusy) return;
    if (online) {
      await refreshKyc();
      if (!canGoOnline) {
        lastError = user?.kycStatus?.toLowerCase() == 'approved'
            ? 'Account is ${user?.status ?? 'pending'}. Contact support to go online.'
            : 'KYC / approval pending. Complete documents before going online.';
        notifyListeners();
        throw ApiException(lastError!);
      }
    }

    final previous = user!.isOnline;
    availabilityBusy = true;
    lastError = null;
    user!.isOnline = online;
    notifyListeners();

    try {
      final res = await api
          .setAvailability(online)
          .timeout(const Duration(seconds: 20));
      user!.isOnline = res['is_online'] == true;
    } catch (e) {
      user!.isOnline = previous;
      lastError = '$e';
      rethrow;
    } finally {
      // Put the switch back immediately. GPS and overlay must not keep the loader up.
      availabilityBusy = false;
      notifyListeners();
    }
    unawaited(_syncPresence());
    if (user?.isOnline == true) {
      unawaited(refreshTasks());
    }
  }

  Future<void> toggleOnline() => setOnline(!(user?.isOnline ?? false));

  Future<void> logout() async {
    if (user?.isOnline == true) {
      try {
        await api.setAvailability(false);
      } catch (_) {}
    }
    await overlay.hideBubble();
    await location.stop();
    await _stopRealtime();
    await api.logout();
    loggedIn = false;
    phone = null;
    debugOtp = null;
    user = null;
    tasks = [];
    earningsSummary = null;
    incentive = null;
    serviceApprovals = [];
    notifyListeners();
  }

  int? _bookingId(String id) {
    final t = tasks.where((e) => e.id == id).firstOrNull;
    return t?.bookingId ?? int.tryParse(id);
  }

  Future<void> acceptTask(String id) async {
    final task = tasks.where((e) => e.id == id).firstOrNull;
    final bookingId = task?.bookingId ?? int.tryParse(id);
    if (bookingId == null) return;
    lastError = null;
    try {
      await JobAlert.stop();
      await api.acceptBooking(bookingId, legType: task?.legType);
      await JobAlert.stop();
      await refreshTasks();
    } catch (e) {
      if ('$e'.toLowerCase().contains('not approved for this service')) {
        lastError = AppStrings.tr('This service is not approved yet');
        unawaited(refreshKyc());
        unawaited(refreshTasks());
        notifyListeners();
        throw ApiException(lastError!);
      }
      lastError = '$e';
      notifyListeners();
      rethrow;
    }
  }

  Future<void> markArrived(String id) async {
    final bookingId = _bookingId(id);
    if (bookingId == null) return;
    lastError = null;
    try {
      await api.updateBookingStatus(bookingId, 'arrived');
      await refreshTasks();
    } catch (e) {
      lastError = '$e';
      notifyListeners();
      rethrow;
    }
  }

  Future<void> startTask(String id, {String? otp, bool cashCollected = false}) async {
    final bookingId = _bookingId(id);
    if (bookingId == null) return;
    lastError = null;
    try {
      await api.updateBookingStatus(
        bookingId,
        'in_progress',
        otp: otp,
        cashCollected: cashCollected,
      );
      try {
        await refreshTasks();
      } catch (_) {
        // Status already updated — refresh failure should not surface as OTP error.
      }
    } catch (e) {
      lastError = '$e';
      notifyListeners();
      // Refresh so UI reflects server status if the update actually committed.
      try {
        await refreshTasks();
      } catch (_) {}
      rethrow;
    }
  }

  Future<void> completeTask(String id, {bool cashCollected = false, String? otp}) async {
    final bookingId = _bookingId(id);
    if (bookingId == null) return;
    lastError = null;
    try {
      await api.updateBookingStatus(
        bookingId,
        'completed',
        cashCollected: cashCollected,
        otp: otp,
      );
      try {
        await refreshTasks();
        await refreshEarnings();
      } catch (_) {}
    } catch (e) {
      lastError = '$e';
      notifyListeners();
      try {
        await refreshTasks();
      } catch (_) {}
      rethrow;
    }
  }

  Future<Map<String, dynamic>> sendJobOtp(int bookingId, String purpose) {
    return api.sendJobOtp(bookingId, purpose);
  }

  Future<void> uploadJobPhotos(String id, List<String> filePaths, {String kind = 'laundry_complete'}) async {
    final bookingId = _bookingId(id);
    if (bookingId == null) return;
    lastError = null;
    try {
      final uploaded = await api.uploadBookingPhotos(
        bookingId: bookingId,
        filePaths: filePaths,
        kind: kind,
      );
      final task = tasks.where((e) => e.id == id).firstOrNull;
      if (task != null && uploaded.isNotEmpty) {
        final urls = uploaded
            .map((e) => e['url']?.toString() ?? '')
            .where((u) => u.isNotEmpty)
            .toList();
        task.photoUrls = [...task.photoUrls, ...urls];
        task.photoCount = task.photoUrls.length;
        if (kind == 'parcel_pickup') {
          task.pickupPhotoCount += urls.length;
        }
        if (kind == 'parcel_pod' || kind == 'drop_proof') {
          task.podPhotoCount += urls.length;
        }
        notifyListeners();
      }
      await refreshTasks();
    } catch (e) {
      lastError = '$e';
      notifyListeners();
      rethrow;
    }
  }

  Future<PartnerTask?> loadTaskDetail(String id) async {
    final bookingId = _bookingId(id);
    if (bookingId == null) return null;
    final json = await api.bookingDetail(bookingId);
    final existing = tasks.where((e) => e.id == id).firstOrNull;
    final task = api.taskFromBooking(
      json,
      partnerId: user?.id,
      asOffer: existing?.status == 'pending' && existing?.legType != 'laundry',
    );
    final idx = tasks.indexWhere((e) => e.id == task.id);
    if (idx >= 0) {
      tasks[idx] = task;
    }
    notifyListeners();
    return task;
  }

  Future<void> rejectTask(String id) async {
    final bookingId = _bookingId(id);
    if (bookingId == null) return;
    lastError = null;
    try {
      await api.rejectBooking(bookingId);
      await JobAlert.stop();
      await refreshTasks();
    } catch (e) {
      lastError = '$e';
      notifyListeners();
      rethrow;
    }
  }

  Future<void> assignRider(String id, String rider) async {
    // Business assign maps to start for now (backend has no separate rider assign).
    await startTask(id);
    final t = tasks.where((e) => e.id == id).firstOrNull;
    if (t != null) {
      t.assignedRider = rider;
      notifyListeners();
    }
  }
}
