import 'dart:math';
import 'package:flutter_stock_app/domain/entities/stock_quote.dart';

class AtrCalculator {
  /// 计算 ATR (Average True Range)
  static List<AtrData> calculate(List<StockQuote> quotes, {int period = 14}) {
    if (quotes.length < period + 1) return [];

    final result = <AtrData>[];

    for (var i = period - 1; i < quotes.length; i++) {
      double trSum = 0;
      for (var j = i - period + 1; j <= i; j++) {
        trSum += _trueRange(quotes, j);
      }
      final atr = trSum / period;
      result.add(AtrData(quotes[i].date, atr, atr));
    }

    return result;
  }

  /// 单日 True Range
  static double _trueRange(List<StockQuote> quotes, int index) {
    if (index == 0) {
      return quotes[index].high - quotes[index].low;
    }

    final high = quotes[index].high;
    final low = quotes[index].low;
    final prevClose = quotes[index - 1].close;

    final tr1 = high - low;
    final tr2 = (high - prevClose).abs();
    final tr3 = (low - prevClose).abs();

    return max(tr1, max(tr2, tr3));
  }

  /// 获取当前 ATR 值
  static double getCurrentAtr(List<StockQuote> quotes, {int period = 14}) {
    if (quotes.length < period + 1) return 0.0;
    final data = calculate(quotes, period: period);
    return data.isEmpty ? 0.0 : data.last.atr;
  }

  /// 计算支撑位和阻力位
  static SupportResistance calculateSupportResistance(List<StockQuote> quotes) {
    if (quotes.length < 20) {
      return SupportResistance(
        supportLevel: 0,
        resistanceLevel: 0,
        breakOutUp: 0,
        breakOutDown: 0,
        allSupportLevels: [],
        allResistanceLevels: [],
      );
    }

    final recent = quotes.length > 60 ? quotes.sublist(quotes.length - 60) : quotes;
    final closes = recent.map((q) => q.close).toList();
    final highs = recent.map((q) => q.high).toList();
    final lows = recent.map((q) => q.low).toList();

    // 局部最低点作为支撑位
    final supportLevels = <double>[];
    for (var i = 2; i < recent.length - 2; i++) {
      if (recent[i].low < recent[i - 1].low &&
          recent[i].low < recent[i - 2].low &&
          recent[i].low < recent[i + 1].low &&
          recent[i].low < recent[i + 2].low) {
        supportLevels.add(recent[i].low);
      }
    }

    // 局部最高点作为阻力位
    final resistanceLevels = <double>[];
    for (var i = 2; i < recent.length - 2; i++) {
      if (recent[i].high > recent[i - 1].high &&
          recent[i].high > recent[i - 2].high &&
          recent[i].high > recent[i + 1].high &&
          recent[i].high > recent[i + 2].high) {
        resistanceLevels.add(recent[i].high);
      }
    }

    final clusteredSupports = _clusterLevels(supportLevels);
    final clusteredResistance = _clusterLevels(resistanceLevels);

    final currentPrice = closes.last;
    final nearestSupport = clusteredSupports.where((s) => s < currentPrice).fold<double>(
        0.0, (prev, s) => s > prev ? s : prev);
    final nearestResistance = clusteredResistance.where((r) => r > currentPrice).fold<double>(
        currentPrice * 1.05, (prev, r) => r < prev ? r : prev);

    final range = nearestResistance - nearestSupport;
    return SupportResistance(
      supportLevel: nearestSupport > 0 ? nearestSupport : currentPrice * 0.95,
      resistanceLevel: nearestResistance,
      breakOutUp: nearestResistance + range * 0.382,
      breakOutDown: nearestSupport - range * 0.382,
      allSupportLevels: clusteredSupports,
      allResistanceLevels: clusteredResistance,
    );
  }

  /// 聚类相近的价格水平
  static List<double> _clusterLevels(List<double> levels, {double threshold = 0.02}) {
    if (levels.isEmpty) return [];
    final sorted = levels.sorted();
    final clustered = <double>[];
    var currentCluster = <double>[sorted.first];

    for (var i = 1; i < sorted.length; i++) {
      final avg = currentCluster.reduce((a, b) => a + b) / currentCluster.length;
      final diff = (sorted[i] - avg).abs() / avg;
      if (diff < threshold) {
        currentCluster.add(sorted[i]);
      } else {
        clustered.add(currentCluster.reduce((a, b) => a + b) / currentCluster.length);
        currentCluster = [sorted[i]];
      }
    }
    clustered.add(currentCluster.reduce((a, b) => a + b) / currentCluster.length);

    return clustered;
  }
}

class AtrData {
  final String date;
  final double atr;
  final double atr14;

  const AtrData(this.date, this.atr, this.atr14);
}

class SupportResistance {
  final double supportLevel;
  final double resistanceLevel;
  final double breakOutUp;
  final double breakOutDown;
  final List<double> allSupportLevels;
  final List<double> allResistanceLevels;

  const SupportResistance({
    required this.supportLevel,
    required this.resistanceLevel,
    required this.breakOutUp,
    required this.breakOutDown,
    required this.allSupportLevels,
    required this.allResistanceLevels,
  });
}

extension _SortedList on List<double> {
  List<double> sorted() {
    final copy = toList();
    copy.sort();
    return copy;
  }
}
