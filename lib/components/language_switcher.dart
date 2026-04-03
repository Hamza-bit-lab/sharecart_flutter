import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:sharecart/controllers/language_controller.dart';
import 'package:sharecart/theme/app_theme.dart';

/// Language switcher for app bar. Uses GetX [LanguageController].
class LanguageSwitcher extends StatelessWidget {
  const LanguageSwitcher({super.key});

  static const _options = [
    ('en', '🇬🇧', 'English'),
    ('ar', '🇸🇦', 'العربية'),
    ('ur', '🇵🇰', 'اردو'),
    ('es', '🇪🇸', 'Español'),
    ('fr', '🇫🇷', 'Français'),
    ('de', '🇩🇪', 'Deutsch'),
    ('zh', '🇨🇳', '中文'),
    ('hi', '🇮🇳', 'हिन्दी'),
    ('ru', '🇷🇺', 'Русский'),
    ('pt', '🇧🇷', 'Português'),
  ];

  @override
  Widget build(BuildContext context) {
    final lang = Get.find<LanguageController>();
    final accent = Theme.of(context).colorScheme.primary;
    final iconColor = IconTheme.of(context).color ?? accent;
    final currentCode = lang.locale.value.languageCode;
    final current = _options.firstWhere(
      (o) => o.$1 == currentCode,
      orElse: () => _options.first,
    );

    return PopupMenuButton<String>(
      onSelected: (code) => lang.changeLanguage(code),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 6,
      itemBuilder: (context) {
        return _options.map((option) {
          final code = option.$1;
          final isSelected = code == currentCode;
          return PopupMenuItem<String>(
            value: code,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(option.$2, style: const TextStyle(fontSize: 18)),
                const SizedBox(width: 8),
                Text(
                  option.$3,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                    color: isSelected ? accent : AppColors.onSurface,
                  ),
                ),
              ],
            ),
          );
        }).toList();
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(current.$2, style: const TextStyle(fontSize: 18)),
            const SizedBox(width: 4),
            Icon(Icons.language, size: 18, color: iconColor),
          ],
        ),
      ),
    );
  }
}
