import 'package:flutter_stock_app/domain/entities/stock_quote.dart';

class WrCalculator {
  /// 计算威廉指标
  /// [quotes] 股票数据
  /// FIXED: 修正了WR6和WR10的lookback周期计算
  static List<WrData> calculate(List<StockQuote> quotes) {
    if (quotes.length < 10) return [];

    final result = <WrData>[];

    for (var i = 9; i < quotes.length; i++) {
      // WR6: 使用6周期lookback (i-5 到 i, 共6个数据点)
      double highestHigh6 = quotes[i].high;
      double lowestLow6 = quotes[i].low;
      for (var j = i - 5; j <= i; j++) {
        if (quotes[j].high > highestHigh6) highestHigh6 = quotes[j].high;
        if (quotes[j].low < lowestLow6) lowestLow6 = quotes[j].low;
      }

      // WR10: 使用10周期lookback (i-9 到 i, 共10个数据点)
      double highestHigh10 = quotes[i].high;
      double lowestLow10 = quotes[i].low;
      for (var j = i - 9; j <= i; j++) {
        if (quotes[j].high > highestHigh10) highestHigh10 = quotes[j].high;
        if (quotes[j].low < lowestLow10) lowestLow10 = quotes[j].low;
      }

      final close = quotes[i].close;

      // WR = (Hn - C) / (Hn - Ln) * 100
      final wr6 = highestHigh6 == lowestLow6 ? 50.0 : (highestHigh6 - close) / (highestHigh6 - lowestLow6) * 100;
      final wr10 = highestHigh10 == lowestLow10 ? 50.0 : (highestHigh10 - close) / (highestHigh10 - lowestLow10) * 100;

      result.add(WrData(date: quotes[i].date, wr6: wr6, wr10: wr10));
    }

    return result;
  }
}
