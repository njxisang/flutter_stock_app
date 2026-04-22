import 'package:flutter/material.dart';

class AppColors {
  static const Color primary = Color(0xFF2196F3);
  static const Color accent = Color(0xFFFF5722);
  static const Color success = Color(0xFF4CAF50);
  static const Color warning = Color(0xFFFF9800);
  static const Color error = Color(0xFFF44336);
  static const Color bullish = Color(0xFF4CAF50);
  static const Color bearish = Color(0xFFF44336);
  static const Color difColor = Color(0xFFFF5722);
  static const Color deaColor = Color(0xFF4CAF50);
  static const Color macdColor = Color(0xFF9C27B0);
  static const Color kColor = Color(0xFFFF5722);
  static const Color dColor = Color(0xFF2196F3);
  static const Color jColor = Color(0xFF9C27B0);
  static const Color bollUpper = Color(0xFFF44336);
  static const Color bollMiddle = Color(0xFF2196F3);
  static const Color bollLower = Color(0xFF4CAF50);
  static const Color ma5Color = Color(0xFFFF5722);
  static const Color ma10Color = Color(0xFF2196F3);
  static const Color ma20Color = Color(0xFF4CAF50);
  static const Color ma60Color = Color(0xFF9C27B0);
  static const Color wr6Color = Color(0xFFFF5722);
  static const Color wr10Color = Color(0xFF2196F3);
  static const Color pdiColor = Color(0xFFFF5722);
  static const Color mdiColor = Color(0xFF4CAF50);
  static const Color adxColor = Color(0xFF2196F3);
  static const Color background = Color(0xFFFAFAFA);
  static const Color surface = Colors.white;
  static const Color textPrimary = Color(0xFF212121);
  static const Color textSecondary = Color(0xFF757575);
}

class AppStrings {
  static const String appName = '股票MACD';
  static const String searchHint = '输入股票代码';
  static const String search = '搜索';
  static const String analyze = '分析';
  static const String addWatchlist = '添加自选';
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
  static const String watchlist = '自选股';
  static const String history = '历史';
  static const String backtest = '回测';
  static const String prediction = '预测';
  static const String risk = '风险';
  static const String turtle = '海龟';
  static const String goldenCross = '金叉信号 - 买入';
  static const String deathCross = '死叉信号 - 卖出';
  static const String noSignal = '暂无信号';
  static const String pleaseSearchStock = '请先搜索股票';
  static const String pleaseInputCode = '请输入股票代码';
  static const String addedToWatchlist = '已添加到自选';
  static const String settingsSaved = '设置已保存';
  static const String noData = '暂无数据';
  static const String loadFailed = '加载失败';
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
