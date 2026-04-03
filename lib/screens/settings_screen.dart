import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:sharecart/controllers/language_controller.dart';
import 'package:sharecart/theme/app_decorations.dart';
import 'package:sharecart/theme/app_theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _keyNotificationsEnabled = 'settings_notifications_enabled';

Future<bool> getNotificationsEnabled() async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getBool(_keyNotificationsEnabled) ?? true;
}

Future<void> setNotificationsEnabled(bool value) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setBool(_keyNotificationsEnabled, value);
}

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _notificationsEnabled = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final enabled = await getNotificationsEnabled();
    if (mounted) setState(() => _notificationsEnabled = enabled);
  }

  static const _languageOptions = [
    ('en', 'English'),
    ('ar', 'العربية'),
    ('ur', 'اردو'),
    ('es', 'Español'),
    ('fr', 'Français'),
    ('de', 'Deutsch'),
    ('zh', '中文'),
    ('hi', 'हिन्दी'),
    ('ru', 'Русский'),
    ('pt', 'Português'),
  ];

  String _languageName(String code) {
    return _languageOptions.firstWhere(
      (o) => o.$1 == code,
      orElse: () => ('en', 'English'),
    ).$2;
  }

  @override
  Widget build(BuildContext context) {
    final lang = Get.find<LanguageController>();
    final accent = Theme.of(context).colorScheme.primary;

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: Text('settings'.tr),
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
      ),
      body: Container(
        decoration: AppDecorations.pageBackground(),
        child: ListView(
        children: [
          _section(
            context,
            title: 'notifications'.tr,
            children: [
              _tile(
                context,
                icon: Icons.notifications_outlined,
                title: 'allowNotifications'.tr,
                subtitle: 'notificationsSubtitle'.tr,
                trailing: Switch(
                  value: _notificationsEnabled,
                  onChanged: (v) async {
                    setState(() => _notificationsEnabled = v);
                    await setNotificationsEnabled(v);
                  },
                  activeColor: accent,
                ),
              ),
            ],
          ),
          _section(
            context,
            title: 'language'.tr,
            children: [
              _tile(
                context,
                icon: Icons.language,
                title: 'language'.tr,
                subtitle: _languageName(lang.locale.value.languageCode),
                onTap: () {
                  showModalBottomSheet<void>(
                    context: context,
                    isScrollControlled: true,
                    builder: (ctx) => SafeArea(
                      child: ListView(
                        shrinkWrap: true,
                        physics: const ClampingScrollPhysics(),
                        children: _languageOptions.map((opt) {
                          final selected =
                              lang.locale.value.languageCode == opt.$1;
                          return ListTile(
                            leading: selected
                                ? Icon(Icons.check, color: accent)
                                : const SizedBox(width: 24),
                            title: Text(opt.$2),
                            onTap: () {
                              lang.changeLanguage(opt.$1);
                              Navigator.pop(ctx);
                            },
                          );
                        }).toList(),
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: 24),
        ],
        ),
      ),
    );
  }

  Widget _section(
    BuildContext context, {
    required String title,
    required List<Widget> children,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
          child: Text(
            title,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: AppColors.onSurfaceVariant,
                ),
          ),
        ),
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          decoration: AppDecorations.settingsSection(
            Theme.of(context).colorScheme.primary,
          ),
          child: Column(children: children),
        ),
      ],
    );
  }

  Widget _tile(
    BuildContext context, {
    required IconData icon,
    required String title,
    String? subtitle,
    Widget? trailing,
    VoidCallback? onTap,
  }) {
    final accent = Theme.of(context).colorScheme.primary;
    return ListTile(
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: accent.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: accent, size: 22),
      ),
      title: Text(
        title,
        style: const TextStyle(
          fontWeight: FontWeight.w500,
          color: AppColors.onSurface,
        ),
      ),
      subtitle: subtitle != null
          ? Text(
              subtitle,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade600,
              ),
            )
          : null,
      trailing: trailing ??
          Icon(Icons.chevron_right, color: Colors.grey.shade400, size: 22),
      onTap: onTap,
    );
  }
}
