import 'dart:math';
import 'package:flutter_stock_app/domain/entities/stock_quote.dart';
import 'package:flutter_stock_app/domain/usecases/calculators/atr_calculator.dart';

class ERatioCalculator {
  /// 计算 E-Ratio (Edge Ratio)
  /// lookbackPeriod: 持仓观察期（默认20天）
  static ERatioResult? calculate(List<StockQuote> quotes, {int lookbackPeriod = 20}) {
    if (quotes.length < 50) return null;

    final sortedQuotes = quotes.sorted((a, b) => a.date.compareTo(b.date));

    // 计算 ATR
    final atrData = AtrCalculator.calculate(sortedQuotes, period: 14);
    if (atrData.isEmpty) return null;
    final atr = atrData.last.atr;

    // 生成交易信号（20日高低点突破）
    final signals = _generateSignals(sortedQuotes);
    if (signals.isEmpty) return null;

    final tradeDetails = <TradeDetail>[];
    var wins = 0;
    var totalProfit = 0.0;
    var totalLoss = 0.0;

    for (var idx = 0; idx < signals.length; idx++) {
      final signal = signals[idx];
      final entryPrice = signal.entryPrice;
      final direction = signal.direction;
      final entryIndex = signal.entryIndex;
      final entryDate = sortedQuotes[entryIndex].date;

      double mfe = 0.0;
      double mae = 0.0;
      var exitPrice = entryPrice;
      var exitIndex = entryIndex;

      for (var i = entryIndex; i < sortedQuotes.length; i++) {
        final price = sortedQuotes[i].close;
        final pnl = (price - entryPrice) * direction;

        if (pnl > mfe) mfe = pnl;
        if (pnl < mae) {
          mae = pnl.abs();
          exitPrice = price;
          exitIndex = i;
        }

        // 持有 lookbackPeriod 天后强制平仓
        if (i - entryIndex >= lookbackPeriod) {
          exitPrice = sortedQuotes[i].close;
          exitIndex = i;
          break;
        }
      }

      // ATR 标准化
      final entryAtr = atrData.length > entryIndex ? atrData[entryIndex].atr : atr;
      final normalizedMfe = entryAtr > 0 ? mfe / entryAtr : 0.0;
      final normalizedMae = entryAtr > 0 ? mae / entryAtr : 0.0;

      final isWin = mfe > mae;
      if (isWin) {
        wins++;
        totalProfit += mfe;
      } else {
        totalLoss += mae;
      }

      tradeDetails.add(TradeDetail(
        tradeNumber: idx + 1,
        date: entryDate,
        direction: direction == 1 ? '做多' : '做空',
        entryPrice: entryPrice,
        exitPrice: exitPrice,
        mfe: mfe,
        mae: mae,
        normalizedMfe: normalizedMfe,
        normalizedMae: normalizedMae,
        result: isWin ? '盈利' : '亏损',
      ));
    }

    if (tradeDetails.isEmpty) return null;

    final avgMfe = tradeDetails.map((t) => t.normalizedMfe).reduce((a, b) => a + b) / tradeDetails.length;
    final avgMae = tradeDetails.map((t) => t.normalizedMae).reduce((a, b) => a + b) / tradeDetails.length;
    final eRatio = avgMae > 0 ? avgMfe / avgMae : 0.0;
    final winRate = wins / tradeDetails.length;
    final profitFactor = totalLoss > 0
        ? totalProfit / totalLoss
        : (totalProfit > 0 ? 999.0 : 0.0);

    return ERatioResult(
      eRatio: eRatio,
      mfeMean: avgMfe,
      maeMean: avgMae,
      atr: atr,
      tradeCount: tradeDetails.length,
      winRate: winRate,
      profitFactor: profitFactor,
      trades: tradeDetails,
      analysis: _buildAnalysis(eRatio, atr, tradeDetails.length, winRate, profitFactor, avgMfe, avgMae, tradeDetails),
      calculationPrinciple: _calculationPrinciple,
    );
  }

  static List<_Signal> _generateSignals(List<StockQuote> quotes) {
    final signals = <_Signal>[];

    for (var i = 20; i < quotes.length - 20; i++) {
      final recent20 = quotes.sublist(i - 20, i);
      final high20 = recent20.map((q) => q.high).reduce(max);
      final low20 = recent20.map((q) => q.low).reduce(min);
      final currentPrice = quotes[i].close;

      if (currentPrice > high20) {
        signals.add(_Signal(currentPrice, 1, i));
      } else if (currentPrice < low20) {
        signals.add(_Signal(currentPrice, -1, i));
      }
    }

    return signals;
  }

