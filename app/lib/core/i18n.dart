import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'settings_store.dart';

/// Lightweight i18n. High-traffic strings are translated (en/id); anything not
/// in the map falls back to English / the key. Extend `_data` to localize more.
class AppStrings {
  const AppStrings(this.lang);
  final String lang;

  String t(String key) =>
      _data[key]?[lang] ?? _data[key]?['en'] ?? key;
}

final stringsProvider = Provider<AppStrings>((ref) {
  final lang = ref.watch(settingsStoreProvider).locale.languageCode;
  return AppStrings(lang);
});

const Map<String, Map<String, String>> _data = {
  'nav.compete': {'en': 'Compete', 'id': 'Bertanding'},
  'nav.organize': {'en': 'Organize', 'id': 'Kelola'},
  'nav.admin': {'en': 'Admin', 'id': 'Admin'},
  'nav.profile': {'en': 'Profile', 'id': 'Profil'},
  'login.welcome': {'en': 'Welcome back', 'id': 'Selamat datang'},
  'login.subtitle': {
    'en': 'Sign in to join and run tournaments.',
    'id': 'Masuk untuk ikut dan mengelola turnamen.'
  },
  'login.email': {'en': 'Email', 'id': 'Email'},
  'login.password': {'en': 'Password', 'id': 'Kata sandi'},
  'login.signIn': {'en': 'Sign in', 'id': 'Masuk'},
  'login.create': {
    'en': 'New here? Create an account',
    'id': 'Baru di sini? Buat akun'
  },
  'login.adminDemo': {
    'en': 'Sign in as admin (demo)',
    'id': 'Masuk sebagai admin (demo)'
  },
  'browse.heroTitle': {
    'en': 'Compete. Organize. Win.',
    'id': 'Bertanding. Kelola. Menang.'
  },
  'browse.heroSub': {
    'en':
        'Join tournaments with secure QRIS entry, or run your own — we handle the bracket, you keep 90% of every entry.',
    'id':
        'Ikuti turnamen dengan pembayaran QRIS, atau buat sendiri — kami atur bagannya, Anda dapat 90% dari tiap pendaftaran.'
  },
  'browse.create': {'en': 'Create a competition', 'id': 'Buat kompetisi'},
  'browse.open': {'en': 'Open competitions', 'id': 'Kompetisi terbuka'},
  'onboarding.title': {
    'en': 'Choose your language & currency',
    'id': 'Pilih bahasa & mata uang'
  },
  'onboarding.subtitle': {
    'en': 'You can change this later in your profile.',
    'id': 'Anda bisa mengubahnya nanti di profil.'
  },
  'onboarding.language': {'en': 'Language', 'id': 'Bahasa'},
  'onboarding.currency': {'en': 'Currency', 'id': 'Mata uang'},
  'common.continue': {'en': 'Continue', 'id': 'Lanjut'},
  'common.save': {'en': 'Save', 'id': 'Simpan'},
  'profile.settings': {'en': 'Language & currency', 'id': 'Bahasa & mata uang'},
};
