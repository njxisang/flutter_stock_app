import 'dart:math';
import 'package:flutter_stock_app/domain/entities/stock_quote.dart';

class MacdCalculator {
  /// 计算MACD指标
  /// [quotes] 股票数据
  /// [shortPeriod] 短期EMA周期，默认12
  /// [longPeriod] 长期EMA周期，默认26
  /// [signalPeriod] 信号线周期，默认9
  static List<MacdData> calculate(
    List<StockQuote> quotes, {
    int shortPeriod = 12,
    int longPeriod = 26,
    int signalPeriod = 9,
  }) {
    if (quotes.length < longPeriod) return [];

    final closes = quotes.map((q) => q.close).toList();

    // 计算EMA
    final ema12 = _calculateEma(closes, shortPeriod);
    final ema26 = _calculateEma(closes, longPeriod);

    if (ema12.isEmpty || ema26.isEmpty) return [];

    // FIXED: 正确的索引对齐 - EMA从period-1位置开始
    final result = <MacdData>[];
    final startIndex = longPeriod - 1;

    for (var i = startIndex; i < quotes.length; i++) {
      final emaIndex = i - startIndex;
      if (emaIndex < ema12.length && emaIndex < ema26.length) {
        final dif = ema12[emaIndex] - ema26[emaIndex];
        result.add(MacdData(date: quotes[i].date, dif: dif, dea: 0, macd: 0));
      }
    }

    // 计算DEA (信号线)
    if (result.length < signalPeriod) return result;

    final difs = result.map((r) => r.dif).toList();
    final deaValues = _calculateEma(difs, signalPeriod);

    for (var i = 0; i < deaValues.length && i < result.length; i++) {
      final dif = result[i].dif;
      final dea = deaValues[i];
      final macd = (dif - dea) * 2;
      result[i] = MacdData(date: result[i].date, dif: dif, dea: dea, macd: macd);
    }

    return result;
  }

  static List<double> _calculateEma(List<double> values, int period) {
    if (values.length < period) return [];

    final multiplier = 2.0 / (period + 1);
    final ema = <double>[];

    // 第一个EMA值是SMA
    var sum = 0.0;
    for (var i = 0; i < period; i++) {
      sum += values[i];
    }
    var prevEma = sum / period;
    ema.add(prevEma);

    // 后续使用EMA公式
    for (var i = period; i < values.length; i++) {
      final currentEma = (values[i] - prevEma) * multiplier + prevEma;
      ema.add(currentEma);
      prevEma = currentEma;
    }

    return ema;
  }

  /// 检测MACD信号（金叉/死叉）
  static MacdSignalResult? detectSignal(List<MacdData> macdData) {
    if (macdData.length < 2) return null;

    // 找到最近的金叉/死叉
    for (var i = macdData.length - 1; i >= 0; i--) {
      if (i < 1) break;

      final current = macdData[i];
      final prev = macdData[i - 1];

      // 金叉：DIF从下往上穿过DEA
      if (prev.dif <= prev.dea && current.dif > current.dea) {
        return MacdSignalResult(signal: MacdSignal.goldenCross, date: current.date);
      }

      // 死叉：DIF从上往下穿过DEA
      if (prev.dif >= prev.dea && current.dif < current.dea) {
        return MacdSignalResult(signal: MacdSignal.deathCross, date: current.date);
      }
    }

    return null;
  }
}
