import 'package:flutter_stock_app/domain/entities/stock_quote.dart';
import 'macd_calculator.dart';
import 'rsi_calculator.dart';
import 'kdj_calculator.dart';
import 'boll_calculator.dart';
import 'ma_calculator.dart';
import 'wr_calculator.dart';
import 'dmi_calculator.dart';

class MultiFactorAnalyzer {
  /// 多因子分析
  static MultiFactorReport analyze(
    List<StockQuote> quotes, {
    int shortPeriod = 12,
    int longPeriod = 26,
    int signalPeriod = 9,
    int rsiPeriod = 14,
    int kdjPeriod = 9,
    int bollPeriod = 20,
  }) {
    if (quotes.length < 60) {
      return MultiFactorReport(
        overallScore: 0,
        rating: '数据不足',
        factors: [],
        riskLevel: '未知',
        recommendations: ['数据不足，无法进行分析'],
      );
    }

    final factors = <FactorResult>[];
    int totalScore = 0;

    // 1. 趋势因子 (MA排列)
    final maData = MaCalculator.calculate(quotes);
    final maScore = maData.isNotEmpty ? _analyzeMaTrend(maData.last) : 0;
    factors.add(FactorResult(
      name: '趋势因子',
      value: maData.isNotEmpty ? 'MA5=${maData.last.ma5.toStringAsFixed(2)} MA10=${maData.last.ma10.toStringAsFixed(2)} MA20=${maData.last.ma20.toStringAsFixed(2)}' : 'N/A',
      score: maScore,
      interpretation: maScore > 0 ? '均线多头排列' : maScore < 0 ? '均线空头排列' : '均线混乱',
    ));
    totalScore += maScore;

    // 2. 动量因子 (RSI)
    final rsiData = RsiCalculator.calculate(quotes, period: rsiPeriod);
    final rsiScore = rsiData.isNotEmpty ? _analyzeRsi(rsiData.last.rsi) : 0;
    factors.add(FactorResult(
      name: 'RSI动量',
      value: rsiData.isNotEmpty ? 'RSI=${rsiData.last.rsi.toStringAsFixed(2)}' : 'N/A',
      score: rsiScore,
      interpretation: rsiData.isNotEmpty
          ? rsiData.last.rsi > 70 ? '超买区域' : rsiData.last.rsi < 30 ? '超卖区域' : '正常区间'
          : 'N/A',
    ));
    totalScore += rsiScore;

    // 3. 波动率因子 (BOLL)
    final bollData = BollCalculator.calculate(quotes, period: bollPeriod);
    final bollScore = bollData.isNotEmpty ? _analyzeBoll(quotes.last.close, bollData.last) : 0;
    factors.add(FactorResult(
      name: '布林带',
      value: bollData.isNotEmpty
          ? '上轨=${bollData.last.upper.toStringAsFixed(2)} 下轨=${bollData.last.lower.toStringAsFixed(2)}'
          : 'N/A',
      score: bollScore,
      interpretation: bollData.isNotEmpty
          ? quotes.last.close > bollData.last.upper
              ? '价格突破上轨，注意回调风险'
              : quotes.last.close < bollData.last.lower
                  ? '价格跌破下轨，可能反弹'
                  : '价格在布林带内运行'
          : 'N/A',
    ));
    totalScore += bollScore;

    // 4. KDJ超买超卖
    final kdjData = KdjCalculator.calculate(quotes, period: kdjPeriod);
    final kdjScore = kdjData.isNotEmpty ? _analyzeKdj(kdjData.last) : 0;
    factors.add(FactorResult(
      name: 'KDJ指标',
      value: kdjData.isNotEmpty ? 'K=${kdjData.last.k.toStringAsFixed(2)} D=${kdjData.last.d.toStringAsFixed(2)} J=${kdjData.last.j.toStringAsFixed(2)}' : 'N/A',
      score: kdjScore,
      interpretation: kdjData.isNotEmpty
          ? kdjData.last.j > 100 ? 'J值超买警惕' : kdjData.last.j < 0 ? 'J值超卖警惕' : 'KDJ正常'
          : 'N/A',
    ));
    totalScore += kdjScore;

    // 5. MACD信号
    final macdData = MacdCalculator.calculate(quotes, shortPeriod: shortPeriod, longPeriod: longPeriod, signalPeriod: signalPeriod);
    final macdSignal = MacdCalculator.detectSignal(macdData);
    final macdScore = macdSignal != null
        ? macdSignal.signal == MacdSignal.goldenCross
            ? 2
            : macdSignal.signal == MacdSignal.deathCross
                ? -2
                : 0
        : 0;
    factors.add(FactorResult(
      name: 'MACD信号',
      value: macdData.isNotEmpty
          ? 'DIF=${macdData.last.dif.toStringAsFixed(3)} DEA=${macdData.last.dea.toStringAsFixed(3)}'
          : 'N/A',
      score: macdScore,
      interpretation: macdSignal != null
          ? macdSignal.signal == MacdSignal.goldenCross
              ? 'MACD金叉买入信号'
              : 'MACD死叉卖出信号'
          : '无明显信号',
    ));
    totalScore += macdScore;

    // 6. DMI趋势强度
    final dmiData = DmiCalculator.calculate(quotes);
    final dmiScore = dmiData.isNotEmpty ? _analyzeDmi(dmiData.last) : 0;
    factors.add(FactorResult(
      name: 'DMI趋势',
      value: dmiData.isNotEmpty ? 'PDI=${dmiData.last.pdi.toStringAsFixed(2)} MDI=${dmiData.last.mdi.toStringAsFixed(2)} ADX=${dmiData.last.adx.toStringAsFixed(2)}' : 'N/A',
      score: dmiScore,
      interpretation: dmiData.isNotEmpty
          ? dmiData.last.adx > 25
              ? dmiData.last.pdi > dmiData.last.mdi
                  ? '趋势明显，多头'
                  : '趋势明显，空头'
              : '趋势不明显'
          : 'N/A',
    ));
    totalScore += dmiScore;

    // 7. WR威廉指标
    final wrData = WrCalculator.calculate(quotes);
    final wrScore = wrData.isNotEmpty ? _analyzeWr(wrData.last) : 0;
    factors.add(FactorResult(
      name: '威廉指标',
      value: wrData.isNotEmpty ? 'WR6=${wrData.last.wr6.toStringAsFixed(2)} WR10=${wrData.last.wr10.toStringAsFixed(2)}' : 'N/A',
      score: wrScore,
      interpretation: wrData.isNotEmpty
          ? wrData.last.wr6 > 80 ? '超卖区域可能反弹' : wrData.last.wr6 < 20 ? '超买区域可能回落' : '正常区间'
          : 'N/A',
    ));
    totalScore += wrScore;

    // 8. 价格位置因子
    final pricePositionScore = _analyzePricePosition(quotes);
    factors.add(FactorResult(
      name: '价格位置',
      value: '当前价格=${quotes.last.close.toStringAsFixed(2)}',
      score: pricePositionScore,
      interpretation: pricePositionScore > 0 ? '价格处于近期高位' : pricePositionScore < 0 ? '价格处于近期低位' : '价格处于中间位置',
    ));
    totalScore += pricePositionScore;

    // 生成评级和建议
    final rating = _getRating(totalScore);
    final riskLevel = _getRiskLevel(totalScore);
    final recommendations = _getRecommendations(factors, macdSignal);

    return MultiFactorReport(
      overallScore: totalScore,
      rating: rating,
      factors: factors,
      riskLevel: riskLevel,
      recommendations: recommendations,
    );
  }

