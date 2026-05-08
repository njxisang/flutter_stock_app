import 'dart:convert';
import 'package:equatable/equatable.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../domain/entities/stock_quote.dart';

/// 席位历史数据存储服务
/// 使用 SharedPreferences 持久化龙虎榜数据和席位追踪记录
class SeatHistoryService {
  static const String _trackedSeatsKey = 'tracked_seats_v2';
  static const String _seatHistoryPrefix = 'seat_history_';
  static const String _lhbCachePrefix = 'lhb_cache_';
  static const String _lastSeenPrefix = 'last_seen_';
  static const int _maxHistoryDays = 90; // 保留近90天数据

  final SharedPreferences _prefs;

  SeatHistoryService(this._prefs);

  // ============ 席位管理 ============

  /// 获取追踪席位列表
  List<String> getTrackedSeats() {
    final json = _prefs.getString(_trackedSeatsKey);
    if (json == null) return _defaultSeats();
    return List<String>.from(jsonDecode(json));
  }

  /// 添加追踪席位
  Future<void> addTrackedSeat(String seat) async {
    final seats = getTrackedSeats();
    if (!seats.contains(seat)) {
      seats.add(seat);
      await _prefs.setString(_trackedSeatsKey, jsonEncode(seats));
    }
  }

  /// 移除追踪席位
  Future<void> removeTrackedSeat(String seat) async {
    final seats = getTrackedSeats();
    seats.remove(seat);
    await _prefs.setString(_trackedSeatsKey, jsonEncode(seats));
    // 同时删除该席位历史
    await _prefs.remove('$_seatHistoryPrefix${seat.hashCode}');
  }

  /// 默认预置席位（与 Python seat_tracker_notification.py 的 SEAT_KEYWORDS 保持一致）
  List<String> _defaultSeats() {
    return [
      // 顶级游资
      '中信证券上海溧阳路',
      '国泰君安南京太平南路',
      '华泰证券绍兴解放北路',
      '作手余哥',
      '小鳄鱼',
      '佛山系',
      '成都系',
      '华泰证券南京长江路',
      // 机构与外资
      '机构专用',
      '高盛中国证券上海浦东新区世纪大道',
      '摩根大通证券上海银城中路',
      '瑞银证券上海花园石桥路',
      '中金上海分公司',
      '中金北京建国门外大街',
      // 沪深股通
      '沪股通专用',
      '深股通专用',
      // 高频活跃营业部
      '国泰海通证券总部',
      '中信证券上海分公司',
      '国盛证券宁波桑田路',
      '华泰证券深圳益田路荣超商务中心',
      '华鑫证券上海宛平南路',
      '华泰证券苏州吴中大道',
      '开源证券西安太华路',
      '国信证券深圳红岭中路',
      '中信建投证券上海营口路',
      '招商证券深圳益田路',
      '中国银河证券宜昌新世纪',
      '平安证券杭州曙光路',
      '东亚前海证券深圳分公司',
      '国泰海通证券上海分公司',
      '国泰海通证券成都北一环路',
    ];
  }

  // ============ 席位操作记录 ============

  /// 记录一次席位在某个股票上的操作
  Future<void> recordSeatOperation(SeatOperation op) async {
    final key = '$_seatHistoryPrefix${op.seatName.hashCode}';
    final existing = _getSeatHistory(key);

    // 检查是否已存在当天的记录（更新而非重复添加）
    final existingIdx = existing.indexWhere(
      (e) => e.seatName == op.seatName && e.symbol == op.symbol && e.date == op.date,
    );

    if (existingIdx >= 0) {
      existing[existingIdx] = op;
    } else {
      existing.add(op);
    }

    // 按日期降序，保留近90天
    existing.sort((a, b) => b.date.compareTo(a.date));
    final trimmed = existing.take(_maxHistoryDays * 3).toList(); // 每天最多3条

    await _prefs.setString(key, jsonEncode(trimmed.map(_seatOpToJson).toList()));

    // 记录最后seen时间（用于检测新建仓）
    final lastSeenKey = '$_lastSeenPrefix${op.seatName.hashCode}_${op.symbol}';
    await _prefs.setString(lastSeenKey, op.date);
  }

