import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import '../../domain/entities/stock_quote.dart';

enum Market { sh, sz, bj, us }

class _CacheEntry {
  final String body;
  final Map<String, String> headers;
  final DateTime timestamp;
  final String apiSource;

  _CacheEntry({
    required this.body,
    required this.headers,
    required this.timestamp,
    required this.apiSource,
  });

  bool get isExpired => DateTime.now().difference(timestamp).inMinutes >= 5;
}

/// 龙虎榜API服务
/// 专注于龙虎榜数据获取：榜单列表和席位明细
class LhbApiService {
  final http.Client _client;
  final Map<String, _CacheEntry> _cache = {};

  LhbApiService({http.Client? client}) : _client = client ?? http.Client();

  String _cacheKey(String url) => md5.convert(utf8.encode(url)).toString();

  _CacheEntry? _getCachedResponse(String url) {
    final key = _cacheKey(url);
    final entry = _cache[key];
    if (entry != null && !entry.isExpired) {
      print('[LHB Cache HIT] URL: $url (API: ${entry.apiSource})');
      return entry;
    }
    print('[LHB Cache MISS] URL: $url');
    return null;
  }

  void _cacheResponse(String url, String body, Map<String, String> headers, String apiSource) {
    final key = _cacheKey(url);
    _cache[key] = _CacheEntry(
      body: body,
      headers: headers,
      timestamp: DateTime.now(),
      apiSource: apiSource,
    );
    print('[LHB Cache STORED] URL: $url (API: $apiSource)');
  }

  Market detectMarket(String symbol) {
    final upper = symbol.toUpperCase();
    if (upper.startsWith('SH') || upper.endsWith('.SS') || upper.endsWith('.SH')) return Market.sh;
    if (upper.startsWith('SZ') || upper.endsWith('.SZ')) return Market.sz;
    if (upper.startsWith('BJ') || (upper.startsWith('8') && upper.length == 6)) return Market.bj;
    if (upper.startsWith('5') && upper.length == 6) return Market.sh;
    if (upper.startsWith('1') && upper.length == 6) return Market.sz;
    if (upper.startsWith('4') && upper.length == 6) return Market.sh;
    if (upper.startsWith('3') && upper.length == 6) return Market.sz;
    if (upper.startsWith('6') && upper.length == 6) return Market.sh;
    if (upper.startsWith('0') && upper.length == 6) return Market.sz;
    return Market.us;
  }

  String normalizeSymbol(String symbol) {
    final clean = symbol.trim().toUpperCase();
    if (clean.contains('.')) return clean;
    if (clean.length == 6 && clean.startsWith('6')) return 'sh.$clean';
    if (clean.length == 6 && clean.startsWith('0')) return 'sz.$clean';
    if (clean.length == 6 && clean.startsWith('3')) return 'sz.$clean';
    if (clean.length == 6 && clean.startsWith('8')) return 'bj.$clean';
    if (clean.length == 6 && clean.startsWith('5')) return 'sh.$clean';
    if (clean.length == 6 && clean.startsWith('1')) return 'sz.$clean';
    if (clean.length == 6 && clean.startsWith('4')) return 'sh.$clean';
    if (clean == '000001' || clean.endsWith('.SS')) return 'sh.000001';
    if (clean == '399001' || clean.endsWith('.SZ')) return 'sz.399001';
    return clean;
  }

  /// 获取龙虎榜列表（指定日期）
  Future<List<LhbEntry>> getLhbData({String? date}) async {
    final targetDate = date ?? _todayStr();
    // 用 >= 而非 =，这样非当天日期也能拉到历史数据
    final url = 'https://datacenter-web.eastmoney.com/api/data/v1/get'
        '?reportName=RPT_DRAGON_LIST_DAILY'
        '&columns=ALL'
        '&pageNumber=1'
        '&pageSize=100'
        '&sortTypes=-1'
        '&sortColumns=TRADE_DATE'
        '&filter=(TRADE_DATE%3D%27$targetDate%27)';

    final cached = _getCachedResponse(url);
    if (cached != null) {
      return _parseLhbResponse(cached.body);
    }

    try {
      print('[API CALL] LHB EastMoney API: $url');
      final response = await _client.get(
        Uri.parse(url),
        headers: {
          'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
          'Referer': 'https://data.eastmoney.com/lhb/',
        },
      );

      if (response.statusCode == 200) {
        _cacheResponse(url, response.body, response.headers, 'EastMoney LHB');
        return _parseLhbResponse(response.body);
      }
    } catch (e) {
      print('[API DEGRADATION] LHB EastMoney API failed: $e');
    }
    return [];
  }

