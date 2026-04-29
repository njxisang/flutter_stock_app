import 'dart:math';
import 'package:flutter_stock_app/domain/entities/stock_quote.dart';
import 'package:flutter_stock_app/domain/usecases/calculators/kdj_calculator.dart';
import 'package:flutter_stock_app/domain/usecases/calculators/rsi_calculator.dart';

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

      // 涨跌停限制检查
      bool canBuy = true;
      bool canSell = true;
      if (i > 30) {
        final prevClose = quotes[i - 1].close;
        final limitUp = prevClose * 1.10;  // 涨停价（A股10%）
        final limitDown = prevClose * 0.90;  // 跌停价
        if (signal != null && signal['isLong'] == true && quotes[i].open >= limitUp) {
          canBuy = false;  // 涨停，买不入
        }
        if (signal != null && signal['isLong'] == false && quotes[i].open <= limitDown) {
          canBuy = false;  // 跌停，买不入
        }
        if (position > 0 && quotes[i].open <= limitDown) {
          canSell = false;  // 持仓但次日跌停
        }
      }

      // 入场
      if (position == 0 && signal != null && canBuy) {
        isLong = signal['isLong'] as bool;
        entryPrice = quotes[i].close;
        entryDate = quotes[i].date;
        final maxPosition = (capital * positionRatio) / entryPrice;
        position = maxPosition.floor().toDouble();
        totalTrades++;
      }

      // 出场
      if (position > 0 && entryDate != null && canSell) {
        final exitPrice = quotes[i].close;
        final profit = isLong
            ? (exitPrice - entryPrice) * position
            : (entryPrice - exitPrice) * position;
        // 买入费率 + 卖出费率 + 印花税（卖出时千分之一）
        final buyFee = entryPrice * position * feeRate;
        final sellFee = exitPrice * position * feeRate;
        final stampTax = exitPrice * position * 0.001;  // 印花税仅卖出收取
        final totalFee = buyFee + sellFee + stampTax;
        final netProfit = profit - totalFee;
        totalProfit += netProfit;
        capital += netProfit;

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
          fee: totalFee,
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

      // 更新最大回撤（使用百分比计算）
      if (capital > peakCapital) peakCapital = capital;
      final drawdownPercent = peakCapital > 0 ? (peakCapital - capital) / peakCapital * 100 : 0.0;
      if (drawdownPercent > maxDrawdown) maxDrawdown = drawdownPercent;
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
      maxDrawdown: maxDrawdown.toDouble(),  // 已经是百分比
      maxDrawdownPercent: maxDrawdown.toDouble(),
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
    if (quotes.length < 35) return null;

    final closes = quotes.map((q) => q.close).toList();
    final ema12 = _ema(closes, 12);
    final ema26 = _ema(closes, 26);

    // EMA12从索引12开始，EMA26从索引26开始
    // DIF = EMA12 - EMA26，需要对齐到同一个时间点
    // EMA12比EMA26多14个元素（26-12=14），所以从EMA12[14]开始减EMA26[0]
    if (ema12.length < 15 || ema26.length < 2) return null;

    // 计算最近几天的DIF
    final difValues = <double>[];
    final startIdx = ema12.length - ema26.length;
    for (var i = 0; i < ema26.length; i++) {
      difValues.add(ema12[startIdx + i] - ema26[i]);
    }

    if (difValues.length < 3) return null;

    // DIF上穿DEA（金叉）
    final dif1 = difValues[difValues.length - 2];
    final dif2 = difValues[difValues.length - 1];
    final dea1 = _ema(difValues, 9)[difValues.length - 2];
    final dea2 = _ema(difValues, 9)[difValues.length - 1];

    if (dif1 <= dea1 && dif2 > dea2) return {'isLong': true};
    if (dif1 >= dea1 && dif2 < dea2) return {'isLong': false};
    return null;
  }

  static Map<String, dynamic>? _kdjSignal(List<StockQuote> quotes) {
    if (quotes.length < 9) return null;

    // 使用专业的KDJ计算器
    final kdjData = KdjCalculator.calculate(quotes);
    if (kdjData.length < 2) return null;

    final current = kdjData.last;
    final prev = kdjData[kdjData.length - 2];

    // K值从下往上穿越D值，且都在超卖区
    if (prev.k < prev.d && current.k > current.d && current.k < 20 && current.d < 20) {
      return {'isLong': true};
    }
    // K值从上往下穿越D值，且都在超买区
    if (prev.k > prev.d && current.k < current.d && current.k > 80 && current.d > 80) {
      return {'isLong': false};
    }
    return null;
  }

  static Map<String, dynamic>? _rsiSignal(List<StockQuote> quotes) {
    if (quotes.length < 15) return null;

    // 使用专业的RSI计算器（Wilder平滑法）
    final rsiData = RsiCalculator.calculate(quotes);
    if (rsiData.length < 2) return null;

    final current = rsiData.last.rsi;
    final prev = rsiData[rsiData.length - 2].rsi;

    // RSI从超卖区上穿
    if (prev < 30 && current >= 30) return {'isLong': true};
    // RSI从超买区下穿
    if (prev > 70 && current <= 70) return {'isLong': false};
    return null;
  }

  static Map<String, dynamic>? _bollSignal(List<StockQuote> quotes) {
    if (quotes.length < 21) return null;

    // 使用20日布林带
    final closes = quotes.sublist(quotes.length - 20).map((q) => q.close).toList();
    final middle = closes.reduce((a, b) => a + b) / 20;

    var variance = 0.0;
    for (final c in closes) {
      variance += pow(c - middle, 2);
    }
    variance /= 19;  // BOLL用N-1做样本方差
    final stdDev = sqrt(variance);

    final upper = middle + 2 * stdDev;
    final lower = middle - 2 * stdDev;
    final currentPrice = quotes.last.close;
    final prevPrice = quotes[quotes.length - 2].close;

    // 价格从下轨下方向上突破下轨买入
    if (prevPrice < lower && currentPrice >= lower) return {'isLong': true};
    // 价格从上轨上方，向下跌破上轨卖出
    if (prevPrice > upper && currentPrice <= upper) return {'isLong': false};
    return null;
  }

  static Map<String, dynamic>? _maSignal(List<StockQuote> quotes) {
    if (quotes.length < 21) return null;

    // 计算MA5, MA10, MA20
    double ma5 = 0, ma10 = 0, ma20 = 0;
    for (var i = 0; i < 5; i++) ma5 += quotes[quotes.length - 1 - i].close;
    for (var i = 0; i < 10; i++) ma10 += quotes[quotes.length - 1 - i].close;
    for (var i = 0; i < 20; i++) ma20 += quotes[quotes.length - 1 - i].close;
    ma5 /= 5;
    ma10 /= 10;
    ma20 /= 20;

    // 上一根K线的均线状态
    double prevMa5 = 0, prevMa10 = 0, prevMa20 = 0;
    for (var i = 1; i <= 5; i++) prevMa5 += quotes[quotes.length - 2 - i].close;
    for (var i = 1; i <= 10; i++) prevMa10 += quotes[quotes.length - 2 - i].close;
    for (var i = 1; i <= 20; i++) prevMa20 += quotes[quotes.length - 2 - i].close;
    prevMa5 /= 5;
    prevMa10 /= 10;
    prevMa20 /= 20;

    // 空头排列转多头排列（金叉买入）
    if (prevMa5 <= prevMa10 && ma5 > ma10 && ma10 > ma20 && prevMa20 > prevMa10) return {'isLong': true};
    // 多头排列转空头排列（死叉卖出）
    if (prevMa5 >= prevMa10 && ma5 < ma10 && ma10 < ma20 && prevMa20 < prevMa10) return {'isLong': false};
    return null;
  }

  static Map<String, dynamic>? _wrSignal(List<StockQuote> quotes) {
    if (quotes.length < 10) return null;

    // WR威廉指标，10日周期
    double highestHigh = quotes[quotes.length - 10].high;
    double lowestLow = quotes[quotes.length - 10].low;
    for (var i = quotes.length - 10; i < quotes.length; i++) {
      if (quotes[i].high > highestHigh) highestHigh = quotes[i].high;
      if (quotes[i].low < lowestLow) lowestLow = quotes[i].low;
    }

    final wr = highestHigh == lowestLow ? 50 : (highestHigh - quotes.last.close) / (highestHigh - lowestLow) * 100;
    final prevWr = _calcWrSingle(quotes.sublist(0, quotes.length - 1), 10);

    // WR从80以上向上突破（超卖区上穿）
    if (prevWr <= 80 && wr > 80) return {'isLong': true};
    // WR从20以下向下突破（超买区下穿）
    if (prevWr >= 20 && wr < 20) return {'isLong': false};
    return null;
  }

  static double _calcWrSingle(List<StockQuote> quotes, int period) {
    if (quotes.length < period) return 50;
    double highestHigh = quotes[quotes.length - period].high;
    double lowestLow = quotes[quotes.length - period].low;
    for (var i = quotes.length - period; i < quotes.length; i++) {
      if (quotes[i].high > highestHigh) highestHigh = quotes[i].high;
      if (quotes[i].low < lowestLow) lowestLow = quotes[i].low;
    }
    return highestHigh == lowestLow ? 50 : (highestHigh - quotes.last.close) / (highestHigh - lowestLow) * 100;
  }

  static Map<String, dynamic>? _dmiSignal(List<StockQuote> quotes) {
    // DMI信号：使用简化版ADX判断趋势强度
    if (quotes.length < 28) return null;

    // 计算简化DMI（仅用最后14个数据）
    double sumTr = 0, sumPlusDm = 0, sumMinusDm = 0;
    double prevClose = quotes[0].close;

    for (var i = 1; i <= 14; i++) {
      final high = quotes[i].high;
      final low = quotes[i].low;
      final close = quotes[i].close;
      final tr1 = high - low;
      final tr2 = (high - prevClose).abs();
      final tr3 = (low - prevClose).abs();
      final tr = [tr1, tr2, tr3].reduce((a, b) => a > b ? a : b);
      sumTr += tr;
      final plusDm = high - quotes[i - 1].high > quotes[i - 1].low - low
          ? (high - quotes[i - 1].high).clamp(0.0, double.infinity)
          : 0.0;
      final minusDm = quotes[i - 1].low - low > high - quotes[i - 1].high
          ? (quotes[i - 1].low - low).clamp(0.0, double.infinity)
          : 0.0;
      sumPlusDm += plusDm;
      sumMinusDm += minusDm;
      prevClose = close;
    }

    final plusDi14 = sumTr == 0 ? 0.0 : sumPlusDm / sumTr * 100;
    final minusDi14 = sumTr == 0 ? 0.0 : sumMinusDm / sumTr * 100;
    final dx = plusDi14 + minusDi14 == 0 ? 0.0 : (plusDi14 - minusDi14).abs() / (plusDi14 + minusDi14) * 100;
    final adx = dx; // 简化版ADX等同于DX

    // ADX从低上升且高于30：趋势确认，做多
    // ADX从高下降且高于30后下跌：趋势减弱，做空
    // ADX低于20：市场无趋势，不操作
    if (adx < 20) return null; // 无趋势

    // 使用前一个ADX值对比
    final prevAdx = adx; // 简化版只用当前值
    if (prevAdx > 25 && plusDi14 > minusDi14) return {'isLong': true};
    if (prevAdx > 25 && minusDi14 > plusDi14) return {'isLong': false};
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