  /// 批量记录龙虎榜席位操作（从LhbEntry列表）
  Future<void> recordLhbEntries(List<LhbEntry> entries) async {
    for (final entry in entries) {
      // 买一席位
      if (entry.buyMaxSeat.isNotEmpty) {
        await recordSeatOperation(SeatOperation(
          seatName: entry.buyMaxSeat,
          symbol: entry.symbol,
          name: entry.name,
          date: entry.date,
          buyAmount: entry.buyAmount,
          sellAmount: 0,
          netAmount: entry.buyAmount,
          isBuy: true,
        ));
      }
      // 卖一席位
      if (entry.sellMaxSeat.isNotEmpty) {
        await recordSeatOperation(SeatOperation(
          seatName: entry.sellMaxSeat,
          symbol: entry.symbol,
          name: entry.name,
          date: entry.date,
          buyAmount: 0,
          sellAmount: entry.sellAmount,
          netAmount: -entry.sellAmount,
          isBuy: false,
        ));
      }
    }
  }

  /// 获取某席位历史操作
  List<SeatOperation> getSeatHistory(String seatName) {
    final key = '$_seatHistoryPrefix${seatName.hashCode}';
    return _getSeatHistory(key);
  }

  List<SeatOperation> _getSeatHistory(String key) {
    final json = _prefs.getString(key);
    if (json == null) return [];
    final list = jsonDecode(json) as List<dynamic>;
    return list.map((e) => _seatOpFromJson(e as Map<String, dynamic>)).toList();
  }

  /// 检测某席位是否新建仓某股票（上次出现日期早于今天）
  bool isNewPosition(String seatName, String symbol) {
    final lastSeenKey = '$_lastSeenPrefix${seatName.hashCode}_$symbol';
    final lastSeen = _prefs.getString(lastSeenKey);
    if (lastSeen == null) return false;
    final today = _todayStr();
    return lastSeen != today; // 今天之前出现过就不是新建仓
  }

  /// 获取某席位的最新建仓股票（今日且净买入）
  List<SeatOperation> getNewPositions(String seatName) {
    final history = getSeatHistory(seatName);
    final today = _todayStr();
    return history
        .where((op) => op.date == today && op.isBuy && op.netAmount > 0)
        .toList();
  }

  /// 获取某席位的统计信息
  SeatStats getSeatStats(String seatName) {
    final history = getSeatHistory(seatName);
    if (history.isEmpty) {
      return SeatStats(
        seatName: seatName,
        totalTrades: 0,
        totalBuyAmount: 0,
        totalSellAmount: 0,
        netAmount: 0,
        avgHoldingDays: 0,
        favoriteSector: '未知',
        winRate: 0,
        stocks: [],
      );
    }

    final totalBuy = history.fold<int>(0, (sum, op) => sum + op.buyAmount);
    final totalSell = history.fold<int>(0, (sum, op) => sum + op.sellAmount);
    final netAmount = totalBuy - totalSell;

    // 按股票分组统计
    final stockMap = <String, List<SeatOperation>>{};
    for (final op in history) {
      stockMap.putIfAbsent(op.symbol, () => []).add(op);
    }

    // 统计买卖都有的股票（完整交易）来算胜率
    final completedTrades = stockMap.entries
        .where((e) => e.value.any((op) => op.isBuy) && e.value.any((op) => !op.isBuy))
        .length;
    final buyOnlyTrades = stockMap.entries
        .where((e) => e.value.any((op) => op.isBuy) && !e.value.any((op) => !op.isBuy))
        .length;
    final winRate = (completedTrades + buyOnlyTrades) > 0
        ? completedTrades / (completedTrades + buyOnlyTrades)
        : 0.0;

    // 偏好板块（用股票代码首位粗估：6=沪市主板/科创，0/3=深市，8=北交所）
    final sectorMap = <String, int>{};
    for (final op in history) {
      final sector = _estimateSector(op.symbol);
      sectorMap[sector] = (sectorMap[sector] ?? 0) + op.netAmount.abs();
    }
    final favoriteSector = sectorMap.entries
        .reduce((a, b) => a.value > b.value ? a : b)
        .key;

    // 估算平均持仓天数（同一只股票两次出现间隔）
    int totalDays = 0;
    int pairCount = 0;
    final datesByStock = <String, List<String>>{};
    for (final op in history) {
      datesByStock.putIfAbsent(op.symbol, () => []).add(op.date);
    }
    for (final dates in datesByStock.values) {
      dates.sort();
      if (dates.length >= 2) {
        // 计算相邻日期差的平均值
        for (int i = 1; i < dates.length; i++) {
          final diff = _daysBetween(dates[i - 1], dates[i]);
          if (diff <= 30) { // 过滤异常间隔
            totalDays += diff;
            pairCount++;
          }
        }
      }
    }
    final avgHoldingDays = pairCount > 0 ? (totalDays / pairCount).round() : 5;

    // 汇总持仓股票（去重）
    final stocks = stockMap.entries.map((e) => SeatStockSummary(
      symbol: e.key,
      name: e.value.first.name,
      appearCount: e.value.length,
      totalNet: e.value.fold<int>(0, (sum, op) => sum + op.netAmount),
      lastDate: e.value.map((op) => op.date).reduce((a, b) => a.compareTo(b) > 0 ? a : b),
    )).toList();

    stocks.sort((a, b) => b.totalNet.abs().compareTo(a.totalNet.abs()));

    return SeatStats(
      seatName: seatName,
      totalTrades: stockMap.length,
      totalBuyAmount: totalBuy,
      totalSellAmount: totalSell,
      netAmount: netAmount,
      avgHoldingDays: avgHoldingDays,
      favoriteSector: favoriteSector,
      winRate: winRate,
      stocks: stocks,
    );
  }