  List<LhbEntry> _parseLhbResponse(String body) {
    final json = jsonDecode(body);
    final result = json['result'] as Map<String, dynamic>?;
    final list = result?['data'] as List<dynamic>?;

    if (list != null) {
      return list.map((item) {
        final m = item as Map<String, dynamic>;
        return LhbEntry(
          date: m['TRADE_DATE'] ?? '',
          symbol: m['SECURITY_CODE'] ?? '',
          name: m['SECURITY_NAME'] ?? '',
          closePrice: (m['CLOSE_PRICE'] ?? 0).toString(),
          changePercent: (m['CHANGE_RATE'] ?? 0).toString(),
          reason: m['EXPLAIN'] ?? '',
          buyMaxSeat: m['BUY_SEAT_1'] ?? '',
          sellMaxSeat: m['SELL_SEAT_1'] ?? '',
          buyAmount: _parseInt(m['BUY_AMT']),
          sellAmount: _parseInt(m['SELL_AMT']),
        );
      }).toList();
    }
    return [];
  }

  /// 获取个股龙虎榜明细（含席位）
  Future<List<LhbSeatDetail>> getLhbSeatDetail(String symbol, {String? date}) async {
    final normalized = normalizeSymbol(symbol);
    final stockCode = normalized.contains('.') ? normalized.split('.')[1] : normalized;
    final targetDate = date ?? _todayStr();

    final url = 'https://datacenter-web.eastmoney.com/api/data/v1/get'
        '?reportName=RPT_STOCK_SEAT_DAILY'
        '&columns=ALL'
        '&pageNumber=1'
        '&pageSize=20'
        '&sortTypes=-1'
        '&sortColumns=NET_AMT'
        '&filter=(TRADE_DATE%3D%27$targetDate%27)(SECUCODE%3D%27$stockCode.SH%27)';

    final cached = _getCachedResponse(url);
    if (cached != null) {
      return _parseLhbSeatResponse(cached.body);
    }

    try {
      print('[API CALL] LHB Seat EastMoney API: $url');
      final response = await _client.get(
        Uri.parse(url),
        headers: {
          'User-Agent': 'Mozilla/5.0',
          'Referer': 'https://data.eastmoney.com/',
        },
      );

      if (response.statusCode == 200) {
        _cacheResponse(url, response.body, response.headers, 'EastMoney LHB Seat');
        return _parseLhbSeatResponse(response.body);
      }
    } catch (e) {
      print('[API DEGRADATION] LHB Seat API failed: $e');
    }
    return [];
  }

  List<LhbSeatDetail> _parseLhbSeatResponse(String body) {
    final json = jsonDecode(body);
    final result = json['result'] as Map<String, dynamic>?;
    final list = result?['data'] as List<dynamic>?;

    if (list != null) {
      return list.map((item) {
        final m = item as Map<String, dynamic>;
        final buyAmt = _parseDouble(m['BUY_AMT']);
        final sellAmt = _parseDouble(m['SELL_AMT']);
        return LhbSeatDetail(
          seatName: m['SEAT_NAME'] ?? '',
          buyAmount: (buyAmt / 10000).toStringAsFixed(0),
          sellAmount: (sellAmt / 10000).toStringAsFixed(0),
          netAmount: ((buyAmt - sellAmt) / 10000).toStringAsFixed(0),
        );
      }).toList();
    }
    return [];
  }

  // ============ 龙虎榜日报摘要（全量席位明细，用于生成概览/排行榜/席位流向）============

