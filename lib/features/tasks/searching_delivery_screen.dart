import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:kaamfast_partner/l10n/app_strings.dart';
import 'package:kaamfast_partner/services/partner_api.dart';
import 'package:kaamfast_partner/theme/partner_theme.dart';
import 'package:provider/provider.dart';

class SearchingDeliveryScreen extends StatefulWidget {
  const SearchingDeliveryScreen({
    super.key,
    required this.bookingId,
    this.phase,
  });

  final int bookingId;
  final String? phase;

  @override
  State<SearchingDeliveryScreen> createState() => _SearchingDeliveryScreenState();
}

class _SearchingDeliveryScreenState extends State<SearchingDeliveryScreen>
    with SingleTickerProviderStateMixin {
  Map<String, dynamic>? _data;
  bool _loading = true;
  String? _error;
  Timer? _poll;
  Timer? _tick;
  late final AnimationController _pulse;
  Duration _remaining = Duration.zero;
  Duration _total = const Duration(minutes: 5);

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(vsync: this, duration: const Duration(seconds: 2))
      ..repeat();
    _load();
    _poll = Timer.periodic(const Duration(seconds: 6), (_) => _load(silent: true));
    _tick = Timer.periodic(const Duration(seconds: 1), (_) => _updateTimer());
  }

  @override
  void dispose() {
    _poll?.cancel();
    _tick?.cancel();
    _pulse.dispose();
    super.dispose();
  }

  Future<void> _load({bool silent = false}) async {
    if (!silent && mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final data = await context.read<PartnerApi>().bookingSearching(widget.bookingId);
      if (!mounted) return;
      setState(() {
        _data = data;
        _loading = false;
        _error = null;
      });
      _updateTimer();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        if (_data == null) _error = '$e';
      });
    }
  }

  void _updateTimer() {
    final data = _data;
    if (data == null) return;
    final expiresRaw = data['offer_expires_at']?.toString();
    final startedRaw = data['offer_started_at']?.toString();
    final timeoutMins = (data['timeout_minutes'] as num?)?.toInt() ?? 5;
    DateTime? expires = expiresRaw != null ? DateTime.tryParse(expiresRaw)?.toLocal() : null;
    DateTime? started = startedRaw != null ? DateTime.tryParse(startedRaw)?.toLocal() : null;
    expires ??= (started ?? DateTime.now()).add(Duration(minutes: timeoutMins));
    started ??= expires.subtract(Duration(minutes: timeoutMins));
    final total = expires.difference(started);
    final left = expires.difference(DateTime.now());
    if (!mounted) return;
    setState(() {
      _total = total.isNegative ? Duration(minutes: timeoutMins) : total;
      _remaining = left.isNegative ? Duration.zero : left;
    });
  }

  @override
  Widget build(BuildContext context) {
    final data = _data;
    final riders = <Map<String, dynamic>>[];
    if (data?['riders'] is List) {
      for (final item in data!['riders'] as List) {
        if (item is Map) riders.add(Map<String, dynamic>.from(item));
      }
    }
    final centerLat = (data?['center'] is Map)
        ? ((data!['center'] as Map)['latitude'] as num?)?.toDouble()
        : null;
    final centerLng = (data?['center'] is Map)
        ? ((data!['center'] as Map)['longitude'] as num?)?.toDouble()
        : null;
    final pickup = data?['pickup'] is Map ? Map<String, dynamic>.from(data!['pickup'] as Map) : null;
    final drop = data?['drop'] is Map ? Map<String, dynamic>.from(data!['drop'] as Map) : null;
    final progress = _total.inSeconds <= 0
        ? 0.0
        : (1 - (_remaining.inSeconds / _total.inSeconds)).clamp(0.0, 1.0);

    return Scaffold(
      backgroundColor: const Color(0xFFF3F5F2),
      body: _loading && data == null
          ? const Center(child: CircularProgressIndicator())
          : _error != null && data == null
              ? Center(child: Text(_error!))
              : Column(
                  children: [
                    Expanded(
                      flex: 5,
                      child: Stack(
                        children: [
                          Positioned.fill(
                            child: _SearchingMap(
                              pulse: _pulse,
                              centerLat: centerLat ?? 22.7196,
                              centerLng: centerLng ?? 75.8577,
                              riders: riders,
                            ),
                          ),
                          SafeArea(
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: CircleAvatar(
                                backgroundColor: Colors.white,
                                child: IconButton(
                                  icon: const Icon(Icons.arrow_back),
                                  onPressed: () => Navigator.pop(context),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      flex: 4,
                      child: Container(
                        width: double.infinity,
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                          boxShadow: [
                            BoxShadow(color: Color(0x22000000), blurRadius: 16, offset: Offset(0, -4)),
                          ],
                        ),
                        child: ListView(
                          padding: const EdgeInsets.fromLTRB(20, 10, 20, 24),
                          children: [
                            Center(
                              child: Container(
                                width: 40,
                                height: 4,
                                decoration: BoxDecoration(
                                  color: PartnerColors.line,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                              ),
                            ),
                            const SizedBox(height: 14),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: LinearProgressIndicator(
                                value: progress,
                                minHeight: 8,
                                backgroundColor: const Color(0xFFE8EEF8),
                                color: const Color(0xFF2F6FED),
                              ),
                            ),
                            const SizedBox(height: 10),
                            Align(
                              alignment: Alignment.centerRight,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFEAF2FF),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.timer_outlined, size: 16, color: Color(0xFF2F6FED)),
                                    const SizedBox(width: 4),
                                    Text(
                                      _formatRemaining(_remaining),
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                        color: Color(0xFF2F6FED),
                                        fontSize: 13,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              context.tr(data?['title']?.toString() ?? 'Searching for delivery partner'),
                              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${context.tr(riders.length == 1 ? '{count} rider nearby' : '{count} riders nearby', {'count': riders.length})} · ${data?['booking_number'] ?? ''}',
                              style: const TextStyle(color: PartnerColors.muted),
                            ),
                            const SizedBox(height: 18),
                            Text(
                              context.tr('Booking Details'),
                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                            ),
                            const SizedBox(height: 10),
                            Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: PartnerColors.line),
                              ),
                              child: Column(
                                children: [
                                  _AddrRow(
                                    color: PartnerColors.accent,
                                    icon: Icons.circle,
                                    text: pickup?['line1']?.toString() ?? context.tr('Pickup location'),
                                  ),
                                  const SizedBox(height: 12),
                                  _AddrRow(
                                    color: PartnerColors.danger,
                                    icon: Icons.location_on,
                                    text: drop?['line1']?.toString() ?? context.tr('Drop location'),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
    );
  }

  String _formatRemaining(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return context.tr('{time} mins', {'time': '$m:$s'});
  }
}

class _AddrRow extends StatelessWidget {
  const _AddrRow({required this.color, required this.icon, required this.text});
  final Color color;
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 10),
        Expanded(
          child: Text(text, style: const TextStyle(fontWeight: FontWeight.w600, height: 1.3)),
        ),
      ],
    );
  }
}

class _SearchingMap extends StatelessWidget {
  const _SearchingMap({
    required this.pulse,
    required this.centerLat,
    required this.centerLng,
    required this.riders,
  });

  final Animation<double> pulse;
  final double centerLat;
  final double centerLng;
  final List<Map<String, dynamic>> riders;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: pulse,
      builder: (context, _) {
        return CustomPaint(
          painter: _MapPainter(pulse: pulse.value),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final size = Size(constraints.maxWidth, constraints.maxHeight);
              final center = Offset(size.width / 2, size.height / 2);
              final scale = size.shortestSide / 0.04; // ~deg span

              Offset project(double lat, double lng) {
                final dx = (lng - centerLng) * scale * math.cos(centerLat * math.pi / 180);
                final dy = (centerLat - lat) * scale;
                return Offset(center.dx + dx, center.dy + dy);
              }

              return Stack(
                children: [
                  ...riders.map((r) {
                    final lat = (r['latitude'] as num?)?.toDouble();
                    final lng = (r['longitude'] as num?)?.toDouble();
                    if (lat == null || lng == null) return const SizedBox.shrink();
                    final pos = project(lat, lng);
                    if (pos.dx < -40 || pos.dy < -40 || pos.dx > size.width + 40 || pos.dy > size.height + 40) {
                      return const SizedBox.shrink();
                    }
                    return Positioned(
                      left: pos.dx - 14,
                      top: pos.dy - 14,
                      child: const Icon(Icons.two_wheeler, color: Color(0xFFE53935), size: 28),
                    );
                  }),
                  Positioned(
                    left: center.dx - 14,
                    top: center.dy - 28,
                    child: const Icon(Icons.location_on, color: PartnerColors.primary, size: 36),
                  ),
                ],
              );
            },
          ),
        );
      },
    );
  }
}

class _MapPainter extends CustomPainter {
  _MapPainter({required this.pulse});
  final double pulse;

  @override
  void paint(Canvas canvas, Size size) {
    final bg = Paint()..color = const Color(0xFFECEFE8);
    canvas.drawRect(Offset.zero & size, bg);

    final road = Paint()
      ..color = Colors.white
      ..strokeWidth = 10
      ..style = PaintingStyle.stroke;
    final roadThin = Paint()
      ..color = const Color(0xFFD7DDD2)
      ..strokeWidth = 2;

    for (var i = 0; i < 8; i++) {
      final y = size.height * (i + 1) / 9;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), road);
      canvas.drawLine(Offset(0, y), Offset(size.width, y), roadThin);
    }
    for (var i = 0; i < 6; i++) {
      final x = size.width * (i + 1) / 7;
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), road);
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), roadThin);
    }

    final park = Paint()..color = const Color(0xFFD5E8C4);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(size.width * 0.12, size.height * 0.18, size.width * 0.28, size.height * 0.16),
        const Radius.circular(12),
      ),
      park,
    );

    final center = Offset(size.width / 2, size.height / 2);
    for (var i = 3; i >= 1; i--) {
      final t = ((pulse + i / 3) % 1.0);
      final radius = 28.0 + t * 70;
      final alpha = (1 - t) * 0.35;
      canvas.drawCircle(
        center,
        radius,
        Paint()..color = PartnerColors.accent.withValues(alpha: alpha),
      );
    }
    canvas.drawCircle(center, 10, Paint()..color = Colors.white);
    canvas.drawCircle(center, 5, Paint()..color = PartnerColors.primary);
  }

  @override
  bool shouldRepaint(covariant _MapPainter oldDelegate) => oldDelegate.pulse != pulse;
}
