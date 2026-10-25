import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:kaamfast_partner/data/mock_data.dart';
import 'package:kaamfast_partner/features/tasks/searching_delivery_screen.dart';
import 'package:kaamfast_partner/l10n/app_strings.dart';
import 'package:kaamfast_partner/state/session_controller.dart';
import 'package:kaamfast_partner/theme/partner_theme.dart';
import 'package:kaamfast_partner/widgets/job_otp_helper.dart';

Future<void> markPartnerArrived(
  BuildContext context,
  SessionController session,
  PartnerTask task,
) async {
  try {
    await session.markArrived(task.id);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.tr('Marked arrived at pickup'))),
      );
    }
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }
}

Future<void> startPartnerJob(
  BuildContext context,
  SessionController session,
  PartnerTask task,
) async {
  try {
    if (task.isPickupLeg) {
      if (task.pickupPhotoCount < 1) {
        final uploaded = await uploadPartnerJobPhotos(
          context,
          session,
          task,
          kind: 'parcel_pickup',
          title: 'Upload clothes photos',
        );
        if (!uploaded || !context.mounted) return;
      }
      final otp = await promptCustomerOtp(
        context: context,
        session: session,
        task: task,
        purpose: 'service_start',
        title: 'Pickup OTP',
        message: 'Ask the customer for the 6-digit OTP shown in their app, then collect the clothes.',
      );
      if (otp == null || !context.mounted) return;
      await session.startTask(task.id, otp: otp);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.tr('Clothes picked up. Drop them at the laundry next.'))),
        );
      }
      return;
    }

    if (task.needsPickupGoodsPhotos && task.pickupPhotoCount < 1) {
      final uploaded = await uploadPartnerJobPhotos(
        context,
        session,
        task,
        kind: 'parcel_pickup',
        title: 'Upload goods photos',
      );
      if (!uploaded || !context.mounted) return;
    }

    String? otp;
    if (task.isOnSiteService) {
      otp = await promptCustomerOtp(
        context: context,
        session: session,
        task: task,
        purpose: 'service_start',
        title: task.isDeliveryService ? 'Pickup OTP' : 'Start service OTP',
        message: task.isDeliveryService
            ? 'Ask sender/customer for the 6-digit OTP, upload goods photos, then collect payment and start.'
            : 'Ask the customer for the 6-digit OTP shown in their Kaam Fast app, then enter it to start.',
      );
      if (otp == null || !context.mounted) return;
    }

    var cashCollected = false;
    if (task.collectPaymentBeforeStart) {
      final ok = await confirmSenderPayment(context, task);
      if (ok != true || !context.mounted) return;
      cashCollected = task.isCash;
    }

    await session.startTask(task.id, otp: otp, cashCollected: cashCollected);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.tr(task.isDeliveryService ? 'Trip started' : 'Service started'))),
      );
    }
  } catch (e) {
    if (context.mounted) {
      final msg = '$e'.trim();
      if (msg.isNotEmpty && msg != 'null') {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
      }
    }
  }
}

Future<bool?> confirmSenderPayment(BuildContext context, PartnerTask task) {
  final method = (task.paymentMethod ?? (task.isCash ? 'cash' : 'online')).toUpperCase();
  if (task.isCash) {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.tr('Collect payment from sender')),
        content: Text(
          context.tr(
            'Collect full cash from the sender ({method}) before starting the trip. '
            'Confirm only after cash is received.',
            {'method': context.tr(method)},
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(context.tr('Not yet'))),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: Text(context.tr('Cash collected'))),
        ],
      ),
    );
  }

  return showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(context.tr('Confirm sender payment')),
      content: Text(
        context.tr(
          'Sender payment method: {method}.\n'
          'Online / wallet payment should already be received. Confirm before starting the trip.',
          {'method': context.tr(method)},
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: Text(context.tr('Back'))),
        FilledButton(onPressed: () => Navigator.pop(context, true), child: Text(context.tr('Payment confirmed'))),
      ],
    ),
  );
}

