import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../domain/entities/stock_quote.dart';
import '../../domain/usecases/calculators/risk_analyzer.dart';
import '../blocs/stock/stock_bloc.dart';

class RiskAnalysisPage extends StatelessWidget {
  const RiskAnalysisPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('风险分析')),
      body: BlocBuilder<StockBloc, StockState>(
        builder: (context, state) {
          if (state is! StockLoaded) {
            return const Center(child: Text('请先加载股票数据'));
          }

          final report = RiskAnalyzer.analyze(state.stockData.quotes);

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Risk rating header
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
                              Text(state.stockData.symbol, style: const TextStyle(color: Colors.grey)),
                            ],
                          ),
                        ),
                        _buildRiskBadge(report),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // Expected return + metrics
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('收益预期', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                        const Divider(),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            _buildMetric('30日预期', '${report.expectedReturn30d.toStringAsFixed(1)}%', report.expectedReturn30d >= 0 ? Colors.green : Colors.red),
                            _buildMetric('60日预期', '${report.expectedReturn60d.toStringAsFixed(1)}%', report.expectedReturn60d >= 0 ? Colors.green : Colors.red),
                            _buildMetric('夏普比率', report.sharpeRatio.toStringAsFixed(2), report.sharpeRatio >= 0 ? Colors.green : Colors.red),
                            _buildMetric('胜率', '${report.winRate.toStringAsFixed(1)}%', Colors.blue),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // Trend
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('趋势判断', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                        const Divider(),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            _buildTrendChip('短期', report.shortTermTrend),
                            _buildTrendChip('中期', report.mediumTermTrend),
                            _buildTrendChip('长期', report.longTermTrend),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // Volatility
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('波动率分析', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                        const Divider(),
                        _buildRow('ATR(14)', report.atr.toStringAsFixed(3)),
                        _buildRow('年化波动率', '${report.volatilityPercent.toStringAsFixed(1)}%'),
                        _buildRow('Beta', report.beta.toStringAsFixed(2)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // Risk metrics
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('风险指标', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                        const Divider(),
                        _buildRow('最大回撤', '${report.maxDrawdown.toStringAsFixed(1)}%'),
                        _buildRow('VAR(95%)', '${report.var95.toStringAsFixed(2)}元'),
                        _buildRow('Beta', report.beta.toStringAsFixed(2)),
                        _buildRow('风险评级', report.riskRating),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // Stop loss
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('止损建议', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                        const Divider(),
                        _buildRow('激进止损', '${report.aggressiveStopLoss.toStringAsFixed(2)}', Colors.orange),
                        _buildRow('保守止损', '${report.conservativeStopLoss.toStringAsFixed(2)}', Colors.red),
                        _buildRow('移动止损', '${report.trailingStopLoss.toStringAsFixed(2)}', Colors.blue),
                        const SizedBox(height: 8),
                        const Text('建议仓位', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                        const SizedBox(height: 4),
                        _buildPositionRecommendation(report),
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

  Widget _buildRiskBadge(RiskReport report) {
    final color = report.riskRating.contains('低') ? Colors.green
        : report.riskRating.contains('高') ? Colors.red : Colors.orange;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: color.withAlpha(25),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color, width: 2),
      ),
      child: Column(
        children: [
          Text(report.riskRating, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color)),
          Text('风险指数: ${report.overallRiskLevel}', style: TextStyle(fontSize: 11, color: color)),
        ],
      ),
    );
  }

  Widget _buildMetric(String label, String value, Color color) {
    return Column(
      children: [
        Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
        const SizedBox(height: 4),
        Text(value, style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: color)),
      ],
    );
  }

  Widget _buildTrendChip(String period, String trend) {
    final color = trend == '上升' ? Colors.green : trend == '下降' ? Colors.red : Colors.grey;
    return Column(
      children: [
        Text(period, style: const TextStyle(fontSize: 12, color: Colors.grey)),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(color: color.withAlpha(25), borderRadius: BorderRadius.circular(12)),
          child: Text(trend, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 13)),
        ),
      ],
    );
  }

  Widget _buildRow(String label, String value, [Color? color]) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey)),
          Text(value, style: TextStyle(fontWeight: FontWeight.w500, color: color)),
        ],
      ),
    );
  }

  Widget _buildPositionRecommendation(RiskReport report) {
    // Simple Kelly-based position sizing
    final riskLevel = report.overallRiskLevel;
    final suggestedPct = riskLevel >= 6 ? 0.30
        : riskLevel >= 4 ? 0.50
        : riskLevel >= 2 ? 0.70
        : 0.85;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.blue.withAlpha(13),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text('建议仓位（风险调整）', style: TextStyle(fontSize: 13)),
          Text('${(suggestedPct * 100).toStringAsFixed(0)}%', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.blue)),
        ],
      ),
    );
  }
}
