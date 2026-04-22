import 'dart:math';
import 'package:flutter_stock_app/domain/entities/stock_quote.dart';

class DmiCalculator {
  /// 计算DMI指标
  /// [quotes] 股票数据
  /// [period] DMI周期，默认14
  static List<DmiData> calculate(List<StockQuote> quotes, {int period = 14}) {
    if (quotes.length < period + 1) return [];

    final result = <DmiData>[];

    double prevClose = quotes[0].close;
    double sumTr = 0;
    double sumPlusDm = 0;
    double sumMinusDm = 0;

    // 计算第一个周期的TR、+DM、-DM
    for (var i = 1; i <= period; i++) {
      final high = quotes[i].high;
      final low = quotes[i].low;
      final close = quotes[i].close;

      // True Range
      final tr1 = high - low;
      final tr2 = (high - prevClose).abs();
      final tr3 = (low - prevClose).abs();
      final tr = [tr1, tr2, tr3].reduce((a, b) => a > b ? a : b);
      sumTr += tr;

      // Directional Movement
      final plusDm = high - quotes[i - 1].high > quotes[i - 1].low - low
          ? max(high - quotes[i - 1].high, 0.0)
          : 0.0;
      final minusDm = quotes[i - 1].low - low > high - quotes[i - 1].high
          ? max(quotes[i - 1].low - low, 0.0)
          : 0.0;

      sumPlusDm += plusDm;
      sumMinusDm += minusDm;
      prevClose = close;
    }

    // 计算第一个ADX
    final plusDi = sumTr == 0 ? 0.0 : sumPlusDm / sumTr * 100;
    final minusDi = sumTr == 0 ? 0.0 : sumMinusDm / sumTr * 100;
    final dx = plusDi + minusDi == 0 ? 0.0 : (plusDi - minusDi).abs() / (plusDi + minusDi) * 100;

    result.add(DmiData(date: quotes[period].date, pdi: plusDi, mdi: minusDi, adx: dx));

    // 后续使用平滑计算
    for (var i = period + 1; i < quotes.length; i++) {
      final high = quotes[i].high;
      final low = quotes[i].low;
      final close = quotes[i].close;

      final tr1 = high - low;
      final tr2 = (high - prevClose).abs();
      final tr3 = (low - prevClose).abs();
      final tr = [tr1, tr2, tr3].reduce((a, b) => a > b ? a : b);

      final plusDm = high - quotes[i - 1].high > quotes[i - 1].low - low
          ? max(high - quotes[i - 1].high, 0.0)
          : 0.0;
      final minusDm = quotes[i - 1].low - low > high - quotes[i - 1].high
          ? max(quotes[i - 1].low - low, 0.0)
          : 0.0;

      // Wilder平滑
      sumTr = sumTr - sumTr / period + tr;
      sumPlusDm = sumPlusDm - sumPlusDm / period + plusDm;
      sumMinusDm = sumMinusDm - sumMinusDm / period + minusDm;

      final currentPlusDi = sumTr == 0 ? 0.0 : sumPlusDm / sumTr * 100;
      final currentMinusDi = sumTr == 0 ? 0.0 : sumMinusDm / sumTr * 100;
      final currentDx = currentPlusDi + currentMinusDi == 0
          ? 0.0
          : (currentPlusDi - currentMinusDi).abs() / (currentPlusDi + currentMinusDi) * 100;

      // 计算ADX（平滑后的DX）
      final prevAdx = result.last.adx;
      final currentAdx = (prevAdx * (period - 1) + currentDx) / period;

      result.add(DmiData(
        date: quotes[i].date,
        pdi: currentPlusDi,
        mdi: currentMinusDi,
        adx: currentAdx,
      ));

      prevClose = close;
    }

    return result;
  }
}
