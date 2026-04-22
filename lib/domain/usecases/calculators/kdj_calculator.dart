import 'dart:math';
import 'package:flutter_stock_app/domain/entities/stock_quote.dart';

class KdjCalculator {
  /// 计算KDJ指标
  /// [quotes] 股票数据
  /// [period] KDJ周期，默认9
  static List<KdjData> calculate(List<StockQuote> quotes, {int period = 9}) {
    if (quotes.length < period) return [];

    final result = <KdjData>[];
    double? prevK;
    double? prevD;
    double? prevJ;

    for (var i = period - 1; i < quotes.length; i++) {
      // 计算RSV
      double highestHigh = quotes[i].high;
      double lowestLow = quotes[i].low;

      for (var j = i - period + 1; j <= i; j++) {
        if (quotes[j].high > highestHigh) highestHigh = quotes[j].high;
        if (quotes[j].low < lowestLow) lowestLow = quotes[j].low;
      }

      final rsv = highestHigh == lowestLow ? 50 : (quotes[i].close - lowestLow) / (highestHigh - lowestLow) * 100;

      // 计算K、D、J值
      double k, d, j;

      if (prevK == null || prevD == null) {
        k = 50;
        d = 50;
      } else {
        k = 2 / 3 * prevK + 1 / 3 * rsv;
        d = 2 / 3 * prevD + 1 / 3 * k;
      }
      j = 3 * k - 2 * d;

      result.add(KdjData(date: quotes[i].date, k: k, d: d, j: j));

      prevK = k;
      prevD = d;
      prevJ = j;
    }

    return result;
  }
}
