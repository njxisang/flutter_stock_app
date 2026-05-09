import 'package:flutter/material.dart';
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

class _TurtleTradingPageState extends State<TurtleTradingPage> {
  double _accountBalance = 100000;
  double _riskPercent = 1.0;
  int _period = 20;

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
      ),
      body: BlocBuilder<StockBloc, StockState>(
        builder: (context, state) {
          if (state is! StockLoaded) {
            return const Center(child: Text('请先加载股票数据'));
          }

          final details = TurtleTradingCalculator.calculate(
            state.stockData.quotes,
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
                // Header with signal
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
                              Text('当前价: ${details.currentPrice.toStringAsFixed(2)}', style: const TextStyle(fontSize: 16, color: AppColors.textSecondary)),
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
                const SizedBox(height: 16),

                // Key price levels
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
                        Row(
                          children: [
                            Expanded(child: _buildPriceCell('2N (2×ATR)', details.atr * 2, Colors.purple)),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // Entry / Stop / Target
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

                // Turtle trading steps
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('海龟交易法规则', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                        const Divider(),
                        _buildStep(1, '确定N值（ATR）', 'N = 过去20日真实波幅的均值'),
                        _buildStep(2, '确定仓位', '每10000元账户资金，仓位 = 10000 / (N × 每点价值)'),
                        _buildStep(3, '入场信号', '价格突破20日高点做多，跌破20日低点做空'),
                        _buildStep(4, '止损规则', '入场价 - 2N为止损点，跌破则出局'),
                        _buildStep(5, '离场信号', '做多：价格跌破10日低点；做空：价格突破10日高点'),
                        _buildStep(6, '加仓规则', '每盈利0.5N可加仓一次，最多加4次'),
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

  void _showSettingsSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(ctx).viewInsets.bottom,
          left: 16,
          right: 16,
          top: 16,
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
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(ctx),
                        child: const Text('取消'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton(
                        onPressed: () => Navigator.pop(ctx),
                        child: const Text('应用'),
                      ),
                    ),
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
            Text('${label == 'N值周期' ? value.round() : value.toStringAsFixed(label == '账户资金' ? 0 : 1)}$suffix',
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
}
