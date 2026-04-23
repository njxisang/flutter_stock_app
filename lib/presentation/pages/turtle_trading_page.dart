import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../domain/usecases/calculators/turtle_trading_calculator.dart';
import '../../domain/entities/stock_quote.dart';
import '../blocs/stock/stock_bloc.dart';

class TurtleTradingPage extends StatelessWidget {
  const TurtleTradingPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('海龟交易')),
      body: BlocBuilder<StockBloc, StockState>(
        builder: (context, state) {
          if (state is! StockLoaded) {
            return const Center(child: Text('请先加载股票数据'));
          }

          final details = TurtleTradingCalculator.calculate(
            state.stockData.quotes,
            accountBalance: 100000,
          );

          final signalColor = details.signal == TurtleSignalType.longBreakout
              ? Colors.green
              : details.signal == TurtleSignalType.shortBreakout
                  ? Colors.red
                  : Colors.grey;
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
                              Text('当前价: ${details.currentPrice.toStringAsFixed(2)}', style: const TextStyle(fontSize: 16, color: Colors.grey)),
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
                            Expanded(child: _buildPriceCell('20日高', details.high20, Colors.red)),
                            Expanded(child: _buildPriceCell('20日低', details.low20, Colors.green)),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(child: _buildPriceCell('10日高', details.high10, Colors.red)),
                            Expanded(child: _buildPriceCell('10日低', details.low10, Colors.green)),
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
                            Expanded(child: _buildTradeCell('入场价', details.entryPrice, Colors.green)),
                            Expanded(child: _buildTradeCell('止损价', details.stopLoss, Colors.red)),
                            Expanded(child: _buildTradeCell('止盈价', details.takeProfit, Colors.orange)),
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
                              color: Colors.grey.withAlpha(13),
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
          Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
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
          Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
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
                Text(desc, style: const TextStyle(fontSize: 12, color: Colors.grey)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
