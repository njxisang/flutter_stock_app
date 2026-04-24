import 'package:flutter/material.dart';

class AppColors {
  // Primary colors - Professional stock app style
  static const Color primary = Color(0xFF238ECF);
  static const Color primaryDark = Color(0xFF1A6AA5);

  // Chinese market convention: Red up, Green down
  static const Color bullish = Color(0xFFDC3535);  // Red for up
  static const Color bearish = Color(0xFF2E8B57);  // Green for down

  // Chart colors
  static const Color bullishLight = Color(0xFFE85656);  // Lighter red
  static const Color bearishLight = Color(0xFF4CAF50);  // Lighter green

  // Background colors
  static const Color background = Color(0xFFF5F5F5);
  static const Color surface = Colors.white;
  static const Color chartBackground = Color(0xFF1A1A2E);
  static const Color cardBackground = Colors.white;

  // Text colors
  static const Color textPrimary = Color(0xFF1A1A1A);
  static const Color textSecondary = Color(0xFF888888);
  static const Color textLight = Colors.white;

  // MACD colors
  static const Color difColor = Color(0xFF2878BE);
  static const Color deaColor = Color(0xFFB45319);
  static const Color macdColor = Color(0xFF9C27B0);
  static const Color macdUp = Color(0xFFDC3535);
  static const Color macdDown = Color(0xFF2E8B57);

  // KDJ colors
  static const Color kColor = Color(0xFFFF6B6B);
  static const Color dColor = Color(0xFF4ECDC4);
  static const Color jColor = Color(0xFFFFE66D);

  // BOLL colors
  static const Color bollUpper = Color(0xFFE85656);
  static const Color bollMiddle = Color(0xFF2878BE);
  static const Color bollLower = Color(0xFF2E8B57);

  // MA colors
  static const Color ma5Color = Color(0xFFFF6B6B);
  static const Color ma10Color = Color(0xFF4ECDC4);
  static const Color ma20Color = Color(0xFFFFE66D);
  static const Color ma60Color = Color(0xFF9C27B0);

  // WR colors
  static const Color wr6Color = Color(0xFFFF6B6B);
  static const Color wr10Color = Color(0xFF4ECDC4);

  // DMI colors
  static const Color pdiColor = Color(0xFFFF6B6B);
  static const Color mdiColor = Color(0xFF4ECDC4);
  static const Color adxColor = Color(0xFFFFE66D);

  // Status colors
  static const Color success = Color(0xFF4CAF50);
  static const Color warning = Color(0xFFFF9800);
  static const Color error = Color(0xFFF44336);

  // Border and divider
  static const Color border = Color(0xFFE0E0E0);
  static const Color divider = Color(0xFFEEEEEE);
}

class AppStrings {
  static const String appName = '股票行情';
  static const String searchHint = '搜索股票代码/名称';
  static const String search = '搜索';
  static const String analyze = '分析';
  static const String addWatchlist = '加自选';
  static const String removeWatchlist = '删自选';
  static const String settings = '设置';
  static const String kline = 'K线';
  static const String macd = 'MACD';
  static const String rsi = 'RSI';
  static const String kdj = 'KDJ';
  static const String boll = 'BOLL';
  static const String ma = 'MA';
  static const String wr = 'WR';
  static const String dmi = 'DMI';
  static const String distribution = '分布';
  static const String watchlist = '自选';
  static const String history = '历史';
  static const String backtest = '回测';
  static const String prediction = '预测';
  static const String risk = '风险';
  static const String turtle = '海龟';
  static const String goldenCross = '金叉';
  static const String deathCross = '死叉';
  static const String noSignal = '无信号';
  static const String pleaseSearchStock = '搜索股票查看';
  static const String pleaseInputCode = '请输入股票代码';
  static const String addedToWatchlist = '已添加自选';
  static const String removedFromWatchlist = '已删除自选';
  static const String settingsSaved = '设置已保存';
  static const String noData = '暂无数据';
  static const String loadFailed = '加载失败';
  static const String market = '市场';
  static const String change = '涨跌幅';
  static const String volume = '成交量';
  static const String high = '最高';
  static const String low = '最低';
  static const String open = '开盘';
  static const String close = '收盘';
  static const String amount = '成交额';
}

class ChartConstants {
  static const int defaultShortPeriod = 12;
  static const int defaultLongPeriod = 26;
  static const int defaultSignalPeriod = 9;
  static const int defaultRsiPeriod = 6;
  static const int defaultKdjPeriod = 9;
  static const int defaultBollPeriod = 20;
  static const int defaultMa5Period = 5;
  static const int defaultMa10Period = 10;
  static const int defaultMa20Period = 20;
  static const int defaultMa60Period = 60;
  static const int defaultWr6Period = 6;
  static const int defaultWr10Period = 10;
  static const int defaultDmiPeriod = 14;
  static const int defaultTurtlePeriod = 20;
  static const int maxChartPoints = 100;
}

class ApiConstants {
  static const int cacheValidHours = 1;
  static const int maxHistoryItems = 20;
  static const int maxRetries = 3;
  static const Duration requestTimeout = Duration(seconds: 30);
}
