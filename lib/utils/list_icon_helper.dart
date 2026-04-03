/// Maps backend icon codes (e.g. bi-cart) to emoji for display.
/// If the backend returns emojis directly, they pass through.
class ListIconHelper {
  ListIconHelper._();

  static const Map<String, String> _codeToEmoji = {
    'bi-cart': '🛒',
    'bi-cart2': '🛒',
    'bi-cart3': '🛒',
    'bi-cart4': '🛒',
    'bi-house': '🏠',
    'bi-house-door': '🏠',
    'bi-house-heart': '🏠',
    'bi-list': '📋',
    'bi-list-ul': '📋',
    'bi-list-check': '📋',
    'bi-basket': '🛍️',
    'bi-basket2': '🛍️',
    'bi-basket3': '🥗',
    'bi-bag': '🛍️',
    'bi-bag-check': '🛍️',
    'bi-shop': '🏪',
    'bi-egg': '🥚',
    'bi-egg-fried': '🍳',
    'bi-flower1': '🌸',
    'bi-flower2': '🌸',
    'bi-star': '⭐',
    'bi-heart': '❤️',
    'bi-balloon-heart': '💕',
    'bi-box2-heart': '💝',
    'bi-receipt': '🧾',
    'bi-emoji-smile': '😊',
    'bi-emoji-party': '🎉',
    'bi-calendar-event': '📅',
    'bi-archive': '📦',
    'bi-cup-straw': '🥤',
    'bi-cup-hot': '☕',
    'bi-apple': '🍎',
    'bi-droplet': '💧',
    'bi-paw': '🐾',
    'bi-pie-chart': '📊',
    'bi-snow': '❄️',
    'bi-bandaid': '🩹',
    'bi-gift': '🎁',
    'bi-truck': '🚚',
    'bi-wallet2': '👛',
    'bi-briefcase': '💼',
    'bi-bookmark': '🔖',
    'bi-pin-map': '📍',
    'bi-geo-alt': '📍',
  };

  /// Returns emoji string for display, or null to use default list icon.
  static String? toEmoji(String? code) {
    if (code == null || code.isEmpty) return null;
    final trimmed = code.trim();
    if (trimmed.isEmpty) return null;
    final lower = trimmed.toLowerCase();
    if (_codeToEmoji.containsKey(lower)) return _codeToEmoji[lower];
    if (trimmed.length <= 4 && !trimmed.startsWith('bi-')) return trimmed;
    return null;
  }

  /// Returns true if [code] looks like an icon code (e.g. bi-*) that we map.
  static bool isIconCode(String? code) {
    if (code == null || code.isEmpty) return false;
    return code.toLowerCase().startsWith('bi-') || _codeToEmoji.containsKey(code.trim().toLowerCase());
  }
}