  /// 龙虎榜席位明细条目（原生）
  LhbSeatRawEntry _parseSeatEntry(Map<String, dynamic> m) {
    return LhbSeatRawEntry(
      tradeDate: m['TRADE_DATE'] ?? '',
      securityCode: m['SECURITY_CODE'] ?? '',
      securityName: m['SECURITY_NAME_ABBR'] ?? '',
      seatName: m['OPERATEDEPT_NAME'] ?? '',
      buyAmt: _parseDouble(m['BUY_AMT']),
      sellAmt: _parseDouble(m['SELL_AMT']),
      netBuy: _parseDouble(m['NET_BUY']),
      tradeDirection: m['TRADE_DIRECTION'] ?? '',
      rank: int.tryParse((m['RANK'] ?? '0').toString()) ?? 0,
      changeRate: _parseDouble(m['CHANGE_RATE']),
      explanation: m['EXPLANATION'] ?? '',
    );
  }

  /// 获取指定日期的龙虎榜席位明细（分页拉取全部）
  Future<List<LhbSeatRawEntry>> getLhbSeatRaw({String? date}) async {
    final targetDate = date ?? _todayStr();
    final datePrefix = targetDate.substring(0, 10);
    final allData = <LhbSeatRawEntry>[];
    int page = 1;

    while (true) {
      final url = 'https://datacenter-web.eastmoney.com/api/data/v1/get'
          '?reportName=RPT_BILLBOARD_SEAT'
          '&columns=TRADE_DATE,SECURITY_CODE,SECURITY_NAME_ABBR,'
          'OPERATEDEPT_NAME,BUY_AMT,SELL_AMT,NET_BUY,TRADE_DIRECTION,RANK,EXPLANATION,CHANGE_RATE'
          '&pageNumber=$page'
          '&pageSize=500'
          '&sortTypes=-1'
          '&sortColumns=TRADE_DATE'
          '&source=WEB'
          '&client=WEB';

      try {
        final response = await _client.get(
          Uri.parse(url),
          headers: {
            'User-Agent': 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36',
            'Referer': 'https://data.eastmoney.com/stock/lhb.html',
          },
        );
        if (response.statusCode != 200) break;
        final json = jsonDecode(response.body);
        final result = json['result'] as Map<String, dynamic>?;
        final pageData = result?['data'] as List<dynamic>? ?? [];
        if (pageData.isEmpty) break;

        // 过滤出目标日期的记录
        for (final item in pageData) {
          final m = item as Map<String, dynamic>;
          final d = (m['TRADE_DATE'] ?? '').toString();
          if (d.isNotEmpty && d.substring(0, d.length > 10 ? 10 : d.length) == datePrefix) {
            allData.add(_parseSeatEntry(m));
          }
        }

        // 如果这条记录已经超过目标日期，停止翻页
        final lastDate = (pageData.last as Map<String, dynamic>)['TRADE_DATE'] ?? '';
        if (lastDate.toString().compareTo(datePrefix) < 0) break;

        final totalPages = result?['pages'] as int? ?? 1;
        if (page >= totalPages) break;
        page++;
      } catch (e) {
        print('[API DEGRADATION] RPT_BILLBOARD_SEAT page $page failed: $e');
        break;
      }
    }

    print('[LHB SEAT RAW] $targetDate → ${allData.length} entries');
    return allData;
  }

  // ============ 辅助方法 ===========

  String _todayStr() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  int _parseInt(dynamic val) {
    if (val == null) return 0;
    if (val is int) return val;
    if (val is double) return val.toInt();
    final s = val.toString().replaceAll(',', '').replaceAll('--', '0');
    return int.tryParse(s) ?? 0;
  }

  double _parseDouble(dynamic val) {
    if (val == null) return 0;
    if (val is double) return val;
    if (val is int) return val.toDouble();
    final s = val.toString().replaceAll(',', '').replaceAll('--', '0');
    return double.tryParse(s) ?? 0;
  }
}

// ============ 龙虎榜席位原始条目 ============

class LhbSeatRawEntry {
  final String tradeDate;
  final String securityCode;
  final String securityName;
  final String seatName;
  final double buyAmt;
  final double sellAmt;
  final double netBuy;
  final String tradeDirection; // 0=买入, 1=卖出
  final int rank;
  final double changeRate;
  final String explanation;

