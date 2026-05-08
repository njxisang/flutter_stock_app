import 'package:flutter/material.dart';

class AppColors {
  // Primary
  static const Color primary = Color(0xFF238ECF);
  static const Color primaryDark = Color(0xFF1A6AA5);

  // Chinese market convention: Red up, Green down (沉稳不刺眼版本)
  static const Color bullish = Color(0xFFCE4040);   // 涨：暗红，比艳红柔和
  static const Color bearish = Color(0xFF3A8A5A);     // 跌：墨绿，比荧光绿沉稳

  // Chart background - 深黑护眼
  static const Color chartBackground = Color(0xFF0D1117);
  static const Color chartBgSecondary = Color(0xFF161B22);

  // Card / surface
  static const Color surface = Color(0xFF161B22);
  static const Color cardBackground = Color(0xFF1C2128);

  // Text
  static const Color textPrimary = Color(0xFFE6EDF3);
  static const Color textSecondary = Color(0xFF8B949E);
  static const Color textTertiary = Color(0xFF484F58);
  static const Color textLight = Color(0xFFE6EDF3);

  // App background (dark mode)
  static const Color background = Color(0xFF0D1117);

  // ── 图表元素配色 ─────────────────────────────────────

  // K线涨跌 — 沉稳色
  static const Color bullBody   = Color(0xFFCE4040);   // 阳线实心
  static const Color bullWick   = Color(0xFFB03030);   // 阳线影线（略深）
  static const Color bearBody   = Color(0xFF3A8A5A);   // 阴线实心
  static const Color bearWick   = Color(0xFF2D6E48);   // 阴线影线（略深）
  static const Color bullHollow = Color(0xFFCE4040);   // 阴线空心边框同阳线
  static const Color bearHollow = Color(0xFF3A8A5A);   // 阳线空心边框同阴线

  // K线高亮（触摸态）
  static const Color bullBodyHl  = Color(0xFFE05555);   // 涨高亮
  static const Color bearBodyHl  = Color(0xFF45A06A);   // 跌高亮

  // 均线 — 色彩区分明显、线条分明
  static const Color ma5Color  = Color(0xFFFF9B6A);   // 橙色（暖，不抢焦点）
  static const Color ma10Color = Color(0xFF6AB8FF);   // 天蓝
  static const Color ma20Color = Color(0xFFBA79E6);   // 薰衣草紫
  static const Color ma60Color = Color(0xFFFFD06A);   // 金黄
  static const Color ma120Color = Color(0xFF7AEFE6);  // 青绿
  static const Color ma250Color = Color(0xFFF0A0F0);  // 粉紫

  // MACD
  static const Color difColor = Color(0xFF6AB8FF);
  static const Color deaColor = Color(0xFFFF9B6A);
  static const Color macdUp   = Color(0xFFCE4040);
  static const Color macdDown = Color(0xFF3A8A5A);
  static const Color macdBar  = Color(0xFF8B949E);

  // KDJ
  static const Color kColor = Color(0xFFFF9B6A);
  static const Color dColor = Color(0xFF6AB8FF);
  static const Color jColor = Color(0xFFBA79E6);

  // BOLL
  static const Color bollUpper   = Color(0xFF6AB8FF);
  static const Color bollMiddle  = Color(0xFFFF9B6A);
  static const Color bollLower   = Color(0xFFBA79E6);

  // WR
  static const Color wr6Color  = Color(0xFFFF9B6A);
  static const Color wr10Color = Color(0xFF6AB8FF);

  // DMI
  static const Color pdiColor = Color(0xFFFF9B6A);
  static const Color mdiColor = Color(0xFF6AB8FF);
  static const Color adxColor = Color(0xFFBA79E6);

  // 网格 / 坐标轴
  static const Color gridLine  = Color(0x1AFFFFFF);   // 2.5% 白色，极淡
  static const Color gridLineStrong = Color(0x33FFFFFF); // 20% 白色，适中
  static const Color axisLabel = Color(0xFF484F58);   // 坐标刻度（小字）
  static const Color axisLabelStrong = Color(0xFF8B949E); // 重要刻度

  // 十字光标
  static const Color crosshairLine = Color(0x66FFFFFF);  // 40% 白
  static const Color crosshairTagBg = Color(0xFFE6EDF3);
  static const Color crosshairTagText = Color(0xFF0D1117);
  static const Color crosshairPriceTag = Color(0xFF6AB8FF);

  // 成交量
  static const Color volUp   = Color(0xFFCE4040);
  static const Color volDown = Color(0xFF3A8A5A);
  static const Color volUpA  = Color(0x33CE4040);   // 20% 透明度
  static const Color volDownA = Color(0x333A8A5A);

  // Tooltip
  static const Color tooltipBg = Color(0xDD1C2128);
  static const Color tooltipBorder = Color(0x33FFFFFF);

  // ── 状态色 ─────────────────────────────────────────
  static const Color success  = Color(0xFF3A8A5A);
  static const Color warning  = Color(0xFFFF9B6A);
  static const Color error    = Color(0xFFCE4040);

  // ── 边框 / 分割线 ─────────────────────────────────
  static const Color border   = Color(0xFF30363D);
  static const Color divider  = Color(0xFF21262D);
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

  // 图表样式
  static const String chartStyle = '图表样式';
  static const String candleStyle = 'K线样式';
  static const String solidCandle = '实心K线';
  static const String hollowCandle = '空心K线';
  static const String colorTheme = '配色主题';
  static const String colorThemeClassic = '经典红绿';
  static const String colorThemeGreenRed = '绿涨红跌';
  static const String colorThemePurple = '紫蓝配色';
  static const String chartSettings = '图表设置';
  static const String candleWidth = 'K线宽度';
  static const String showMa = '显示均线';
  static const String showVolume = '显示成交量';
  static const String maSettings = '均线设置';

  // 指标参数
  static const String shortPeriod = '短期';
  static const String longPeriod = '长期';
  static const String signalPeriod = '信号';
  static const String period = '周期';

  // 数据管理
  static const String displaySettings = '显示设置';
  static const String dataManagement = '数据管理';
  static const String clearSearchHistory = '清除搜索历史';
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

  // 图表样式默认值
  static const bool defaultHollowCandle = false;
  static const int defaultCandleWidth = 8;      // 1-16
  static const double defaultWickWidth = 0.8;
  static const double defaultMaWidth = 1.4;
  static const bool defaultShowMa5 = true;
  static const bool defaultShowMa10 = true;
  static const bool defaultShowMa20 = true;
  static const bool defaultShowMa60 = false;
  static const bool defaultShowVolume = true;
}

class ApiConstants {
  static const int cacheValidHours = 1;
  static const int maxHistoryItems = 20;
  static const int maxRetries = 3;
  static const Duration requestTimeout = Duration(seconds: 30);
}
