import 'dart:math';
import 'package:flutter_stock_app/domain/entities/stock_quote.dart';
import 'package:flutter_stock_app/domain/usecases/calculators/macd_calculator.dart';
import 'package:flutter_stock_app/domain/usecases/calculators/rsi_calculator.dart';
import 'package:flutter_stock_app/domain/usecases/calculators/kdj_calculator.dart';
import 'package:flutter_stock_app/domain/usecases/calculators/boll_calculator.dart';
import 'package:flutter_stock_app/domain/usecases/calculators/ma_calculator.dart';
import 'package:flutter_stock_app/domain/usecases/calculators/wr_calculator.dart';
import 'package:flutter_stock_app/domain/usecases/calculators/dmi_calculator.dart';
import 'package:flutter_stock_app/domain/usecases/calculators/multi_factor_analyzer.dart';

class CorrelationAnalyzer {
  /// 计算两只股票收盘价之间的皮尔逊相关系数
  static CorrelationResult calculateCorrelation(
    List<double> stockPrices,
    List<double> marketPrices,
  ) {
    if (stockPrices.length < 10 ||
        marketPrices.length < 10 ||
        stockPrices.length != marketPrices.length) {
      return CorrelationResult(0.0, '数据不足', '无法计算');
    }

    final n = stockPrices.length.toDouble();
    final stockMean = stockPrices.reduce((a, b) => a + b) / n;
    final marketMean = marketPrices.reduce((a, b) => a + b) / n;

    var covariance = 0.0;
    var stockVariance = 0.0;
    var marketVariance = 0.0;

    for (var i = 0; i < stockPrices.length; i++) {
      final sd = stockPrices[i] - stockMean;
      final md = marketPrices[i] - marketMean;
      covariance += sd * md;
      stockVariance += sd * sd;
      marketVariance += md * md;
    }

    final corr = stockVariance > 0 && marketVariance > 0
        ? covariance / sqrt(stockVariance * marketVariance)
        : 0.0;

    String interpretation;
    String strength;
    if (corr >= 0.8) {
      interpretation = '高度正相关';
      strength = '很强';
    } else if (corr >= 0.5) {
      interpretation = '中度正相关';
      strength = '较强';
    } else if (corr >= 0.3) {
      interpretation = '弱正相关';
      strength = '一般';
    } else if (corr >= -0.3) {
      interpretation = '几乎无相关';
      strength = '弱';
    } else if (corr >= -0.5) {
      interpretation = '弱负相关';
      strength = '一般';
    } else if (corr >= -0.8) {
      interpretation = '中度负相关';
      strength = '较强';
    } else {
      interpretation = '高度负相关';
      strength = '很强';
    }

    return CorrelationResult(corr, interpretation, strength);
  }

  /// 大盘对比分析
  static MarketComparison compareWithMarket(
    List<StockQuote> stockQuotes,
    List<StockQuote> marketQuotes,
  ) {
    if (stockQuotes.isEmpty || marketQuotes.isEmpty) {
      return MarketComparison(
        stockChange: 0,
        marketChange: 0,
        relativeStrength: 0,
        correlationResult: CorrelationResult(0.0, '数据不足', '无法计算'),
        interpretation: '数据不足，无法对比',
      );
    }

    // 按日期对齐
    final marketByDate = marketQuotes.fold<Map<String, StockQuote>>(
      {},
      (map, q) => map..[q.date] = q,
    );
    final alignedStock = stockQuotes.where((q) => marketByDate.containsKey(q.date)).toList();

    if (alignedStock.length < 10) {
      return MarketComparison(
        stockChange: _calculateChange(stockQuotes),
        marketChange: _calculateChange(marketQuotes),
        relativeStrength: 0,
        correlationResult: CorrelationResult(0.0, '数据不足', '无法计算'),
        interpretation: '数据不足，无法对比',
      );
    }

    final alignedMarket = alignedStock.map((q) => marketByDate[q.date]!).toList();

    final stockChange = _calculateChange(alignedStock);
    final marketChange = _calculateChange(alignedMarket);
    final relativeStrength = stockChange - marketChange;

    final stockPrices = alignedStock.map((q) => q.close).toList();
    final marketPrices = alignedMarket.map((q) => q.close).toList();
    final correlationResult = calculateCorrelation(stockPrices, marketPrices);

    final interpretation = _buildInterpretation(
      stockChange,
      marketChange,
      relativeStrength,
      correlationResult,
    );

    return MarketComparison(
      stockChange: stockChange,
      marketChange: marketChange,
      relativeStrength: relativeStrength,
      correlationResult: correlationResult,
      interpretation: interpretation,
    );
  }

