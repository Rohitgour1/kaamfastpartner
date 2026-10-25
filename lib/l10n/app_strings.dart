import 'package:flutter/widgets.dart';
import 'package:kaamfast_partner/l10n/hi/index.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// English text is the lookup key; a missing Hindi entry falls back to English.
class AppStrings {
  AppStrings._();

  static const prefsKey = 'partner_language';
  static const defaultLanguage = 'hi';
  static const supported = ['hi', 'en'];

  static String languageCode = defaultLanguage;

  static Map<String, String>? _hiLower;

  static Future<String> loadSaved() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString(prefsKey);
      languageCode = supported.contains(saved) ? saved! : defaultLanguage;
    } catch (_) {
      languageCode = defaultLanguage;
    }
    return languageCode;
  }

  static String translate(String code, String en, [Map<String, Object?>? args]) {
    var out = en;
    if (code == 'hi' && en.isNotEmpty) {
      out = hiStrings[en] ?? _lookupLoose(en) ?? en;
    }
    if (args != null) {
      args.forEach((key, value) => out = out.replaceAll('{$key}', '${value ?? ''}'));
    }
    return out;
  }

  static String tr(String en, [Map<String, Object?>? args]) => translate(languageCode, en, args);

  /// Server-provided names (services, modules, statuses) can differ in case or spacing.
  static String? _lookupLoose(String en) {
    final lower = _hiLower ??= {
      for (final entry in hiStrings.entries) entry.key.trim().toLowerCase(): entry.value,
    };
    return lower[en.trim().toLowerCase()];
  }
}

extension TrContext on BuildContext {
  String tr(String en, [Map<String, Object?>? args]) => AppStrings.translate(
        Localizations.maybeLocaleOf(this)?.languageCode ?? AppStrings.languageCode,
        en,
        args,
      );
}
