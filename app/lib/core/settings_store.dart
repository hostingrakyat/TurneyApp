import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'formatters.dart';

/// User-chosen app preferences (language + currency), persisted on-device.
class SettingsStore extends ChangeNotifier {
  SettingsStore(this._prefs) {
    final lc = _prefs.getString('locale');
    if (lc != null) _locale = Locale(lc);
    _currency = AppCurrency.fromName(_prefs.getString('currency'));
    _onboarded = _prefs.getBool('onboarded') ?? false;
    Format.setCurrency(_currency);
  }

  final SharedPreferences _prefs;
  Locale _locale = const Locale('en');
  AppCurrency _currency = AppCurrency.idr;
  bool _onboarded = false;

  Locale get locale => _locale;
  AppCurrency get currency => _currency;
  bool get onboarded => _onboarded;

  Future<void> setLocale(Locale l) async {
    _locale = l;
    await _prefs.setString('locale', l.languageCode);
    notifyListeners();
  }

  Future<void> setCurrency(AppCurrency c) async {
    _currency = c;
    Format.setCurrency(c);
    await _prefs.setString('currency', c.name);
    notifyListeners();
  }

  Future<void> completeOnboarding() async {
    _onboarded = true;
    await _prefs.setBool('onboarded', true);
    notifyListeners();
  }
}

/// Provided in `main()` after SharedPreferences loads.
final settingsStoreProvider = ChangeNotifierProvider<SettingsStore>(
  (ref) => throw UnimplementedError('SettingsStore provided in main()'),
);