  /// 组合分析
  static PortfolioAnalysis analyzePortfolio(
    List<Triple<String, String, List<StockQuote>>> stockDataList,
  ) {
    if (stockDataList.length < 2) {
      return PortfolioAnalysis(
        stocks: [],
        correlationMatrix: {},
        diversificationScore: 0,
        overallRisk: '股票数量不足',
        recommendations: ['请选择至少2只股票进行分析'],
      );
    }

    // 计算每只股票的得分
    final stocks = stockDataList.map((data) {
      final symbol = data.first;
      final name = data.second;
      final quotes = data.third;
      final change = _calculateChange(quotes);
      final macd = MacdCalculator.calculate(quotes);
      final rsi = RsiCalculator.calculate(quotes, period: 6);
      final kdj = KdjCalculator.calculate(quotes, period: 9);
      final boll = BollCalculator.calculate(quotes, period: 20);
      final ma = MaCalculator.calculate(quotes);
      final wr = WrCalculator.calculate(quotes);
      final dmi = DmiCalculator.calculate(quotes);
      final report = MultiFactorAnalyzer.analyze(quotes);
      return PortfolioStock(
        symbol: symbol,
        name: name,
        quotes: quotes,
        change: change,
        score: report.overallScore,
      );
    }).toList();

    // 计算相关性矩阵
    final correlationMatrix = <Pair<String, String>, double>{};
    for (var i = 0; i < stocks.length; i++) {
      for (var j = i + 1; j < stocks.length; j++) {
        final quotes2ByDate = stocks[j].quotes.fold<Map<String, StockQuote>>(
          {},
          (map, q) => map..[q.date] = q,
        );
        final aligned1 = stocks[i].quotes.where((q) => quotes2ByDate.containsKey(q.date)).toList();
        final aligned2 = aligned1.map((q) => quotes2ByDate[q.date]!).toList();

        if (aligned1.length >= 10) {
          final corr = _calculateCorrelationValue(
            aligned1.map((q) => q.close).toList(),
            aligned2.map((q) => q.close).toList(),
          );
          correlationMatrix[Pair(stocks[i].symbol, stocks[j].symbol)] = corr;
        }
      }
    }

    // 分散度评分
    final avgCorrelation = correlationMatrix.isNotEmpty
        ? correlationMatrix.values.reduce((a, b) => a + b) / correlationMatrix.length
        : 0.0;
    final diversificationScore = (1 - avgCorrelation) * 100;

    // 整体风险
    final avgScore = stocks.map((s) => s.score).reduce((a, b) => a + b) / stocks.length;
    final overallRisk = avgScore >= 4
        ? '低风险'
        : avgScore >= 2
            ? '中等风险'
            : avgScore >= 0
                ? '偏高风险'
                : '高风险';

    // 建议
    final recommendations = <String>[];
    final highCorrPairs = correlationMatrix.entries.where((e) => e.value > 0.7).toList();
    if (highCorrPairs.isNotEmpty) {
      recommendations.add('⚠️ 以下股票相关性较高，建议保留1只:');
      for (final entry in highCorrPairs) {
        final pair = entry.key;
        recommendations.add('  - ${pair.first} 与 ${pair.second}');
      }
    }

    final topStock = stocks.reduce((a, b) => a.score > b.score ? a : b);
    final lowStock = stocks.reduce((a, b) => a.score < b.score ? a : b);
    if (topStock.symbol != lowStock.symbol) {
      recommendations.add('⭐ 建议重点关注: ${topStock.name}(${topStock.symbol})，得分${topStock.score}/16');
      recommendations.add('⚠️ 建议考虑替换: ${lowStock.name}(${lowStock.symbol})，得分${lowStock.score}/16');
    }

    if (diversificationScore < 50) {
      recommendations.add('📊 组合分散度不足，建议增加不同行业的股票以降低风险');
    } else {
      recommendations.add('✅ 组合分散度良好，股票相关性适中');
    }

    final avgChange = stocks.map((s) => s.change).reduce((a, b) => a + b) / stocks.length;
    if (avgChange > 5) {
      recommendations.add('📈 组合涨幅整体表现优异，平均${avgChange.toStringAsFixed(1)}%');
    } else if (avgChange < -5) {
      recommendations.add('📉 组合整体表现较弱，注意风险控制');
    }

    return PortfolioAnalysis(
      stocks: stocks,
      correlationMatrix: correlationMatrix,
      diversificationScore: diversificationScore,
      overallRisk: overallRisk,
      recommendations: recommendations,
    );
  }