  static String _buildAnalysis(
    double eRatio,
    double atr,
    int tradeCount,
    double winRate,
    double profitFactor,
    double avgMfe,
    double avgMae,
    List<TradeDetail> tradeDetails,
  ) {
    final buf = StringBuffer();
    buf.writeln('═══════════════════════════════');
    buf.writeln('【E-Ratio 策略分析结果】');
    buf.writeln('═══════════════════════════════');
    buf.writeln();
    buf.writeln('▸ 核心指标:');
    buf.writeln('  • E-Ratio: ${eRatio.toStringAsFixed(3)}');
    buf.writeln('  • ATR(14): ${atr.toStringAsFixed(3)}');
    buf.writeln('  • 交易次数: $tradeCount');
    buf.writeln();
    buf.writeln('▸ 统计指标:');
    buf.writeln('  • 胜率: ${(winRate * 100).toStringAsFixed(1)}%');
    buf.writeln('  • 盈亏比: ${profitFactor.toStringAsFixed(2)}');
    buf.writeln('  • 平均MFE: ${avgMfe.toStringAsFixed(2)} ATR');
    buf.writeln('  • 平均MAE: ${avgMae.toStringAsFixed(2)} ATR');
    buf.writeln();
    buf.writeln('▸ 策略评价:');
    if (eRatio >= 1.5) {
      buf.writeln('  ✓ 策略有效性很高，边缘优势明显');
    } else if (eRatio >= 1.2) {
      buf.writeln('  ✓ 策略有效性较好，具有正向边缘');
    } else if (eRatio >= 1.0) {
      buf.writeln('  ○ 策略勉强有效，边缘较小');
    } else {
      buf.writeln('  ✗ 策略可能无效，建议优化');
    }
    buf.writeln();
    buf.writeln('═══════════════════════════════');
    buf.writeln('【每笔交易详情】');
    buf.writeln('═══════════════════════════════');
    buf.writeln();
    buf.writeln('${'序号'.padRight(4)} ${'日期'.padRight(10)} ${'方向'.padRight(4)} ${'入场价'.padRight(10)} ${'出场价'.padRight(10)} ${'MFE'.padRight(8)} ${'MAE'}');
    buf.writeln(List.filled(60, '-').join());

    for (final trade in tradeDetails) {
      buf.writeln(
        '${trade.tradeNumber.toString().padRight(4)} '
        '${trade.date.toString().padRight(10)} '
        '${trade.direction.padRight(4)} '
        '${trade.entryPrice.toStringAsFixed(3).padRight(10)} '
        '${trade.exitPrice.toStringAsFixed(3).padRight(10)} '
        '${trade.mfe.toStringAsFixed(3).padRight(8)} '
        '${trade.mae.toStringAsFixed(3)}',
      );
    }
    return buf.toString();
  }

  static const String _calculationPrinciple = '''
═══════════════════════════════
【E-Ratio 计算原理】
═══════════════════════════════

一、什么是E-Ratio?
  E-Ratio (Edge Ratio/胜算率) 衡量交易信号发出后,
  价格有利波动幅度与不利波动幅度的比值。

二、核心概念:
  • MFE (Max Favorable Excursion):
    持仓期间的最大潜在盈利，即价格向有利方向的最大移动
  • MAE (Max Adverse Excursion):
    持仓期间的最大潜在亏损，即价格向不利方向的最大移动
  • ATR (Average True Range):
    平均真实波幅，用于标准化不同市场的波动率

三、计算公式:
  1. TR = max(H-L, |H-PCP|, |L-PCP|)
     (True Range 真实波幅)
  2. ATR = TR的14日简单移动平均
  3. MFE(ATR) = MFE / ATR (标准化)
     MAE(ATR) = MAE / ATR (标准化)
  4. E-Ratio = MFE(ATR)均值 / MAE(ATR)均值

四、交易信号:
  • 入场: 突破20日高点做多，跌破20日低点做空
  • 出场: 持有20个交易日后平仓

五、解读标准:
  • E-Ratio >= 1.5: 策略非常有效
  • E-Ratio >= 1.2: 策略有效
  • E-Ratio >= 1.0: 策略勉强有效
  • E-Ratio < 1.0: 策略可能无效
''';
}

class _Signal {
  final double entryPrice;
  final int direction; // 1=做多, -1=做空
  final int entryIndex;

  _Signal(this.entryPrice, this.direction, this.entryIndex);
}

class TradeDetail {
  final int tradeNumber;
  final String date;
  final String direction;
  final double entryPrice;
  final double exitPrice;
  final double mfe;
  final double mae;
  final double normalizedMfe;
  final double normalizedMae;
  final String result;

  const TradeDetail({
    required this.tradeNumber,
    required this.date,
    required this.direction,
    required this.entryPrice,
    required this.exitPrice,
    required this.mfe,
    required this.mae,
    required this.normalizedMfe,
    required this.normalizedMae,
    required this.result,
  });
}

class ERatioResult {
  final double eRatio;
  final double mfeMean;
  final double maeMean;
  final double atr;
  final int tradeCount;
  final double winRate;
  final double profitFactor;
  final List<TradeDetail> trades;
  final String analysis;
  final String calculationPrinciple;

  const ERatioResult({
    required this.eRatio,
    required this.mfeMean,
    required this.maeMean,
    required this.atr,
    required this.tradeCount,
    required this.winRate,
    required this.profitFactor,
    required this.trades,
    required this.analysis,
    required this.calculationPrinciple,
  });
}

extension on List<StockQuote> {
  List<StockQuote> sorted(int Function(StockQuote, StockQuote) compare) {
    final copy = toList();
    copy.sort(compare);
    return copy;
  }
}
