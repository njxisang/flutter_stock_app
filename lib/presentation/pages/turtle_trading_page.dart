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
  // ── 基础参数 ──
  double _accountBalance = 100000;
  double _riskPercent = 1.0;
  double _feeRate = 0.001;

  // ── 周期参数 ──
  int _period = 20;       // ATR计算周期
  int _entryPeriod = 20;  // 入场周期（突破该周期高点做多/低点做空）
  int _exitPeriod = 10;   // 离场周期（跌破该周期低点做多/突破高点做空）

  // ── 止损止盈 ──
  double _stopLossN = 2.0;      // 止损：入场价 ± N倍ATR
  double _profitTargetN = 4.0;  // 止盈：入场价 ± N倍ATR

  // ── 追踪止损 ──
  double _trailingStopAtr = 2.0;   // ATR倍数（跌破N日最低/突破N日最高）
  int _trailingStopPeriod = 20;    // 追踪止损周期

  // ── 仓位 ──
  int _maxPosition = 4;  // 最大持仓份数

  DateTime _startDate = DateTime.now().subtract(const Duration(days: 365));
  DateTime _endDate = DateTime.now();
  final _dateFormat = DateFormat('yyyy-MM-dd');
  bool _isLoadingData = false;
  bool _isRunningBacktest = false;
  TurtleBacktestResult? _backtestResult;
  List<TurtleBacktestResult> _compareResults = [];
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

          final filteredQuotes = state.stockData.quotes.where((q) {
            final d = DateTime.parse(q.date);
            return !d.isBefore(_startDate) && !d.isAfter(_endDate);
          }).toList();

          final quotes = filteredQuotes.isNotEmpty ? filteredQuotes : state.stockData.quotes;
          _currentQuotes = quotes;

          return Column(
            children: [
              _buildDateBar(context),
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

  Widget _buildDateBar(BuildContext context) {
    return Container(
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
              onPressed: () => _ensureDataForRange(context),
              tooltip: '补全数据',
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            ),
        ],
      ),
    );
  }

  Widget _buildSignalTab(List<StockQuote> quotes) {
    final details = TurtleTradingCalculator.calculate(
      quotes,
      period: _period,
      entryPeriod: _entryPeriod,
      exitPeriod: _exitPeriod,
      accountBalance: _accountBalance,
      riskPercent: _riskPercent,
      stopLossN: _stopLossN,
      profitTargetN: _profitTargetN,
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
          // 当前参数标签
          _buildParamChipRow(),
          const SizedBox(height: 12),

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
                      Expanded(child: _buildPriceCell('${_entryPeriod}日高', details.high20, AppColors.error)),
                      Expanded(child: _buildPriceCell('${_entryPeriod}日低', details.low20, AppColors.success)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(child: _buildPriceCell('${_exitPeriod}日高', details.high10, AppColors.error)),
                      Expanded(child: _buildPriceCell('${_exitPeriod}日低', details.low10, AppColors.success)),
                    ],
                  ),
                  const Divider(),
                  Row(
                    children: [
                      Expanded(child: _buildPriceCell('ATR($_period)', details.atr, Colors.blue)),
                      Expanded(child: _buildPriceCell('ATR(14)', details.atr14, Colors.blue)),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

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
                  _buildStep(3, '入场信号', '价格突破${_entryPeriod}日高点做多，跌破${_entryPeriod}日低点做空'),
                  _buildStep(4, '止损规则', '入场价 - ${_stopLossN.toStringAsFixed(0)}N为止损点'),
                  _buildStep(5, '离场信号', '做多：跌破${_exitPeriod}日低点；做空：突破${_exitPeriod}日高点'),
                  _buildStep(6, '止盈规则', '达到${_profitTargetN.toStringAsFixed(0)}N目标价止盈'),
                  if (_trailingStopAtr > 0)
                    _buildStep(7, '追踪止损', '跌破${_trailingStopPeriod}日最低-${_trailingStopAtr.toStringAsFixed(0)}N'),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildParamChipRow() {
    return Wrap(
      spacing: 6,
      runSpacing: 4,
      children: [
        _paramChip('入$_entryPeriod', '入场周期'),
        _paramChip('离$_exitPeriod', '离场周期'),
        _paramChip('${_stopLossN.toStringAsFixed(0)}N', '止损'),
        _paramChip('${_profitTargetN.toStringAsFixed(0)}N', '止盈'),
        _paramChip('追${_trailingStopPeriod}日', '追踪止损'),
        _paramChip('${_maxPosition}份', '最大仓位'),
      ],
    );
  }

  Widget _paramChip(String value, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.primary.withAlpha(20),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.primary.withAlpha(50)),
      ),
      child: Text(
        '$value $label',
        style: const TextStyle(fontSize: 11, color: AppColors.primary),
      ),
    );
  }

  Widget _buildBacktestTab(List<StockQuote> quotes) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 参数摘要
          _buildParameterSummaryCard(),
          const SizedBox(height: 12),

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
            _buildBacktestSummary(_backtestResult!),
            const SizedBox(height: 16),
            _buildBacktestMetrics(_backtestResult!),
            const SizedBox(height: 16),
            if (_backtestResult!.trades.isNotEmpty) ...[
              _buildExitDistribution(_backtestResult!),
              const SizedBox(height: 16),
              _buildTradeList(_backtestResult!),
            ],

            const SizedBox(height: 24),
            const Divider(),
            const SizedBox(height: 8),

            // 多参数比较
            _buildCompareSection(quotes),
          ],
        ],
      ),
    );
  }

  Widget _buildParameterSummaryCard() {
    return Card(
      color: AppColors.primary.withAlpha(10),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.tune, size: 16, color: AppColors.primary),
                const SizedBox(width: 6),
                const Text('当前参数', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.primary)),
                const Spacer(),
                TextButton(
                  onPressed: _showSettingsSheet,
                  child: const Text('修改', style: TextStyle(fontSize: 12)),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 16,
              runSpacing: 6,
              children: [
                _psItem('资金', '${_accountBalance.toStringAsFixed(0)}元'),
                _psItem('费率', '${(_feeRate * 100).toStringAsFixed(2)}%'),
                _psItem('风险', '${_riskPercent.toStringAsFixed(1)}%'),
                _psItem('ATR周期', '$_period日'),
                _psItem('入场周期', '$_entryPeriod日'),
                _psItem('离场周期', '$_exitPeriod日'),
                _psItem('止损', '${_stopLossN.toStringAsFixed(1)}N'),
                _psItem('止盈', '${_profitTargetN.toStringAsFixed(1)}N'),
                _psItem('追踪止损', '${_trailingStopPeriod}日/${_trailingStopAtr.toStringAsFixed(1)}N'),
                _psItem('最大仓位', '$_maxPosition份'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _psItem(String label, String value) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('$label: ', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
        Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildCompareSection(List<StockQuote> quotes) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text('多参数比较', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(width: 8),
            Text('（自动生成4组参数组合）',
                style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
          ],
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          height: 44,
          child: OutlinedButton.icon(
            icon: const Icon(Icons.compare_arrows, size: 18),
            label: const Text('运行多参数比较'),
            onPressed: () => _runCompare(quotes),
          ),
        ),
        if (_compareResults.isNotEmpty) ...[
          const SizedBox(height: 12),
          ..._compareResults.asMap().entries.map((entry) {
            final r = entry.value;
            final isSelected = identical(r, _backtestResult);
            return Card(
              color: isSelected ? AppColors.primary.withAlpha(15) : null,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
                side: isSelected
                    ? const BorderSide(color: AppColors.primary, width: 2)
                    : BorderSide.none,
              ),
              child: InkWell(
                onTap: () => setState(() => _backtestResult = r),
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  child: Row(
                    children: [
                      Container(
                        width: 24, height: 24,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: entry.key == 0
                              ? Colors.amber.withAlpha(50)
                              : AppColors.textSecondary.withAlpha(25),
                        ),
                        child: Center(
                          child: entry.key == 0
                              ? const Icon(Icons.emoji_events, size: 14, color: Colors.amber)
                              : Text('${entry.key + 1}', style: const TextStyle(fontSize: 12)),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(entry.key == 0 ? '激进方案' : entry.key == 1 ? '保守方案' : '参数组合${entry.key + 1}',
                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                            Text(_compareParamsDesc(entry.key),
                                style: const TextStyle(fontSize: 10, color: AppColors.textSecondary)),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            '${r.totalProfit >= 0 ? '+' : ''}${r.totalProfit.toStringAsFixed(0)}元',
                            style: TextStyle(
                              fontSize: 14, fontWeight: FontWeight.bold,
                              color: r.totalProfit >= 0 ? AppColors.success : AppColors.error,
                            ),
                          ),
                          Text(
                            '${r.totalProfit >= 0 ? '+' : ''}${(r.totalProfit / r.initialCapital * 100).toStringAsFixed(1)}%',
                            style: TextStyle(
                              fontSize: 11,
                              color: r.totalProfit >= 0 ? AppColors.success : AppColors.error,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(width: 8),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text('胜率', style: const TextStyle(fontSize: 10, color: AppColors.textSecondary)),
                          Text('${r.winRate.toStringAsFixed(0)}%', style: const TextStyle(fontSize: 12)),
                        ],
                      ),
                      const SizedBox(width: 8),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text('最大回撤', style: const TextStyle(fontSize: 10, color: AppColors.textSecondary)),
                          Text('${r.maxDrawdownPercent.toStringAsFixed(1)}%', style: const TextStyle(fontSize: 12)),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),
        ],
      ],
    );
  }

  String _compareParamsDesc(int idx) {
    final combos = [
      '激进：$_entryPeriod日/止损${(_stopLossN + 0.5).toStringAsFixed(1)}N/止盈${(_profitTargetN - 1).toStringAsFixed(1)}N',
      '保守：${(_entryPeriod + 10).toString()}日/止损${(_stopLossN - 0.5).toStringAsFixed(1)}N/止盈${(_profitTargetN + 1).toStringAsFixed(1)}N',
      '短期：${(_entryPeriod - 5).toString()}日/离场${(_exitPeriod - 2).toString()}日',
      '长期：${(_entryPeriod + 10).toString()}日/离场${(_exitPeriod + 5).toString()}日',
    ];
    return combos[idx.clamp(0, combos.length - 1)];
  }

  void _runCompare(List<StockQuote> quotes) async {
    setState(() => _isRunningBacktest = true);

    final combos = [
      {'entryPeriod': _entryPeriod, 'exitPeriod': _exitPeriod, 'stopLossN': _stopLossN + 0.5, 'profitTargetN': _profitTargetN - 1.0},
      {'entryPeriod': _entryPeriod + 10, 'exitPeriod': _exitPeriod, 'stopLossN': (_stopLossN - 0.5).clamp(0.5, 4.0), 'profitTargetN': _profitTargetN + 1.0},
      {'entryPeriod': (_entryPeriod - 5).clamp(5, 60), 'exitPeriod': (_exitPeriod - 2).clamp(3, 30), 'stopLossN': _stopLossN, 'profitTargetN': _profitTargetN},
      {'entryPeriod': (_entryPeriod + 10).clamp(5, 60), 'exitPeriod': (_exitPeriod + 5).clamp(3, 30), 'stopLossN': _stopLossN, 'profitTargetN': _profitTargetN},
    ];

    final futures = combos.map((c) async {
      return TurtleTradingCalculator.runTurtleBacktest(
        quotes,
        period: _period,
        entryPeriod: c['entryPeriod'] as int,
        exitPeriod: c['exitPeriod'] as int,
        accountBalance: _accountBalance,
        riskPercent: _riskPercent,
        feeRate: _feeRate,
        stopLossN: c['stopLossN'] as double,
        profitTargetN: c['profitTargetN'] as double,
        trailingStopAtr: _trailingStopAtr,
        trailingStopPeriod: _trailingStopPeriod,
        maxPosition: _maxPosition,
      );
    }).toList();

    final results = await Future.wait(futures);
    results.sort((a, b) => b.totalProfit.compareTo(a.totalProfit));

    if (mounted) {
      setState(() {
        _compareResults = results;
        _backtestResult = results.first;
        _isRunningBacktest = false;
      });
    }
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
    final trailingStopCount = r.trades.where((t) => t.exitReason == '追踪止损').length;

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
                if (trailingStopCount > 0) _buildMetric('追踪止损', '$trailingStopCount次', Colors.purple),
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
                    if (trailingStopCount > 0)
                      Expanded(flex: trailingStopCount, child: Container(height: 8, color: Colors.purple.withAlpha(180))),
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
                  if (trailingStopCount > 0)
                    Text('追踪止损${(trailingStopCount / r.totalTrades * 100).toStringAsFixed(0)}%',
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
      _compareResults = [];
    });
    try {
      final result = await Future(() => TurtleTradingCalculator.runTurtleBacktest(
        quotes,
        period: _period,
        entryPeriod: _entryPeriod,
        exitPeriod: _exitPeriod,
        accountBalance: _accountBalance,
        riskPercent: _riskPercent,
        feeRate: _feeRate,
        stopLossN: _stopLossN,
        profitTargetN: _profitTargetN,
        trailingStopAtr: _trailingStopAtr,
        trailingStopPeriod: _trailingStopPeriod,
        maxPosition: _maxPosition,
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

  Future<void> _ensureDataForRange(BuildContext context) async {
    setState(() => _isLoadingData = true);
    final state = this.context.read<StockBloc>().state;
    if (state is! StockLoaded) return;
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
        this.context.read<StockBloc>().add(LoadStock(state.stockData.symbol, startDate: start, endDate: end));
        ScaffoldMessenger.of(this.context).showSnackBar(SnackBar(content: Text('正在拉取 $start ~ $end 数据...')));
      }
    } else {
      ScaffoldMessenger.of(this.context).showSnackBar(const SnackBar(content: Text('数据已覆盖所选时间段')));
    }
    setState(() => _isLoadingData = false);
  }

  void _showSettingsSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.85,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (ctx, scrollController) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom,
            left: 16, right: 16, top: 16,
          ),
          child: StatefulBuilder(
            builder: (ctx, setSheetState) {
              return ListView(
                controller: scrollController,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('海龟参数设置', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // 基础设置
                  _sectionHeader('基础设置'),
                  _buildSliderTile('账户资金', _accountBalance, 10000, 1000000, (v) {
                    setSheetState(() => _accountBalance = v.roundToDouble());
                    setState(() {});
                  }, suffix: '元'),
                  _buildSliderTile('每份风险比例', _riskPercent, 0.1, 5.0, (v) {
                    setSheetState(() => _riskPercent = double.parse(v.toStringAsFixed(1)));
                    setState(() {});
                  }, suffix: '%'),
                  _buildSliderTile('交易费率', _feeRate * 100, 0.01, 0.5, (v) {
                    setSheetState(() => _feeRate = double.parse(v.toStringAsFixed(3)) / 100);
                    setState(() {});
                  }, suffix: '%', divisions: 49),

                  const SizedBox(height: 12),
                  _sectionHeader('周期参数'),
                  _buildSliderTile('ATR计算周期', _period.toDouble(), 10, 60, (v) {
                    setSheetState(() => _period = v.round());
                    setState(() {});
                  }, suffix: '日', divisions: 50),
                  _buildSliderTile('入场周期', _entryPeriod.toDouble(), 5, 60, (v) {
                    setSheetState(() => _entryPeriod = v.round());
                    setState(() {});
                  }, suffix: '日', divisions: 55),
                  _buildSliderTile('离场周期', _exitPeriod.toDouble(), 3, 30, (v) {
                    setSheetState(() => _exitPeriod = v.round());
                    setState(() {});
                  }, suffix: '日', divisions: 27),

                  const SizedBox(height: 12),
                  _sectionHeader('止损止盈'),
                  _buildSliderTile('止损倍数', _stopLossN, 0.5, 4.0, (v) {
                    setSheetState(() => _stopLossN = double.parse(v.toStringAsFixed(1)));
                    setState(() {});
                  }, suffix: 'N', divisions: 7),
                  _buildSliderTile('止盈倍数', _profitTargetN, 1.0, 8.0, (v) {
                    setSheetState(() => _profitTargetN = double.parse(v.toStringAsFixed(1)));
                    setState(() {});
                  }, suffix: 'N', divisions: 14),

                  const SizedBox(height: 12),
                  _sectionHeader('追踪止损（趋势破坏出场）'),
                  _buildSliderTile('追踪止损周期', _trailingStopPeriod.toDouble(), 5, 60, (v) {
                    setSheetState(() => _trailingStopPeriod = v.round());
                    setState(() {});
                  }, suffix: '日', divisions: 55),
                  _buildSliderTile('追踪止损ATR倍数', _trailingStopAtr, 0.5, 4.0, (v) {
                    setSheetState(() => _trailingStopAtr = double.parse(v.toStringAsFixed(1)));
                    setState(() {});
                  }, suffix: 'N', divisions: 7),

                  const SizedBox(height: 12),
                  _sectionHeader('仓位管理'),
                  _buildSliderTile('最大持仓份数', _maxPosition.toDouble(), 1, 8, (v) {
                    setSheetState(() => _maxPosition = v.round());
                    setState(() {});
                  }, suffix: '份', divisions: 7),

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
      ),
    );
  }

  Widget _sectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4, top: 4),
      child: Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.primary)),
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
                '${label.contains('周期') || label.contains('份数') ? value.round() : value.toStringAsFixed(label.contains('资金') ? 0 : label.contains('费率') ? 3 : 1)}$suffix',
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
          ],
        ),
        Slider(
          value: value.clamp(min, max),
          min: min,
          max: max,
          divisions: divisions ?? ((max - min) ~/ (label.contains('资金') ? 1000 : label.contains('费率') ? 0.01 : 0.1)),
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
