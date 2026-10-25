import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:kaamfast_partner/l10n/app_strings.dart';
import 'package:kaamfast_partner/l10n/locale_controller.dart';
import 'package:kaamfast_partner/theme/partner_theme.dart';
import 'package:provider/provider.dart';

const languageOptions = [
  (code: 'hi', label: 'हिन्दी', subtitle: 'Hindi'),
  (code: 'en', label: 'English', subtitle: 'अंग्रेज़ी'),
];

String languageLabel(String code) =>
    languageOptions.firstWhere((o) => o.code == code, orElse: () => languageOptions.first).label;

Future<void> showLanguagePicker(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (sheetContext) {
      final controller = sheetContext.watch<LocaleController>();
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                sheetContext.tr('Choose language'),
                style: GoogleFonts.hankenGrotesk(fontWeight: FontWeight.w800, fontSize: 18),
              ),
              const SizedBox(height: 12),
              for (final option in languageOptions)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Material(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(14),
                      onTap: () async {
                        await controller.setLanguage(option.code);
                        if (sheetContext.mounted) Navigator.of(sheetContext).pop();
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: controller.languageCode == option.code
                                ? PartnerColors.accent
                                : PartnerColors.line,
                            width: controller.languageCode == option.code ? 2 : 1,
                          ),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    option.label,
                                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                                  ),
                                  Text(
                                    option.subtitle,
                                    style: const TextStyle(fontSize: 12, color: PartnerColors.muted),
                                  ),
                                ],
                              ),
                            ),
                            Icon(
                              controller.languageCode == option.code
                                  ? Icons.check_circle
                                  : Icons.circle_outlined,
                              color: controller.languageCode == option.code
                                  ? PartnerColors.accent
                                  : PartnerColors.muted,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      );
    },
  );
}

/// Compact pill for app bars on screens shown before login.
class LanguageButton extends StatelessWidget {
  const LanguageButton({super.key, this.color});

  final Color? color;

  @override
  Widget build(BuildContext context) {
    final code = context.watch<LocaleController>().languageCode;
    return TextButton.icon(
      onPressed: () => showLanguagePicker(context),
      style: TextButton.styleFrom(foregroundColor: color ?? PartnerColors.primary),
      icon: const Icon(Icons.translate, size: 18),
      label: Text(languageLabel(code), style: const TextStyle(fontWeight: FontWeight.w700)),
    );
  }
}
