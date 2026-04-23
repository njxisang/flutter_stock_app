import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:go_router/go_router.dart';
import '../../domain/entities/stock_quote.dart';
import '../../domain/usecases/calculators/multi_factor_analyzer.dart';
import '../blocs/stock/stock_bloc.dart';

class AnalysisPage extends StatefulWidget {
  const AnalysisPage({super.key});

  @override
  State<AnalysisPage> createState() => _AnalysisPageState();
}

class _AnalysisPageState extends State<AnalysisPage> {
  bool _showMarketComparison = false;
  StockData? _indexData;
  bool _loadingIndex = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('多因子分析'),
        actions: [
          IconButton(
            icon: Icon(_showMarketComparison ? Icons.compare_arrows : Icons.show_chart),
            tooltip: '大盘对比',
            onPressed: () => _loadMarketComparison(context),
          ),
        ],
      ),
      body: BlocBuilder<StockBloc, StockState>(
        builder: (context, state) {
          if (state is! StockLoaded) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.analytics_outlined, size: 64, color: Colors.grey),
                  const SizedBox(height: 16),
                  const Text('请先加载股票数据', style: TextStyle(fontSize: 16, color: Colors.grey)),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('返回'),
                  ),
                ],
              ),
            );
          }

          final report = MultiFactorAnalyzer.analyze(state.stockData.quotes);
          final last = state.stockData.quotes.last;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Stock header
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
                              const SizedBox(height: 4),
                              Text('最新价: ${last.close.toStringAsFixed(2)}', style: const TextStyle(fontSize: 14)),
                            ],
                          ),
                        ),
                        _buildScoreCircle(report.overallScore),
                      ],
                    ),
                  ),
                ),

                // Risk level
                const SizedBox(height: 8),
                _buildRiskBadge(report.riskLevel),

                // 大盘对比图表
                if (_showMarketComparison && _indexData != null) ...[
                  const SizedBox(height: 16),
                  _buildMarketComparisonChart(state.stockData, _indexData!),
                ],

                // 7 indicator cards
                const SizedBox(height: 16),
                ...report.factors.map((f) => _buildFactorCard(f)),

                // 支撑/阻力位
                const SizedBox(height: 16),
                _buildSupportResistance(state.stockData.quotes),

                // 建议
                if (report.recommendations.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  _buildRecommendationsCard(report.recommendations),
                ],

                // 操作按钮
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(child: _buildActionButton(context, '信号分析', '/analysis/signal', Icons.flash_on)),
                    const SizedBox(width: 8),
                    Expanded(child: _buildActionButton(context, '风险分析', '/analysis/risk', Icons.security)),
                    const SizedBox(width: 8),
                    Expanded(child: _buildActionButton(context, '价格预测', '/analysis/prediction', Icons.trending_up)),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(child: _buildActionButton(context, '海龟交易', '/turtle', Icons.speed)),
                    const SizedBox(width: 8),
                    Expanded(child: _buildActionButton(context, '组合分析', '/portfolio', Icons.pie_chart)),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildScoreCircle(int score) {
    final color = score >= 3 ? Colors.green : score >= 0 ? Colors.orange : Colors.red;
    return Container(
      width: 72,
      height: 72,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color.withAlpha(25),
        border: Border.all(color: color, width: 3),
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('$score', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: color)),
            Text('评分', style: TextStyle(fontSize: 10, color: color)),
          ],
        ),
      ),
    );
  }

  Widget _buildRiskBadge(String riskLevel) {
    final color = riskLevel.contains('低') ? Colors.green : riskLevel.contains('高') ? Colors.red : Colors.orange;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: color.withAlpha(25),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color),
      ),
      child: Text('风险等级: $riskLevel', style: TextStyle(color: color, fontWeight: FontWeight.bold)),
    );
  }

  Widget _buildFactorCard(FactorResult f) {
    final scoreColor = f.score > 0 ? Colors.green : f.score < 0 ? Colors.red : Colors.grey;
    final statusText = f.score > 0 ? '利好' : f.score < 0 ? '利空' : '中性';
    final statusColor = f.score > 0 ? Colors.green : f.score < 0 ? Colors.red : Colors.grey;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ExpansionTile(
        leading: Container(
          width: 40, height: 40,
          decoration: BoxDecoration(shape: BoxShape.circle, color: scoreColor.withAlpha(25)),
          child: Center(child: Text('${f.score > 0 ? '+' : ''}${f.score}', style: TextStyle(color: scoreColor, fontWeight: FontWeight.bold))),
        ),
        title: Text(f.name, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(f.value, style: const TextStyle(fontSize: 12)),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(color: statusColor.withAlpha(25), borderRadius: BorderRadius.circular(8)),
                  child: Text(statusText, style: TextStyle(color: statusColor, fontSize: 12)),
                ),
                const SizedBox(height: 8),
                Text(f.interpretation, style: const TextStyle(fontSize: 13)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSupportResistance(List<StockQuote> quotes) {
    if (quotes.length < 20) return const SizedBox.shrink();
    final highs = quotes.map((q) => q.high).toList();
    final lows = quotes.map((q) => q.low).toList();
    final current = quotes.last.close;
    final recentHighs = highs.sublist(highs.length - 20);
    final recentLows = lows.sublist(lows.length - 20);
    final resistance = recentHighs.reduce((a, b) => a > b ? a : b);
    final support = recentLows.reduce((a, b) => a < b ? a : b);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('关键价位', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const Divider(),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildPriceInfo('阻力位', resistance, Colors.red),
                _buildPriceInfo('当前价', current, Colors.blue),
                _buildPriceInfo('支撑位', support, Colors.green),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPriceInfo(String label, double price, Color color) {
    return Column(
      children: [
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
        const SizedBox(height: 4),
        Text(price.toStringAsFixed(2), style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color)),
      ],
    );
  }

  Widget _buildRecommendationsCard(List<String> recs) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('投资建议', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const Divider(),
            ...recs.map((r) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.check_circle, size: 16, color: Colors.blue),
                  const SizedBox(width: 8),
                  Expanded(child: Text(r, style: const TextStyle(fontSize: 13))),
                ],
              ),
            )),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton(BuildContext context, String label, String route, IconData icon) {
    return ElevatedButton.icon(
      onPressed: () => context.go(route),
      icon: Icon(icon, size: 18),
      label: Text(label, style: const TextStyle(fontSize: 12)),
      style: ElevatedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 12),
        minimumSize: Size.zero,
      ),
    );
  }

  Widget _buildMarketComparisonChart(StockData stock, StockData index) {
    if (stock.quotes.isEmpty || index.quotes.isEmpty) return const SizedBox.shrink();

    final stockBase = stock.quotes.first.close;
    final indexBase = index.quotes.first.close;
    final minLen = stock.quotes.length < index.quotes.length ? stock.quotes.length : index.quotes.length;

    final stockSpots = <FlSpot>[];
    final indexSpots = <FlSpot>[];

    for (var i = 0; i < minLen; i++) {
      final sPct = (stock.quotes[i].close - stockBase) / stockBase * 100;
      final iPct = (index.quotes[i].close - indexBase) / indexBase * 100;
      stockSpots.add(FlSpot(i.toDouble(), sPct));
      indexSpots.add(FlSpot(i.toDouble(), iPct));
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('大盘对比 (相对涨跌)', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Row(
              children: [
                Container(width: 12, height: 3, color: Colors.blue),
                const SizedBox(width: 4),
                Text(stock.symbol, style: const TextStyle(fontSize: 12)),
                const SizedBox(width: 16),
                Container(width: 12, height: 3, color: Colors.orange),
                const SizedBox(width: 4),
                const Text('上证指数', style: TextStyle(fontSize: 12)),
              ],
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 160,
              child: LineChart(
                LineChartData(
                  lineBarsData: [
                    LineChartBarData(spots: stockSpots, color: Colors.blue, dotData: const FlDotData(show: false)),
                    LineChartBarData(spots: indexSpots, color: Colors.orange, dotData: const FlDotData(show: false)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _loadMarketComparison(BuildContext context) async {
    if (_indexData != null) {
      setState(() => _showMarketComparison = !_showMarketComparison);
      return;
    }
    setState(() => _loadingIndex = true);
    try {
      final bloc = context.read<StockBloc>();
      final indexData = await bloc.apiService.getStockData('000001');
      if (mounted) {
        setState(() {
          _indexData = indexData;
          _showMarketComparison = true;
          _loadingIndex = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loadingIndex = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('加载大盘数据失败: $e')));
      }
    }
  }
}