  LhbSeatRawEntry({
    required this.tradeDate,
    required this.securityCode,
    required this.securityName,
    required this.seatName,
    required this.buyAmt,
    required this.sellAmt,
    required this.netBuy,
    required this.tradeDirection,
    required this.rank,
    required this.changeRate,
    required this.explanation,
  });

  bool get isBuy => tradeDirection == '0';
  bool get isSell => tradeDirection == '1';
}

// ============ 龙虎榜日报摘要模型 ============

/// 席位分类（用于分类汇总）
enum SeatCategory { institution, foreign, hkStock, retail, other }

class LhbSummaryModel {
  final String date;
  final int totalEntries;    // 席位明细总条数
  final int totalStocks;     // 上榜股票只数
  final int upCount;          // 上涨只数
  final int downCount;        // 下跌只数
  final List<LhbStockRank> topGainers;   // 涨幅榜 TOP10
  final List<LhbStockRank> topLosers;    // 跌幅榜 TOP10
  final List<SeatTypeSummary> seatTypeSummary; // 席位类型资金流向
  final List<LhbStockRank> newPositions;  // 预置席位新建仓（7天未出现）

  LhbSummaryModel({
    required this.date,
    required this.totalEntries,
    required this.totalStocks,
    required this.upCount,
    required this.downCount,
    required this.topGainers,
    required this.topLosers,
    required this.seatTypeSummary,
    required this.newPositions,
  });

  String get dateDisplay => date;
}

/// 单只股票在龙虎榜的聚合数据
class LhbStockRank {
  final String code;
  final String name;
  final double changeRate;
  final double totalBuy;
  final double totalSell;
  final double totalNet;
  final String topBuySeat;  // 买一席位简称
  final double topBuyNet;
  final String topSellSeat; // 卖一席位简称
  final double topSellNet;
  final bool isNewPosition; // 是否新建仓
  final String? seat;       // 所属席位（新建仓时）

  LhbStockRank({
    required this.code,
    required this.name,
    required this.changeRate,
    required this.totalBuy,
    required this.totalSell,
    required this.totalNet,
    required this.topBuySeat,
    required this.topBuyNet,
    required this.topSellSeat,
    required this.topSellNet,
    this.isNewPosition = false,
    this.seat,
  });

  String get changeDisplay => '${changeRate >= 0 ? '+' : ''}${changeRate.toStringAsFixed(2)}%';
  String get netDisplay => '${totalNet >= 0 ? '+' : ''}${(totalNet / 1e8).toStringAsFixed(3)}亿';
  String get buyDisplay => '${(totalBuy / 1e8).toStringAsFixed(3)}亿';
  String get sellDisplay => '${(totalSell / 1e8).toStringAsFixed(3)}亿';
}

/// 席位类型资金流向汇总
class SeatTypeSummary {
  final String typeName;       // 机构/外资/沪深股通/游资
  final double totalBuy;
  final double totalSell;
  final double totalNet;

  SeatTypeSummary({
    required this.typeName,
    required this.totalBuy,
    required this.totalSell,
    required this.totalNet,
  });

  String get netDisplay => '${totalNet >= 0 ? '+' : ''}${(totalNet / 1e8).toStringAsFixed(3)}亿';
  String get buyDisplay => '${(totalBuy / 1e8).toStringAsFixed(3)}亿';
  String get sellDisplay => '${(totalSell / 1e8).toStringAsFixed(3)}亿';
}

