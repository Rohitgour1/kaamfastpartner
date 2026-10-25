import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:kaamfast_partner/core/app_constants.dart';
import 'package:kaamfast_partner/l10n/app_strings.dart';
import 'package:kaamfast_partner/theme/partner_theme.dart';
import 'package:url_launcher/url_launcher.dart';

Future<void> openLegalUrl(BuildContext context, String url) async {
  final uri = Uri.parse(url);
  final opened = await launchUrl(uri, mode: LaunchMode.inAppBrowserView) ||
      await launchUrl(uri, mode: LaunchMode.externalApplication);
  if (!opened && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(url)));
  }
}

/// Mandatory consent row shown before sending the login OTP.
class TermsConsent extends StatefulWidget {
  const TermsConsent({super.key, required this.value, required this.onChanged});

  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  State<TermsConsent> createState() => _TermsConsentState();
}

class _TermsConsentState extends State<TermsConsent> {
  late final _terms = TapGestureRecognizer()
    ..onTap = () => openLegalUrl(context, AppConstants.termsUrl);
  late final _privacy = TapGestureRecognizer()
    ..onTap = () => openLegalUrl(context, AppConstants.privacyPolicyUrl);

  @override
  void dispose() {
    _terms.dispose();
    _privacy.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const link = TextStyle(
      color: PartnerColors.primary,
      fontWeight: FontWeight.w700,
      decoration: TextDecoration.underline,
    );
    return InkWell(
      onTap: () => widget.onChanged(!widget.value),
      borderRadius: BorderRadius.circular(8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 32,
            height: 32,
            child: Checkbox(
              value: widget.value,
              onChanged: (v) => widget.onChanged(v ?? false),
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text.rich(
                TextSpan(
                  style: const TextStyle(fontSize: 13, height: 1.4, color: PartnerColors.muted),
                  children: [
                    TextSpan(text: context.tr('I agree to the ')),
                    TextSpan(
                      text: context.tr('Terms & Conditions'),
                      style: link,
                      recognizer: _terms,
                    ),
                    TextSpan(text: context.tr(' and ')),
                    TextSpan(
                      text: context.tr('Privacy Policy'),
                      style: link,
                      recognizer: _privacy,
                    ),
                    TextSpan(text: context.tr('.')),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
