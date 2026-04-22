import 'dart:math';
import 'package:flutter_stock_app/domain/entities/stock_quote.dart';

class BollCalculator {
  /// 计算布林带指标
  /// [quotes] 股票数据
  /// [period] 布林带周期，默认20
  static List<BollData> calculate(List<StockQuote> quotes, {int period = 20}) {
    if (quotes.length < period) return [];

    final result = <BollData>[];

    for (var i = period - 1; i < quotes.length; i++) {
      // 获取最近period个收盘价
      final closes = <double>[];
      for (var j = i - period + 1; j <= i; j++) {
        closes.add(quotes[j].close);
      }

      // 计算中轨（SMA）
      final middle = closes.reduce((a, b) => a + b) / period;

      // 计算标准差（使用样本标准差）
      final mean = middle;
      var variance = 0.0;
      for (final close in closes) {
        variance += pow(close - mean, 2);
      }
      variance /= (period - 1); // 样本标准差
      final stdDev = sqrt(variance);

      // 计算上下轨
      final upper = middle + 2 * stdDev;
      final lower = middle - 2 * stdDev;

      result.add(BollData(
        date: quotes[i].date,
        upper: upper,
        middle: middle,
        lower: lower,
      ));
    }

    return result;
  }
}