/// 龙虎榜日报摘要服务（纯计算，无网络）
class LhbSummaryService {
  // 预置追踪席位关键词
  static const Map<String, String> SEAT_KEYWORDS = {
    '中信溧阳路': '溧阳路',
    '太平南路': '太平南路',
    '绍兴解放路': '解放路',
    '作手余哥': '作手余哥',
    '小鳄鱼': '小鳄鱼',
    '佛山系': '佛山',
    '成都系': '成都',
    '飞云江路': '飞云江路',
    '机构专用': '机构专用',
    '高盛中国': '高盛(中国)证券',
    '摩根大通': '摩根大通证券',
    '瑞银证券': '瑞银证券',
    '中金上海': '中国国际金融股份有限公司上海分公司',
    '中金北京': '中国国际金融股份有限公司北京',
    '沪股通': '沪股通专用',
    '深股通': '深股通专用',
    '国泰海通总部': '国泰海通证券股份有限公司总部',
    '中信上海分公司': '中信证券股份有限公司上海分公司',
    '国盛宁波桑田': '国盛证券股份有限公司宁波桑田路',
    '华泰深圳益田': '华泰证券股份有限公司深圳益田路荣超商务中心',
    '华鑫上海宛平': '华鑫证券有限责任公司上海宛平南路',
    '华泰苏州吴中': '华泰证券股份有限公司苏州吴中大道',
    '开源西安太华': '开源证券股份有限公司西安太华路',
    '国信深圳红岭': '国信证券股份有限公司深圳红岭中路',
    '中信建投上海': '中信建投证券股份有限公司上海营口路',
    '招商深圳益田': '招商证券股份有限公司深圳益田路',
    '银河宜昌新世纪': '中国银河证券股份有限公司宜昌新世纪',
    '平安杭州曙光': '平安证券股份有限公司杭州曙光路',
    '东亚前海深圳': '东亚前海证券有限责任公司深圳分公司',
    '国泰海通上海': '国泰海通证券股份有限公司上海分公司',
    '国泰海通成都': '国泰海通证券股份有限公司成都北一环路',
  };

  // 席位 → 类型
  static const Map<String, SeatCategory> SEAT_CATEGORY = {
    '机构专用': SeatCategory.institution,
    '高盛(中国)证券': SeatCategory.foreign,
    '摩根大通证券': SeatCategory.foreign,
    '瑞银证券': SeatCategory.foreign,
    '中国国际金融股份有限公司上海分公司': SeatCategory.foreign,
    '中国国际金融股份有限公司北京': SeatCategory.foreign,
    '沪股通专用': SeatCategory.hkStock,
    '深股通专用': SeatCategory.hkStock,
  };

  static SeatCategory _getCategory(String seatKeyword) {
    if (SEAT_CATEGORY.containsKey(seatKeyword)) return SEAT_CATEGORY[seatKeyword]!;
    return SeatCategory.retail;
  }

  static String _matchSeat(String opDeptName) {
    if (opDeptName.isEmpty) return '';
    for (final keyword in SEAT_KEYWORDS.values) {
      if (opDeptName.contains(keyword)) return keyword;
    }
    return '';
  }

  static String _getSeatTypeName(SeatCategory cat) {
    switch (cat) {
      case SeatCategory.institution: return '机构';
      case SeatCategory.foreign: return '外资';
      case SeatCategory.hkStock: return '沪深股通';
      case SeatCategory.retail: return '游资';
      case SeatCategory.other: return '其他';
    }
  }

