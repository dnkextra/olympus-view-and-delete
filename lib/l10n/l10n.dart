import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'app_localizations.dart';

class L10n {
  static const all = [Locale('en'), Locale('ru'), Locale('uk')];
}

List<LocalizationsDelegate<dynamic>> get localizationsDelegates => const [
  AppLocalizations.delegate,
  GlobalMaterialLocalizations.delegate,
  GlobalWidgetsLocalizations.delegate,
  GlobalCupertinoLocalizations.delegate,
];
