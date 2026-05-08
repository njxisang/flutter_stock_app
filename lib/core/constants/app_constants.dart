import 'package:flutter/material.dart';

/// 同花顺风格配色方案
/// 核心理念：深色背景 + 高对比涨跌色 + 清晰层次
class AppColors {
  AppColors._();

  // ── 主题色 ──────────────────────────────────────────────
  static const Color primary     = Color(0xFF1E88E5);  // 同花顺蓝（鲜亮）
  static const Color primaryDark  = Color(0xFF1565C0);
  static const Color primaryLight = Color(0xFF42A5F5);

  // ── A股涨跌色（高对比、更醒目）──
  // 涨：鲜红 | 跌：翠绿（与同花顺/东方财富一致）
  static const Color bullish = Color(0xFFED2B2B);   // 涨：正红（鲜亮高对比）
  static const Color bearish = Color(0xFF21C45E);   // 跌：翠绿（鲜亮高对比）

  // ── 背景色系（全深色统一）──
  // 主背景：深灰蓝（非纯黑，更有质感）
  static const Color background     = Color(0xFF111827);
  // 卡片/页面表面
  static const Color surface        = Color(0xFF1A2030);
  static const Color cardBackground = Color(0xFF1E2535);
  // 图表背景（稍深以突出K线）
  static const Color chartBackground    = Color(0xFF0F131C);
  static const Color chartBgSecondary   = Color(0xFF161B28);

  // ── 文字色系 ─────────────────────────────────────────────
  static const Color textPrimary   = Color(0xFFFFFFFF);
  static const Color textSecondary = Color(0xFF8899AA);  // 次要文字（偏蓝灰）
  static const Color textTertiary  = Color(0xFF4A5568);  // 辅助/禁用

  // ── K线涨跌（实心）──
  static const Color bullBody   = Color(0xFFED2B2B);   // 阳线实心
  static const Color bullWick   = Color(0xFFD42020);   // 阳线影线
  static const Color bearBody   = Color(0xFF21C45E);   // 阴线实心
  static const Color bearWick   = Color(0xFF1AAF55);   // 阴线影线

  // ── K线空心边框 ──────────────────────────────────────────
  static const Color bullHollow = Color(0xFFED2B2B);
  static const Color bearHollow = Color(0xFF21C45E);

  // ── K线高亮（触摸态）──
  static const Color bullBodyHl = Color(0xFFFF4D4D);
  static const Color bearBodyHl = Color(0xFF2DE075);

  // ── 均线配色（色彩分明、不抢焦点）──
  static const Color ma5Color   = Color(0xFFFF8C00);   // 橙黄（MA5）
  static const Color ma10Color  = Color(0xFF00B0FF);   // 天蓝（MA10）
  static const Color ma20Color  = Color(0xFFEA80FC);   // 紫罗兰（MA20）
  static const Color ma60Color  = Color(0xFFFFD740);   // 金色（MA60）
  static const Color ma120Color = Color(0xFF00E5FF);   // 青色（MA120）
  static const Color ma250Color = Color(0xFFF06292);   // 粉色（MA250）

  // ── MACD ────────────────────────────────────────────────
  static const Color difColor  = Color(0xFF00B0FF);
  static const Color deaColor  = Color(0xFFFF8C00);
  static const Color macdUp    = Color(0xFFED2B2B);
  static const Color macdDown = Color(0xFF21C45E);
  static const Color macdBar   = Color(0xFF8899AA);

  // ── KDJ ─────────────────────────────────────────────────
  static const Color kColor = Color(0xFFFF8C00);
  static const Color dColor = Color(0xFF00B0FF);
  static const Color jColor = Color(0xFFEA80FC);

  // ── BOLL ────────────────────────────────────────────────
  static const Color bollUpper  = Color(0xFF00B0FF);
  static const Color bollMiddle = Color(0xFFFF8C00);
  static const Color bollLower  = Color(0xFFEA80FC);

  // ── WR ─────────────────────────────────────────────────
  static const Color wr6Color  = Color(0xFFFF8C00);
  static const Color wr10Color = Color(0xFF00B0FF);

  // ── DMI ────────────────────────────────────────────────
  static const Color pdiColor = Color(0xFFFF8C00);
  static const Color mdiColor = Color(0xFF00B0FF);
  static const Color adxColor = Color(0xFFEA80FC);

  // ── 网格/坐标轴 ─────────────────────────────────────────
  static const Color gridLine       = Color(0x1AFFFFFF);    // 10% 白
  static const Color gridLineStrong = Color(0x30FFFFFF);    // 19% 白
  static const Color axisLabel      = Color(0xFF4A5568);    // 刻度
  static const Color axisLabelStrong = Color(0xFF8899AA);   // 重要刻度

  // ── 十字光标 ─────────────────────────────────────────────
  static const Color crosshairLine    = Color(0x66FFFFFF);
  static const Color crosshairTagBg   = Color(0xFFE8F4FD);
  static const Color crosshairTagText = Color(0xFF111827);
  static const Color crosshairPriceTag = Color(0xFF00B0FF);

  // ── 成交量 ───────────────────────────────────────────────
  static const Color volUp    = Color(0xFFED2B2B);
  static const Color volDown  = Color(0xFF21C45E);
  static const Color volUpA   = Color(0x33ED2B2B);
  static const Color volDownA = Color(0x3321C45E);

  // ── Tooltip ─────────────────────────────────────────────
  static const Color tooltipBg     = Color(0xDD1E2535);  // 87% 深蓝灰
  static const Color tooltipBorder = Color(0x40FFFFFF);

  // ── 状态色 ───────────────────────────────────────────────
  static const Color success = Color(0xFF21C45E);
  static const Color warning = Color(0xFFFF8C00);
  static const Color error   = Color(0xFFED2B2B);

  // ── 边框/分割线 ─────────────────────────────────────────
  static const Color border  = Color(0xFF2A3444);
  static const Color divider = Color(0xFF1E2535);
}

// ─────────────────────────────────────────────────────────
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

// ─────────────────────────────────────────────────────────
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
  static const int defaultCandleWidth = 8;
  static const double defaultWickWidth = 0.8;
  static const double defaultMaWidth = 1.4;
  static const bool defaultShowMa5 = true;
  static const bool defaultShowMa10 = true;
  static const bool defaultShowMa20 = true;
  static const bool defaultShowMa60 = false;
  static const bool defaultShowVolume = true;
}

// ─────────────────────────────────────────────────────────
class ApiConstants {
  static const int cacheValidHours = 1;
  static const int maxHistoryItems = 20;
  static const int maxRetries = 3;
  static const Duration requestTimeout = Duration(seconds: 30);
}
