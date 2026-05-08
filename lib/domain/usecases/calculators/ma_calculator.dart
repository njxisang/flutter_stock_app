import 'package:flutter_stock_app/domain/entities/stock_quote.dart';

class MaCalculator {
  /// 计算均线数据 — O(n) 滑动窗口版
  /// [quotes] 股票数据
  static List<MaData> calculate(List<StockQuote> quotes) {
    if (quotes.length < 60) return [];

    // 预计算前60项的初始和
    double sum5 = 0, sum10 = 0, sum20 = 0, sum60 = 0;
    for (var j = 0; j < 60; j++) {
      final c = quotes[j].close;
      if (j < 5)   sum5  += c;
      if (j < 10)  sum10 += c;
      if (j < 20)  sum20 += c;
      sum60 += c;
    }

    final result = <MaData>[];

    for (var i = 59; i < quotes.length; i++) {
      if (i > 59) {
        // 滑动窗口：移除出口元素，加入入口元素
        sum5  += quotes[i].close - quotes[i - 5].close;
        sum10 += quotes[i].close - quotes[i - 10].close;
        sum20 += quotes[i].close - quotes[i - 20].close;
        sum60 += quotes[i].close - quotes[i - 60].close;
      }

      result.add(MaData(
        date: quotes[i].date,
        ma5: sum5 / 5,
        ma10: sum10 / 10,
        ma20: sum20 / 20,
        ma60: sum60 / 60,
      ));
    }

    return result;
  }
}
