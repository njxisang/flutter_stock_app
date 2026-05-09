import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../core/constants/app_constants.dart';

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
  bool _isLoadingData = false;

  DateTime _startDate = DateTime.now().subtract(const Duration(days: 365));
  DateTime _endDate = DateTime.now();

  final _dateFormat = DateFormat('yyyy-MM-dd');

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
                  const Icon(Icons.show_chart, size: 64, color: AppColors.textSecondary),
                  const SizedBox(height: 16),
                  const Text('请先在图表页面加载股票数据', style: TextStyle(fontSize: 16, color: AppColors.textSecondary)),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => context.go('/'),
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
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(state.stockData.name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                                  Text(state.stockData.symbol, style: const TextStyle(color: AppColors.textSecondary)),
                                ],
                              ),
                            ),
                            Text('${state.stockData.quotes.length}个数据点'),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                icon: const Icon(Icons.calendar_today, size: 16),
                                label: Text(_dateFormat.format(_startDate)),
                                onPressed: () => _selectDate(true),
                              ),
                            ),
                            const Padding(
                              padding: EdgeInsets.symmetric(horizontal: 8),
                              child: Text('至', style: TextStyle(color: AppColors.textSecondary)),
                            ),
                            Expanded(
                              child: OutlinedButton.icon(
                                icon: const Icon(Icons.calendar_today, size: 16),
                                label: Text(_dateFormat.format(_endDate)),
                                onPressed: () => _selectDate(false),
                              ),
                            ),
                            const SizedBox(width: 8),
                            if (_isLoadingData)
                              const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2))
                            else
                              IconButton(
                                icon: const Icon(Icons.refresh, size: 20),
                                onPressed: () => _ensureDataForRange(state),
                                tooltip: '补全该时间段数据',
                              ),
                          ],
                        ),
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
                        Text(_strategyDescriptions[_selectedStrategy] ?? '', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
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
                const SizedBox(height: 12),

                // Collapsed params summary when result is shown
                if (_result != null) ...[
                  ExpansionTile(
                    title: Text('策略: ${_getStrategyName(_selectedStrategy)} | 初始: ${_initialCapitalController.text} | ${_dateFormat.format(_startDate)}~${_dateFormat.format(_endDate)}',
                      style: const TextStyle(fontSize: 12)),
                    tilePadding: EdgeInsets.zero,
                    childrenPadding: EdgeInsets.zero,
                    children: [
                      _buildParamSummary(),
                    ],
                  ),
                  const SizedBox(height: 8),
                ],

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

  void _runBacktest(StockLoaded state) async {
    setState(() => _isRunning = true);

    final initialCapital = double.tryParse(_initialCapitalController.text) ?? 100000;
    final feeRate = double.tryParse(_feeRateController.text) ?? 0.001;
    final positionRatio = double.tryParse(_positionRatioController.text) ?? 1.0;

    // 按所选日期过滤数据
    final filteredQuotes = state.stockData.quotes.where((q) {
      final d = DateTime.parse(q.date);
      return !d.isBefore(_startDate) && !d.isAfter(_endDate);
    }).toList();

    if (filteredQuotes.isEmpty) {
      if (mounted) {
        setState(() => _isRunning = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('所选时间段内无数据，请先补全数据')),
        );
        _ensureDataForRange(state);
      }
      return;
    }

    try {
      final result = await Future(() => BacktestCalculator.runBacktest(
        filteredQuotes,
        _selectedStrategy,
        initialCapital: initialCapital,
        feeRate: feeRate,
        positionRatio: positionRatio,
      ));

      if (mounted) {
        setState(() {
          _result = result;
          _isRunning = false;
        });
      }
    } catch (e, st) {
      debugPrint('Backtest error: $e\n$st');
      if (mounted) {
        setState(() => _isRunning = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('回测出错: $e')),
        );
      }
    }
  }

  Future<void> _selectDate(bool isStart) async {
    final initial = isStart ? _startDate : _endDate;
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );
    if (picked == null) return;
    setState(() {
      if (isStart) {
        if (picked.isAfter(_endDate)) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('开始日期不能晚于结束日期')),
          );
          return;
        }
        _startDate = picked;
      } else {
        if (picked.isBefore(_startDate)) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('结束日期不能早于开始日期')),
          );
          return;
        }
        _endDate = picked;
      }
    });
    _result = null; // 日期变了清除上次结果
  }

  Future<void> _ensureDataForRange(StockLoaded state) async {
    setState(() => _isLoadingData = true);

    // 检查现有数据是否覆盖所选时间段
    final existingQuotes = state.stockData.quotes;
    DateTime? existingStart;
    DateTime? existingEnd;

    if (existingQuotes.isNotEmpty) {
      existingStart = DateTime.parse(existingQuotes.first.date);
      existingEnd = DateTime.parse(existingQuotes.last.date);
    }

    bool needFetch = existingQuotes.isEmpty;
    String start = _dateFormat.format(_startDate);
    String end = _dateFormat.format(_endDate);

    // 如果起始日期比现有数据更早，需要补
    if (!needFetch && existingStart != null && _startDate.isBefore(existingStart)) {
      needFetch = true;
    }
    // 如果结束日期比现有数据更晚，需要补
    if (!needFetch && existingEnd != null && _endDate.isAfter(existingEnd)) {
      needFetch = true;
    }

    if (needFetch) {
      if (mounted) {
        context.read<StockBloc>().add(LoadStock(
          state.stockData.symbol,
          startDate: start,
          endDate: end,
        ));
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('正在拉取 $start ~ $end 数据...')),
        );
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('数据已覆盖所选时间段，直接回测')),
      );
    }

    setState(() => _isLoadingData = false);
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
                color: isProfit ? AppColors.success.withAlpha(26) : AppColors.error.withAlpha(26),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildMetric('总收益', '${r.totalProfit >= 0 ? '+' : ''}${r.totalProfit.toStringAsFixed(2)}', isProfit ? AppColors.success : AppColors.error),
                  _buildMetric('收益率', '${r.totalProfit >= 0 ? '+' : ''}${(r.totalProfit / r.initialCapital * 100).toStringAsFixed(2)}%', isProfit ? AppColors.success : AppColors.error),
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
                    leading: Icon(t.profit >= 0 ? Icons.arrow_upward : Icons.arrow_downward, color: t.profit >= 0 ? AppColors.success : AppColors.error),
                    title: Text('${t.isLong ? "多" : "空"} ${t.entryDate} → ${t.exitDate}'),
                    subtitle: Text('入场:${t.entryPrice.toStringAsFixed(2)} 出场:${t.exitPrice.toStringAsFixed(2)}'),
                    trailing: Text('${t.profit >= 0 ? "+" : ""}${t.profit.toStringAsFixed(2)}', style: TextStyle(color: t.profit >= 0 ? AppColors.success : AppColors.error)),
                  )),
              if (r.trades.length > 10) Padding(
                padding: const EdgeInsets.all(8),
                child: Text('还有 ${r.trades.length - 10} 条记录...', style: const TextStyle(color: AppColors.textSecondary)),
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
        Text(label, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
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
          Text(label, style: const TextStyle(color: AppColors.textSecondary)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  Widget _buildParamSummary() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('本次参数', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
            const Divider(),
            _buildRow('策略', _getStrategyName(_selectedStrategy)),
            _buildRow('初始资金', _initialCapitalController.text),
            _buildRow('费率', _feeRateController.text),
            _buildRow('仓位比例', _positionRatioController.text),
          ],
        ),
      ),
    );
  }
}
