import 'package:flutter_stock_app/domain/entities/stock_quote.dart';

class RsiCalculator {
  /// 计算RSI指标
  /// [quotes] 股票数据
  /// [period] RSI周期，默认14
  static List<RsiData> calculate(List<StockQuote> quotes, {int period = 14}) {
    if (quotes.length < period + 1) return [];

    final result = <RsiData>[];
    double avgGain = 0;
    double avgLoss = 0;

    // 计算第一个周期的平均涨跌幅
    for (var i = 1; i <= period; i++) {
      final change = quotes[i].close - quotes[i - 1].close;
      if (change > 0) {
        avgGain += change;
      } else {
        avgLoss += change.abs();
      }
    }
    avgGain /= period;
    avgLoss /= period;

    // 计算第一个RSI
    final firstRsi = avgLoss == 0 ? 100.0 : 100.0 - (100.0 / (1.0 + avgGain / avgLoss));
    result.add(RsiData(date: quotes[period].date, rsi: firstRsi));

    // 使用Wilder平滑法计算后续RSI
    for (var i = period + 1; i < quotes.length; i++) {
      final change = quotes[i].close - quotes[i - 1].close;
      final gain = change > 0 ? change : 0.0;
      final loss = change < 0 ? change.abs() : 0.0;

      avgGain = (avgGain * (period - 1) + gain) / period;
      avgLoss = (avgLoss * (period - 1) + loss) / period;

      final rsi = avgLoss == 0 ? 100.0 : 100.0 - (100.0 / (1.0 + avgGain / avgLoss));
      result.add(RsiData(date: quotes[i].date, rsi: rsi));
    }

    return result;
  }
}
