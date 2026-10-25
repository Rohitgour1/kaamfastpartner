import 'dart:async';

import 'package:kaamfast_partner/l10n/app_strings.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';

class RazorpayCheckout {
  Future<Map<String, String>> open({
    required String key,
    String orderId = '',
    required int amountPaise,
    String name = 'Kaam Fast',
    String? description,
    String? contact,
    String? email,
  }) async {
    if (key.trim().isEmpty) {
      throw Exception(
        AppStrings.tr('Razorpay Key ID missing. Save it in Admin → Payments.'),
      );
    }

    final razorpay = Razorpay();
    final done = Completer<Map<String, String>>();

    void success(PaymentSuccessResponse response) {
      if (!done.isCompleted) {
        done.complete({
          'gateway_payment_id': response.paymentId ?? '',
          'gateway_signature': response.signature ?? '',
          'gateway_order_id': response.orderId ?? orderId,
        });
      }
    }

    void error(PaymentFailureResponse response) {
      if (!done.isCompleted) {
        done.completeError(
          Exception(
            response.message ?? AppStrings.tr('Payment cancelled or failed'),
          ),
        );
      }
    }

    razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, success);
    razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, error);
    razorpay.on(Razorpay.EVENT_EXTERNAL_WALLET, (_) {});

    final options = <String, dynamic>{
      'key': key.trim(),
      'amount': amountPaise,
      'currency': 'INR',
      'name': name,
      'description': description ?? AppStrings.tr('Payment'),
      'prefill': {
        if (contact != null && contact.isNotEmpty) 'contact': contact,
        if (email != null && email.isNotEmpty) 'email': email,
      },
      'theme': {'color': '#011431'},
      'retry': {'enabled': true, 'max_count': 1},
    };
    if (orderId.trim().isNotEmpty) {
      options['order_id'] = orderId.trim();
    }

    razorpay.open(options);

    try {
      return await done.future;
    } finally {
      razorpay.clear();
    }
  }
}
