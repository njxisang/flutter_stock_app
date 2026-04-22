import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../../domain/entities/stock_quote.dart';

class StockLocalStorage {
  static const String _watchlistKey = 'watchlist';
  static const String _historyKey = 'search_history';
  static const String _settingsKey = 'stock_settings';
  static const int _maxHistoryItems = 20;

  final SharedPreferences _prefs;

  StockLocalStorage(this._prefs);

  // Watchlist
  List<WatchlistItem> getWatchlist() {
    final json = _prefs.getString(_watchlistKey);
    if (json == null) return [];
    final list = jsonDecode(json) as List<dynamic>;
    return list.map((e) => WatchlistItem(
      symbol: e['symbol'] as String,
      name: e['name'] as String,
    )).toList();
  }

  Future<void> addToWatchlist(String symbol, String name) async {
    final list = getWatchlist();
    list.removeWhere((e) => e.symbol == symbol);
    list.insert(0, WatchlistItem(symbol: symbol, name: name));
    await _prefs.setString(_watchlistKey, jsonEncode(list.map((e) => {'symbol': e.symbol, 'name': e.name}).toList()));
  }

  Future<void> removeFromWatchlist(String symbol) async {
    final list = getWatchlist();
    list.removeWhere((e) => e.symbol == symbol);
    await _prefs.setString(_watchlistKey, jsonEncode(list.map((e) => {'symbol': e.symbol, 'name': e.name}).toList()));
  }

  // Search History - FIXED: Using List instead of Set to preserve order
  List<String> getSearchHistory() {
    final json = _prefs.getString(_historyKey);
    if (json == null) return [];
    return List<String>.from(jsonDecode(json));
  }

  Future<void> addToSearchHistory(String symbol) async {
    final history = getSearchHistory();
    history.remove(symbol);
    history.insert(0, symbol);
    final limited = history.take(_maxHistoryItems).toList();
    await _prefs.setString(_historyKey, jsonEncode(limited));
  }

  Future<void> removeFromSearchHistory(String symbol) async {
    final history = getSearchHistory();
    history.remove(symbol);
    await _prefs.setString(_historyKey, jsonEncode(history));
  }

  Future<void> clearSearchHistory() async {
    await _prefs.remove(_historyKey);
  }

  // Settings
  Map<String, dynamic> getSettings() {
    final json = _prefs.getString(_settingsKey);
    if (json == null) {
      return {
        'shortPeriod': 12,
        'longPeriod': 26,
        'signalPeriod': 9,
        'rsiPeriod': 6,
        'kdjPeriod': 9,
        'bollPeriod': 20,
        'darkMode': false,
      };
    }
    return jsonDecode(json);
  }

  Future<void> saveSettings(Map<String, dynamic> settings) async {
    await _prefs.setString(_settingsKey, jsonEncode(settings));
  }

  Future<void> clearCache() async {
    final keys = _prefs.getKeys().where((k) => k.startsWith('cache_')).toList();
    for (final key in keys) {
      await _prefs.remove(key);
    }
  }
}
