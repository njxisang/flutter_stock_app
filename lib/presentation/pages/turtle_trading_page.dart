import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/constants/app_constants.dart';

import 'package:flutter_bloc/flutter_bloc.dart';
import '../../domain/usecases/calculators/turtle_trading_calculator.dart';
import '../../domain/entities/stock_quote.dart';
import '../blocs/stock/stock_bloc.dart';

class TurtleTradingPage extends StatefulWidget {
  const TurtleTradingPage({super.key});

  @override
  State<TurtleTradingPage> createState() => _TurtleTradingPageState();
}

class _TurtleTradingPageState extends State<TurtleTradingPage> with SingleTickerProviderStateMixin {
  double _accountBalance = 100000;
  double _riskPercent = 1.0;
  int _period = 20;
  double _stopLossN = 2.0;
  double _profitTargetN = 4.0;

  DateTime _startDate = DateTime.now().subtract(const Duration(days: 365));
  DateTime _endDate = DateTime.now();
  final _dateFormat = DateFormat('yyyy-MM-dd');
  bool _isLoadingData = false;
  bool _isRunningBacktest = false;
  TurtleBacktestResult? _backtestResult;
  List<StockQuote> _currentQuotes = [];

  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('海龟交易'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: _showSettingsSheet,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: '信号'),
            Tab(text: '回测'),
          ],
        ),
      ),
      body: BlocBuilder<StockBloc, StockState>(
        builder: (context, state) {
          if (state is! StockLoaded) {
            return const Center(child: Text('请先加载股票数据'));
          }

          // 按所选日期过滤
          final filteredQuotes = state.stockData.quotes.where((q) {
            final d = DateTime.parse(q.date);
            return !d.isBefore(_startDate) && !d.isAfter(_endDate);
          }).toList();

          final quotes = filteredQuotes.isNotEmpty ? filteredQuotes : state.stockData.quotes;
          _currentQuotes = quotes;

          return Column(
            children: [
              // 日期选择条
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                color: Theme.of(context).cardColor,
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.calendar_today, size: 14),
                        label: Text(_dateFormat.format(_startDate), style: const TextStyle(fontSize: 12)),
                        onPressed: () => _selectDate(true),
                      ),
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 6),
                      child: Text('至', style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                    ),
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.calendar_today, size: 14),
                        label: Text(_dateFormat.format(_endDate), style: const TextStyle(fontSize: 12)),
                        onPressed: () => _selectDate(false),
                      ),
                    ),
                    const SizedBox(width: 4),
                    if (_isLoadingData)
                      const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                    else
                      IconButton(
                        icon: const Icon(Icons.refresh, size: 18),
                        onPressed: () => _ensureDataForRange(state),
                        tooltip: '补全数据',
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                      ),
                  ],
                ),
              ),
              // Tab 内容
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildSignalTab(_currentQuotes),
                    _buildBacktestTab(_currentQuotes),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSignalTab(List<StockQuote> quotes) {
    final details = TurtleTradingCalculator.calculate(
      quotes,
      period: _period,
      accountBalance: _accountBalance,
      riskPercent: _riskPercent,
    );

    final signalColor = details.signal == TurtleSignalType.longBreakout
        ? AppColors.success
        : details.signal == TurtleSignalType.shortBreakout
            ? AppColors.error
            : AppColors.textSecondary;
    final signalText = details.signal == TurtleSignalType.longBreakout
        ? '做多信号'
        : details.signal == TurtleSignalType.shortBreakout
            ? '做空信号'
            : '观望';

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 信号卡片
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(quotes.last.date, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                        const SizedBox(height: 4),
                        Text('${details.currentPrice.toStringAsFixed(2)}', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: signalColor.withAlpha(25),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: signalColor, width: 2),
                    ),
                    child: Column(
                      children: [
                        Icon(Icons.speed, color: signalColor, size: 24),
                        const SizedBox(height: 4),
                        Text(signalText, style: TextStyle(color: signalColor, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

          // 关键价位
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('关键价位', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  const Divider(),
                  Row(
                    children: [
                      Expanded(child: _buildPriceCell('20日高', details.high20, AppColors.error)),
                      Expanded(child: _buildPriceCell('20日低', details.low20, AppColors.success)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(child: _buildPriceCell('10日高', details.high10, AppColors.error)),
                      Expanded(child: _buildPriceCell('10日低', details.low10, AppColors.success)),
                    ],
                  ),
                  const Divider(),
                  Row(
                    children: [
                      Expanded(child: _buildPriceCell('ATR(14)', details.atr14, Colors.blue)),
                      Expanded(child: _buildPriceCell('ATR(20)', details.atr, Colors.blue)),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

          // 交易计划
          Card(
            color: Colors.blue.withAlpha(13),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('交易计划', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  const Divider(),
                  Row(
                    children: [
                      Expanded(child: _buildTradeCell('入场价', details.entryPrice, AppColors.success)),
                      Expanded(child: _buildTradeCell('止损价', details.stopLoss, AppColors.error)),
                      Expanded(child: _buildTradeCell('止盈价', details.takeProfit, AppColors.warning)),
                    ],
                  ),
                  const Divider(),
                  Row(
                    children: [
                      Expanded(child: _buildTradeCell('仓位大小', details.positionSize, Colors.blue)),
                      Expanded(child: _buildTradeCell('风报比', details.riskReward, Colors.purple)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (details.signalExplanation.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.textSecondary.withAlpha(13),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(details.signalExplanation, style: const TextStyle(fontSize: 13)),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

          // 规则说明
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('海龟交易法规则', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  const Divider(),
                  _buildStep(1, '确定N值（ATR）', 'N = 过去${_period}日真实波幅的均值'),
                  _buildStep(2, '确定仓位', '每份风险 = 账户${_riskPercent.toStringAsFixed(1)}% / N值'),
                  _buildStep(3, '入场信号', '价格突破20日高点做多，跌破20日低点做空'),
                  _buildStep(4, '止损规则', '入场价 - ${_stopLossN.toStringAsFixed(0)}N为止损点'),
                  _buildStep(5, '离场信号', '做多：跌破10日低点；做空：突破10日高点'),
                  _buildStep(6, '止盈规则', '达到${_profitTargetN.toStringAsFixed(0)}N目标价止盈'),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBacktestTab(List<StockQuote> quotes) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 运行按钮
          if (_backtestResult == null && !_isRunningBacktest)
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.play_arrow),
                label: Text('运行海龟回测（${quotes.length}个数据点）'),
                onPressed: () => _runBacktest(quotes),
              ),
            ),

          if (_isRunningBacktest)
            const Center(child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 12),
                Text('正在回测...', style: TextStyle(color: AppColors.textSecondary)),
              ],
            )),

          if (_backtestResult != null) ...[
            // 汇总卡片
            _buildBacktestSummary(_backtestResult!),
            const SizedBox(height: 16),

            // 关键指标
            _buildBacktestMetrics(_backtestResult!),
            const SizedBox(height: 16),

            // 出场分布
            if (_backtestResult!.trades.isNotEmpty) ...[
              _buildExitDistribution(_backtestResult!),
              const SizedBox(height: 16),

              // 交易记录
              _buildTradeList(_backtestResult!),
            ],
          ],
        ],
      ),
    );
  }

  Widget _buildBacktestSummary(TurtleBacktestResult r) {
    final isProfit = r.totalProfit >= 0;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isProfit ? AppColors.success.withAlpha(26) : AppColors.error.withAlpha(26),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildMetric('总收益', '${r.totalProfit >= 0 ? '+' : ''}${r.totalProfit.toStringAsFixed(0)}元', isProfit ? AppColors.success : AppColors.error),
                  _buildMetric('收益率', '${r.totalProfit >= 0 ? '+' : ''}${(r.totalProfit / r.initialCapital * 100).toStringAsFixed(1)}%', isProfit ? AppColors.success : AppColors.error),
                  _buildMetric('胜率', '${r.winRate.toStringAsFixed(1)}%', Colors.blue),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.refresh, size: 16),
                    label: const Text('重新运行', style: TextStyle(fontSize: 12)),
                    onPressed: () => _runBacktest(_currentQuotes),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBacktestMetrics(TurtleBacktestResult r) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('关键指标', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const Divider(),
            _buildRow('交易次数', '${r.totalTrades}'),
            _buildRow('盈利次数', '${r.winningTrades}'),
            _buildRow('亏损次数', '${r.losingTrades}'),
            _buildRow('盈亏比', r.profitFactor > 0 ? r.profitFactor.toStringAsFixed(2) : 'N/A'),
            _buildRow('平均盈利', '${r.avgWin.toStringAsFixed(0)}元'),
            _buildRow('平均亏损', '${r.avgLoss.toStringAsFixed(0)}元'),
            _buildRow('最大回撤', '${r.maxDrawdownPercent.toStringAsFixed(2)}%'),
            _buildRow('夏普比率', r.sharpeRatio.toStringAsFixed(2)),
            _buildRow('初始资金', '${r.initialCapital.toStringAsFixed(0)}元'),
            _buildRow('最终资金', '${r.finalCapital.toStringAsFixed(0)}元'),
          ],
        ),
      ),
    );
  }

  Widget _buildExitDistribution(TurtleBacktestResult r) {
    final stopLossCount = r.trades.where((t) => t.exitReason == '止损').length;
    final takeProfitCount = r.trades.where((t) => t.exitReason == '止盈').length;
    final trendBreakCount = r.trades.where((t) => t.exitReason == '趋势破坏').length;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('出场分布', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const Divider(),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildMetric('止损', '$stopLossCount次', AppColors.error),
                _buildMetric('止盈', '$takeProfitCount次', AppColors.warning),
                _buildMetric('趋势破坏', '$trendBreakCount次', Colors.blue),
              ],
            ),
            if (r.totalTrades > 0) ...[
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: Row(
                  children: [
                    if (stopLossCount > 0)
                      Expanded(flex: stopLossCount, child: Container(height: 8, color: AppColors.error.withAlpha(180))),
                    if (takeProfitCount > 0)
                      Expanded(flex: takeProfitCount, child: Container(height: 8, color: AppColors.warning.withAlpha(180))),
                    if (trendBreakCount > 0)
                      Expanded(flex: trendBreakCount, child: Container(height: 8, color: Colors.blue.withAlpha(180))),
                  ],
                ),
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('止损${(stopLossCount / r.totalTrades * 100).toStringAsFixed(0)}%',
                      style: const TextStyle(fontSize: 10, color: AppColors.textSecondary)),
                  Text('止盈${(takeProfitCount / r.totalTrades * 100).toStringAsFixed(0)}%',
                      style: const TextStyle(fontSize: 10, color: AppColors.textSecondary)),
                  Text('趋势破坏${(trendBreakCount / r.totalTrades * 100).toStringAsFixed(0)}%',
                      style: const TextStyle(fontSize: 10, color: AppColors.textSecondary)),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildTradeList(TurtleBacktestResult r) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('交易记录（共${r.trades.length}笔）', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const Divider(),
            ...r.trades.map((t) => ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading: Container(
                width: 40, height: 40,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: (t.isLong ? AppColors.success : AppColors.error).withAlpha(25),
                ),
                child: Center(
                  child: Text(t.isLong ? '多' : '空',
                      style: TextStyle(color: t.isLong ? AppColors.success : AppColors.error, fontWeight: FontWeight.bold, fontSize: 12)),
                ),
              ),
              title: Text('${t.entryDate} → ${t.exitDate}',
                  style: const TextStyle(fontSize: 12)),
              subtitle: Text(
                  '入场${t.entryPrice.toStringAsFixed(2)} 出场${t.exitPrice.toStringAsFixed(2)} | ${t.exitReason} | 持仓${t.holdingDays}天',
                  style: const TextStyle(fontSize: 10, color: AppColors.textSecondary)),
              trailing: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                      '${t.profit >= 0 ? '+' : ''}${t.profit.toStringAsFixed(0)}',
                      style: TextStyle(
                          color: t.profit >= 0 ? AppColors.success : AppColors.error,
                          fontWeight: FontWeight.bold,
                          fontSize: 13)),
                  Text(
                      '${t.profitPercent >= 0 ? '+' : ''}${t.profitPercent.toStringAsFixed(1)}%',
                      style: TextStyle(
                          color: t.profitPercent >= 0 ? AppColors.success : AppColors.error,
                          fontSize: 10)),
                ],
              ),
            )),
          ],
        ),
      ),
    );
  }

  // ── 以下为工具方法 ──

  void _runBacktest(List<StockQuote> quotes) async {
    if (quotes.length < _period + 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('数据不足，至少需要${_period + 1}个数据点')),
      );
      return;
    }
    setState(() {
      _isRunningBacktest = true;
      _backtestResult = null;
    });
    try {
      final result = await Future(() => TurtleTradingCalculator.runTurtleBacktest(
        quotes,
        period: _period,
        accountBalance: _accountBalance,
        riskPercent: _riskPercent,
        stopLossN: _stopLossN,
        profitTargetN: _profitTargetN,
      ));
      if (mounted) {
        setState(() {
          _backtestResult = result;
          _isRunningBacktest = false;
        });
      }
    } catch (e, st) {
      debugPrint('Turtle backtest error: $e\n$st');
      if (mounted) {
        setState(() => _isRunningBacktest = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('回测出错: $e')));
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
  }

  Future<void> _ensureDataForRange(StockLoaded state) async {
    setState(() => _isLoadingData = true);
    final existingQuotes = state.stockData.quotes;
    String start = _dateFormat.format(_startDate);
    String end = _dateFormat.format(_endDate);
    bool needFetch = existingQuotes.isEmpty;
    if (!needFetch) {
      final existingStart = DateTime.parse(existingQuotes.first.date);
      final existingEnd = DateTime.parse(existingQuotes.last.date);
      if (_startDate.isBefore(existingStart) || _endDate.isAfter(existingEnd)) needFetch = true;
    }
    if (needFetch) {
      if (mounted) {
        context.read<StockBloc>().add(LoadStock(state.stockData.symbol, startDate: start, endDate: end));
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('正在拉取 $start ~ $end 数据...')));
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('数据已覆盖所选时间段')));
    }
    setState(() => _isLoadingData = false);
  }

  void _showSettingsSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(ctx).viewInsets.bottom,
          left: 16, right: 16, top: 16,
        ),
        child: StatefulBuilder(
          builder: (ctx, setSheetState) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('海龟参数设置', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                _buildSliderTile('账户资金', _accountBalance, 10000, 1000000, (v) {
                  setSheetState(() => _accountBalance = v.roundToDouble());
                  setState(() {});
                }, suffix: '元'),
                const SizedBox(height: 8),
                _buildSliderTile('每份风险比例', _riskPercent, 0.1, 5.0, (v) {
                  setSheetState(() => _riskPercent = double.parse(v.toStringAsFixed(1)));
                  setState(() {});
                }, suffix: '%'),
                const SizedBox(height: 8),
                _buildSliderTile('N值周期', _period.toDouble(), 10, 60, (v) {
                  setSheetState(() => _period = v.round());
                  setState(() {});
                }, suffix: '日', divisions: 50),
                const SizedBox(height: 8),
                _buildSliderTile('止损倍数', _stopLossN, 1.0, 4.0, (v) {
                  setSheetState(() => _stopLossN = double.parse(v.toStringAsFixed(1)));
                  setState(() {});
                }, suffix: 'N', divisions: 6),
                const SizedBox(height: 8),
                _buildSliderTile('止盈倍数', _profitTargetN, 2.0, 8.0, (v) {
                  setSheetState(() => _profitTargetN = double.parse(v.toStringAsFixed(1)));
                  setState(() {});
                }, suffix: 'N', divisions: 12),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(child: OutlinedButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消'))),
                    const SizedBox(width: 12),
                    Expanded(child: FilledButton(onPressed: () => Navigator.pop(ctx), child: const Text('应用'))),
                  ],
                ),
                const SizedBox(height: 8),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildSliderTile(String label, double value, double min, double max, ValueChanged<double> onChanged, {String suffix = '', int? divisions}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: const TextStyle(fontSize: 14)),
            Text(
                '${label == 'N值周期' ? value.round() : value.toStringAsFixed(label == '账户资金' ? 0 : 1)}$suffix',
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
          ],
        ),
        Slider(
          value: value,
          min: min,
          max: max,
          divisions: divisions ?? ((max - min) ~/ (label == '账户资金' ? 1000 : 0.1)),
          onChanged: onChanged,
        ),
      ],
    );
  }

  Widget _buildPriceCell(String label, double value, Color color) {
    return Container(
      padding: const EdgeInsets.all(8),
      margin: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        border: Border.all(color: color.withAlpha(50)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Text(label, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
          const SizedBox(height: 2),
          Text(value.toStringAsFixed(2), style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: color)),
        ],
      ),
    );
  }

  Widget _buildTradeCell(String label, double value, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: color.withAlpha(13),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Text(label, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
          const SizedBox(height: 4),
          Text(value.toStringAsFixed(2), style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color)),
        ],
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

  Widget _buildStep(int num, String title, String desc) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 24, height: 24,
            decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.blue.withAlpha(25)),
            child: Center(child: Text('$num', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.blue))),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                Text(desc, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
