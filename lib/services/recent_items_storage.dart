import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

const _key = 'recent_item_names';
const _maxCount = 10;

/// Stores and retrieves recently added item names for quick-add chips.
class RecentItemsStorage {
  RecentItemsStorage._();
  static final RecentItemsStorage instance = RecentItemsStorage._();

  Future<List<String>> getRecentNames() async {
    final prefs = await SharedPreferences.getInstance();
    final json = prefs.getString(_key);
    if (json == null) return [];
    try {
      final list = jsonDecode(json) as List<dynamic>?;
      return list?.whereType<String>().take(_maxCount).toList() ?? [];
    } catch (_) {
      return [];
    }
  }

  Future<void> addName(String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    final current = await getRecentNames();
    final updated = [trimmed, ...current.where((s) => s.toLowerCase() != trimmed.toLowerCase())].take(_maxCount).toList();
    await prefs.setString(_key, jsonEncode(updated));
  }
}
