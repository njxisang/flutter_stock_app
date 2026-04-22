import 'dart:math';
import 'package:flutter_stock_app/domain/entities/stock_quote.dart';

enum BacktestStrategy { macd, kdj, rsi, boll, ma, wr, dmi, multi }

class BacktestCalculator {
  /// 执行回测
  /// [quotes] 股票数据
  /// [strategy] 策略类型
  /// [initialCapital] 初始资金
  /// [feeRate] 手续费率
  /// [positionRatio] 仓位比例
  static BacktestResult runBacktest(
    List<StockQuote> quotes,
    BacktestStrategy strategy, {
    double initialCapital = 100000,
    double feeRate = 0.001,
    double positionRatio = 1.0,
  }) {
    if (quotes.length < 30) {
      return _emptyResult(initialCapital);
    }

    final trades = <Trade>[];
    double capital = initialCapital;
    double position = 0;
    double entryPrice = 0;
    String? entryDate;
    bool isLong = true;
    double peakCapital = capital;

    double totalTrades = 0;
    double winningTrades = 0;
    double losingTrades = 0;
    double totalProfit = 0;
    double maxDrawdown = 0;
    double totalWin = 0;
    double totalLoss = 0;

    for (var i = 30; i < quotes.length; i++) {
      final signal = _getSignal(quotes.sublist(0, i + 1), strategy);

      // 入场
      if (position == 0 && signal != null) {
        isLong = signal['isLong'] as bool;
        entryPrice = quotes[i].close;
        entryDate = quotes[i].date;
        final maxPosition = (capital * positionRatio) / entryPrice;
        position = maxPosition.floor().toDouble();
        totalTrades++;
      }

      // 出场
      if (position > 0 && entryDate != null) {
        final exitPrice = quotes[i].close;
        final profit = isLong
            ? (exitPrice - entryPrice) * position
            : (entryPrice - exitPrice) * position;
        final fee = (entryPrice * position + exitPrice * position) * feeRate;
        final netProfit = profit - fee;
        totalProfit += netProfit;
        capital += netProfit;

        final holdingDays = quotes.indexOf(quotes.firstWhere((q) => q.date == entryDate)).clamp(0, quotes.length - 1);

        trades.add(Trade(
          entryDate: entryDate,
          entryPrice: entryPrice,
          exitDate: quotes[i].date,
          exitPrice: exitPrice,
          quantity: position.toInt(),
          isLong: isLong,
          profit: netProfit,
          profitPercent: (netProfit / (entryPrice * position)) * 100,
          holdingDays: i - quotes.indexWhere((q) => q.date == entryDate),
          fee: fee,
        ));

        if (netProfit > 0) {
          winningTrades++;
          totalWin += netProfit;
        } else {
          losingTrades++;
          totalLoss += netProfit.abs();
        }

        position = 0;
        entryDate = null;
      }

      // 更新最大回撤
      if (capital > peakCapital) peakCapital = capital;
      final drawdown = peakCapital - capital;
      if (drawdown > maxDrawdown) maxDrawdown = drawdown;
    }

    final winRate = totalTrades > 0 ? winningTrades / totalTrades * 100 : 0;
    final avgWin = winningTrades > 0 ? totalWin / winningTrades : 0;
    final avgLoss = losingTrades > 0 ? totalLoss / losingTrades : 0;
    final profitFactor = totalLoss > 0 ? totalWin / totalLoss : totalWin > 0 ? double.infinity : 0.0;
    final sharpeRatio = _calculateSharpeRatio(trades);
    final kellyPercent = winRate > 0 ? winRate - (100 - winRate) / (profitFactor > 0 ? profitFactor : 1) : 0;

    return BacktestResult(
      totalTrades: totalTrades.toInt(),
      winningTrades: winningTrades.toInt(),
      losingTrades: losingTrades.toInt(),
      winRate: winRate.toDouble(),
      totalProfit: totalProfit.toDouble(),
      maxDrawdown: maxDrawdown.toDouble(),
      maxDrawdownPercent: peakCapital > 0 ? maxDrawdown / peakCapital * 100 : 0.0,
      sharpeRatio: sharpeRatio.toDouble(),
      kellyPercent: kellyPercent.toDouble(),
      kellyFraction: kellyPercent > 0 ? '${(kellyPercent / 2).toStringAsFixed(1)}%' : '0%',
      avgWin: avgWin.toDouble(),
      avgLoss: avgLoss.toDouble(),
      profitFactor: profitFactor.isFinite ? profitFactor : 0.0,
      trades: trades,
      initialCapital: initialCapital.toDouble(),
      finalCapital: capital.toDouble(),
    );
  }