  /// 从原始席位明细构建日报摘要
  /// prevLastSeen: 上一次推送时记录的 last_seen（席位→股票→最后日期），用于判断新建仓
  static LhbSummaryModel build({
    required String date,
    required List<LhbSeatRawEntry> entries,
    required Map<String, Map<String, String>> prevLastSeen,
  }) {
    if (entries.isEmpty) {
      return LhbSummaryModel(
        date: date,
        totalEntries: 0,
        totalStocks: 0,
        upCount: 0,
        downCount: 0,
        topGainers: [],
        topLosers: [],
        seatTypeSummary: [],
        newPositions: [],
      );
    }

    // 按股票聚合
    final stockMap = <String, _StockAgg>{};
    for (final e in entries) {
      final code = e.securityCode;
      if (code.isEmpty) continue;
      final agg = stockMap.putIfAbsent(code, () => _StockAgg(code: code, name: e.securityName));
      if (e.isBuy) {
        agg.buyEntries.add(e);
      } else if (e.isSell) {
        agg.sellEntries.add(e);
      }
      if (agg.changeRate == 0) agg.changeRate = e.changeRate;
    }

    // 统计
    final stockCodes = stockMap.keys.toSet();
    final upCount = stockCodes.where((c) => (stockMap[c]?.changeRate ?? 0) > 0).length;
    final downCount = stockCodes.where((c) => (stockMap[c]?.changeRate ?? 0) < 0).length;

    // 涨幅/跌幅榜
    final stocksWithChange = stockCodes.map((code) {
      final agg = stockMap[code]!;
      final totalBuy = agg.buyEntries.fold(0.0, (s, e) => s + e.buyAmt);
      final totalSell = agg.sellEntries.fold(0.0, (s, e) => s + e.sellAmt);
      final totalNet = totalBuy - totalSell;

      // 找买一/卖一（按净买绝对值）
      final sortedBuy = agg.buyEntries.toList()
        ..sort((a, b) => b.netBuy.abs().compareTo(a.netBuy.abs()));
      final sortedSell = agg.sellEntries.toList()
        ..sort((a, b) => b.netBuy.abs().compareTo(a.netBuy.abs()));

      final topBuy = sortedBuy.isNotEmpty ? sortedBuy.first : null;
      final topSell = sortedSell.isNotEmpty ? sortedSell.first : null;

      return _StockWithChange(
        code: code,
        name: agg.name,
        changeRate: agg.changeRate,
        totalBuy: totalBuy,
        totalSell: totalSell,
        totalNet: totalNet,
        topBuySeat: topBuy != null ? _matchSeat(topBuy.seatName) : '',
        topBuyNet: topBuy?.netBuy ?? 0,
        topSellSeat: topSell != null ? _matchSeat(topSell.seatName) : '',
        topSellNet: topSell?.netBuy ?? 0,
      );
    }).toList()
      ..sort((a, b) => a.changeRate.abs().compareTo(b.changeRate.abs()));

    final gainers = stocksWithChange.where((s) => s.changeRate > 0).take(10).toList();
    final losers = stocksWithChange.where((s) => s.changeRate < 0).take(10).toList();

    final topGainers = gainers.map((s) => LhbStockRank(
      code: s.code,
      name: s.name,
      changeRate: s.changeRate,
      totalBuy: s.totalBuy,
      totalSell: s.totalSell,
      totalNet: s.totalNet,
      topBuySeat: s.topBuySeat,
      topBuyNet: s.topBuyNet,
      topSellSeat: s.topSellSeat,
      topSellNet: s.topSellNet,
    )).toList();

    final topLosers = losers.map((s) => LhbStockRank(
      code: s.code,
      name: s.name,
      changeRate: s.changeRate,
      totalBuy: s.totalBuy,
      totalSell: s.totalSell,
      totalNet: s.totalNet,
      topBuySeat: s.topBuySeat,
      topBuyNet: s.topBuyNet,
      topSellSeat: s.topSellSeat,
      topSellNet: s.topSellNet,
    )).toList();

    // 席位类型汇总
    final typeStats = <SeatCategory, _TypeStat>{};
    for (final cat in SeatCategory.values) {
      typeStats[cat] = _TypeStat();
    }

    for (final e in entries) {
      final keyword = _matchSeat(e.seatName);
      final cat = keyword.isEmpty ? SeatCategory.other : _getCategory(keyword);
      final stat = typeStats[cat]!;
      if (e.isBuy) {
        stat.buy += e.buyAmt;
        stat.net += e.netBuy;
      } else if (e.isSell) {
        stat.sell += e.sellAmt;
        stat.net += e.netBuy;
      }
      stat.count++;
    }

    final seatTypeSummary = <SeatTypeSummary>[];
    for (final cat in [SeatCategory.institution, SeatCategory.foreign, SeatCategory.hkStock, SeatCategory.retail]) {
      final stat = typeStats[cat]!;
      if (stat.count > 0) {
        seatTypeSummary.add(SeatTypeSummary(
          typeName: _getSeatTypeName(cat),
          totalBuy: stat.buy,
          totalSell: stat.sell,
          totalNet: stat.net,
        ));
      }
    }
    // 按净买排序
    seatTypeSummary.sort((a, b) => b.totalNet.compareTo(a.totalNet));

    // 新建仓检测
    final lastSeen = prevLastSeen.isNotEmpty ? prevLastSeen : {};
    final newPositions = <LhbStockRank>[];

    // 找出预置席位的买操作（isBuy=True, rank=0-4）
    final trackedBuyEntries = entries.where((e) {
      if (!e.isBuy) return false;
      if (e.rank > 4) return false; // 只看买一~买五
      final keyword = _matchSeat(e.seatName);
      return keyword.isNotEmpty;
    }).toList();

    // 按(席位, 股票)聚合，取最大净买
    final bestBySeatStock = <String, LhbSeatRawEntry>{};
    for (final e in trackedBuyEntries) {
      final keyword = _matchSeat(e.seatName);
      final key = '$keyword|${e.securityCode}';
      if (!bestBySeatStock.containsKey(key) || e.netBuy > bestBySeatStock[key]!.netBuy) {
        bestBySeatStock[key] = e;
      }
    }

    for (final e in bestBySeatStock.values) {
      if (e.netBuy <= 0) continue;
      final keyword = _matchSeat(e.seatName);
      final seatLast = lastSeen[keyword] ?? {};
      final prevDate = seatLast[e.securityCode] ?? '';
      int daysGap = 999;
      if (prevDate.isNotEmpty) {
        try {
          // prevDate 格式: 'YYYY-MM-DD'
          final parts = prevDate.split('-');
          if (parts.length >= 3) {
            final pd = DateTime(int.parse(parts[0]), int.parse(parts[1]), int.parse(parts[2]));
            final td = DateTime.parse(date);
            daysGap = td.difference(pd).inDays;
          }
        } catch (_) {}
      }
      final isNew = prevDate.isEmpty || daysGap >= 7;

      if (isNew) {
        // 获取该席位这只票的全部买入用于计算总净买
        final allBuyForStock = entries.where((x) =>
          x.securityCode == e.securityCode &&
          x.isBuy &&
          _matchSeat(x.seatName) == keyword
        ).toList();
        final totalBuy = allBuyForStock.fold(0.0, (s, x) => s + x.buyAmt);
        final totalSell = entries.where((x) =>
          x.securityCode == e.securityCode &&
          x.isSell &&
          _matchSeat(x.seatName) == keyword
        ).fold(0.0, (s, x) => s + x.sellAmt);
        final totalNet = totalBuy - totalSell;

        newPositions.add(LhbStockRank(
          code: e.securityCode,
          name: e.securityName,
          changeRate: e.changeRate,
          totalBuy: totalBuy,
          totalSell: totalSell,
          totalNet: totalNet,
          topBuySeat: keyword,
          topBuyNet: e.netBuy,
          topSellSeat: '',
          topSellNet: 0,
          isNewPosition: true,
          seat: keyword,
        ));
      }
    }

    newPositions.sort((a, b) => b.totalNet.compareTo(a.totalNet));

    return LhbSummaryModel(
      date: date,
      totalEntries: entries.length,
      totalStocks: stockCodes.length,
      upCount: upCount,
      downCount: downCount,
      topGainers: topGainers,
      topLosers: topLosers,
      seatTypeSummary: seatTypeSummary,
      newPositions: newPositions,
    );
  }
}

// 内部聚合类
class _StockAgg {
  final String code;
  final String name;
  double changeRate = 0;
  final List<LhbSeatRawEntry> buyEntries = [];
  final List<LhbSeatRawEntry> sellEntries = [];

  _StockAgg({required this.code, required this.name});
}

class _StockWithChange {
  final String code;
  final String name;
  final double changeRate;
  final double totalBuy;
  final double totalSell;
  final double totalNet;
  final String topBuySeat;
  final double topBuyNet;
  final String topSellSeat;
  final double topSellNet;

  _StockWithChange({
    required this.code,
    required this.name,
    required this.changeRate,
    required this.totalBuy,
    required this.totalSell,
    required this.totalNet,
    required this.topBuySeat,
    required this.topBuyNet,
    required this.topSellSeat,
    required this.topSellNet,
  });
}

class _TypeStat {
  double buy = 0;
  double sell = 0;
  double net = 0;
  int count = 0;
}
