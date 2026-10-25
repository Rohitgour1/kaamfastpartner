import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:kaamfast_partner/data/mock_data.dart';
import 'package:kaamfast_partner/l10n/app_strings.dart';
import 'package:kaamfast_partner/state/session_controller.dart';
import 'package:kaamfast_partner/theme/partner_theme.dart';

Future<String?> promptCustomerOtp({
  required BuildContext context,
  required SessionController session,
  required PartnerTask task,
  required String purpose,
  required String title,
  required String message,
}) async {
  final bookingId = task.bookingId;
  if (bookingId == null) return null;

  return showDialog<String>(
    context: context,
    barrierDismissible: false,
    builder: (context) => _CustomerOtpDialog(
      bookingId: bookingId,
      session: session,
      purpose: purpose,
      title: title,
      message: message,
    ),
  );
}

class _CustomerOtpDialog extends StatefulWidget {
  const _CustomerOtpDialog({
    required this.bookingId,
    required this.session,
    required this.purpose,
    required this.title,
    required this.message,
  });

  final int bookingId;
  final SessionController session;
  final String purpose;
  final String title;
  final String message;

  @override
  State<_CustomerOtpDialog> createState() => _CustomerOtpDialogState();
}

class _CustomerOtpDialogState extends State<_CustomerOtpDialog> {
  final _controller = TextEditingController();
  bool _submitting = false;
  String? _error;
  String? _debugOtp;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _resend() async {
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      final payload = await widget.session.sendJobOtp(widget.bookingId, widget.purpose);
      if (!mounted) return;
      setState(() {
        _debugOtp = payload['debug_otp']?.toString() ?? payload['otp']?.toString();
        _submitting = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = '$e';
        _submitting = false;
      });
    }
  }

  void _submit() {
    final value = _controller.text.trim();
    if (value.length != 6) {
      setState(() => _error = context.tr('Enter the 6-digit OTP from the customer.'));
      return;
    }
    Navigator.pop(context, value);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(context.tr(widget.title)),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(context.tr(widget.message)),
            const SizedBox(height: 12),
            TextField(
              controller: _controller,
              autofocus: true,
              keyboardType: TextInputType.number,
              maxLength: 6,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: InputDecoration(
                labelText: context.tr('6-digit OTP'),
                counterText: '',
                errorText: _error,
              ),
              onChanged: (_) {
                if (_error != null) setState(() => _error = null);
              },
              onSubmitted: (_) => _submit(),
            ),
            if (_debugOtp != null && _debugOtp!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  'Debug OTP: $_debugOtp',
                  style: const TextStyle(fontSize: 12, color: PartnerColors.muted),
                ),
              ),
            TextButton(
              onPressed: _submitting ? null : _resend,
              child: Text(context.tr('Ask customer to refresh OTP')),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _submitting ? null : () => Navigator.pop(context),
          child: Text(context.tr('Cancel')),
        ),
        FilledButton(
          onPressed: _submitting ? null : _submit,
          child: Text(context.tr('Verify')),
        ),
      ],
    );
  }
}
