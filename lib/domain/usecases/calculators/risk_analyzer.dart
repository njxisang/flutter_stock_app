import 'dart:math';
import 'package:flutter_stock_app/domain/entities/stock_quote.dart';

class RiskAnalyzer {
  /// 风险分析
  static RiskReport analyze(List<StockQuote> quotes, {double riskFreeRate = 0.03}) {
    if (quotes.length < 60) {
      return _emptyReport();
    }

    final currentPrice = quotes.last.close;

    // 计算日收益率
    final returns = <double>[];
    for (var i = 1; i < quotes.length; i++) {
      returns.add((quotes[i].close - quotes[i - 1].close) / quotes[i - 1].close);
    }

    // 期望收益（年化）
    final avgReturn = returns.reduce((a, b) => a + b) / returns.length;
    final expectedReturn30d = avgReturn * 30 * 100;
    final expectedReturn60d = avgReturn * 60 * 100;

    // 夏普比率
    final variance = returns.fold(0.0, (sum, r) => sum + pow(r - avgReturn, 2)) / returns.length;
    final stdDev = sqrt(variance);
    final sharpeRatio = stdDev > 0 ? (avgReturn - riskFreeRate / 252) / stdDev * sqrt(252) : 0.0;

    // 胜率
    final winningTrades = returns.where((r) => r > 0).length;
    final winRate = winningTrades / returns.length * 100;

    // 趋势分析
    final shortTermTrend = _analyzeShortTrend(quotes);
    final mediumTermTrend = _analyzeMediumTrend(quotes);
    final longTermTrend = _analyzeLongTrend(quotes);

    // ATR和波动率
    final atr = _calculateAtr(quotes, 14);
    final volatilityPercent = stdDev * sqrt(252) * 100;

    // VaR (95%置信度)
    returns.sort();
    final varIndex = (returns.length * 0.05).floor();
    final var95 = returns.isNotEmpty && varIndex < returns.length
        ? -returns[varIndex] * currentPrice
        : 0.0;

    // 最大回撤
    final maxDrawdown = _calculateMaxDrawdown(quotes);

    // Beta
    final beta = _calculateBeta(quotes);

    // 止损位
    final aggressiveStopLoss = currentPrice - 1.5 * atr;
    final conservativeStopLoss = currentPrice - 2.5 * atr;
    final trailingStopLoss = currentPrice - 2 * atr;

    // 风险等级
    final overallRiskLevel = _calculateOverallRiskLevel(volatilityPercent, maxDrawdown, beta);
    final riskRating = _getRiskRating(overallRiskLevel);

    return RiskReport(
      expectedReturn30d: expectedReturn30d,
      expectedReturn60d: expectedReturn60d,
      sharpeRatio: sharpeRatio,
      winRate: winRate,
      shortTermTrend: shortTermTrend,
      mediumTermTrend: mediumTermTrend,
      longTermTrend: longTermTrend,
      atr: atr,
      volatilityPercent: volatilityPercent,
      var95: var95,
      maxDrawdown: maxDrawdown,
      beta: beta,
      aggressiveStopLoss: aggressiveStopLoss,
      conservativeStopLoss: conservativeStopLoss,
      trailingStopLoss: trailingStopLoss,
      overallRiskLevel: overallRiskLevel,
      riskRating: riskRating,
    );
  }

  static double _calculateAtr(List<StockQuote> quotes, int period) {
    if (quotes.length < period + 1) return 0;

    final trueRanges = <double>[];
    for (var i = 1; i < quotes.length; i++) {
      final tr1 = quotes[i].high - quotes[i].low;
      final tr2 = (quotes[i].high - quotes[i - 1].close).abs();
      final tr3 = (quotes[i].low - quotes[i - 1].close).abs();
      trueRanges.add(max(max(tr1, tr2), tr3));
    }

    if (trueRanges.length < period) return 0;

    double sum = 0;
    for (var i = 0; i < period; i++) {
      sum += trueRanges[trueRanges.length - period + i];
    }
    return sum / period;
  }

