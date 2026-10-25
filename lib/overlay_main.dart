import 'package:flutter/material.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';
import 'package:kaamfast_partner/l10n/app_strings.dart';
import 'package:kaamfast_partner/services/job_alert.dart';
import 'package:kaamfast_partner/theme/partner_theme.dart';
import 'package:url_launcher/url_launcher.dart';

/// Separate isolate UI for the floating bubble (Android only).
@pragma('vm:entry-point')
Future<void> overlayMain() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AppStrings.loadSaved();
  runApp(const MaterialApp(
    debugShowCheckedModeBanner: false,
    home: PartnerOverlayBubble(),
  ));
}

class PartnerOverlayBubble extends StatefulWidget {
  const PartnerOverlayBubble({super.key});

  @override
  State<PartnerOverlayBubble> createState() => _PartnerOverlayBubbleState();
}

class _PartnerOverlayBubbleState extends State<PartnerOverlayBubble> {
  bool _newJob = false;

  @override
  void initState() {
    super.initState();
    FlutterOverlayWindow.overlayListener.listen((event) {
      if (event is Map && (event['action']?.toString() == 'new_job' || event['status']?.toString() == 'alert')) {
        if (mounted) setState(() => _newJob = true);
        _openApp();
      }
    });
  }

  Future<void> _openApp() async {
    try {
      await JobAlert.openAppIfPossible();
    } catch (_) {}
    try {
      await launchUrl(
        Uri.parse('kaamfastpartner://open'),
        mode: LaunchMode.externalApplication,
      );
    } catch (_) {}
    try {
      await FlutterOverlayWindow.shareData({'action': 'open_app'});
    } catch (_) {}
    if (mounted) setState(() => _newJob = false);
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _openApp,
        child: Center(
          child: SizedBox(
            width: 112,
            height: 112,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  width: 112,
                  height: 112,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: PartnerColors.primaryDeep,
                    border: Border.all(color: _newJob ? PartnerColors.accent : Colors.white, width: 3),
                  ),
                  child: ClipOval(
                    child: Image.asset(
                      'assets/images/logo.png',
                      fit: BoxFit.cover,
                      cacheWidth: 224,
                      cacheHeight: 224,
                      errorBuilder: (_, __, ___) => const Icon(
                        Icons.local_shipping_rounded,
                        color: Colors.white,
                        size: 48,
                      ),
                    ),
                  ),
                ),
                Positioned(
                  bottom: 6,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: _newJob ? PartnerColors.danger : PartnerColors.accent,
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: Colors.white, width: 1),
                    ),
                    child: Text(
                      AppStrings.tr(_newJob ? 'NEW JOB' : 'ONLINE'),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.4,
                        height: 1.1,
                      ),
                    ),
                  ),
                ),
                Positioned(
                  top: 0,
                  right: 0,
                  child: GestureDetector(
                    onTap: () async {
                      try {
                        await FlutterOverlayWindow.closeOverlay();
                      } catch (_) {}
                    },
                    child: Container(
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                      padding: const EdgeInsets.all(4),
                      child: const Icon(
                        Icons.close,
                        size: 16,
                        color: Colors.black,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