  static double _calculateChange(List<StockQuote> quotes) {
    if (quotes.length < 2) return 0.0;
    final firstPrice = quotes.first.close;
    final lastPrice = quotes.last.close;
    return (lastPrice - firstPrice) / firstPrice * 100;
  }

  static double _calculateCorrelationValue(List<double> prices1, List<double> prices2) {
    if (prices1.length < 10 || prices2.length < 10 || prices1.length != prices2.length) {
      return 0.0;
    }
    final n = prices1.length.toDouble();
    final mean1 = prices1.reduce((a, b) => a + b) / n;
    final mean2 = prices2.reduce((a, b) => a + b) / n;

    var covariance = 0.0;
    var var1 = 0.0;
    var var2 = 0.0;

    for (var i = 0; i < prices1.length; i++) {
      final d1 = prices1[i] - mean1;
      final d2 = prices2[i] - mean2;
      covariance += d1 * d2;
      var1 += d1 * d1;
      var2 += d2 * d2;
    }

    return var1 > 0 && var2 > 0 ? covariance / sqrt(var1 * var2) : 0.0;
  }

  static String _buildInterpretation(
    double stockChange,
    double marketChange,
    double relativeStrength,
    CorrelationResult corr,
  ) {
    final buf = StringBuffer();
    buf.write('股票涨幅: ${stockChange.toStringAsFixed(2)}%, ');
    buf.write('大盘涨幅: ${marketChange.toStringAsFixed(2)}%\n');
    buf.write('相对强度: ${relativeStrength.toStringAsFixed(2)}%\n');
    buf.write('相关性: ${corr.interpretation}(${corr.strength})\n');

    if (relativeStrength > 5 && corr.correlation > 0.3) {
      buf.write('→ 该股跑赢大盘，且与大盘走势同步，强势特征明显');
    } else if (relativeStrength > 5 && corr.correlation < 0) {
      buf.write('→ 该股逆市上涨，走势独立于大盘，强势特征明显');
    } else if (relativeStrength < -5 && corr.correlation > 0.3) {
      buf.write('→ 该股跌幅超过大盘，受市场影响较大，注意风险');
    } else if (relativeStrength < -5 && corr.correlation < 0) {
      buf.write('→ 该股逆市下跌，走势弱于大盘，注意风险');
    } else if (relativeStrength.abs() <= 5 && corr.correlation > 0.5) {
      buf.write('→ 该股与大盘走势基本一致，随市场波动');
    } else {
      buf.write('→ 该股走势相对独立，可关注其独立性带来的机会');
    }

    return buf.toString();
  }
}

class CorrelationResult {
  final double correlation;
  final String interpretation;
  final String strength;

  const CorrelationResult(this.correlation, this.interpretation, this.strength);
}

class MarketComparison {
  final double stockChange;
  final double marketChange;
  final double relativeStrength;
  final CorrelationResult correlationResult;
  final String interpretation;

  const MarketComparison({
    required this.stockChange,
    required this.marketChange,
    required this.relativeStrength,
    required this.correlationResult,
    required this.interpretation,
  });
}

class PortfolioStock {
  final String symbol;
  final String name;
  final List<StockQuote> quotes;
  final double change;
  final int score;

  const PortfolioStock({
    required this.symbol,
    required this.name,
    required this.quotes,
    required this.change,
    required this.score,
  });
}

class PortfolioAnalysis {
  final List<PortfolioStock> stocks;
  final Map<Pair<String, String>, double> correlationMatrix;
  final double diversificationScore;
  final String overallRisk;
  final List<String> recommendations;

  const PortfolioAnalysis({
    required this.stocks,
    required this.correlationMatrix,
    required this.diversificationScore,
    required this.overallRisk,
    required this.recommendations,
  });
}

class Pair<K, V> {
  final K first;
  final V second;

  const Pair(this.first, this.second);

  @override
  bool operator ==(Object other) =>
      other is Pair && other.first == first && other.second == second;

  @override
  int get hashCode => first.hashCode ^ second.hashCode;
}

class Triple<K, V, T> {
  final K first;
  final V second;
  final T third;

  const Triple(this.first, this.second, this.third);

  @override
  String toString() => 'Triple($first, $second, $third)';
}
