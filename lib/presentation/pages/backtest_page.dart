import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../domain/entities/stock_quote.dart';
import '../../domain/usecases/calculators/backtest_calculator.dart';
import '../blocs/stock/stock_bloc.dart';

class BacktestPage extends StatefulWidget {
  const BacktestPage({super.key});

  @override
  State<BacktestPage> createState() => _BacktestPageState();
}

class _BacktestPageState extends State<BacktestPage> {
  BacktestStrategy _selectedStrategy = BacktestStrategy.macd;
  final _initialCapitalController = TextEditingController(text: '100000');
  final _feeRateController = TextEditingController(text: '0.001');
  final _positionRatioController = TextEditingController(text: '1.0');
  BacktestResult? _result;
  bool _isRunning = false;

  final _strategyDescriptions = {
    BacktestStrategy.macd: 'MACD金叉买入，死叉卖出',
    BacktestStrategy.kdj: 'KDJ超卖买入，超买卖出',
    BacktestStrategy.rsi: 'RSI<30买入，RSI>70卖出',
    BacktestStrategy.boll: 'BOLL下轨买入，上轨卖出',
    BacktestStrategy.ma: 'MA多头排列买入，空头排列卖出',
    BacktestStrategy.wr: 'WR>80买入，WR<20卖出',
    BacktestStrategy.dmi: 'DMI趋势跟随策略',
    BacktestStrategy.multi: '多指标共振信号',
  };

