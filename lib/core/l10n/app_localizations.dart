import 'package:flutter/material.dart';
import 'strings_en.dart';
import 'strings_hi.dart';

/// Supported locales
const List<Locale> appSupportedLocales = [
  Locale('en'),
  Locale('hi'),
];

/// App localizations — simple key-value pattern for fast lookup.
/// Avoids code generation overhead for this project size.
class AppLocalizations {
  final Locale locale;

  AppLocalizations(this.locale);

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  Map<String, String> get _strings {
    switch (locale.languageCode) {
      case 'hi':
        return stringsHi;
      default:
        return stringsEn;
    }
  }

  String translate(String key) {
    return _strings[key] ?? stringsEn[key] ?? key;
  }

  /// Shorthand
  String t(String key) => translate(key);
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) =>
      ['en', 'hi'].contains(locale.languageCode);

  @override
  Future<AppLocalizations> load(Locale locale) async {
    return AppLocalizations(locale);
  }

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

/// Extension for quick access
extension LocalizationX on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this);
  String t(String key) => AppLocalizations.of(this).translate(key);
}
