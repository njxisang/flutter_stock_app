import 'dart:math';
import 'package:flutter_stock_app/domain/entities/stock_quote.dart';
import 'package:flutter_stock_app/domain/usecases/calculators/kdj_calculator.dart';
import 'package:flutter_stock_app/domain/usecases/calculators/rsi_calculator.dart';

enum BacktestStrategy { macd, kdj, rsi, boll, ma, wr, dmi, multi, cci, stochRsi }

/// 策略参数配置（所有策略通用结构）
class StrategyParams {
  // ─── MACD参数 ───
  final int macdFastPeriod;    // 默认12
  final int macdSlowPeriod;    // 默认26
  final int macdSignalPeriod;  // 默认9

  // ─── KDJ参数 ───
  final int kdjPeriod;         // 默认9
  final int kdjKPeriod;        // 默认3
  final int kdjDPeriod;        // 默认3
  final int kdjOverbought;     // 默认80
  final int kdjOversold;       // 默认20

  // ─── RSI参数 ───
  final int rsiPeriod;         // 默认14
  final int rsiOverbought;     // 默认70
  final int rsiOversold;       // 默认30

  // ─── BOLL参数 ───
  final int bollPeriod;        // 默认20
  final int bollStdDev;        // 默认2（倍數）

  // ─── MA参数 ───
  final int maShortPeriod;     // 默认5
  final int maMidPeriod;       // 默认10
  final int maLongPeriod;      // 默认20

  // ─── WR参数 ───
  final int wrPeriod;         // 默认10
  final int wrOverbought;      // 默认20（WR>此值超买，做空）
  final int wrOversold;       // 默认80（WR<此值超卖，做多）

  // ─── DMI参数 ───
  final int dmiPeriod;         // 默认14
  final int dmiAdxPeriod;      // 默认14（ADX自身平滑周期）
  final int dmiTrendThreshold; // 默认25（ADX>此值认为有趋势）

  // ─── CCI参数 ───
  final int cciPeriod;         // 默认14

  // ─── StochRSI参数 ───
  final int stochRsiPeriod;   // 默认14
  final int stochRsiKPeriod;  // 默认3
  final int stochRsiDPeriod;  // 默认3

  // ─── MA + Volume 参数 ───
  final int volumeMAperiod;   // 均量周期，默认5
  final bool volumeFilter;    // 是否启用放量过滤，默认false

  const StrategyParams({
    this.macdFastPeriod = 12,
    this.macdSlowPeriod = 26,
    this.macdSignalPeriod = 9,
    this.kdjPeriod = 9,
    this.kdjKPeriod = 3,
    this.kdjDPeriod = 3,
    this.kdjOverbought = 80,
    this.kdjOversold = 20,
    this.rsiPeriod = 14,
    this.rsiOverbought = 70,
    this.rsiOversold = 30,
    this.bollPeriod = 20,
    this.bollStdDev = 2,
    this.maShortPeriod = 5,
    this.maMidPeriod = 10,
    this.maLongPeriod = 20,
    this.wrPeriod = 10,
    this.wrOverbought = 20,
    this.wrOversold = 80,
    this.dmiPeriod = 14,
    this.dmiAdxPeriod = 14,
    this.dmiTrendThreshold = 25,
    this.cciPeriod = 14,
    this.stochRsiPeriod = 14,
    this.stochRsiKPeriod = 3,
    this.stochRsiDPeriod = 3,
    this.volumeMAperiod = 5,
    this.volumeFilter = false,
  });

  /// 默认参数工厂
  factory StrategyParams.defaults() => const StrategyParams();