  @override
  void dispose() {
    _initialCapitalController.dispose();
    _feeRateController.dispose();
    _positionRatioController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('回测'),
      ),
      body: BlocBuilder<StockBloc, StockState>(
        builder: (context, state) {
          if (state is! StockLoaded) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.show_chart, size: 64, color: Colors.grey),
                  const SizedBox(height: 16),
                  const Text('请先在图表页面加载股票数据', style: TextStyle(fontSize: 16, color: Colors.grey)),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('返回图表'),
                  ),
                ],
              ),
            );
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Stock Info
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(state.stockData.name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                              Text(state.stockData.symbol, style: const TextStyle(color: Colors.grey)),
                            ],
                          ),
                        ),
                        Text('${state.stockData.quotes.length}个数据点'),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Strategy Selection
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('策略选择', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        DropdownButtonFormField<BacktestStrategy>(
                          value: _selectedStrategy,
                          decoration: const InputDecoration(
                            border: OutlineInputBorder(),
                            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          ),
                          items: BacktestStrategy.values.map((s) {
                            return DropdownMenuItem(value: s, child: Text(_getStrategyName(s)));
                          }).toList(),
                          onChanged: (v) => setState(() => _selectedStrategy = v!),
                        ),
                        const SizedBox(height: 8),
                        Text(_strategyDescriptions[_selectedStrategy] ?? '', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Parameters
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('参数设置', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _initialCapitalController,
                                decoration: const InputDecoration(
                                  labelText: '初始资金',
                                  border: OutlineInputBorder(),
                                ),
                                keyboardType: TextInputType.number,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: TextField(
                                controller: _feeRateController,
                                decoration: const InputDecoration(
                                  labelText: '费率',
                                  border: OutlineInputBorder(),
                                ),
                                keyboardType: TextInputType.number,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _positionRatioController,
                          decoration: const InputDecoration(
                            labelText: '仓位比例 (0-1)',
                            border: OutlineInputBorder(),
                          ),
                          keyboardType: TextInputType.number,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Run Button
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: _isRunning ? null : () => _runBacktest(state),
                    child: _isRunning ? const CircularProgressIndicator() : const Text('运行回测'),
                  ),
                ),
                const SizedBox(height: 16),

                // Results
                if (_result != null) _buildResultCard(),
              ],
            ),
          );
        },
      ),
    );
  }

  String _getStrategyName(BacktestStrategy s) {
    return switch (s) {
      BacktestStrategy.macd => 'MACD',
      BacktestStrategy.kdj => 'KDJ',
      BacktestStrategy.rsi => 'RSI',
      BacktestStrategy.boll => 'BOLL',
      BacktestStrategy.ma => 'MA均线',
      BacktestStrategy.wr => 'WR威廉',
      BacktestStrategy.dmi => 'DMI',
      BacktestStrategy.multi => '多指标综合',
    };
  }

  void _runBacktest(StockLoaded state) {
    setState(() => _isRunning = true);

    final initialCapital = double.tryParse(_initialCapitalController.text) ?? 100000;
    final feeRate = double.tryParse(_feeRateController.text) ?? 0.001;
    final positionRatio = double.tryParse(_positionRatioController.text) ?? 1.0;

    final result = BacktestCalculator.runBacktest(
      state.stockData.quotes,
      _selectedStrategy,
      initialCapital: initialCapital,
      feeRate: feeRate,
      positionRatio: positionRatio,
    );

    setState(() {
      _result = result;
      _isRunning = false;
    });
  }

  Widget _buildResultCard() {
    final r = _result!;
    final isProfit = r.totalProfit >= 0;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Summary
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isProfit ? Colors.green.withAlpha(26) : Colors.red.withAlpha(26),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildMetric('总收益', '${r.totalProfit >= 0 ? '+' : ''}${r.totalProfit.toStringAsFixed(2)}', isProfit ? Colors.green : Colors.red),
                  _buildMetric('收益率', '${r.totalProfit >= 0 ? '+' : ''}${(r.totalProfit / r.initialCapital * 100).toStringAsFixed(2)}%', isProfit ? Colors.green : Colors.red),
                  _buildMetric('胜率', '${r.winRate.toStringAsFixed(1)}%', Colors.blue),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Key Metrics
            const Text('关键指标', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const Divider(),
            _buildRow('夏普比率', r.sharpeRatio.toStringAsFixed(2)),
            _buildRow('Kelly仓位', r.kellyFraction),
            _buildRow('盈亏比', r.profitFactor > 0 ? r.profitFactor.toStringAsFixed(2) : 'N/A'),
            _buildRow('最大回撤', '${r.maxDrawdownPercent.toStringAsFixed(2)}%'),
            _buildRow('平均盈利', r.avgWin.toStringAsFixed(2)),
            _buildRow('平均亏损', r.avgLoss.toStringAsFixed(2)),
            _buildRow('交易次数', '${r.totalTrades}'),
            _buildRow('盈利次数', '${r.winningTrades}'),
            _buildRow('亏损次数', '${r.losingTrades}'),
            _buildRow('初始资金', r.initialCapital.toStringAsFixed(2)),
            _buildRow('最终资金', r.finalCapital.toStringAsFixed(2)),

            // Trade List
            if (r.trades.isNotEmpty) ...[
              const SizedBox(height: 16),
              const Text('交易记录', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const Divider(),
              ...r.trades.take(10).map((t) => ListTile(
                    dense: true,
                    leading: Icon(t.profit >= 0 ? Icons.arrow_upward : Icons.arrow_downward, color: t.profit >= 0 ? Colors.green : Colors.red),
                    title: Text('${t.isLong ? "多" : "空"} ${t.entryDate} → ${t.exitDate}'),
                    subtitle: Text('入场:${t.entryPrice.toStringAsFixed(2)} 出场:${t.exitPrice.toStringAsFixed(2)}'),
                    trailing: Text('${t.profit >= 0 ? "+" : ""}${t.profit.toStringAsFixed(2)}', style: TextStyle(color: t.profit >= 0 ? Colors.green : Colors.red)),
                  )),
              if (r.trades.length > 10) Padding(
                padding: const EdgeInsets.all(8),
                child: Text('还有 ${r.trades.length - 10} 条记录...', style: const TextStyle(color: Colors.grey)),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildMetric(String label, String value, Color color) {
    return Column(
      children: [
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
        const SizedBox(height: 4),
        Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color)),
      ],
    );
  }

  Widget _buildRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}
