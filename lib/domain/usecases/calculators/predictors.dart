import 'dart:math';
import 'package:flutter_stock_app/domain/entities/stock_quote.dart';

class LinearRegressionPredictor {
  /// 线性回归预测
  /// FIXED: 使用正确的复利公式
  static LrResult fit(List<StockQuote> quotes) {
    if (quotes.length < 2) return LrResult(0, 0, 100);

    final closes = quotes.map((q) => q.close).toList();

    // 计算日均收益率
    var sumReturns = 0.0;
    for (var i = 1; i < closes.length; i++) {
      sumReturns += (closes[i] - closes[i - 1]) / closes[i - 1];
    }
    final dailyReturn = sumReturns / (closes.length - 1);

    // 计算R平方
    final meanY = closes.reduce((a, b) => a + b) / closes.length;
    var ssTot = 0.0;
    var ssRes = 0.0;

    for (var i = 0; i < closes.length; i++) {
      ssTot += pow(closes[i] - meanY, 2);
      // FIXED: 正确的线性回归预测公式
      final predicted = closes[0] * pow(1 + dailyReturn, i);
      ssRes += pow(closes[i] - predicted, 2);
    }

    final rSquared = ssTot > 0 ? max(0.0, 1 - (ssRes / ssTot)) : 0.0;

    return LrResult(dailyReturn * 100, rSquared, closes.last);
  }

  static List<PredictionPoint> predict(LrResult lr, double lastPrice, int days) {
    final results = <PredictionPoint>[];

    for (var day = 1; day <= days; day++) {
      // FIXED: 使用正确的复利增长预测
      final predictedPrice = lastPrice * pow(1 + lr.avgChangePercent / 100.0, day);
      final clampedPrice = max(predictedPrice, lastPrice * 0.5);
      results.add(PredictionPoint(day: day, price: clampedPrice));
    }

    return results;
  }
}

class LrResult {
  final double avgChangePercent;
  final double rSquared;
  final double avgPrice;

  LrResult(this.avgChangePercent, this.rSquared, this.avgPrice);
}

class PredictionPoint {
  final int day;
  final double price;

  PredictionPoint({required this.day, required this.price});
}

class HoltPredictor {
  /// Holt双指数平滑预测
  static HoltResult predict(List<StockQuote> quotes, int days) {
    if (quotes.length < 10) return HoltResult(0, 0, quotes.last.close);

    final closes = quotes.map((q) => q.close).toList();
    final n = closes.length;

    // 初始值
    var level = closes[0];
    var trend = closes[1] - closes[0];

    // alpha和beta参数
    const alpha = 0.3;
    const beta = 0.1;

    // 平滑
    for (var i = 1; i < n; i++) {
      final newLevel = alpha * closes[i] + (1 - alpha) * (level + trend);
      final newTrend = beta * (newLevel - level) + (1 - beta) * trend;
      level = newLevel;
      trend = newTrend;
    }

    // 预测
    final predictions = <double>[];
    for (var i = 1; i <= days; i++) {
      predictions.add(level + trend * i);
    }

    // 计算置信度
    var variance = 0.0;
    for (var i = 1; i < n; i++) {
      final predicted = level + trend * i;
      variance += pow(closes[i] - predicted, 2);
    }
    variance /= n;
    final confidence = ((1 - min(1.0, sqrt(variance) / level)).clamp(0.0, 1.0) * 5).toDouble();

    return HoltResult(confidence, trend, closes.last);
  }
}

class HoltResult {
  final double confidence;
  final double trendPerDay;
  final double lastPrice;

  HoltResult(this.confidence, this.trendPerDay, this.lastPrice);
}

class SimpleArimaPredictor {
  /// 简化ARIMA预测
  /// FIXED: 修正置信度计算
  static ArimaResult predict(List<StockQuote> quotes, int days) {
    if (quotes.length < 20) return ArimaResult(0, 0, quotes.last.close);

    final closes = quotes.map((q) => q.close).toList();

    // 计算一阶差分
    final diffs = <double>[];
    for (var i = 1; i < closes.length; i++) {
      diffs.add(closes[i] - closes[i - 1]);
    }

    // 差分序列均值
    final avgDiff = diffs.reduce((a, b) => a + b) / diffs.length;

    // 计算趋势强度
    var variance = 0.0;
    for (final d in diffs) {
      variance += pow(d - avgDiff, 2);
    }
    variance /= diffs.length;
    final trendStrength = avgDiff.abs() / (sqrt(variance) + 0.0001);

    // 预测
    var lastPrice = closes.last;
    final predictions = <double>[];
    for (var i = 0; i < days; i++) {
      lastPrice += avgDiff * 0.9; // 轻微阻尼
      predictions.add(lastPrice);
    }

    // FIXED: 使用归一化波动率计算置信度
    final volatility = sqrt(variance) / closes.average;
    double confidence;
    if (trendStrength > 2.5 && volatility < 0.1) {
      confidence = 5;
    } else if (trendStrength > 2.0 && volatility < 0.15) {
      confidence = 4;
    } else if (trendStrength > 1.5) {
      confidence = 3;
    } else if (trendStrength > 1.0) {
      confidence = 2;
    } else {
      confidence = 1;
    }

    return ArimaResult(confidence, avgDiff, closes.last);
  }
}