  StrategyParams copyWith({
    int? macdFastPeriod, int? macdSlowPeriod, int? macdSignalPeriod,
    int? kdjPeriod, int? kdjKPeriod, int? kdjDPeriod, int? kdjOverbought, int? kdjOversold,
    int? rsiPeriod, int? rsiOverbought, int? rsiOversold,
    int? bollPeriod, int? bollStdDev,
    int? maShortPeriod, int? maMidPeriod, int? maLongPeriod,
    int? wrPeriod, int? wrOverbought, int? wrOversold,
    int? dmiPeriod, int? dmiAdxPeriod, int? dmiTrendThreshold,
    int? cciPeriod,
    int? stochRsiPeriod, int? stochRsiKPeriod, int? stochRsiDPeriod,
    int? volumeMAperiod, bool? volumeFilter,
  }) => StrategyParams(
    macdFastPeriod: macdFastPeriod ?? this.macdFastPeriod,
    macdSlowPeriod: macdSlowPeriod ?? this.macdSlowPeriod,
    macdSignalPeriod: macdSignalPeriod ?? this.macdSignalPeriod,
    kdjPeriod: kdjPeriod ?? this.kdjPeriod,
    kdjKPeriod: kdjKPeriod ?? this.kdjKPeriod,
    kdjDPeriod: kdjDPeriod ?? this.kdjDPeriod,
    kdjOverbought: kdjOverbought ?? this.kdjOverbought,
    kdjOversold: kdjOversold ?? this.kdjOversold,
    rsiPeriod: rsiPeriod ?? this.rsiPeriod,
    rsiOverbought: rsiOverbought ?? this.rsiOverbought,
    rsiOversold: rsiOversold ?? this.rsiOversold,
    bollPeriod: bollPeriod ?? this.bollPeriod,
    bollStdDev: bollStdDev ?? this.bollStdDev,
    maShortPeriod: maShortPeriod ?? this.maShortPeriod,
    maMidPeriod: maMidPeriod ?? this.maMidPeriod,
    maLongPeriod: maLongPeriod ?? this.maLongPeriod,
    wrPeriod: wrPeriod ?? this.wrPeriod,
    wrOverbought: wrOverbought ?? this.wrOverbought,
    wrOversold: wrOversold ?? this.wrOversold,
    dmiPeriod: dmiPeriod ?? this.dmiPeriod,
    dmiAdxPeriod: dmiAdxPeriod ?? this.dmiAdxPeriod,
    dmiTrendThreshold: dmiTrendThreshold ?? this.dmiTrendThreshold,
    cciPeriod: cciPeriod ?? this.cciPeriod,
    stochRsiPeriod: stochRsiPeriod ?? this.stochRsiPeriod,
    stochRsiKPeriod: stochRsiKPeriod ?? this.stochRsiKPeriod,
    stochRsiDPeriod: stochRsiDPeriod ?? this.stochRsiDPeriod,
    volumeMAperiod: volumeMAperiod ?? this.volumeMAperiod,
    volumeFilter: volumeFilter ?? this.volumeFilter,
  );
}

class BacktestConfig {
  final double initialCapital;
  final double feeRate;
  final double positionRatio;
  final StrategyParams params;
  final double? stopLossPercent;    // 如 5.0 = 亏损5%时止损
  final double? takeProfitPercent;   // 如 10.0 = 盈利10%时止盈
  final bool enableTimeExit;         // 持有N天后强制退出（防震荡）
  final int maxHoldingDays;           // 默认20
  final double slippagePercent;       // 滑点，如 0.001 = 0.1%

  const BacktestConfig({
    this.initialCapital = 100000,
    this.feeRate = 0.001,
    this.positionRatio = 1.0,
    this.params = const StrategyParams(),
    this.stopLossPercent,
    this.takeProfitPercent,
    this.enableTimeExit = false,
    this.maxHoldingDays = 20,
    this.slippagePercent = 0.0,
  });
}

