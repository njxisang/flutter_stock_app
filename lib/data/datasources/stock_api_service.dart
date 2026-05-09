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

class StockApiService {
  final http.Client _client;
  final Map<String, _CacheEntry> _cache = {};

  StockApiService({http.Client? client}) : _client = client ?? http.Client();

  String _cacheKey(String url) => md5.convert(utf8.encode(url)).toString();

  _CacheEntry? _getCachedResponse(String url) {
    final key = _cacheKey(url);
    final entry = _cache[key];
    if (entry != null && !entry.isExpired) {
      print('[Cache HIT] URL: $url (API: ${entry.apiSource})');
      return entry;
    }
    print('[Cache MISS] URL: $url');
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
    print('[Cache STORED] URL: $url (API: $apiSource)');
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

  Future<StockData> getStockData(String symbol, {String startDate = '', String endDate = ''}) async {
    final market = detectMarket(symbol);
    if (market == Market.us) {
      return _getUSStockData(symbol, startDate, endDate);
    }
    return _getCNStockData(symbol, market, startDate, endDate);
  }

  Future<StockData> _getCNStockData(String symbol, Market market, String startDate, String endDate) async {
    final normalized = normalizeSymbol(symbol);
    final stockCode = normalized.contains('.') ? normalized.split('.')[1] : normalized;
    final stockName = await _getStockName(stockCode, market);

    final beginDate = startDate.isNotEmpty ? startDate.replaceAll('-', '') : '20240101';
    final endDateStr = endDate.isNotEmpty ? endDate.replaceAll('-', '') : '20251231';

    final secid = switch (market) {
      Market.sh => '1.$stockCode',
      Market.sz => '0.$stockCode',
      Market.bj => '0.$stockCode',
      Market.us => '1.$stockCode',
    };

    final url = 'https://push2his.eastmoney.com/api/qt/stock/kline/get?secid=$secid&fields1=f1,f2,f3,f4,f5,f6&fields2=f51,f52,f53,f54,f55,f56,f57,f58,f59,f60,f61&klt=101&fqt=1&beg=$beginDate&end=$endDateStr&lmt=500';

    // Check cache first
    final cached = _getCachedResponse(url);
    if (cached != null) {
      return _parseCNStockResponse(cached.body, normalized, stockName);
    }

    try {
      print('[API CALL] EastMoney Primary API: $url');
      final response = await _client.get(
        Uri.parse(url),
        headers: {
          'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
          'Referer': 'https://quote.eastmoney.com/',
        },
      );

      if (response.statusCode == 200) {
        _cacheResponse(url, response.body, response.headers, 'EastMoney Primary');
        final json = jsonDecode(response.body);
        final data = json['data'] as Map<String, dynamic>?;
        final klines = data?['klines'] as List<dynamic>?;

        if (klines != null && klines.isNotEmpty) {
          final quotes = <StockQuote>[];
          for (final item in klines) {
            final parts = item.toString().split(',');
            if (parts.length >= 6) {
              quotes.add(StockQuote(
                date: parts[0],
                open: double.tryParse(parts[1]) ?? 0.0,
                high: double.tryParse(parts[3]) ?? 0.0,
                low: double.tryParse(parts[4]) ?? 0.0,
                close: double.tryParse(parts[2]) ?? 0.0,
                volume: int.tryParse(parts[5]) ?? 0,
              ));
            }
          }
          if (quotes.isNotEmpty) {
            return StockData(symbol: normalized, name: stockName, quotes: quotes);
          }
        }
      }
    } catch (e) {
      print('[API DEGRADATION] EastMoney Primary API failed: $e');
      // Fall through to backup APIs
    }

    // Try Tencent backup API
    return _getTencentBackupData(symbol, market, stockName, startDate, endDate);
  }

  Future<StockData> _parseCNStockResponse(String body, String normalized, String stockName) async {
    final json = jsonDecode(body);
    final data = json['data'] as Map<String, dynamic>?;
    final klines = data?['klines'] as List<dynamic>?;

    if (klines != null && klines.isNotEmpty) {
      final quotes = <StockQuote>[];
      for (final item in klines) {
        final parts = item.toString().split(',');
        if (parts.length >= 6) {
          quotes.add(StockQuote(
            date: parts[0],
            open: double.tryParse(parts[1]) ?? 0.0,
            high: double.tryParse(parts[3]) ?? 0.0,
            low: double.tryParse(parts[4]) ?? 0.0,
            close: double.tryParse(parts[2]) ?? 0.0,
            volume: int.tryParse(parts[5]) ?? 0,
          ));
        }
      }
      if (quotes.isNotEmpty) {
        return StockData(symbol: normalized, name: stockName, quotes: quotes);
      }
    }
    throw Exception('无法解析股票数据');
  }

  Future<StockData> _getTencentBackupData(String symbol, Market market, String stockName, String startDate, String endDate) async {
    final normalized = normalizeSymbol(symbol);
    final marketCode = switch (market) { Market.sh => 'sh', Market.sz => 'sz', Market.bj => 'bj', Market.us => 'sh' };
    final stockCode = normalized.contains('.') ? normalized.split('.')[1] : normalized;

    final url = 'https://web.ifzq.gtimg.cn/appstock/app/fqkline/get?var=&param=${marketCode}$stockCode,day,,,320,qfq';

    // Check cache first
    final cached = _getCachedResponse(url);
    if (cached != null) {
      return _parseTencentBackupResponse(cached.body, normalized, stockName);
    }

    try {
      print('[API CALL] Tencent Backup API: $url');
      final response = await _client.get(
        Uri.parse(url),
        headers: {'User-Agent': 'Mozilla/5.0'},
      );

      if (response.statusCode == 200) {
        _cacheResponse(url, response.body, response.headers, 'Tencent Backup');
        return _parseTencentBackupResponse(response.body, normalized, stockName);
      }
    } catch (e) {
      print('[API DEGRADATION] Tencent Backup API failed: $e');
    }

    throw Exception('无法获取股票数据');
  }

  num _toNum(dynamic value) {
    if (value is num) return value;
    if (value is String) return double.tryParse(value) ?? 0;
    return 0;
  }

  Future<StockData> _parseTencentBackupResponse(String body, String normalized, String stockName) async {
    final json = jsonDecode(body);

    // The API returns data under key like "sh600399", not "sh.600399"
    final marketCode = normalized.contains('.')
        ? normalized.split('.')[0]  // "sh" from "sh.600399"
        : (normalizeSymbol(normalized).contains('.')
            ? normalizeSymbol(normalized).split('.')[0]
            : 'sh');
    final stockCode = normalized.contains('.') ? normalized.split('.')[1] : normalized;
    final apiKey = marketCode + stockCode;  // e.g., "sh600399"

    // Try the correct key format first, then fallback to other methods
    final data = json['data']?[apiKey]
                ?? json['data']?[normalized.toLowerCase()]
                ?? json['data']?[normalized]
                ?? json['data'];
    if (data == null) throw Exception('无法解析备份API数据');

    List<dynamic>? qfqday = data is List ? data as List<dynamic> : null;
    if (qfqday == null) {
      final dataMap = data as Map<String, dynamic>?;
      qfqday = dataMap?['qfqday'] as List<dynamic>?;
      qfqday ??= dataMap?['day'] as List<dynamic>?;
      qfqday ??= dataMap?.values.firstOrNull as List<dynamic>?;
    }

    if (qfqday == null || qfqday.isEmpty) throw Exception('无法解析备份API数据');

    final quotes = <StockQuote>[];
    for (final item in qfqday) {
      if (item is List && item.length >= 6) {
        quotes.add(StockQuote(
          date: item[0].toString(),
          open: _toNum(item[1]).toDouble(),
          high: _toNum(item[2]).toDouble(),
          low: _toNum(item[3]).toDouble(),
          close: _toNum(item[4]).toDouble(),
          volume: _toNum(item[5]).toInt(),
        ));
      }
    }
    if (quotes.isNotEmpty) {
      return StockData(symbol: normalized, name: stockName, quotes: quotes);
    }
    throw Exception('无法解析备份API数据');
  }

  Future<String> _getStockName(String stockCode, Market market) async {
    final types = ['14', '5', '16', '28', '7'];

    for (final type in types) {
      try {
        final url = 'https://searchapi.eastmoney.com/api/suggest/get?input=$stockCode&type=$type&count=1';
        
        // Check cache first
        final cached = _getCachedResponse(url);
        if (cached != null) {
          final json = jsonDecode(cached.body);
          final QuotationCode = json['QuotationCode'] as List<dynamic>?;
          if (QuotationCode != null && QuotationCode.isNotEmpty) {
            final name = QuotationCode[0]['Name'] as String?;
            if (name != null && name.isNotEmpty) {
              return name;
            }
          }
          continue;
        }

        final response = await _client.get(
          Uri.parse(url),
          headers: {
            'User-Agent': 'Mozilla/5.0',
            'Referer': 'https://quote.eastmoney.com/',
          },
        );

        if (response.statusCode == 200) {
          _cacheResponse(url, response.body, response.headers, 'EastMoney StockName');
          final json = jsonDecode(response.body);
          final QuotationCode = json['QuotationCode'] as List<dynamic>?;
          if (QuotationCode != null && QuotationCode.isNotEmpty) {
            final name = QuotationCode[0]['Name'] as String?;
            if (name != null && name.isNotEmpty) {
              return name;
            }
          }
        }
      } catch (e) {
        continue;
      }
    }

    // Default names based on code prefix
    if (stockCode.startsWith('1') || stockCode.startsWith('5')) return 'ETF $stockCode';
    if (stockCode.startsWith('6')) return '上海股票 $stockCode';
    if (stockCode.startsWith('0') || stockCode.startsWith('3')) return '深圳股票 $stockCode';
    if (stockCode.startsWith('8') || stockCode.startsWith('4')) return '北交所股票 $stockCode';
    return '股票 $stockCode';
  }

  Future<StockData> _getUSStockData(String symbol, String startDate, String endDate) async {
    final url = 'https://query1.finance.yahoo.com/v8/finance/chart/$symbol?interval=1d&range=6mo';

    // Check cache first
    final cached = _getCachedResponse(url);
    if (cached != null) {
      return _parseUSStockResponse(cached.body, symbol);
    }

    try {
      print('[API CALL] Yahoo Finance API: $url');
      final response = await _client.get(
        Uri.parse(url),
        headers: {'User-Agent': 'Mozilla/5.0'},
      );

      if (response.statusCode == 200) {
        _cacheResponse(url, response.body, response.headers, 'Yahoo Finance');
        final json = jsonDecode(response.body);
        final chart = json['chart'] as Map<String, dynamic>?;
        final result = (chart?['result'] as List<dynamic>?)?.firstOrNull as Map<String, dynamic>?;
        final meta = result?['meta'] as Map<String, dynamic>?;
        final symbolName = meta?['shortName'] ?? symbol;

        final indicators = result?['indicators'] as Map<String, dynamic>?;
        final quote = (indicators?['quote'] as List<dynamic>?)?.firstOrNull as Map<String, dynamic>?;
        final closeArr = quote?['close'] as List<dynamic>?;
        final openArr = quote?['open'] as List<dynamic>?;
        final highArr = quote?['high'] as List<dynamic>?;
        final lowArr = quote?['low'] as List<dynamic>?;
        final volumeArr = quote?['volume'] as List<dynamic>?;
        final timestamps = result?['timestamp'] as List<dynamic>?;

        if (timestamps != null && closeArr != null) {
          final quotes = <StockQuote>[];
          for (var i = 0; i < timestamps.length; i++) {
            final ts = timestamps[i] as int;
            final date = DateTime.fromMillisecondsSinceEpoch(ts * 1000);
            final dateStr = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
            final closeVal = (closeArr[i] as num?)?.toDouble() ?? 0.0;
            if (closeVal > 0) {
              quotes.add(StockQuote(
                date: dateStr,
                open: (openArr?[i] as num?)?.toDouble() ?? closeVal,
                high: (highArr?[i] as num?)?.toDouble() ?? closeVal,
                low: (lowArr?[i] as num?)?.toDouble() ?? closeVal,
                close: closeVal,
                volume: (volumeArr?[i] as num?)?.toInt() ?? 0,
              ));
            }
          }
          if (quotes.isNotEmpty) {
            return StockData(symbol: symbol, name: symbolName.toString(), quotes: quotes);
          }
        }
      }
    } catch (e) {
      print('[API DEGRADATION] Yahoo Finance API failed: $e');
      throw Exception('无法获取美股数据: $e');
    }

    throw Exception('无法获取股票数据');
  }

  Future<StockData> _parseUSStockResponse(String body, String symbol) async {
    final json = jsonDecode(body);
    final chart = json['chart'] as Map<String, dynamic>?;
    final result = (chart?['result'] as List<dynamic>?)?.firstOrNull as Map<String, dynamic>?;
    final meta = result?['meta'] as Map<String, dynamic>?;
    final symbolName = meta?['shortName'] ?? symbol;

    final indicators = result?['indicators'] as Map<String, dynamic>?;
    final quote = (indicators?['quote'] as List<dynamic>?)?.firstOrNull as Map<String, dynamic>?;
    final closeArr = quote?['close'] as List<dynamic>?;
    final openArr = quote?['open'] as List<dynamic>?;
    final highArr = quote?['high'] as List<dynamic>?;
    final lowArr = quote?['low'] as List<dynamic>?;
    final volumeArr = quote?['volume'] as List<dynamic>?;
    final timestamps = result?['timestamp'] as List<dynamic>?;

    if (timestamps != null && closeArr != null) {
      final quotes = <StockQuote>[];
      for (var i = 0; i < timestamps.length; i++) {
        final ts = timestamps[i] as int;
        final date = DateTime.fromMillisecondsSinceEpoch(ts * 1000);
        final dateStr = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
        final closeVal = (closeArr[i] as num?)?.toDouble() ?? 0.0;
        if (closeVal > 0) {
          quotes.add(StockQuote(
            date: dateStr,
            open: (openArr?[i] as num?)?.toDouble() ?? closeVal,
            high: (highArr?[i] as num?)?.toDouble() ?? closeVal,
            low: (lowArr?[i] as num?)?.toDouble() ?? closeVal,
            close: closeVal,
            volume: (volumeArr?[i] as num?)?.toInt() ?? 0,
          ));
        }
      }
      if (quotes.isNotEmpty) {
        return StockData(symbol: symbol, name: symbolName.toString(), quotes: quotes);
      }
    }
    throw Exception('无法解析美股数据');
  }
}
