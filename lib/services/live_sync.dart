import 'dart:async';

import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:kaamfast_partner/services/job_alert.dart';
import 'package:kaamfast_partner/services/push_service.dart';

class LiveSync extends ChangeNotifier {
  LiveSync();

  final List<StreamSubscription<dynamic>> _subs = [];
  int tick = 0;
  int pushTick = 0;
  int jobAlertTick = 0;
  String? lastTitle;
  String? lastBody;
  String? lastJobType;
  Map<String, String> lastData = {};

  /// Bumped on any `service.*` event (approval changes) from push or realtime.
  int serviceTick = 0;
  Map<String, String> lastServiceEvent = {};
  bool _liveReady = false;
  bool _offersReady = false;
  Set<String> _offerIds = {};

  Future<void> startPartner(int partnerId) async {
    await stop();
    _liveReady = false;
    _offersReady = false;
    _offerIds = {};
    await PushService.init();
    _subs.add(PushService.foreground.listen(_onMessage));
    _subs.add(PushService.opened.listen(_onOpened));
    final initial = await PushService.initialMessage();
    if (initial != null) {
      _onOpened(initial);
    }
    try {
      _subs.add(
        FirebaseDatabase.instance
            .ref('live/partners/$partnerId/latest')
            .onValue
            .listen(
          (event) {
            if (!_liveReady) {
              _liveReady = true;
              _bump();
              return;
            }
            _handleLiveValue(event.snapshot.value);
          },
          onError: (Object error) {
            debugPrint('Live latest listen error: $error');
          },
        ),
      );
      _subs.add(
        FirebaseDatabase.instance
            .ref('live/partners/$partnerId/offers')
            .onValue
            .listen(
          (event) {
            final ids = _offerIdsOf(event.snapshot.value);
            if (!_offersReady) {
              _offersReady = true;
              _offerIds = ids;
              if (ids.isNotEmpty) {
                lastJobType = 'booking.available';
                jobAlertTick++;
                JobAlert.ringAndOpen();
              }
              _bump();
              return;
            }
            final added = ids.difference(_offerIds);
            _offerIds = ids;
            if (added.isNotEmpty) {
              lastJobType = 'booking.available';
              jobAlertTick++;
              JobAlert.ringAndOpen();
            } else if (ids.isEmpty) {
              JobAlert.stop();
            }
            _bump();
          },
          onError: (Object error) {
            debugPrint('Live offers listen error: $error');
          },
        ),
      );
    } catch (e) {
      debugPrint('Live partner listen skipped: $e');
    }
  }

  void _handleLiveValue(Object? value) {
    if (value is Map) {
      final type = value['type']?.toString();
      final data = value['data'];
      _noteServiceEvent(type, {
        if (data is Map) ...data.map((k, v) => MapEntry('$k', '$v')),
        ...value.map((k, v) => MapEntry('$k', v is Map ? '' : '$v')),
      });
      if (type == 'booking.available') {
        lastJobType = type;
        jobAlertTick++;
        JobAlert.ringAndOpen();
      } else if (type == 'booking.assigned' ||
          type == 'booking.taken' ||
          type == 'booking.declined' ||
          type == 'booking.started' ||
          type == 'booking.arrived') {
        JobAlert.stop();
      }
    }
    _bump();
  }

  void _onMessage(RemoteMessage message) {
    lastTitle = message.notification?.title;
    lastBody = message.notification?.body;
    lastData = message.data.map((key, value) => MapEntry(key, '$value'));
    pushTick++;
    final data = Map<String, dynamic>.from(message.data);
    final type = data['type']?.toString();
    _noteServiceEvent(type, {
      ...lastData,
      'title': ?lastTitle,
      'body': ?lastBody,
    });
    if (type == 'booking.searching_delivery') {
      lastJobType = type;
      _bump();
      return;
    }
    if (type == 'booking.assigned' ||
        type == 'booking.taken' ||
        type == 'booking.declined' ||
        type == 'booking.started' ||
        type == 'booking.arrived') {
      JobAlert.stop();
      _bump();
      return;
    }
    if (JobAlert.isJobPayload(data, title: lastTitle, type: type)) {
      lastJobType = type ?? 'booking.available';
      jobAlertTick++;
      JobAlert.ringAndOpen();
    }
    _bump();
  }

  void _noteServiceEvent(String? type, Map<String, String> data) {
    if (type == null || !type.startsWith('service.')) return;
    lastServiceEvent = {...data, 'type': type};
    serviceTick++;
  }

  void _onOpened(RemoteMessage message) {
    _onMessage(message);
    JobAlert.openAppIfPossible();
  }

  Set<String> _offerIdsOf(Object? value) {
    if (value is! Map) return {};
    return value.keys.map((key) => '$key').toSet();
  }

  void _bump() {
    tick++;
    notifyListeners();
  }

  Future<void> stop() async {
    for (final sub in _subs) {
      await sub.cancel();
    }
    _subs.clear();
    await JobAlert.stop();
  }

  @override
  void dispose() {
    stop();
    super.dispose();
  }
}
