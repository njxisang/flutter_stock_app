import 'dart:math';
import 'package:flutter_stock_app/domain/entities/stock_quote.dart';

class TurtleTradingCalculator {
  /// 执行海龟完整回测（遍历全部历史数据）
  static TurtleBacktestResult runTurtleBacktest(
    List<StockQuote> quotes, {
    int period = 20,
    double accountBalance = 100000,
    double riskPercent = 1.0,
    double feeRate = 0.001,
    double stopLossN = 2.0,   // N倍止损（海龟标准2N）
    double profitTargetN = 4.0, // N倍止盈（海龟标准2R=4N）
  }) {
    if (quotes.length < period + 1) {
      return _emptyTurtleResult(accountBalance);
    }

    // 计算每日的N值（True Range的20日均值）
    final trueRanges = <double>[];
    for (var i = 1; i < quotes.length; i++) {
      final tr = _trueRange(quotes[i], quotes[i - 1]);
      trueRanges.add(tr);
    }

    // 从索引 period 开始做回测（前 period 天预热N值）
    final trades = <TurtleTrade>[];
    double capital = accountBalance;
    double peakCapital = capital;
    double maxDrawdownPercent = 0;

    // 持仓状态
    double? entryPrice;
    String? entryDate;
    double? atrAtEntry;
    double? stopLoss;
    double? takeProfit;
    bool? isLong;
    int? entryIdx;

    // 统计
    double totalTrades = 0;
    double winningTrades = 0;
    double losingTrades = 0;
    double totalWin = 0;
    double totalLoss = 0;

    // 计算前20日高低点（用于判断趋势破坏）
    double? high20AtEntry;
    double? low20AtEntry;

    for (var i = period; i < quotes.length; i++) {
      final n = trueRanges[i - 1]; // quotes[i] 对应的N值

      // 计算最近 period 日的高低点
      double high20 = quotes[i - period].high;
      double low20 = quotes[i - period].low;
      double high10 = quotes[i - 10].high;
      double low10 = quotes[i - 10].low;
      for (var j = i - period + 1; j < i; j++) {
        if (quotes[j].high > high20) high20 = quotes[j].high;
        if (quotes[j].low < low20) low20 = quotes[j].low;
      }
      for (var j = i - 10 + 1; j < i; j++) {
        if (quotes[j].high > high10) high10 = quotes[j].high;
        if (quotes[j].low < low10) low10 = quotes[j].low;
      }

      final price = quotes[i].close;
      final atr = trueRanges[i - 1];

      // === 出场逻辑 ===
      if (entryPrice != null && entryIdx != null) {
        bool shouldExit = false;
        String exitReason = '';

        // 止损
        if (isLong! && price <= stopLoss!) {
          shouldExit = true;
          exitReason = '止损';
        } else if (!isLong! && price >= stopLoss!) {
          shouldExit = true;
          exitReason = '止损';
        }

        // 止盈（4N目标）
        if (!shouldExit) {
          if (isLong! && price >= takeProfit!) {
            shouldExit = true;
            exitReason = '止盈';
          } else if (!isLong! && price <= takeProfit!) {
            shouldExit = true;
            exitReason = '止盈';
          }
        }

        // 趋势破坏出场（10日低/高）
        if (!shouldExit) {
          if (isLong! && price <= low10) {
            shouldExit = true;
            exitReason = '趋势破坏';
          } else if (!isLong! && price >= high10) {
            shouldExit = true;
            exitReason = '趋势破坏';
          }
        }

        if (shouldExit) {
          final quantity = ((capital * (riskPercent / 100)) / (atr * stopLossN)).floor().toDouble();
          final grossProfit = isLong!
              ? (price - entryPrice!) * quantity
              : (entryPrice! - price) * quantity;
          final buyFee = entryPrice! * quantity * feeRate;
          final sellFee = price * quantity * feeRate;
          final stampTax = price * quantity * 0.001;
          final netProfit = grossProfit - buyFee - sellFee - stampTax;
          final profitPercent = (netProfit / (entryPrice! * quantity)) * 100;

          totalTrades++;
          if (netProfit > 0) {
            winningTrades++;
            totalWin += netProfit;
          } else {
            losingTrades++;
            totalLoss += netProfit.abs();
          }

          capital += netProfit;
          if (capital > peakCapital) peakCapital = capital;
          final dd = peakCapital > 0 ? (peakCapital - capital) / peakCapital * 100 : 0.0;
          if (dd > maxDrawdownPercent) maxDrawdownPercent = dd;

          trades.add(TurtleTrade(
            entryDate: entryDate!,
            entryPrice: entryPrice!,
            exitDate: quotes[i].date,
            exitPrice: price,
            quantity: quantity.toInt(),
            isLong: isLong!,
            profit: netProfit,
            profitPercent: profitPercent,
            holdingDays: i - entryIdx!,
            atrAtEntry: atrAtEntry!,
            atrAtExit: atr,
            stopLoss: stopLoss!,
            takeProfit: takeProfit!,
            exitReason: exitReason,
          ));

          entryPrice = null;
          entryDate = null;
          atrAtEntry = null;
          stopLoss = null;
          takeProfit = null;
          isLong = null;
          entryIdx = null;
          high20AtEntry = null;
          low20AtEntry = null;
        }
      }

      // === 入场逻辑 ===
      if (entryPrice == null && n > 0) {
        // 涨跌停检查
        if (i > period) {
          final prevClose = quotes[i - 1].close;
          final limitUp = prevClose * 1.10;
          final limitDown = prevClose * 0.90;
          if (quotes[i].open >= limitUp || quotes[i].open <= limitDown) continue;
        }

        if (price > high20) {
          // 做多入场
          isLong = true;
          entryPrice = price;
          entryDate = quotes[i].date;
          atrAtEntry = n;
          stopLoss = price - stopLossN * n;
          takeProfit = price + profitTargetN * n;
          entryIdx = i;
          high20AtEntry = high20;
          low20AtEntry = low20;
        } else if (price < low20) {
          // 做空入场
          isLong = false;
          entryPrice = price;
          entryDate = quotes[i].date;
          atrAtEntry = n;
          stopLoss = price + stopLossN * n;
          takeProfit = price - profitTargetN * n;
          entryIdx = i;
          high20AtEntry = high20;
          low20AtEntry = low20;
        }
      }
    }

    // 计算当前信号（最后一根K线）
    final lastQuote = quotes.last;
    double currentHigh20 = quotes[quotes.length - period].high;
    double currentLow20 = quotes[quotes.length - period].low;
    double currentAtr = 0;
    double sumAtr = 0;
    for (var i = trueRanges.length - period; i < trueRanges.length; i++) sumAtr += trueRanges[i];
    currentAtr = sumAtr / period;
    for (var j = quotes.length - period + 1; j < quotes.length; j++) {
      if (quotes[j].high > currentHigh20) currentHigh20 = quotes[j].high;
      if (quotes[j].low < currentLow20) currentLow20 = quotes[j].low;
    }

    TurtleSignalType currentSignal;
    if (lastQuote.close > currentHigh20) {
      currentSignal = TurtleSignalType.longBreakout;
    } else if (lastQuote.close < currentLow20) {
      currentSignal = TurtleSignalType.shortBreakout;
    } else {
      currentSignal = TurtleSignalType.none;
    }

    // 构建当前信号详情
    final currentDetails = TurtleDetails(
      currentPrice: lastQuote.close,
      high20: currentHigh20,
      low20: currentLow20,
      high10: quotes.skip(quotes.length - 10).map((q) => q.high).reduce(max),
      low10: quotes.skip(quotes.length - 10).map((q) => q.low).reduce(min),
      atr: currentAtr,
      atr14: trueRanges.length >= 14 ? trueRanges.skip(trueRanges.length - 14).reduce((a, b) => a + b) / 14 : 0,
      entryPrice: lastQuote.close,
      stopLoss: currentSignal == TurtleSignalType.longBreakout
          ? lastQuote.close - stopLossN * currentAtr
          : currentSignal == TurtleSignalType.shortBreakout
              ? lastQuote.close + stopLossN * currentAtr : 0,
      takeProfit: currentSignal == TurtleSignalType.longBreakout
          ? lastQuote.close + profitTargetN * currentAtr
          : currentSignal == TurtleSignalType.shortBreakout
              ? lastQuote.close - profitTargetN * currentAtr : 0,
      riskReward: currentAtr > 0 ? (stopLossN / 1).toDouble() : 0,
      positionSize: currentAtr > 0 ? (accountBalance * (riskPercent / 100)) / (currentAtr * stopLossN) : 0,
      signal: currentSignal,
      signalExplanation: currentSignal == TurtleSignalType.longBreakout
          ? '价格突破20日高点(${currentHigh20.toStringAsFixed(2)})，做多信号'
          : currentSignal == TurtleSignalType.shortBreakout
              ? '价格跌破20日低点(${currentLow20.toStringAsFixed(2)})，做空信号'
              : '价格未突破20日高低点，等待信号',
      stepDetails: [],
    );

    // 统计
    final winRate = totalTrades > 0 ? winningTrades / totalTrades * 100 : 0.0;
    final avgWin = winningTrades > 0 ? totalWin / winningTrades : 0.0;
    final avgLoss = losingTrades > 0 ? totalLoss / losingTrades : 0.0;
    final profitFactor = totalLoss > 0 ? totalWin / totalLoss : totalWin > 0 ? double.infinity : 0.0;
    final sharpeRatio = _calcSharpeRatio(trades);

    return TurtleBacktestResult(
      totalTrades: totalTrades.toInt(),
      winningTrades: winningTrades.toInt(),
      losingTrades: losingTrades.toInt(),
      winRate: winRate,
      totalProfit: capital - accountBalance,
      maxDrawdownPercent: maxDrawdownPercent,
      sharpeRatio: sharpeRatio,
      avgWin: avgWin,
      avgLoss: avgLoss,
      profitFactor: profitFactor.isFinite ? profitFactor : 0.0,
      trades: trades,
      initialCapital: accountBalance,
      finalCapital: capital,
      currentSignal: currentSignal,
      currentDetails: currentDetails,
    );
  }