  static Map<String, dynamic>? _getSignal(List<StockQuote> quotes, BacktestStrategy strategy) {
    switch (strategy) {
      case BacktestStrategy.macd:
        return _macdSignal(quotes);
      case BacktestStrategy.kdj:
        return _kdjSignal(quotes);
      case BacktestStrategy.rsi:
        return _rsiSignal(quotes);
      case BacktestStrategy.boll:
        return _bollSignal(quotes);
      case BacktestStrategy.ma:
        return _maSignal(quotes);
      case BacktestStrategy.wr:
        return _wrSignal(quotes);
      case BacktestStrategy.dmi:
        return _dmiSignal(quotes);
      case BacktestStrategy.multi:
        return _multiSignal(quotes);
    }
  }

  static Map<String, dynamic>? _macdSignal(List<StockQuote> quotes) {
    if (quotes.length < 26) return null;

    final closes = quotes.map((q) => q.close).toList();
    final ema12 = _ema(closes, 12);
    final ema26 = _ema(closes, 26);

    if (quotes.length < 35) return null;

    final dif1 = ema12[ema12.length - 2];
    final dea1 = ema26[ema26.length - 2];
    final dif2 = ema12[ema12.length - 1];
    final dea2 = ema26[ema26.length - 1];

    if (dif1 <= dea1 && dif2 > dea2) return {'isLong': true};
    if (dif1 >= dea1 && dif2 < dea2) return {'isLong': false};
    return null;
  }

  static Map<String, dynamic>? _kdjSignal(List<StockQuote> quotes) {
    if (quotes.length < 9) return null;

    double highestHigh = quotes[quotes.length - 9].high;
    double lowestLow = quotes[quotes.length - 9].low;
    for (var i = quotes.length - 9; i < quotes.length; i++) {
      if (quotes[i].high > highestHigh) highestHigh = quotes[i].high;
      if (quotes[i].low < lowestLow) lowestLow = quotes[i].low;
    }

    final rsv = highestHigh == lowestLow ? 50 : (quotes.last.close - lowestLow) / (highestHigh - lowestLow) * 100;
    final k = 2 / 3 * 50 + 1 / 3 * rsv;
    final d = 2 / 3 * 50 + 1 / 3 * k;

    if (k < 20 && d < 20 && k > d) return {'isLong': true};
    if (k > 80 && d > 80 && k < d) return {'isLong': false};
    return null;
  }

  static Map<String, dynamic>? _rsiSignal(List<StockQuote> quotes) {
    if (quotes.length < 15) return null;

    double avgGain = 0, avgLoss = 0;
    for (var i = quotes.length - 14; i < quotes.length; i++) {
      final change = quotes[i].close - quotes[i - 1].close;
      if (change > 0) avgGain += change;
      else avgLoss += change.abs();
    }
    avgGain /= 14;
    avgLoss /= 14;
    final rsi = avgLoss == 0 ? 100 : 100 - (100 / (1 + avgGain / avgLoss));

    if (rsi < 30) return {'isLong': true};
    if (rsi > 70) return {'isLong': false};
    return null;
  }

  static Map<String, dynamic>? _bollSignal(List<StockQuote> quotes) {
    if (quotes.length < 20) return null;

    final closes = quotes.sublist(quotes.length - 20).map((q) => q.close).toList();
    final middle = closes.reduce((a, b) => a + b) / 20;

    var variance = 0.0;
    for (final c in closes) {
      variance += pow(c - middle, 2);
    }
    variance /= 19;
    final stdDev = sqrt(variance);

    final upper = middle + 2 * stdDev;
    final lower = middle - 2 * stdDev;
    final currentPrice = quotes.last.close;

    if (currentPrice < lower) return {'isLong': true};
    if (currentPrice > upper) return {'isLong': false};
    return null;
  }

