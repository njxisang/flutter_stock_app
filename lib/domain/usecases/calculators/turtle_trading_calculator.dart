import 'dart:math';
import 'package:flutter_stock_app/domain/entities/stock_quote.dart';

class TurtleTradingCalculator {
  /// 计算海龟交易信号
  /// [quotes] 股票数据
  /// [period] N值计算周期，默认20
  static TurtleDetails calculate(List<StockQuote> quotes, {int period = 20, double accountBalance = 100000}) {
    if (quotes.length < period) {
      return _emptyDetails();
    }

    // 计算True Range和N值
    final trueRanges = <double>[];
    for (var i = 1; i < quotes.length; i++) {
      final high = quotes[i].high;
      final low = quotes[i].low;
      final prevClose = quotes[i - 1].close;

      final tr = max(max(high - low, (high - prevClose).abs()), (low - prevClose).abs());
      trueRanges.add(tr);
    }

    // 计算20日N值
    if (trueRanges.length < period) return _emptyDetails();

    double sumN = 0;
    for (var i = 0; i < period; i++) {
      sumN += trueRanges[i];
    }
    final atr = sumN / period;

    // 14日N值
    double sumN14 = 0;
    final n14Start = trueRanges.length - 14;
    for (var i = n14Start; i < trueRanges.length; i++) {
      sumN14 += trueRanges[i];
    }
    final atr14 = sumN14 / 14;

    // 计算最近20日高低点
    final last20 = quotes.sublist(quotes.length - period);
    double high20 = last20[0].high;
    double low20 = last20[0].low;
    for (final q in last20) {
      if (q.high > high20) high20 = q.high;
      if (q.low < low20) low20 = q.low;
    }

    // 计算最近10日高低点
    final last10 = quotes.sublist(quotes.length - 10);
    double high10 = last10[0].high;
    double low10 = last10[0].low;
    for (final q in last10) {
      if (q.high > high10) high10 = q.high;
      if (q.low < low10) low10 = q.low;
    }

    final currentPrice = quotes.last.close;

    // 判断信号
    TurtleSignalType signal;
    String explanation;
    double entryPrice;
    List<String> steps;

    if (currentPrice > high20) {
      signal = TurtleSignalType.longBreakout;
      explanation = '价格突破20日高点($high20)，做多信号';
      entryPrice = high20;
      steps = [
        '1. 入场：买入价 = 突破20日高点 $high20',
        '2. 止损：买入价 - 2N = ${(high20 - 2 * atr).toStringAsFixed(2)}',
        '3. 止盈：2倍风险收益',
        '4. 仓位：每份风险 = 账户1% / N值',
        '5. 风险管理：总仓位不超过4份',
      ];
    } else if (currentPrice < low20) {
      signal = TurtleSignalType.shortBreakout;
      explanation = '价格跌破20日低点($low20)，做空信号';
      entryPrice = low20;
      steps = [
        '1. 入场：卖出价 = 跌破20日低点 $low10',
        '2. 止损：卖出价 + 2N = ${(low20 + 2 * atr).toStringAsFixed(2)}',
        '3. 止盈：2倍风险收益',
        '4. 仓位：每份风险 = 账户1% / N值',
      ];
    } else {
      signal = TurtleSignalType.none;
      explanation = '价格未突破20日高低点，等待信号';
      entryPrice = currentPrice;
      steps = ['当前无信号，等待价格突破20日高点或跌破20日低点'];
    }

    // 计算仓位大小（每份风险 = 账户1%）
    final riskAmount = accountBalance * 0.01;
    final positionSize = atr > 0 ? riskAmount / atr : 0.0;

    // 计算止损和止盈
    final stopLoss = signal == TurtleSignalType.longBreakout
        ? currentPrice - 2 * atr
        : signal == TurtleSignalType.shortBreakout
            ? currentPrice + 2 * atr
            : 0.0;

    final takeProfit = signal == TurtleSignalType.longBreakout
        ? currentPrice + 4 * atr
        : signal == TurtleSignalType.shortBreakout
            ? currentPrice - 4 * atr
            : 0.0;

    final riskReward = stopLoss != 0 ? ((currentPrice - stopLoss) / atr).abs() : 0.0;

    return TurtleDetails(
      currentPrice: currentPrice,
      high20: high20,
      low20: low20,
      high10: high10,
      low10: low10,
      atr: atr,
      atr14: atr14,
      entryPrice: entryPrice,
      stopLoss: stopLoss,
      takeProfit: takeProfit,
      riskReward: riskReward,
      positionSize: positionSize,
      signal: signal,
      signalExplanation: explanation,
      stepDetails: steps,
    );
  }

  static TurtleDetails _emptyDetails() {
    return TurtleDetails(
      currentPrice: 0,
      high20: 0,
      low20: 0,
      high10: 0,
      low10: 0,
      atr: 0,
      atr14: 0,
      entryPrice: 0,
      stopLoss: 0,
      takeProfit: 0,
      riskReward: 0,
      positionSize: 0,
      signal: TurtleSignalType.none,
      signalExplanation: '数据不足',
      stepDetails: [],
    );
  }
}
