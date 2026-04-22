import 'package:flutter_stock_app/domain/entities/stock_quote.dart';

class MaCalculator {
  /// 计算均线数据
  /// [quotes] 股票数据
  static List<MaData> calculate(List<StockQuote> quotes) {
    if (quotes.length < 60) return [];

    final result = <MaData>[];

    for (var i = 59; i < quotes.length; i++) {
      double sum5 = 0, sum10 = 0, sum20 = 0, sum60 = 0;

      for (var j = 0; j < 5; j++) {
        sum5 += quotes[i - j].close;
      }
      for (var j = 0; j < 10; j++) {
        sum10 += quotes[i - j].close;
      }
      for (var j = 0; j < 20; j++) {
        sum20 += quotes[i - j].close;
      }
      for (var j = 0; j < 60; j++) {
        sum60 += quotes[i - j].close;
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
