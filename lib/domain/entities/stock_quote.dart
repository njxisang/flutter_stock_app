import 'package:equatable/equatable.dart';

class StockQuote extends Equatable {
  final String date;
  final double open;
  final double high;
  final double low;
  final double close;
  final int volume;

  const StockQuote({
    required this.date,
    required this.open,
    required this.high,
    required this.low,
    required this.close,
    required this.volume,
  });

  @override
  List<Object?> get props => [date, open, high, low, close, volume];
}

class StockData extends Equatable {
  final String symbol;
  final String name;
  final List<StockQuote> quotes;

  const StockData({
    required this.symbol,
    required this.name,
    required this.quotes,
  });

  @override
  List<Object?> get props => [symbol, name, quotes];
}

class MacdData extends Equatable {
  final String date;
  final double dif;
  final double dea;
  final double macd;

  const MacdData({
    required this.date,
    required this.dif,
    required this.dea,
    required this.macd,
  });

  @override
  List<Object?> get props => [date, dif, dea, macd];
}

enum MacdSignal { goldenCross, deathCross, none }

class MacdSignalResult extends Equatable {
  final MacdSignal signal;
  final String date;

  const MacdSignalResult({required this.signal, required this.date});

  @override
  List<Object?> get props => [signal, date];
}

class RsiData extends Equatable {
  final String date;
  final double rsi;

  const RsiData({required this.date, required this.rsi});

  @override
  List<Object?> get props => [date, rsi];
}

class KdjData extends Equatable {
  final String date;
  final double k;
  final double d;
  final double j;

  const KdjData({required this.date, required this.k, required this.d, required this.j});

  @override
  List<Object?> get props => [date, k, d, j];
}

class BollData extends Equatable {
  final String date;
  final double upper;
  final double middle;
  final double lower;

  const BollData({required this.date, required this.upper, required this.middle, required this.lower});

  @override
  List<Object?> get props => [date, upper, middle, lower];
}

class MaData extends Equatable {
  final String date;
  final double ma5;
  final double ma10;
  final double ma20;
  final double ma60;

  const MaData({
    required this.date,
    required this.ma5,
    required this.ma10,
    required this.ma20,
    required this.ma60,
  });

  @override
  List<Object?> get props => [date, ma5, ma10, ma20, ma60];
}

class WrData extends Equatable {
  final String date;
  final double wr6;
  final double wr10;

  const WrData({required this.date, required this.wr6, required this.wr10});

  @override
  List<Object?> get props => [date, wr6, wr10];
}

class DmiData extends Equatable {
  final String date;
  final double pdi;
  final double mdi;
  final double adx;

  const DmiData({required this.date, required this.pdi, required this.mdi, required this.adx});

  @override
  List<Object?> get props => [date, pdi, mdi, adx];
}

class FactorResult extends Equatable {
  final String name;
  final String value;
  final int score;
  final String interpretation;

  const FactorResult({
    required this.name,
    required this.value,
    required this.score,
    required this.interpretation,
  });

  @override
  List<Object?> get props => [name, value, score, interpretation];
}

class MultiFactorReport extends Equatable {
  final int overallScore;
  final String rating;
  final List<FactorResult> factors;
  final String riskLevel;
  final List<String> recommendations;

  const MultiFactorReport({
    required this.overallScore,
    required this.rating,
    required this.factors,
    required this.riskLevel,
    required this.recommendations,
  });

  @override
  List<Object?> get props => [overallScore, rating, factors, riskLevel, recommendations];
}

class PricePrediction extends Equatable {
  final String date;
  final double predictedPrice;
  final String trend;
  final int confidence;
  final String reason;
  final double holtPrice;
  final double lrPrice;
  final double arimaPrice;

  const PricePrediction({
    required this.date,
    required this.predictedPrice,
    required this.trend,
    required this.confidence,
    required this.reason,
    required this.holtPrice,
    required this.lrPrice,
    required this.arimaPrice,
  });

  @override
  List<Object?> get props => [date, predictedPrice, trend, confidence, reason, holtPrice, lrPrice, arimaPrice];
}

class PredictionResult extends Equatable {
  final List<PricePrediction> predictions;
  final double currentPrice;
  final String symbol;
  final String name;
  final String overallTrend;
  final int overallConfidence;
  final List<String> technicalReasons;

  const PredictionResult({
    required this.predictions,
    required this.currentPrice,
    required this.symbol,
    required this.name,
    required this.overallTrend,
    required this.overallConfidence,
    required this.technicalReasons,
  });

  @override
  List<Object?> get props => [predictions, currentPrice, symbol, name, overallTrend, overallConfidence, technicalReasons];
}