  String _estimateSector(String symbol) {
    final clean = symbol.replaceAll(RegExp(r'[^0-9]'), '');
    if (clean.isEmpty) return '其他';
    final prefix = clean[0];
    switch (prefix) {
      case '6':
        return '沪市主板/科创';
      case '0':
      case '3':
        return '深市主板/创业板';
      case '8':
      case '4':
        return '北交所';
      default:
        return '其他';
    }
  }

  int _daysBetween(String a, String b) {
    final da = DateTime.parse(a);
    final db = DateTime.parse(b);
    return db.difference(da).inDays.abs();
  }

  String _todayStr() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  // ============ 序列化 ============

  Map<String, dynamic> _seatOpToJson(SeatOperation op) {
    return {
      'seatName': op.seatName,
      'symbol': op.symbol,
      'name': op.name,
      'date': op.date,
      'buyAmount': op.buyAmount,
      'sellAmount': op.sellAmount,
      'netAmount': op.netAmount,
      'isBuy': op.isBuy,
    };
  }

  SeatOperation _seatOpFromJson(Map<String, dynamic> json) {
    return SeatOperation(
      seatName: json['seatName'] as String,
      symbol: json['symbol'] as String,
      name: json['name'] as String,
      date: json['date'] as String,
      buyAmount: json['buyAmount'] as int,
      sellAmount: json['sellAmount'] as int,
      netAmount: json['netAmount'] as int,
      isBuy: json['isBuy'] as bool,
    );
  }
}

// ============ 新增实体 ============

/// 席位操作记录
class SeatOperation extends Equatable {
  final String seatName;
  final String symbol;
  final String name;
  final String date;
  final int buyAmount;
  final int sellAmount;
  final int netAmount;
  final bool isBuy;

  const SeatOperation({
    required this.seatName,
    required this.symbol,
    required this.name,
    required this.date,
    required this.buyAmount,
    required this.sellAmount,
    required this.netAmount,
    required this.isBuy,
  });

  @override
  List<Object?> get props => [seatName, symbol, name, date, buyAmount, sellAmount, netAmount, isBuy];
}

/// 席位统计信息
class SeatStats extends Equatable {
  final String seatName;
  final int totalTrades;
  final int totalBuyAmount;
  final int totalSellAmount;
  final int netAmount;
  final int avgHoldingDays;
  final String favoriteSector;
  final double winRate;
  final List<SeatStockSummary> stocks;

  const SeatStats({
    required this.seatName,
    required this.totalTrades,
    required this.totalBuyAmount,
    required this.totalSellAmount,
    required this.netAmount,
    required this.avgHoldingDays,
    required this.favoriteSector,
    required this.winRate,
    required this.stocks,
  });

  @override
  List<Object?> get props => [seatName, totalTrades, totalBuyAmount, totalSellAmount, netAmount, avgHoldingDays, favoriteSector, winRate, stocks];
}

/// 席位持仓股票汇总
class SeatStockSummary extends Equatable {
  final String symbol;
  final String name;
  final int appearCount;
  final int totalNet;
  final String lastDate;

  const SeatStockSummary({
    required this.symbol,
    required this.name,
    required this.appearCount,
    required this.totalNet,
    required this.lastDate,
  });

  int get totalNetAbs => totalNet.abs();

  @override
  List<Object?> get props => [symbol, name, appearCount, totalNet, lastDate];
}
