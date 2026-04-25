import 'dart:convert';
import 'package:flutter/services.dart';

class AppLocalizations {
  final String languageCode;
  Map<String, String>? _localizedStrings;

  AppLocalizations(this.languageCode);

  Future<void> load() async {
    String jsonString = await rootBundle.loadString('assets/translations/$languageCode.json');
    Map<String, dynamic> jsonMap = json.decode(jsonString);
    _localizedStrings = jsonMap.map((key, value) => MapEntry(key, value.toString()));
  }

  String translate(String key, {Map<String, String>? args}) {
    String value = _localizedStrings?[key] ?? key;
    if (args != null) {
      args.forEach((key, val) {
        value = value.replaceAll('{$key}', val);
      });
    }
    return value;
  }
}
