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
    final url = 'https://datacenter-web.eastmoney.com/api/data/v1/get?reportName=RPT_DRAGON_LIST_DAILY&columns=ALL&pageNumber=1&pageSize=50&sortTypes=-1&sortColumns=TRADE_DATE&filter=(TRADE_DATE%3D%27$targetDate%27)';

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

    final url = 'https://datacenter-web.eastmoney.com/api/data/v1/get?reportName=RPT_STOCK_SEAT_DAILY&columns=ALL&pageNumber=1&pageSize=20&sortTypes=-1&sortColumns=NET_AMT&filter=(TRADE_DATE%3D%27$targetDate%27)(SECUCODE%3D%27$stockCode.SH%27)';

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
      print('[API DEGRADATION] LHB Seat EastMoney API failed: $e');
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

  // ============ 辅助方法 ============

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