  static double _trueRange(StockQuote current, StockQuote prev) {
    return max(max(current.high - current.low,
        (current.high - prev.close).abs()),
        (current.low - prev.close).abs());
  }

  static double _calcSharpeRatio(List<TurtleTrade> trades) {
    if (trades.length < 2) return 0;
    final returns = trades.map((t) => t.profitPercent).toList();
    final mean = returns.reduce((a, b) => a + b) / returns.length;
    final variance = returns.map((r) => pow(r - mean, 2)).reduce((a, b) => a + b) / returns.length;
    final stdDev = sqrt(variance);
    return stdDev > 0 ? (mean / stdDev) * sqrt(252 / 20) : 0;
  }

  static TurtleBacktestResult _emptyTurtleResult(double accountBalance) {
    return TurtleBacktestResult(
      totalTrades: 0,
      winningTrades: 0,
      losingTrades: 0,
      winRate: 0,
      totalProfit: 0,
      maxDrawdownPercent: 0,
      sharpeRatio: 0,
      avgWin: 0,
      avgLoss: 0,
      profitFactor: 0,
      trades: const [],
      initialCapital: accountBalance,
      finalCapital: accountBalance,
      currentSignal: TurtleSignalType.none,
      currentDetails: TurtleDetails(
        currentPrice: 0, high20: 0, low20: 0, high10: 0, low10: 0,
        atr: 0, atr14: 0, entryPrice: 0, stopLoss: 0, takeProfit: 0,
        riskReward: 0, positionSize: 0, signal: TurtleSignalType.none,
        signalExplanation: '数据不足', stepDetails: [],
      ),
    );
  }

  /// 计算海龟交易信号（原有方法，仅返回最后一根K线信号）
  static TurtleDetails calculate(List<StockQuote> quotes, {int period = 20, double accountBalance = 100000, double riskPercent = 1.0}) {
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
        '1. 入场：卖出价 = 跌破20日低点 $low20',
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

    // 计算仓位大小（每份风险 = 账户riskPercent%）
    final riskAmount = accountBalance * (riskPercent / 100);
    final positionSize = atr > 0 ? riskAmount / atr : 0.0;

    // 计算止损和止盈（基于入场价，而非当前价）
    // 海龟规则：止损 = 入场价 ± 2N，止盈 = 入场价 ± 4N（或2倍风险收益）
    double stopLoss = 0.0;
    double takeProfit = 0.0;
    if (signal == TurtleSignalType.longBreakout) {
      stopLoss = entryPrice - 2 * atr;
      takeProfit = entryPrice + 4 * atr; // 4N = 2倍风险收益（止损2N）
    } else if (signal == TurtleSignalType.shortBreakout) {
      stopLoss = entryPrice + 2 * atr;
      takeProfit = entryPrice - 4 * atr;
    }

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