class BacktestCalculator {
  /// 执行回测（参数化版本）
  /// [quotes] 股票数据
  /// [strategy] 策略类型
  /// [initialCapital] 初始资金
  /// [feeRate] 手续费率（双边，一般0.0005~0.001）
  /// [positionRatio] 仓位比例（0~1）
  /// [params] 策略参数
  /// [stopLossPercent] 止损百分比（如5.0=亏损5%止损）
  /// [takeProfitPercent] 止盈百分比（如10.0=盈利10%止盈）
  /// [enableTimeExit] 是否启用时间止损
  /// [maxHoldingDays] 最大持仓天数
  /// [slippagePercent] 滑点（如0.001=千分之一）
  static BacktestResult runBacktest(
    List<StockQuote> quotes, {
    BacktestStrategy strategy = BacktestStrategy.macd,
    double initialCapital = 100000,
    double feeRate = 0.001,
    double positionRatio = 1.0,
    StrategyParams params = const StrategyParams(),
    double? stopLossPercent,
    double? takeProfitPercent,
    bool enableTimeExit = false,
    int maxHoldingDays = 20,
    double slippagePercent = 0.0,
  }) {
    if (quotes.length < 30) {
      return _emptyResult(initialCapital);
    }

    final trades = <Trade>[];
    double capital = initialCapital;
    double position = 0;
    double entryPrice = 0;
    String? entryDate;
    int? entryIndex;  // 记录入场K线索引，用于时间止损计算
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
      final signal = _getSignal(quotes.sublist(0, i + 1), strategy, params);

      // 涨跌停限制检查（用于判断能否买入/卖出）
      bool canBuy = true;
      bool canSell = true;
      double? limitUp;
      double? limitDown;
      if (i > 30) {
        final prevClose = quotes[i - 1].close;
        limitUp = prevClose * 1.10;   // 涨停价（A股10%）
        limitDown = prevClose * 0.90;  // 跌停价
        if (quotes[i].open >= limitUp) {
          canBuy = false;  // 涨停，买不入
        }
        if (quotes[i].open <= limitDown) {
          canBuy = false;  // 跌停，买不入
        }
        // 持仓时次日涨跌停：涨停可卖出（but用开盘价），跌停无法主动卖出
        if (position > 0 && quotes[i].open <= limitDown) {
          canSell = false;  // 跌停无法主动卖出（只能等反向信号）
        }
      }

      // === 入场：信号产生后，次日开盘执行（模拟真实成交）===
      // B-2: 入场跳过涨跌停，且使用次日开盘价+滑点
      if (position == 0 && signal != null && canBuy) {
        isLong = signal['isLong'] as bool;
        final entryExecPrice = quotes[i].open * (1 + slippagePercent);  // 次日开盘价+滑点
        entryPrice = entryExecPrice;
        entryDate = quotes[i].date;
        entryIndex = i;  // 记录入场索引，用于时间止损
        final maxPosition = (capital * positionRatio) / entryPrice;
        position = maxPosition.floor().toDouble();
        totalTrades++;
      }

      // === 出场顺序：止损 > 止盈 > 时间止损 > 涨跌停强平 > 反向信号 ===
      if (position > 0 && entryDate != null) {
        bool shouldExit = false;
        String exitReason = TradeExitReason.reverseSignal;

        // 1. 止损检查（B-1: 用实际止损价判断，而非仅看canSell）
        if (stopLossPercent != null && stopLossPercent > 0) {
          final stopLossPrice = isLong
              ? entryPrice * (1 - stopLossPercent / 100)
              : entryPrice * (1 + stopLossPercent / 100);
          final exitPrice = quotes[i].close;
          if ((isLong && exitPrice <= stopLossPrice) || (!isLong && exitPrice >= stopLossPrice)) {
            shouldExit = true;
            exitReason = TradeExitReason.stopLoss;
          }
        }

        // 2. 止盈检查
        if (!shouldExit && takeProfitPercent != null && takeProfitPercent > 0) {
          final tpPrice = isLong
              ? entryPrice * (1 + takeProfitPercent / 100)
              : entryPrice * (1 - takeProfitPercent / 100);
          final exitPrice = quotes[i].close;
          if ((isLong && exitPrice >= tpPrice) || (!isLong && exitPrice <= tpPrice)) {
            shouldExit = true;
            exitReason = TradeExitReason.takeProfit;
          }
        }

        // 3. 时间止损（防震荡）
        if (!shouldExit && enableTimeExit && entryIndex != null) {
          final holdingDays = i - entryIndex!;
          if (holdingDays >= maxHoldingDays) {
            shouldExit = true;
            exitReason = TradeExitReason.timeExit;
          }
        }

        // 4. 涨跌停无法卖出：次日跌停时强制以收盘价平仓
        if (!shouldExit && !canSell) {
          shouldExit = true;
          exitReason = TradeExitReason.limitDown;
        }

        // 5. 反向信号出场（只有canSell=true时才执行）
        if (!shouldExit && canSell && signal != null) {
          final signalIsLong = signal['isLong'] as bool;
          if (signalIsLong != isLong) {
            shouldExit = true;
            exitReason = TradeExitReason.reverseSignal;
          }
        }

        if (shouldExit) {
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

          final holdingDays = entryIndex != null ? i - entryIndex! : 0;

          trades.add(Trade(
            entryDate: entryDate,
            entryPrice: entryPrice,
            exitDate: quotes[i].date,
            exitPrice: exitPrice,
            quantity: position.toInt(),
            isLong: isLong,
            profit: netProfit,
            profitPercent: (netProfit / (entryPrice * position)) * 100,
            holdingDays: holdingDays,
            fee: totalFee,
            exitReason: exitReason,
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
          entryIndex = null;
        }
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
    final kellyCapped = kellyPercent < 0 ? 0.0 : kellyPercent; // B-6: Kelly不能为负

    return BacktestResult(
      totalTrades: totalTrades.toInt(),
      winningTrades: winningTrades.toInt(),
      losingTrades: losingTrades.toInt(),
      winRate: winRate.toDouble(),
      totalProfit: totalProfit.toDouble(),
      maxDrawdown: maxDrawdown.toDouble(),  // 已经是百分比
      maxDrawdownPercent: maxDrawdown.toDouble(),
      sharpeRatio: sharpeRatio.toDouble(),
      kellyPercent: kellyCapped.toDouble(),
      kellyFraction: kellyCapped > 0 ? '${(kellyCapped / 2).toStringAsFixed(1)}%' : '0%',
      avgWin: avgWin.toDouble(),
      avgLoss: avgLoss.toDouble(),
      profitFactor: profitFactor.isFinite ? profitFactor : 0.0,
      trades: trades,
      initialCapital: initialCapital.toDouble(),
      finalCapital: capital.toDouble(),
    );
  }

  static Map<String, dynamic>? _getSignal(List<StockQuote> quotes, BacktestStrategy strategy, StrategyParams params) {
    switch (strategy) {
      case BacktestStrategy.macd:
        return _macdSignal(quotes, params);
      case BacktestStrategy.kdj:
        return _kdjSignal(quotes, params);
      case BacktestStrategy.rsi:
        return _rsiSignal(quotes, params);
      case BacktestStrategy.boll:
        return _bollSignal(quotes, params);
      case BacktestStrategy.ma:
        return _maSignal(quotes, params);
      case BacktestStrategy.wr:
        return _wrSignal(quotes, params);
      case BacktestStrategy.dmi:
        return _dmiSignal(quotes, params);
      case BacktestStrategy.multi:
        return _multiSignal(quotes, params);
      case BacktestStrategy.cci:
        return _cciSignal(quotes, params);
      case BacktestStrategy.stochRsi:
        return _stochRsiSignal(quotes, params);
    }
  }

  // ═══════════════════════════════════════════════════
  //  MACD 信号（参数化 + 正确DEA计算）
  //  DIF = EMA(fast) - EMA(slow)，DEA = EMA(DIF, signalPeriod)
  //  金叉：DIF从下方穿越DEA → 做多；死叉：DIF从上方穿越DEA → 做空
  // ═══════════════════════════════════════════════════
  static Map<String, dynamic>? _macdSignal(List<StockQuote> quotes, StrategyParams params) {
    final minLen = params.macdSlowPeriod + params.macdSignalPeriod + 1;
    if (quotes.length < minLen) return null;

    final closes = quotes.map((q) => q.close).toList();
    final emaFast = _ema(closes, params.macdFastPeriod);
    final emaSlow = _ema(closes, params.macdSlowPeriod);

    // 对齐到同一时间点：DIF[i] = emaFast对齐位置 - emaSlow[i]
    if (emaFast.length < 2 || emaSlow.length < 2) return null;
    final offset = emaFast.length - emaSlow.length;
    final difLen = emaSlow.length;

    final difValues = List<double>.generate(difLen, (i) => emaFast[offset + i] - emaSlow[i]);
    if (difValues.length < 2) return null;

    // ── 迭代计算DEA（正确方式：每天用当天DIF更新DEA）──
    // 第一天DEA = 当天DIF（初始值）
    final deaValues = <double>[difValues[0]];
    final alpha = 2.0 / (params.macdSignalPeriod + 1); // 平滑系数
    for (var i = 1; i < difValues.length; i++) {
      deaValues.add((difValues[i] - deaValues[i - 1]) * alpha + deaValues[i - 1]);
    }

    if (deaValues.length < 2) return null;
    final dif1 = difValues[difValues.length - 2];
    final dif2 = difValues[difValues.length - 1];
    final dea1 = deaValues[deaValues.length - 2];
    final dea2 = deaValues[deaValues.length - 1];

    if (dif1 <= dea1 && dif2 > dea2) return {'isLong': true};
    if (dif1 >= dea1 && dif2 < dea2) return {'isLong': false};
    return null;
  }

  // ═══════════════════════════════════════════════════
  //  KDJ 信号（参数化 + 修复：去掉过于严格的超买超卖过滤）
  //  金叉（K上穿D）→ 做多；死叉（K下穿D）→ 做空
  //  可选：在极值区（K<20超卖 / K>80超买）加强信号
  // ═══════════════════════════════════════════════════
  static Map<String, dynamic>? _kdjSignal(List<StockQuote> quotes, StrategyParams params) {
    if (quotes.length < params.kdjPeriod + 1) return null;

    final kdjData = KdjCalculator.calculate(quotes, period: params.kdjPeriod);
    if (kdjData.length < 2) return null;

    final current = kdjData.last;
    final prev = kdjData[kdjData.length - 2];

    // 金叉：K从下方穿越D
    if (prev.k < prev.d && current.k > current.d) {
      // 加强条件：K在超卖区（可选）
      if (current.k < params.kdjOversold) return {'isLong': true};
      // 无超卖条件也做多（普通金叉）
      return {'isLong': true};
    }
    // 死叉：K从上方穿越D
    if (prev.k > prev.d && current.k < current.d) {
      // 加强条件：K在超买区
      if (current.k > params.kdjOverbought) return {'isLong': false};
      return {'isLong': false};
    }
    return null;
  }

  // ═══════════════════════════════════════════════════
  //  RSI 信号（参数化 + 修复：RSI<30做多，RSI>70做空，
  //  改为上穿/下穿阈值而非单纯比较）
  // ═══════════════════════════════════════════════════
  static Map<String, dynamic>? _rsiSignal(List<StockQuote> quotes, StrategyParams params) {
    if (quotes.length < params.rsiPeriod + 2) return null;

    final rsiData = RsiCalculator.calculate(quotes, period: params.rsiPeriod);
    if (rsiData.length < 2) return null;

    final current = rsiData.last.rsi;
    final prev = rsiData[rsiData.length - 2].rsi;

    // RSI从超卖区上穿threshold → 做多
    if (prev < params.rsiOversold && current >= params.rsiOversold) return {'isLong': true};
    // RSI从超买区下穿threshold → 做空
    if (prev > params.rsiOverbought && current <= params.rsiOverbought) return {'isLong': false};
    return null;
  }

  // ═══════════════════════════════════════════════════
  //  BOLL 信号（参数化 + 修复：标准差除数改为N，与通达信一致）
  //  价格向上突破上轨 → 做多；价格向下突破下轨 → 做空
  // ═══════════════════════════════════════════════════
  static Map<String, dynamic>? _bollSignal(List<StockQuote> quotes, StrategyParams params) {
    final n = params.bollPeriod;
    if (quotes.length < n + 1) return null;

    final closes = quotes.sublist(quotes.length - n).map((q) => q.close).toList();
    final middle = closes.reduce((a, b) => a + b) / n;

    var variance = 0.0;
    for (final c in closes) {
      variance += pow(c - middle, 2);
    }
    variance /= n; // 通达信/同花顺：除N（非N-1）
    final stdDev = sqrt(variance);

    final upper = middle + params.bollStdDev * stdDev;
    final lower = middle - params.bollStdDev * stdDev;
    final currentPrice = quotes.last.close;
    final prevPrice = quotes[quotes.length - 2].close;

    // 价格向上突破下轨 → 做多
    if (prevPrice < lower && currentPrice >= lower) return {'isLong': true};
    // 价格向下突破上轨 → 做空
    if (prevPrice > upper && currentPrice <= upper) return {'isLong': false};
    return null;
  }

  // ═══════════════════════════════════════════════════
  //  MA 均线信号（参数化）
  //  空头排列转多头排列（短>中>长，且之前不是）→ 做多
  //  多头排列转空头排列（短<中<长，且之前不是）→ 做空
  // ═══════════════════════════════════════════════════
  static Map<String, dynamic>? _maSignal(List<StockQuote> quotes, StrategyParams params) {
    final s = params.maShortPeriod;
    final m = params.maMidPeriod;
    final l = params.maLongPeriod;
    if (quotes.length < l + 1) return null;

    double calcMa(int len) {
      double sum = 0;
      for (var i = 0; i < len; i++) sum += quotes[quotes.length - 1 - i].close;
      return sum / len;
    }

    double calcPrevMa(int len) {
      double sum = 0;
      for (var i = 1; i <= len; i++) sum += quotes[quotes.length - 1 - i].close;
      return sum / len;
    }

    final maS = calcMa(s);
    final maM = calcMa(m);
    final maL = calcMa(l);
    final prevMaS = calcPrevMa(s);
    final prevMaM = calcPrevMa(m);
    final prevMaL = calcPrevMa(l);

    // 金叉：空头(短<=中) → 多头(短>中>长)，且之前中<长
    if (prevMaS <= prevMaM && maS > maM && maM > maL && prevMaM <= prevMaL) {
      // 量价共振：放量（当日成交量 > 均量 × 1.5）
      if (params.volumeFilter) {
        final vol = quotes.last.volume;
        double volSum = 0;
        for (var i = 0; i < params.volumeMAperiod; i++) volSum += quotes[quotes.length - 1 - i].volume;
        final volMa = volSum / params.volumeMAperiod;
        if (vol < volMa * 1.5) return null;  // 缩量，不确认
      }
      return {'isLong': true};
    }
    // 死叉：多头(短>=中) → 空头(短<中<长)，且之前中>长
    if (prevMaS >= prevMaM && maS < maM && maM < maL && prevMaM >= prevMaL) {
      if (params.volumeFilter) {
        final vol = quotes.last.volume;
        double volSum = 0;
        for (var i = 0; i < params.volumeMAperiod; i++) volSum += quotes[quotes.length - 1 - i].volume;
        final volMa = volSum / params.volumeMAperiod;
        if (vol < volMa * 1.5) return null;
      }
      return {'isLong': false};
    }
    return null;
  }

  // ═══════════════════════════════════════════════════
  //  WR 威廉指标信号（参数化 + 修复：WR>oversold(80)为超卖买入，
  //  WR<overbought(20)为超买卖出，与实际逻辑一致）
  //  WR = (HHV - C) / (HHV - LLV) * 100
  //  WR>80（价格贴近低点）= 超卖 → 潜在买入机会
  //  WR<20（价格贴近高点）= 超买 → 潜在卖出机会
  // ═══════════════════════════════════════════════════
  static Map<String, dynamic>? _wrSignal(List<StockQuote> quotes, StrategyParams params) {
    if (quotes.length < params.wrPeriod + 1) return null;

    final wr = _calcWrSingle(quotes, params.wrPeriod);
    final prevWr = _calcWrSingle(quotes.sublist(0, quotes.length - 1), params.wrPeriod);

    // WR从超卖区（>oversold）向上突破 → 价格从低位反弹 → 做多
    if (prevWr <= params.wrOversold && wr > params.wrOversold) return {'isLong': true};
    // WR从超买区（<overbought）向下跌破 → 价格从高位回落 → 做空
    if (prevWr >= params.wrOverbought && wr < params.wrOverbought) return {'isLong': false};
    return null;
  }

  static double _calcWrSingle(List<StockQuote> quotes, int period) {
    if (quotes.length < period) return 50.0;
    double highestHigh = quotes[quotes.length - period].high;
    double lowestLow = quotes[quotes.length - period].low;
    for (var i = quotes.length - period; i < quotes.length; i++) {
      if (quotes[i].high > highestHigh) highestHigh = quotes[i].high;
      if (quotes[i].low < lowestLow) lowestLow = quotes[i].low;
    }
    return highestHigh == lowestLow ? 50.0 : (highestHigh - quotes.last.close) / (highestHigh - lowestLow) * 100;
  }

  // ═══════════════════════════════════════════════════
  //  DMI 信号（参数化 + 修复：迭代计算真实ADX）
  //  +DI > -DI 且 ADX 上升（>threshold）→ 做多
  //  -DI > +DI 且 ADX 上升（>threshold）→ 做空
  //  ADX < threshold → 无趋势，不操作
  // ═══════════════════════════════════════════════════
  static Map<String, dynamic>? _dmiSignal(List<StockQuote> quotes, StrategyParams params) {
    if (quotes.length < params.dmiPeriod * 2 + 1) return null;

    final n = params.dmiPeriod;

    // ── 计算TR, +DM, -DM（逐日）──
    final trList = <double>[];
    final plusDmList = <double>[];
    final minusDmList = <double>[];

    for (var i = 1; i < quotes.length; i++) {
      final high = quotes[i].high;
      final low = quotes[i].low;
      final prevClose = quotes[i - 1].close;
      final tr = [high - low, (high - prevClose).abs(), (low - prevClose).abs()].reduce((a, b) => a > b ? a : b);
      trList.add(tr);

      final upMove = high - quotes[i - 1].high;
      final downMove = quotes[i - 1].low - low;
      final plusDm = (upMove > downMove && upMove > 0) ? upMove : 0.0;
      final minusDm = (downMove > upMove && downMove > 0) ? downMove : 0.0;
      plusDmList.add(plusDm);
      minusDmList.add(minusDm);
    }

    // ── Wilder平滑 ──
    double smoothTr(double tr) => tr; // 仅占位，Wilder平滑在下面循环中做
    double smoothPlusDm(double dm) => dm;
    double smoothMinusDm(double dm) => dm;

    // ── 迭代计算 DIx, ADX ──
    // ATR[i] = (ATR[i-1]*(n-1) + TR[i]) / n
    // +DI[i] = (+DM[i] / ATR[i]) * 100
    // -DI[i] = (-DM[i] / ATR[i]) * 100
    // DX[i] = |+DI - -DI| / (+DI + -DI) * 100
    // ADX[i] = (ADX[i-1]*(n-1) + DX[i]) / n

    double atr = 0, plusDi = 0, minusDi = 0, adx = 0;
    final diSeries = <(double, double, double)>[]; // (+DI, -DI, ADX)

    for (var i = n; i < trList.length; i++) {
      if (i == n) {
        // 初始化：前n个TR/DM之和
        double sumTr = 0, sumPlusDm = 0, sumMinusDm = 0;
        for (var j = 0; j < n; j++) {
          sumTr += trList[j];
          sumPlusDm += plusDmList[j];
          sumMinusDm += minusDmList[j];
        }
        atr = sumTr / n;
        plusDi = sumTr == 0 ? 0 : sumPlusDm / sumTr * 100;
        minusDi = sumTr == 0 ? 0 : sumMinusDm / sumTr * 100;
      } else {
        atr = (atr * (n - 1) + trList[i]) / n;
        plusDi = atr == 0 ? 0 : plusDmList[i] / atr * 100;
        minusDi = atr == 0 ? 0 : minusDmList[i] / atr * 100;
      }

      final dx = plusDi + minusDi == 0 ? 0.0 : (plusDi - minusDi).abs() / (plusDi + minusDi) * 100;
      if (i == n) {
        adx = dx.toDouble();
      } else {
        adx = (adx * (n - 1) + dx) / n;
      }
      diSeries.add((plusDi, minusDi, adx));
    }

    if (diSeries.length < 2) return null;
    final (plusDiCurr, minusDiCurr, adxCurr) = diSeries.last;
    final (_, __, adxPrev) = diSeries[diSeries.length - 2];

    // ADX < threshold：无趋势
    if (adxCurr < params.dmiTrendThreshold) return null;
    // ADX上升 + +DI > -DI → 上升趋势，做多
    if (adxCurr > adxPrev && plusDiCurr > minusDiCurr) return {'isLong': true};
    // ADX上升 + -DI > +DI → 下降趋势，做空
    if (adxCurr > adxPrev && minusDiCurr > plusDiCurr) return {'isLong': false};
    return null;
  }

  // ═══════════════════════════════════════════════════
  //  多策略共振信号（参数化）
  //  至少N个子策略同向时产生信号（默认2个）
  // ═══════════════════════════════════════════════════
  static Map<String, dynamic>? _multiSignal(List<StockQuote> quotes, StrategyParams params) {
    // 使用 MACD / KDJ / RSI 三个主流指标
    final macd = _macdSignal(quotes, params);
    final kdj = _kdjSignal(quotes, params);
    final rsi = _rsiSignal(quotes, params);

    int longCount = 0, shortCount = 0;
    if (macd != null) { macd['isLong'] ? longCount++ : shortCount++; }
    if (kdj != null) { kdj['isLong'] ? longCount++ : shortCount++; }
    if (rsi != null) { rsi['isLong'] ? longCount++ : shortCount++; }

    if (longCount >= 2) return {'isLong': true};
    if (shortCount >= 2) return {'isLong': false};
    return null;
  }

  // ═══════════════════════════════════════════════════
  //  CCI 信号（顺势指标）
  //  CCI 从 -100 以下上穿 → 做多
  //  CCI 从 +100 以上下穿 → 做空
  // ═══════════════════════════════════════════════════
  static Map<String, dynamic>? _cciSignal(List<StockQuote> quotes, StrategyParams params) {
    final n = params.cciPeriod;
    if (quotes.length < n + 1) return null;

    // 计算典型价格 TP = (High + Low + Close) / 3
    // CCI = (TP - MA(TP)) / (0.015 × 平均绝对偏差)
    final tpList = quotes.map((q) => (q.high + q.low + q.close) / 3.0).toList();

    // 计算 MA(TP)
    double calcMa(List<double> arr, int len) {
      double sum = 0;
      for (var i = 0; i < len; i++) sum += arr[arr.length - 1 - i];
      return sum / len;
    }

    final currentTp = tpList.last;
    final prevTp = tpList[tpList.length - 2];

    // MA of TP for current and previous
    final maCurrent = calcMa(tpList, n);
    final maPrev = calcMa(tpList.sublist(0, tpList.length - 1), n);

    // 计算平均绝对偏差
    double calcMad(List<double> arr, int len, double ma) {
      double sum = 0;
      for (var i = 0; i < len; i++) sum += (arr[arr.length - 1 - i] - ma).abs();
      return sum / len;
    }

    final madCurrent = calcMad(tpList, n, maCurrent);
    final madPrev = calcMad(tpList.sublist(0, tpList.length - 1), n, maPrev);

    // CCI = (TP - MA) / (0.015 × MAD)
    double calcCci(double tp, double ma, double mad) {
      if (mad == 0) return 0;
      return (tp - ma) / (0.015 * mad);
    }

    final cciCurrent = calcCci(currentTp, maCurrent, madCurrent);
    final cciPrev = calcCci(prevTp, maPrev, madPrev);

    // CCI 从 -100 以下上穿 → 做多
    if (cciPrev <= -100 && cciCurrent > -100) return {'isLong': true};
    // CCI 从 +100 以上下穿 → 做空
    if (cciPrev >= 100 && cciCurrent < 100) return {'isLong': false};
    return null;
  }

  // ═══════════════════════════════════════════════════
  //  StochRSI 信号（RSI 的 RSI，增强信号灵敏度）
  //  StochRSI = (RSI - minRSI) / (maxRSI - minRSI) × 100
  //  K = SMA(StochRSI, KPeriod)，D = SMA(K, DPeriod)
  //  金叉（K上穿D）在超卖区 → 做多；死叉（K下穿D）在超买区 → 做空
  // ═══════════════════════════════════════════════════
  static Map<String, dynamic>? _stochRsiSignal(List<StockQuote> quotes, StrategyParams params) {
    final rsiPeriod = params.rsiPeriod > 0 ? params.rsiPeriod : 14;
    final kPeriod = params.stochRsiKPeriod;
    final dPeriod = params.stochRsiDPeriod;
    final stoRsiPeriod = params.stochRsiPeriod;

    if (quotes.length < rsiPeriod + stoRsiPeriod + kPeriod + dPeriod) return null;

    // 先计算 RSI 系列
    final rsiData = RsiCalculator.calculate(quotes, period: rsiPeriod);
    if (rsiData.length < stoRsiPeriod + 1) return null;

    // 取最近 stoRsiPeriod 个 RSI 值
    final rsiValues = rsiData.map((r) => r.rsi).toList();

    // 计算 StochRSI：StochRSI[i] = (RSI[i] - min(RSI_lastN)) / (max(RSI_lastN) - min(RSI_lastN)) * 100
    final stoRsiValues = <double>[];
    for (var i = stoRsiPeriod - 1; i < rsiValues.length; i++) {
      final window = rsiValues.sublist(i - stoRsiPeriod + 1, i + 1);
      final minRsi = window.reduce((a, b) => a < b ? a : b);
      final maxRsi = window.reduce((a, b) => a > b ? a : b);
      if (maxRsi == minRsi) {
        stoRsiValues.add(50);
      } else {
        stoRsiValues.add((rsiValues[i] - minRsi) / (maxRsi - minRsi) * 100);
      }
    }

    if (stoRsiValues.length < kPeriod + 1) return null;

    // 计算 K = SMA(StochRSI, KPeriod)
    double sma(List<double> arr, int len) {
      double sum = 0;
      for (var i = arr.length - len; i < arr.length; i++) sum += arr[i];
      return sum / len;
    }

    double smaAt(List<double> arr, int endIdx, int len) {
      double sum = 0;
      for (var i = endIdx - len + 1; i <= endIdx; i++) sum += arr[i];
      return sum / len;
    }

    final kValues = <double>[];
    for (var i = kPeriod - 1; i < stoRsiValues.length; i++) {
      final window = stoRsiValues.sublist(i - kPeriod + 1, i + 1);
      kValues.add(window.reduce((a, b) => a + b) / kPeriod);
    }

    if (kValues.length < dPeriod + 1) return null;

    // 计算 D = SMA(K, DPeriod)
    final dValues = <double>[];
    for (var i = dPeriod - 1; i < kValues.length; i++) {
      final window = kValues.sublist(i - dPeriod + 1, i + 1);
      dValues.add(window.reduce((a, b) => a + b) / dPeriod);
    }

    if (dValues.length < 2) return null;

    final kCurr = kValues[kValues.length - 1];
    final kPrev = kValues[kValues.length - 2];
    final dCurr = dValues[dValues.length - 1];
    final dPrev = dValues[dValues.length - 2];

    // 20 以下为超卖区，80 以上为超买区
    final oversoldThreshold = 20.0;
    final overboughtThreshold = 80.0;

    // 金叉在超卖区 → 做多
    if (kPrev <= dPrev && kCurr > dCurr && kCurr < oversoldThreshold) return {'isLong': true};
    // 死叉在超买区 → 做空
    if (kPrev >= dPrev && kCurr < dCurr && kCurr > overboughtThreshold) return {'isLong': false};
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