class ArimaResult {
  final double confidence;
  final double avgDiff;
  final double lastPrice;

  ArimaResult(this.confidence, this.avgDiff, this.lastPrice);
}

class EnsemblePredictor {
  /// 集成预测 - 综合多个模型
  static EnsembleResult predict(List<StockQuote> quotes, int days) {
    if (quotes.length < 20) {
      return EnsembleResult(
        predictions: [],
        overallTrend: '数据不足',
        overallConfidence: 0,
        technicalReasons: ['数据不足无法预测'],
      );
    }

    final lastPrice = quotes.last.close;

    // 三个模型的预测
    final lr = LinearRegressionPredictor.fit(quotes);
    final lrPredictions = LinearRegressionPredictor.predict(lr, lastPrice, days);

    final holt = HoltPredictor.predict(quotes, days);

    final arima = SimpleArimaPredictor.predict(quotes, days);

    // 集成预测（加权平均）
    final predictions = <PricePredictionItem>[];
    for (var i = 0; i < days; i++) {
      final lrPrice = i < lrPredictions.length ? lrPredictions[i].price : lastPrice;
      final holtPrice = holt.trendPerDay * (i + 1) + lastPrice;
      final arimaPrice = arima.avgDiff * (i + 1) * 0.9 + lastPrice;

      // 简单平均
      final avgPrice = (lrPrice + holtPrice + arimaPrice) / 3;

      predictions.add(PricePredictionItem(
        day: i + 1,
        price: avgPrice,
        lrPrice: lrPrice,
        holtPrice: holtPrice,
        arimaPrice: arimaPrice,
      ));
    }

    // 综合趋势
    String overallTrend;
    if (lr.avgChangePercent > 0.1 && holt.trendPerDay > 0) {
      overallTrend = '上涨';
    } else if (lr.avgChangePercent < -0.1 && holt.trendPerDay < 0) {
      overallTrend = '下跌';
    } else {
      overallTrend = '震荡';
    }

    // FIXED: 计算综合置信度 - 基于模型一致性和趋势强度
    final predictionVariances = <double>[];
    for (final p in predictions) {
      final mean = (p.lrPrice + p.holtPrice + p.arimaPrice) / 3;
      final variance = (pow(p.lrPrice - mean, 2) + pow(p.holtPrice - mean, 2) + pow(p.arimaPrice - mean, 2)) / 3;
      predictionVariances.add(sqrt(variance));
    }
    final avgVariance = predictionVariances.isNotEmpty ? predictionVariances.reduce((a, b) => a + b) / predictionVariances.length : 0;

    // 基于模型一致性的置信度调整
    int baseConfidence;
    if (lr.rSquared > 0.7 && holt.confidence > 4 && arima.confidence > 4) {
      baseConfidence = 5;
    } else if (lr.rSquared > 0.5 && holt.confidence > 3 && arima.confidence > 3) {
      baseConfidence = 4;
    } else if (lr.rSquared > 0.3) {
      baseConfidence = 3;
    } else {
      baseConfidence = 2;
    }

    // 一致性调整
    final agreementBonus = avgVariance / lastPrice < 0.02 ? 1 : avgVariance / lastPrice < 0.05 ? 0 : -1;
    final overallConfidence = (baseConfidence + agreementBonus).clamp(1, 5).toInt();

    final technicalReasons = <String>[];
    if (lr.rSquared > 0.6) {
      technicalReasons.add('线性回归R²=${(lr.rSquared * 100).toStringAsFixed(1)}%');
    }
    if (holt.confidence > 3) {
      technicalReasons.add('Holt平滑置信度=${holt.confidence.toStringAsFixed(1)}星');
    }
    if (arima.confidence > 3) {
      technicalReasons.add('ARIMA趋势强度=${arima.confidence.toStringAsFixed(1)}星');
    }

    return EnsembleResult(
      predictions: predictions,
      overallTrend: overallTrend,
      overallConfidence: overallConfidence,
      technicalReasons: technicalReasons,
    );
  }
}

class PricePredictionItem {
  final int day;
  final double price;
  final double lrPrice;
  final double holtPrice;
  final double arimaPrice;

  PricePredictionItem({
    required this.day,
    required this.price,
    required this.lrPrice,
    required this.holtPrice,
    required this.arimaPrice,
  });
}

class EnsembleResult {
  final List<PricePredictionItem> predictions;
  final String overallTrend;
  final int overallConfidence;
  final List<String> technicalReasons;

  EnsembleResult({
    required this.predictions,
    required this.overallTrend,
    required this.overallConfidence,
    required this.technicalReasons,
  });
}

extension on List<double> {
  double get average => isEmpty ? 0 : reduce((a, b) => a + b) / length;
}
