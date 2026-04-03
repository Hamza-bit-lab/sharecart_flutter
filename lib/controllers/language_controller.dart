import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

const String _keyLanguage = 'app_language';

class LanguageController extends GetxController {
  LanguageController({required SharedPreferences prefs}) : _prefs = prefs;

  final SharedPreferences _prefs;

  final Rx<Locale> locale = const Locale('en').obs;

  @override
  void onInit() {
    super.onInit();
    _loadLocale();
  }

  void _loadLocale() {
    final code = _prefs.getString(_keyLanguage) ?? 'en';
    locale.value = Locale(code);
    Get.updateLocale(Locale(code));
  }

  Future<void> changeLanguage(String languageCode) async {
    if (locale.value.languageCode == languageCode) return;
    locale.value = Locale(languageCode);
    await _prefs.setString(_keyLanguage, languageCode);
    Get.updateLocale(Locale(languageCode));
    Get.forceAppUpdate();
  }

  bool get isRtl {
    final code = locale.value.languageCode;
    return code == 'ar' || code == 'ur';
  }
}
