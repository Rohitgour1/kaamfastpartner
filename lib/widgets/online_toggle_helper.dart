import 'package:flutter/material.dart';
import 'package:kaamfast_partner/l10n/app_strings.dart';
import 'package:kaamfast_partner/services/overlay_permission_service.dart';
import 'package:kaamfast_partner/state/session_controller.dart';
import 'package:kaamfast_partner/theme/partner_theme.dart';

/// When partner goes online on Android, ask for overlay permission via popup.
Future<void> goOnlineWithOverlayPrompt(BuildContext context, SessionController session) async {
  final goingOnline = !(session.user?.isOnline ?? false);

  if (goingOnline) {
    await session.refreshKyc();
    if (!context.mounted) return;
  }

  if (goingOnline && !session.canGoOnline) {
    final kycOk = session.user?.kycStatus?.toLowerCase() == 'approved';
    final status = session.user?.status;
    final kycStatus = session.user?.kycStatus;
    await showDialog<void>(
      context: context,
      builder: (ctx) {
        final reason = kycOk
            ? ctx.tr(
                'KYC is approved, but your account is {status}. Please contact support.',
                {'status': ctx.tr(status ?? 'pending')},
              )
            : ctx.tr('KYC must be completed before you can go online.');
        final summary = ctx.tr('Status: {status} · KYC: {kyc}', {
          'status': status != null ? ctx.tr(status) : '—',
          'kyc': kycStatus != null ? ctx.tr(kycStatus) : '—',
        });
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(
            ctx.tr(kycOk ? 'Account not active' : 'KYC required'),
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
          content: Text('$reason\n\n$summary'),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(ctx),
              style: FilledButton.styleFrom(backgroundColor: PartnerColors.primary),
              child: Text(ctx.tr('OK')),
            ),
          ],
        );
      },
    );
    return;
  }

  if (goingOnline && OverlayPermissionService.instance.isAndroid) {
    final overlay = OverlayPermissionService.instance;
    final granted = await overlay.isPermissionGranted();
    final prefOn = await overlay.isPreferenceEnabled();

    if (!granted || !prefOn) {
      if (!context.mounted) return;
      final allow = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              const Icon(Icons.picture_in_picture_alt_outlined, color: PartnerColors.primary),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  ctx.tr('Display over other apps'),
                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
                ),
              ),
            ],
          ),
          content: Text(
            ctx.tr(
              'Allow “Display over other apps” to show a floating bubble while receiving jobs. '
              'This lets you see your ONLINE status on top of maps and other apps.',
            ),
            style: const TextStyle(height: 1.4),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(ctx.tr('Not now')),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: FilledButton.styleFrom(backgroundColor: PartnerColors.primary),
              child: Text(ctx.tr('Allow')),
            ),
          ],
        ),
      );

      if (allow == true) {
        var ok = granted;
        if (!ok) {
          ok = await overlay.requestPermission();
        }
        if (ok) {
          await overlay.setPreferenceEnabled(true);
        } else if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                context.tr('Allow “Display over other apps” in Settings, then try going Online again.'),
              ),
            ),
          );
        }
      }
      // Even if Not now — still go online; bubble just won't show.
    }
  }

  if (!context.mounted) return;
  await session.toggleOnline();
}
