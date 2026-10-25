import 'package:flutter/material.dart';
import 'package:kaamfast_partner/l10n/app_strings.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LocaleController extends ChangeNotifier {
  Locale _locale = Locale(AppStrings.languageCode);

  Locale get locale => _locale;
  String get languageCode => _locale.languageCode;

  Future<void> load() async {
    final code = await AppStrings.loadSaved();
    if (code != _locale.languageCode) {
      _locale = Locale(code);
      notifyListeners();
    }
  }

  Future<void> setLanguage(String code) async {
    if (!AppStrings.supported.contains(code) || code == _locale.languageCode) return;
    AppStrings.languageCode = code;
    _locale = Locale(code);
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(AppStrings.prefsKey, code);
    } catch (_) {}
  }
}