  static double _calculateMaxDrawdown(List<StockQuote> quotes) {
    double peak = quotes.first.close;
    double maxDrawdown = 0;

    for (final quote in quotes) {
      if (quote.close > peak) peak = quote.close;
      final drawdown = (peak - quote.close) / peak;
      if (drawdown > maxDrawdown) maxDrawdown = drawdown;
    }

    return maxDrawdown * 100;
  }

  static double _calculateBeta(List<StockQuote> quotes) {
    // 简化版：使用价格变化率的标准差与市场平均的比较
    if (quotes.length < 20) return 1.0;

    final returns = <double>[];
    for (var i = 1; i < quotes.length; i++) {
      returns.add((quotes[i].close - quotes[i - 1].close) / quotes[i - 1].close);
    }

    final variance = returns.fold(0.0, (sum, r) => sum + pow(r - returns.average, 2)) / returns.length;

    // 假设市场波动率为2%
    final marketVariance = 0.02 * 0.02;
    return variance > 0 ? sqrt(variance) / sqrt(marketVariance) : 1.0;
  }

  static String _analyzeShortTrend(List<StockQuote> quotes) {
    if (quotes.length < 10) return '数据不足';
    final last10 = quotes.sublist(quotes.length - 10);
    final ma5 = last10.map((q) => q.close).toList().average;
    final currentPrice = quotes.last.close;
    if (currentPrice > ma5 * 1.02) return '上升';
    if (currentPrice < ma5 * 0.98) return '下降';
    return '震荡';
  }

  static String _analyzeMediumTrend(List<StockQuote> quotes) {
    if (quotes.length < 30) return '数据不足';
    final last30 = quotes.sublist(quotes.length - 30);
    final ma10 = last30.map((q) => q.close).toList().average;
    final currentPrice = quotes.last.close;
    if (currentPrice > ma10 * 1.03) return '上升';
    if (currentPrice < ma10 * 0.97) return '下降';
    return '震荡';
  }

  static String _analyzeLongTrend(List<StockQuote> quotes) {
    if (quotes.length < 60) return '数据不足';
    final last60 = quotes.sublist(quotes.length - 60);
    final ma20 = last60.map((q) => q.close).toList().average;
    final currentPrice = quotes.last.close;
    if (currentPrice > ma20 * 1.05) return '上升';
    if (currentPrice < ma20 * 0.95) return '下降';
    return '震荡';
  }

  static int _calculateOverallRiskLevel(double volatility, double maxDrawdown, double beta) {
    int risk = 0;
    if (volatility > 30) risk += 3;
    else if (volatility > 20) risk += 2;
    else if (volatility > 10) risk += 1;

    if (maxDrawdown > 30) risk += 3;
    else if (maxDrawdown > 20) risk += 2;
    else if (maxDrawdown > 10) risk += 1;

    if (beta > 1.5) risk += 2;
    else if (beta > 1.2) risk += 1;

    return risk.clamp(0, 9);
  }

  static String _getRiskRating(int level) {
    if (level <= 2) return '低风险';
    if (level <= 4) return '中等风险';
    if (level <= 6) return '较高风险';
    return '高风险';
  }

  static RiskReport _emptyReport() {
    return RiskReport(
      expectedReturn30d: 0.0,
      expectedReturn60d: 0.0,
      sharpeRatio: 0.0,
      winRate: 0.0,
      shortTermTrend: '数据不足',
      mediumTermTrend: '数据不足',
      longTermTrend: '数据不足',
      atr: 0.0,
      volatilityPercent: 0.0,
      var95: 0.0,
      maxDrawdown: 0.0,
      beta: 1.0,
      aggressiveStopLoss: 0.0,
      conservativeStopLoss: 0.0,
      trailingStopLoss: 0.0,
      overallRiskLevel: 0,
      riskRating: '未知',
    );
  }
}

extension DoubleListExtension on List<double> {
  double get average => isEmpty ? 0 : reduce((a, b) => a + b) / length;
}