Future<void> completePartnerJob(
  BuildContext context,
  SessionController session,
  PartnerTask task,
) async {
  try {
    if (task.needsCompletePhotos && task.photoCount < 1 && task.photoUrls.isEmpty) {
      final uploaded = await uploadPartnerJobPhotos(context, session, task);
      if (!uploaded || !context.mounted) return;
    }

    if (task.needsPodPhotos && task.podPhotoCount < 1) {
      final uploaded = await uploadPartnerJobPhotos(
        context,
        session,
        task,
        kind: 'parcel_pod',
        title: 'Upload proof of delivery',
      );
      if (!uploaded || !context.mounted) return;
    }

    String? otp;
    if (task.isOnSiteService) {
      otp = await promptCustomerOtp(
        context: context,
        session: session,
        task: task,
        purpose: 'service_complete',
        title: task.isDeliveryService ? 'Drop OTP' : 'End service OTP',
        message: task.isDeliveryService
            ? (task.collectPaymentAtDrop
                ? 'Ask receiver for OTP, upload POD, collect cash, then complete.'
                : 'Ask receiver/customer for the OTP, upload POD, then complete the trip.')
            : 'Ask the customer for the new 6-digit OTP. Payment / wallet settlement runs only after this OTP is verified.',
      );
      if (otp == null || !context.mounted) return;
    } else if (task.isPickupLeg && task.handoffOtpRequired) {
      otp = await promptCustomerOtp(
        context: context,
        session: session,
        task: task,
        purpose: 'pickup_to_laundry',
        title: 'Drop clothes at laundry',
        message: 'Ask the laundry partner for the 6-digit OTP from their app after you drop the clothes.',
      );
      if (otp == null || !context.mounted) return;
    } else if (task.isDropLeg && !task.isCash) {
      otp = await promptCustomerOtp(
        context: context,
        session: session,
        task: task,
        purpose: 'drop_to_user',
        title: 'Delivery OTP',
        message: 'Ask the customer for the 6-digit OTP shown in their Kaam Fast app to complete return delivery.',
      );
      if (otp == null || !context.mounted) return;
    }

    if (task.collectPaymentAtDrop) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(context.tr('Collect payment from receiver')),
          content: Text(
            context.tr(
              'Collect full cash from the receiver at drop. '
              'Platform fee, tax, and commission will be deducted from your wallet after complete.',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(context.tr('Not yet')),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(context.tr('Cash collected')),
            ),
          ],
        ),
      );
      if (confirmed != true || !context.mounted) return;
      await session.completeTask(task.id, cashCollected: true, otp: otp);
    } else if (task.isCash && !task.collectPaymentBeforeStart) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(context.tr('Cash collected?')),
          content: Text(
            context.tr(
              'Confirm you collected the full cash amount from the customer. Platform fee, tax, and commission will be deducted from your wallet.',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(context.tr('Not yet')),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(context.tr('Yes, collected')),
            ),
          ],
        ),
      );
      if (confirmed != true || !context.mounted) return;
      await session.completeTask(task.id, cashCollected: true, otp: otp);
    } else {
      // Sender already paid / confirmed at pickup.
      await session.completeTask(task.id, cashCollected: task.isCash, otp: otp);
    }
    if (context.mounted) {
      if (task.needsCompletePhotos && task.bookingId != null) {
        await Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => SearchingDeliveryScreen(bookingId: task.bookingId!),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.tr('Job marked complete'))),
        );
      }
    }
  } catch (e) {
    if (context.mounted) {
      final msg = '$e'.trim();
      if (msg.isNotEmpty && msg != 'null') {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
      }
    }
  }
}

Future<bool> uploadPartnerJobPhotos(
  BuildContext context,
  SessionController session,
  PartnerTask task, {
  String kind = 'laundry_complete',
  String title = 'Upload completed laundry photos',
}) async {
  final source = await showModalBottomSheet<ImageSource>(
    context: context,
    showDragHandle: true,
    builder: (context) {
      return SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
              child: Text(
                context.tr(title),
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined, color: PartnerColors.primary),
              title: Text(context.tr('Take photo')),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined, color: PartnerColors.primary),
              title: Text(context.tr('Choose from gallery')),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
          ],
        ),
      );
    },
  );
  if (source == null || !context.mounted) return false;

  final picker = ImagePicker();
  final paths = <String>[];
  if (source == ImageSource.gallery) {
    final files = await picker.pickMultiImage(imageQuality: 80, maxWidth: 2000);
    paths.addAll(files.map((e) => e.path));
  } else {
    final file = await picker.pickImage(source: source, imageQuality: 80, maxWidth: 2000);
    if (file != null) paths.add(file.path);
  }
  if (paths.isEmpty || !context.mounted) return false;

  try {
    await session.uploadJobPhotos(task.id, paths, kind: kind);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.tr(
              paths.length == 1 ? '{count} photo uploaded' : '{count} photos uploaded',
              {'count': paths.length},
            ),
          ),
        ),
      );
    }
    return true;
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
    return false;
  }
}