enum TurtleSignalType { longBreakout, shortBreakout, longExit, shortExit, none }

class TurtleDetails extends Equatable {
  final double currentPrice;
  final double high20;
  final double low20;
  final double high10;
  final double low10;
  final double atr;
  final double atr14;
  final double entryPrice;
  final double stopLoss;
  final double takeProfit;
  final double riskReward;
  final double positionSize;
  final TurtleSignalType signal;
  final String signalExplanation;
  final List<String> stepDetails;

  const TurtleDetails({
    required this.currentPrice,
    required this.high20,
    required this.low20,
    required this.high10,
    required this.low10,
    required this.atr,
    required this.atr14,
    required this.entryPrice,
    required this.stopLoss,
    required this.takeProfit,
    required this.riskReward,
    required this.positionSize,
    required this.signal,
    required this.signalExplanation,
    required this.stepDetails,
  });

  @override
  List<Object?> get props => [currentPrice, high20, low20, high10, low10, atr, atr14, entryPrice, stopLoss, takeProfit, riskReward, positionSize, signal, signalExplanation, stepDetails];
}

class Trade extends Equatable {
  final String entryDate;
  final double entryPrice;
  final String exitDate;
  final double exitPrice;
  final int quantity;
  final bool isLong;
  final double profit;
  final double profitPercent;
  final int holdingDays;
  final double fee;

  const Trade({
    required this.entryDate,
    required this.entryPrice,
    required this.exitDate,
    required this.exitPrice,
    required this.quantity,
    required this.isLong,
    required this.profit,
    required this.profitPercent,
    required this.holdingDays,
    required this.fee,
  });

  @override
  List<Object?> get props => [entryDate, entryPrice, exitDate, exitPrice, quantity, isLong, profit, profitPercent, holdingDays, fee];
}

class BacktestResult extends Equatable {
  final int totalTrades;
  final int winningTrades;
  final int losingTrades;
  final double winRate;
  final double totalProfit;
  final double maxDrawdown;
  final double maxDrawdownPercent;
  final double sharpeRatio;
  final double kellyPercent;
  final String kellyFraction;
  final double avgWin;
  final double avgLoss;
  final double profitFactor;
  final List<Trade> trades;
  final double initialCapital;
  final double finalCapital;

  const BacktestResult({
    required this.totalTrades,
    required this.winningTrades,
    required this.losingTrades,
    required this.winRate,
    required this.totalProfit,
    required this.maxDrawdown,
    required this.maxDrawdownPercent,
    required this.sharpeRatio,
    required this.kellyPercent,
    required this.kellyFraction,
    required this.avgWin,
    required this.avgLoss,
    required this.profitFactor,
    required this.trades,
    required this.initialCapital,
    required this.finalCapital,
  });

  @override
  List<Object?> get props => [totalTrades, winningTrades, losingTrades, winRate, totalProfit, maxDrawdown, maxDrawdownPercent, sharpeRatio, kellyPercent, kellyFraction, avgWin, avgLoss, profitFactor, trades, initialCapital, finalCapital];
}

class RiskReport extends Equatable {
  final double expectedReturn30d;
  final double expectedReturn60d;
  final double sharpeRatio;
  final double winRate;
  final String shortTermTrend;
  final String mediumTermTrend;
  final String longTermTrend;
  final double atr;
  final double volatilityPercent;
  final double var95;
  final double maxDrawdown;
  final double beta;
  final double aggressiveStopLoss;
  final double conservativeStopLoss;
  final double trailingStopLoss;
  final int overallRiskLevel;
  final String riskRating;

  const RiskReport({
    required this.expectedReturn30d,
    required this.expectedReturn60d,
    required this.sharpeRatio,
    required this.winRate,
    required this.shortTermTrend,
    required this.mediumTermTrend,
    required this.longTermTrend,
    required this.atr,
    required this.volatilityPercent,
    required this.var95,
    required this.maxDrawdown,
    required this.beta,
    required this.aggressiveStopLoss,
    required this.conservativeStopLoss,
    required this.trailingStopLoss,
    required this.overallRiskLevel,
    required this.riskRating,
  });

  @override
  List<Object?> get props => [expectedReturn30d, expectedReturn60d, sharpeRatio, winRate, shortTermTrend, mediumTermTrend, longTermTrend, atr, volatilityPercent, var95, maxDrawdown, beta, aggressiveStopLoss, conservativeStopLoss, trailingStopLoss, overallRiskLevel, riskRating];
}

class WatchlistItem extends Equatable {
  final String symbol;
  final String name;

  const WatchlistItem({required this.symbol, required this.name});

  @override
  List<Object?> get props => [symbol, name];
}
