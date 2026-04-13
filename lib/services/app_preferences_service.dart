import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class NotificationPreferences {
  final bool messages;
  final bool offers;
  final bool news;

  const NotificationPreferences({
    required this.messages,
    required this.offers,
    required this.news,
  });

  const NotificationPreferences.defaults()
      : messages = true,
        offers = true,
        news = false;

  NotificationPreferences copyWith({
    bool? messages,
    bool? offers,
    bool? news,
  }) {
    return NotificationPreferences(
      messages: messages ?? this.messages,
      offers: offers ?? this.offers,
      news: news ?? this.news,
    );
  }
}

class AppPreferencesService {
  static const _messagesKey = 'notifications.messages';
  static const _offersKey = 'notifications.offers';
  static const _newsKey = 'notifications.news';
  static const _guestCategoryClicksKey = 'guest.category_clicks';

  Future<NotificationPreferences> loadNotificationPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    return NotificationPreferences(
      messages: prefs.getBool(_messagesKey) ?? true,
      offers: prefs.getBool(_offersKey) ?? true,
      news: prefs.getBool(_newsKey) ?? false,
    );
  }

  Future<void> saveNotificationPreferences(
    NotificationPreferences preferences,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_messagesKey, preferences.messages);
    await prefs.setBool(_offersKey, preferences.offers);
    await prefs.setBool(_newsKey, preferences.news);
  }

  Future<Map<String, int>> loadGuestCategoryClicks() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_guestCategoryClicksKey);
    if (raw == null || raw.trim().isEmpty) return const {};

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) return const {};

      return decoded.map(
        (key, value) => MapEntry(
          key,
          value is num ? value.toInt() : 0,
        ),
      )..removeWhere((key, value) => key.trim().isEmpty || value <= 0);
    } catch (_) {
      return const {};
    }
  }

  Future<void> saveGuestCategoryClicks(Map<String, int> categoryClicks) async {
    final prefs = await SharedPreferences.getInstance();
    final sanitized = Map<String, int>.from(categoryClicks)
      ..removeWhere((key, value) => key.trim().isEmpty || value <= 0);

    if (sanitized.isEmpty) {
      await prefs.remove(_guestCategoryClicksKey);
      return;
    }

    await prefs.setString(_guestCategoryClicksKey, jsonEncode(sanitized));
  }
}
