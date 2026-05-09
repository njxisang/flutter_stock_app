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

/// 资金流向API服务
/// 专注于资金流向数据获取：个股资金流向和实时大单数据
class FundFlowApiService {
  final http.Client _client;
  final Map<String, _CacheEntry> _cache = {};

  FundFlowApiService({http.Client? client}) : _client = client ?? http.Client();

  String _cacheKey(String url) => md5.convert(utf8.encode(url)).toString();

  _CacheEntry? _getCachedResponse(String url) {
    final key = _cacheKey(url);
    final entry = _cache[key];
    if (entry != null && !entry.isExpired) {
      print('[FundFlow Cache HIT] URL: $url (API: ${entry.apiSource})');
      return entry;
    }
    print('[FundFlow Cache MISS] URL: $url');
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
    print('[FundFlow Cache STORED] URL: $url (API: $apiSource)');
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

  /// 获取个股名称（内部使用）
  Future<String> _getStockName(String stockCode, Market market) async {
    final types = ['14', '5', '16', '28', '7'];

    for (final type in types) {
      try {
        final url = 'https://searchapi.eastmoney.com/api/suggest/get?input=$stockCode&type=$type&count=1';

        // Check cache first
        final cached = _getCachedResponse(url);
        if (cached != null) {
          final json = jsonDecode(cached.body);
          final table = json['QuotationCodeTable'] as Map<String, dynamic>?;
          final data = table?['Data'] as List<dynamic>?;
          if (data != null && data.isNotEmpty) {
            final name = data[0]['Name'] as String?;
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
          final table = json['QuotationCodeTable'] as Map<String, dynamic>?;
          final data = table?['Data'] as List<dynamic>?;
          if (data != null && data.isNotEmpty) {
            final name = data[0]['Name'] as String?;
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

  /// 获取个股资金流向（东方财富）
  Future<MoneyFlowData> getStockFundFlow(String symbol) async {
    final normalized = normalizeSymbol(symbol);
    final stockCode = normalized.contains('.') ? normalized.split('.')[1] : normalized;
    final market = detectMarket(symbol);
    final secid = market == Market.sh ? '1.$stockCode' : '0.$stockCode';

    final url = 'https://push2.eastmoney.com/api/qt/stock/fflow/daykline/get?lmt=60&klt=101&secid=$secid&fields1=f1,f2,f3,f7&fields2=f51,f52,f53,f54,f55,f56,f57,f58,f59,f60,f61,f62,f63';

    try {
      final response = await _client.get(
        Uri.parse(url),
        headers: {
          'User-Agent': 'Mozilla/5.0',
          'Referer': 'https://quote.eastmoney.com/',
        },
      );

      if (response.statusCode == 200) {
        _cacheResponse(url, response.body, response.headers, 'EastMoney FundFlow');
        final json = jsonDecode(response.body);
        final data = json['data'] as Map<String, dynamic>?;
        final klines = data?['klines'] as List<dynamic>?;

        if (klines != null && klines.isNotEmpty) {
          final flows = <CapitalFlow>[];
          for (final item in klines) {
            final parts = item.toString().split(',');
            if (parts.length >= 4) {
              flows.add(CapitalFlow(
                date: parts[0],
                bigDealIn: double.tryParse(parts[1]) ?? 0,
                bigDealOut: double.tryParse(parts[2]) ?? 0,
                netInflow: double.tryParse(parts[3]) ?? 0,
                turnoverRate: parts.length > 4 ? (double.tryParse(parts[4]) ?? 0) : 0,
              ));
            }
          }
          if (flows.isNotEmpty) {
            final name = await _getStockName(stockCode, market);
            return MoneyFlowData(symbol: normalized, name: name, flows: flows);
          }
        }
      }
    } catch (e) {
      // fall through
    }
    return MoneyFlowData(symbol: symbol, name: '', flows: []);
  }

  /// 资金流向实时大单数据
  Future<Map<String, double>> getFundFlowRealtime(String symbol) async {
    final normalized = normalizeSymbol(symbol);
    final stockCode = normalized.contains('.') ? normalized.split('.')[1] : normalized;
    final market = detectMarket(symbol);
    final secid = market == Market.sh ? '1.$stockCode' : '0.$stockCode';

    final url = 'https://push2.eastmoney.com/api/qt/stock/fflow/get?secid=$secid&fields1=f1,f2,f3,f7&fields2=f51,f52,f53,f54,f55,f56,f57,f58';

    try {
      final response = await _client.get(
        Uri.parse(url),
        headers: {
          'User-Agent': 'Mozilla/5.0',
          'Referer': 'https://quote.eastmoney.com/',
        },
      );

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        final data = json['data'] as Map<String, dynamic>?;
        return {
          'close': (data?['f3'] ?? 0).toDouble(),
          'priceChange': (data?['f4'] ?? 0).toDouble(),
          'netInflowMain': (data?['f62'] ?? 0).toDouble(),
          'netInflowSmall': (data?['f66'] ?? 0).toDouble(),
          'netInflowMid': (data?['f69'] ?? 0).toDouble(),
          'turnoverRate': (data?['f168'] ?? 0).toDouble(),
        };
      }
    } catch (e) {
      // fall through
    }
    return {};
  }
}
