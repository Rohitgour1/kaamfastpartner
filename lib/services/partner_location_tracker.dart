import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:kaamfast_partner/services/partner_api.dart';

class PartnerLocationTracker {
  PartnerLocationTracker(this._api);

  final PartnerApi _api;
  Timer? _timer;
  StreamSubscription<Position>? _stream;
  bool _running = false;
  bool _onTrip = false;

  /// Call when partner has an active assigned / arrived / in-progress job.
  void setOnTrip(bool onTrip) {
    if (_onTrip == onTrip) return;
    _onTrip = onTrip;
    if (_running) {
      unawaited(_restartStream());
    }
  }

  Future<void> start() async {
    if (_running) {
      await _ping();
      return;
    }
    final allowed = await _ensurePermission();
    if (!allowed) return;
    _running = true;
    await _ping();
    _timer?.cancel();
    _timer = Timer.periodic(
      Duration(seconds: _onTrip ? 5 : 12),
      (_) => _ping(),
    );
    await _restartStream();
  }

  Future<void> stop() async {
    _running = false;
    _onTrip = false;
    _timer?.cancel();
    _timer = null;
    await _stream?.cancel();
    _stream = null;
  }

  Future<void> _restartStream() async {
    await _stream?.cancel();
    _timer?.cancel();
    _timer = Timer.periodic(
      Duration(seconds: _onTrip ? 5 : 12),
      (_) => _ping(),
    );
    _stream = Geolocator.getPositionStream(
      locationSettings: LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: _onTrip ? 8 : 25,
      ),
    ).listen((position) {
      _api.updateLocation(position.latitude, position.longitude).ignore();
    });
  }

  Future<void> pingNow() => _ping();

  Future<void> _ping() async {
    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 12),
        ),
      ).timeout(const Duration(seconds: 15));
      await _api
          .updateLocation(position.latitude, position.longitude)
          .timeout(const Duration(seconds: 12));
    } catch (e) {
      debugPrint('Partner location ping skipped: $e');
    }
  }

  Future<bool> _ensurePermission() async {
    final enabled = await Geolocator.isLocationServiceEnabled();
    if (!enabled) {
      debugPrint('GPS is off; partner location will not sync.');
      return false;
    }
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    return permission == LocationPermission.always ||
        permission == LocationPermission.whileInUse;
  }
}