  static Map<String, dynamic>? _maSignal(List<StockQuote> quotes) {
    if (quotes.length < 20) return null;

    double ma5 = 0, ma10 = 0, ma20 = 0;
    for (var i = 0; i < 5; i++) ma5 += quotes[quotes.length - 1 - i].close;
    for (var i = 0; i < 10; i++) ma10 += quotes[quotes.length - 1 - i].close;
    for (var i = 0; i < 20; i++) ma20 += quotes[quotes.length - 1 - i].close;
    ma5 /= 5;
    ma10 /= 10;
    ma20 /= 20;

    if (ma5 > ma10 && ma10 > ma20) return {'isLong': true};
    if (ma5 < ma10 && ma10 < ma20) return {'isLong': false};
    return null;
  }

  static Map<String, dynamic>? _wrSignal(List<StockQuote> quotes) {
    if (quotes.length < 10) return null;

    double highestHigh = quotes[quotes.length - 10].high;
    double lowestLow = quotes[quotes.length - 10].low;
    for (var i = quotes.length - 10; i < quotes.length; i++) {
      if (quotes[i].high > highestHigh) highestHigh = quotes[i].high;
      if (quotes[i].low < lowestLow) lowestLow = quotes[i].low;
    }

    final wr = highestHigh == lowestLow ? 50 : (highestHigh - quotes.last.close) / (highestHigh - lowestLow) * 100;

    if (wr > 80) return {'isLong': true};
    if (wr < 20) return {'isLong': false};
    return null;
  }

  static Map<String, dynamic>? _dmiSignal(List<StockQuote> quotes) {
    // 简化版DMI信号
    if (quotes.length < 14) return null;
    // 默认无信号
    return null;
  }

  static Map<String, dynamic>? _multiSignal(List<StockQuote> quotes) {
    // 多策略共振
    final macd = _macdSignal(quotes);
    final kdj = _kdjSignal(quotes);
    final rsi = _rsiSignal(quotes);

    int longCount = 0, shortCount = 0;
    if (macd != null) {
      if (macd['isLong']) longCount++;
      else shortCount++;
    }
    if (kdj != null) {
      if (kdj['isLong']) longCount++;
      else shortCount++;
    }
    if (rsi != null) {
      if (rsi['isLong']) longCount++;
      else shortCount++;
    }

    if (longCount >= 2) return {'isLong': true};
    if (shortCount >= 2) return {'isLong': false};
    return null;
  }

  static List<double> _ema(List<double> values, int period) {
    if (values.length < period) return [];
    final multiplier = 2.0 / (period + 1);
    final ema = <double>[];
    var sum = 0.0;
    for (var i = 0; i < period; i++) sum += values[i];
    var prevEma = sum / period;
    ema.add(prevEma);
    for (var i = period; i < values.length; i++) {
      final currentEma = (values[i] - prevEma) * multiplier + prevEma;
      ema.add(currentEma);
      prevEma = currentEma;
    }
    return ema;
  }

  static double _calculateSharpeRatio(List<Trade> trades) {
    if (trades.length < 2) return 0;
    final returns = trades.map((t) => t.profitPercent).toList();
    final mean = returns.reduce((a, b) => a + b) / returns.length;
    var variance = 0.0;
    for (final r in returns) {
      variance += pow(r - mean, 2);
    }
    variance /= returns.length;
    return mean / sqrt(variance);
  }

  static BacktestResult _emptyResult(double initialCapital) {
    return BacktestResult(
      totalTrades: 0,
      winningTrades: 0,
      losingTrades: 0,
      winRate: 0,
      totalProfit: 0,
      maxDrawdown: 0,
      maxDrawdownPercent: 0,
      sharpeRatio: 0,
      kellyPercent: 0,
      kellyFraction: '0%',
      avgWin: 0,
      avgLoss: 0,
      profitFactor: 0,
      trades: [],
      initialCapital: initialCapital,
      finalCapital: initialCapital,
    );
  }
}
