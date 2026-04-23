import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:fl_chart/fl_chart.dart';
import 'dart:math';
import '../../domain/entities/stock_quote.dart';
import '../blocs/stock/stock_bloc.dart';

class PredictionPage extends StatelessWidget {
  const PredictionPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('价格预测')),
      body: BlocBuilder<StockBloc, StockState>(
        builder: (context, state) {
          if (state is! StockLoaded) {
            return const Center(child: Text('请先加载股票数据'));
          }

          final quotes = state.stockData.quotes;
          if (quotes.length < 30) {
            return const Center(child: Text('数据不足，需要至少30个数据点'));
          }

          final currentPrice = quotes.last.close;
          final recentQuotes = quotes.sublist(quotes.length - 60 > 0 ? quotes.length - 60 : 0);

          // Holt predictions
          final holtResult = _holtPredict(recentQuotes, 10);
          // LR predictions
          final lrResult = _lrPredict(recentQuotes, 10);
          // ARIMA-like (simple MA-based)
          final arimaResult = _arimaPredict(recentQuotes, 10);

          final currentChange = quotes.length > 1
              ? (currentPrice - quotes[quotes.length - 2].close) / quotes[quotes.length - 2].close * 100
              : 0.0;
          final avgConfidence = ((holtResult.confidence + lrResult.confidence + arimaResult.confidence) / 3).round();
          final trendText = currentChange > 1 ? '上涨' : currentChange < -1 ? '下跌' : '震荡';

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(state.stockData.name, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                              Text('当前价: ${currentPrice.toStringAsFixed(2)}', style: const TextStyle(color: Colors.grey)),
                              Text('${currentChange >= 0 ? '+' : ''}${currentChange.toStringAsFixed(2)}%', style: TextStyle(color: currentChange >= 0 ? Colors.green : Colors.red)),
                            ],
                          ),
                        ),
                        _buildTrendBadge(trendText, avgConfidence),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Prediction chart
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('预测图表 (历史 + 未来10日)', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            _legendDot(Colors.grey, '历史'),
                            const SizedBox(width: 12),
                            _legendDot(Colors.blue, 'Holt'),
                            const SizedBox(width: 12),
                            _legendDot(Colors.green, 'LR'),
                            const SizedBox(width: 12),
                            _legendDot(Colors.orange, 'ARIMA'),
                          ],
                        ),
                        const SizedBox(height: 8),
                        SizedBox(
                          height: 200,
                          child: _buildPredictionChart(quotes, holtResult, lrResult, arimaResult),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Prediction table
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('预测明细', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                        const Divider(),
                        _buildTableHeader(),
                        ...List.generate(10, (i) {
                          final baseDate = DateTime.now();
                          final predDate = baseDate.add(Duration(days: i + 1));
                          final dateStr = '${predDate.month}/${predDate.day}';
                          final holt = holtResult.prices.length > i ? holtResult.prices[i] : 0.0;
                          final lr = lrResult.prices.length > i ? lrResult.prices[i] : 0.0;
                          final arima = arimaResult.prices.length > i ? arimaResult.prices[i] : 0.0;
                          final avg = (holt + lr + arima) / 3;
                          final trend = avg > currentPrice ? '↑' : avg < currentPrice ? '↓' : '→';
                          return _buildTableRow(dateStr, avg, holt, lr, arima, trend);
                        }),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Algorithm confidence
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('算法置信度', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                        const Divider(),
                        _buildConfidenceRow('Holt双指数平滑', holtResult.confidence),
                        _buildConfidenceRow('线性回归', lrResult.confidence),
                        _buildConfidenceRow('ARIMA', arimaResult.confidence),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Technical reasons
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('技术面原因', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                        const Divider(),
                        ..._buildTechnicalReasons(state).map((r) => Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(Icons.circle, size: 6, color: Colors.blue),
                              const SizedBox(width: 8),
                              Expanded(child: Text(r, style: const TextStyle(fontSize: 13))),
                            ],
                          ),
                        )),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildTrendBadge(String trend, int confidence) {
    final color = trend == '上涨' ? Colors.green : trend == '下跌' ? Colors.red : Colors.grey;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withAlpha(25),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color),
      ),
      child: Column(
        children: [
          Text(trend, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color)),
          Text('置信度 ${'★' * (confidence ~/ 20)}${'☆' * (5 - confidence ~/ 20)}', style: TextStyle(fontSize: 10, color: color)),
        ],
      ),
    );
  }

  Widget _legendDot(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 10, height: 3, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2))),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 11)),
      ],
    );
  }

  Widget _buildPredictionChart(List<StockQuote> quotes, _PredResult holt, _PredResult lr, _PredResult arima) {
    final displayQuotes = quotes.length > 60 ? quotes.sublist(quotes.length - 60) : quotes;
    final lastIdx = displayQuotes.length;

    final histSpots = displayQuotes.asMap().entries.map((e) => FlSpot(e.key.toDouble(), e.value.close)).toList();

    final holtSpots = <FlSpot>[];
    final lrSpots = <FlSpot>[];
    final arimaSpots = <FlSpot>[];

    for (var i = 0; i < 10; i++) {
      holtSpots.add(FlSpot((lastIdx + i).toDouble(), holt.prices.length > i ? holt.prices[i] : 0));
      lrSpots.add(FlSpot((lastIdx + i).toDouble(), lr.prices.length > i ? lr.prices[i] : 0));
      arimaSpots.add(FlSpot((lastIdx + i).toDouble(), arima.prices.length > i ? arima.prices[i] : 0));
    }

    return LineChart(
      LineChartData(
        lineBarsData: [
          LineChartBarData(spots: histSpots, color: Colors.grey, dotData: const FlDotData(show: false)),
          LineChartBarData(spots: holtSpots, color: Colors.blue, dotData: const FlDotData(show: false)),
          LineChartBarData(spots: lrSpots, color: Colors.green, dotData: const FlDotData(show: false)),
          LineChartBarData(spots: arimaSpots, color: Colors.orange, dotData: const FlDotData(show: false)),
        ],
      ),
    );
  }

  Widget _buildTableHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: Colors.grey.shade300))),
      child: const Row(
        children: [
          Expanded(flex: 2, child: Text('日期', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
          Expanded(flex: 2, child: Text('综合', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
          Expanded(flex: 2, child: Text('Holt', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
          Expanded(flex: 2, child: Text('LR', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
          Expanded(flex: 2, child: Text('ARIMA', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
          Expanded(flex: 1, child: Text('趋势', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
        ],
      ),
    );
  }

  Widget _buildTableRow(String date, double avg, double holt, double lr, double arima, String trend) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: Colors.grey.shade200))),
      child: Row(
        children: [
          Expanded(flex: 2, child: Text(date, style: const TextStyle(fontSize: 11))),
          Expanded(flex: 2, child: Text(avg.toStringAsFixed(2), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500))),
          Expanded(flex: 2, child: Text(holt.toStringAsFixed(2), style: const TextStyle(fontSize: 11, color: Colors.blue))),
          Expanded(flex: 2, child: Text(lr.toStringAsFixed(2), style: const TextStyle(fontSize: 11, color: Colors.green))),
          Expanded(flex: 2, child: Text(arima.toStringAsFixed(2), style: const TextStyle(fontSize: 11, color: Colors.orange))),
          Expanded(flex: 1, child: Text(trend, style: TextStyle(fontSize: 12, color: trend == '↑' ? Colors.green : trend == '↓' ? Colors.red : Colors.grey))),
        ],
      ),
    );
  }

  Widget _buildConfidenceRow(String name, int confidence) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(width: 100, child: Text(name, style: const TextStyle(fontSize: 13))),
          Expanded(
            child: LinearProgressIndicator(
              value: confidence / 100,
              backgroundColor: Colors.grey.shade200,
              valueColor: AlwaysStoppedAnimation(confidence > 60 ? Colors.green : Colors.orange),
            ),
          ),
          const SizedBox(width: 8),
          Text('$confidence%', style: const TextStyle(fontSize: 12)),
        ],
      ),
    );
  }

  List<String> _buildTechnicalReasons(StockLoaded state) {
    final reasons = <String>[];
    final q = state.stockData.quotes;
    final last = q.last;

    if (state.macdSignal != null && state.macdSignal!.signal == MacdSignal.goldenCross) {
      reasons.add('MACD形成金叉，短期技术面偏多');
    } else if (state.macdSignal != null && state.macdSignal!.signal == MacdSignal.deathCross) {
      reasons.add('MACD形成死叉，短期技术面偏空');
    }

    if (state.rsiData.isNotEmpty) {
      final rsi = state.rsiData.last.rsi;
      if (rsi < 30) reasons.add('RSI处于超卖区域，可能存在反弹机会');
      else if (rsi > 70) reasons.add('RSI处于超买区域，回调风险较大');
    }

    if (state.kdjData.isNotEmpty) {
      final kdj = state.kdjData.last;
      if (kdj.k < 20) reasons.add('KDJ的K值处于低位，超卖信号');
    }

    if (state.dmiData.isNotEmpty && state.dmiData.last.adx > 25) {
      if (state.dmiData.last.pdi > state.dmiData.last.mdi) {
        reasons.add('DMI显示上升趋势明显');
      } else {
        reasons.add('DMI显示下降趋势明显');
      }
    }

    if (reasons.isEmpty) {
      reasons.add('各指标信号不一，建议等待明确信号后再操作');
    }

    return reasons;
  }

  // Holt double exponential smoothing
  _PredResult _holtPredict(List<StockQuote> quotes, int days) {
    if (quotes.length < 10) return _PredResult(List.filled(days, quotes.last.close), 50);
    final closes = quotes.map((q) => q.close).toList();
    var level = closes[0];
    var trend = closes.length > 1 ? closes[1] - closes[0] : 0.0;
    const alpha = 0.3, beta = 0.1;
    for (var i = 1; i < closes.length; i++) {
      final newLevel = alpha * closes[i] + (1 - alpha) * (level + trend);
      final newTrend = beta * (newLevel - level) + (1 - beta) * trend;
      level = newLevel;
      trend = newTrend;
    }
    final prices = List.generate(days, (i) => level + trend * (i + 1));
    final avgChange = (prices.last - closes.last) / closes.last;
    final confidence = (100 - (avgChange.abs() * 200).clamp(0, 50)).round();
    return _PredResult(prices, confidence.clamp(30, 90));
  }

  // Linear regression
  _PredResult _lrPredict(List<StockQuote> quotes, int days) {
    if (quotes.length < 5) return _PredResult(List.filled(days, quotes.last.close), 50);
    final n = quotes.length;
    final closes = quotes.map((q) => q.close).toList();
    var sumX = 0.0, sumY = 0.0, sumXY = 0.0, sumX2 = 0.0;
    for (var i = 0; i < n; i++) {
      sumX += i; sumY += closes[i]; sumXY += i * closes[i]; sumX2 += i * i;
    }
    final slope = (n * sumXY - sumX * sumY) / (n * sumX2 - sumX * sumX);
    final intercept = (sumY - slope * sumX) / n;
    final prices = List.generate(days, (i) => intercept + slope * (n + i));
    final avgChange = n > 0 ? (prices.last - closes.last) / closes.last : 0;
    final confidence = (100 - (avgChange.abs() * 200).clamp(0, 50)).round();
    return _PredResult(prices, confidence.clamp(30, 90));
  }

  // Simple ARIMA-like: MA + trend
  _PredResult _arimaPredict(List<StockQuote> quotes, int days) {
    if (quotes.length < 20) return _PredResult(List.filled(days, quotes.last.close), 40);
    final n = quotes.length;
    final closes = quotes.map((q) => q.close).toList();
    final maPeriod = 10;
    final recentMa = closes.sublist(n - maPeriod).reduce((a, b) => a + b) / maPeriod;
    final trendSlope = (closes.last - closes[n - maPeriod]) / maPeriod;
    final prices = List.generate(days, (i) => recentMa + trendSlope * (i + 1));
    return _PredResult(prices, 55);
  }
}

class _PredResult {
  final List<double> prices;
  final int confidence;
  _PredResult(this.prices, this.confidence);
}
