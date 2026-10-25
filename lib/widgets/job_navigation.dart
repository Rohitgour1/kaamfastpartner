import 'package:flutter/material.dart';
import 'package:kaamfast_partner/data/mock_data.dart';
import 'package:kaamfast_partner/l10n/app_strings.dart';
import 'package:url_launcher/url_launcher.dart';

Future<void> openJobRoute(BuildContext context, PartnerTask task) async {
  final dest = _destination(task);
  if (dest == null || dest.isEmpty) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.tr('Customer location is missing for this job.'))),
      );
    }
    return;
  }

  final q = Uri.encodeComponent(dest);
  final uris = [
    Uri.parse('google.navigation:q=$q&mode=d'),
    Uri.parse('comgooglemaps://?daddr=$q&directionsmode=driving'),
    Uri.parse('https://www.google.com/maps/dir/?api=1&destination=$q&travelmode=driving'),
  ];

  Object? lastError;
  for (final uri in uris) {
    try {
      final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (launched) return;
    } catch (e) {
      lastError = e;
    }
  }

  if (context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(lastError != null ? '$lastError' : context.tr('Could not open Google Maps.'))),
    );
  }
}

String? _destination(PartnerTask task) {
  final useDrop = task.status == 'in_progress' && task.hasDrop && !task.isOnSiteService;
  if (useDrop) {
    if (task.dropLat != null && task.dropLng != null) {
      return '${task.dropLat},${task.dropLng}';
    }
    if (task.hasDrop) return task.drop;
  }
  if (task.pickupLat != null && task.pickupLng != null) {
    return '${task.pickupLat},${task.pickupLng}';
  }
  if (task.pickup.isNotEmpty && task.pickup != '—') return task.pickup;
  if (task.dropLat != null && task.dropLng != null) {
    return '${task.dropLat},${task.dropLng}';
  }
  if (task.hasDrop) return task.drop;
  return null;
}