  static int _analyzeMaTrend(MaData ma) {
    if (ma.ma5 > ma.ma10 && ma.ma10 > ma.ma20) return 2;
    if (ma.ma5 < ma.ma10 && ma.ma10 < ma.ma20) return -2;
    if (ma.ma5 > ma.ma20) return 1;
    if (ma.ma5 < ma.ma20) return -1;
    return 0;
  }

  static int _analyzeRsi(double rsi) {
    if (rsi > 80) return -2;
    if (rsi > 70) return -1;
    if (rsi < 20) return 2;
    if (rsi < 30) return 1;
    return 0;
  }

  static int _analyzeBoll(double price, BollData boll) {
    if (price > boll.upper) return -1;
    if (price < boll.lower) return 1;
    if (price > boll.middle) return 1;
    return 0;
  }

  static int _analyzeKdj(KdjData kdj) {
    if (kdj.j > 100) return -2;
    if (kdj.j < 0) return 2;
    if (kdj.k > kdj.d) return 1;
    if (kdj.k < kdj.d) return -1;
    return 0;
  }

  static int _analyzeDmi(DmiData dmi) {
    if (dmi.adx < 20) return 0;
    if (dmi.pdi > dmi.mdi) return dmi.adx > 25 ? 2 : 1;
    return dmi.adx > 25 ? -2 : -1;
  }

  static int _analyzeWr(WrData wr) {
    if (wr.wr6 > 80) return 2;
    if (wr.wr6 < 20) return -2;
    return 0;
  }

  static int _analyzePricePosition(List<StockQuote> quotes) {
    final last20 = quotes.sublist(quotes.length - 20);
    final prices = last20.map((q) => q.close).toList();
    final currentPrice = quotes.last.close;
    final maxPrice = prices.reduce((a, b) => a > b ? a : b);
    final minPrice = prices.reduce((a, b) => a < b ? a : b);
    final position = (currentPrice - minPrice) / (maxPrice - minPrice);
    if (position > 0.8) return -1;
    if (position < 0.2) return 1;
    return 0;
  }

  static String _getRating(int score) {
    if (score >= 6) return '★★★★★ 强烈推荐';
    if (score >= 3) return '★★★★☆ 推荐';
    if (score >= 0) return '★★★☆☆ 中性';
    if (score >= -3) return '★★☆☆☆ 谨慎';
    return '★☆☆☆☆ 不推荐';
  }

  static String _getRiskLevel(int score) {
    if (score >= 6) return '低风险';
    if (score >= 3) return '中等风险';
    if (score >= 0) return '较高风险';
    return '高风险';
  }

  static List<String> _getRecommendations(List<FactorResult> factors, MacdSignalResult? macdSignal) {
    final recommendations = <String>[];

    final positiveFactors = factors.where((f) => f.score > 0).length;
    final negativeFactors = factors.where((f) => f.score < 0).length;

    if (positiveFactors >= 6) {
      recommendations.add('多因子共振看多，可考虑买入');
    } else if (negativeFactors >= 6) {
      recommendations.add('多因子共振看空，建议观望或卖出');
    }

    if (macdSignal?.signal == MacdSignal.goldenCross) {
      recommendations.add('MACD出现金叉，关注买入机会');
    } else if (macdSignal?.signal == MacdSignal.deathCross) {
      recommendations.add('MACD出现死叉，注意风险');
    }

    final rsiFactor = factors.firstWhere((f) => f.name == 'RSI动量', orElse: () => factors.first);
    if (rsiFactor.score < 0) {
      recommendations.add('RSI显示超买，建议等待回调后再买入');
    } else if (rsiFactor.score > 0) {
      recommendations.add('RSI显示超卖，可能存在反弹机会');
    }

    if (recommendations.isEmpty) {
      recommendations.add('各指标信号不一，建议观望等待明确信号');
    }

    return recommendations;
  }
}
